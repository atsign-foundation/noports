#include "atcommons/memory_util.h"
#include "sshnpd/device_info.h"
#include "sshnpd/sshnpd.h"
#include "sshnpd/version.h"
#include <atchops/aes.h>
#include <atchops/iv.h>
#include <atchops/rsa.h>
#include <atchops/rsa_key.h>
#include <atchops/sha.h>
#include <atclient/atclient.h>
#include <atclient/atclient_utils.h>
#include <atclient/atkey.h>
#include <atclient/atkeys.h>
#include <atclient/atkeys_file.h>
#include <atclient/connection.h>
#include <atclient/connection_hooks.h>
#include <atclient/json.h>
#include <atclient/monitor.h>
#include <atclient/notify.h>
#include <atclient/string_utils.h>
#include <atlogger/atlogger.h>
#include <errno.h>
#include <libgen.h>
#include <mbedtls/psa_util.h>
#include <signal.h>
#include <sshnpd/daemon.h>
#include <sshnpd/file_utils.h>
#include <sshnpd/handler_commons.h>
#include <sshnpd/run_srv_process.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

#define FILENAME_BUFFER_SIZE 500
#define LOGGER_TAG "sshnpd - main"

// Signal handling
static void exit_handler(int sig) {
  atlogger_log("exit_handler", ATLOGGER_LOGGING_LEVEL_WARN, "Received signal: %d\n", sig);
  should_run = 0;
  exit(1);
}
static void child_exit_handler(int sig) {
  atlogger_log("child_exit_handler", ATLOGGER_LOGGING_LEVEL_WARN, "Received signal: %d\n", sig);
  int status;
  pid_t pid = waitpid(-1, &status, WNOHANG);
  if (pid > 0 && WIFEXITED(status)) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "pid %d exited\n", pid);
  }
}

static void free_if_not_null(void *ptr) {
  if (ptr != NULL) {
    free(ptr);
    ptr = NULL;
  }
}

int main(int argc, char **argv) {
  int res = 0;
  atlogger_set_logging_stream(stderr);

  // setup initial values for global variables
  is_child_process = false;
  should_run = 1;
  device_info_pos = 0;
  device_info_last_sent = NULL;
  device_info_attempts = 0;

  // device info
  struct atcommons_memlist memlist = atcommons_memlist_create(32);
#define safe_memlist(x) res = x;
  if (res > 0) {
    atcommons_memlist_failure_free(&memlist);
    return res;
  }

  // Catch sigint and pass to the handler
  signal(SIGINT, exit_handler);
  signal(SIGCHLD, child_exit_handler);

  // 1.  Load default values
  apply_default_values_to_sshnpd_params(&params);

  // 2.  Parse the command line arguments
  if (parse_sshnpd_params(&params, argc, (const char **)argv) != 0) {
    return 1;
  }

  // explicitly pass free_fn here because it is okay for these params to be null sometimes
  // normally this would be an error
  res = atcommons_memlist_add(&memlist, params.manager_list, true, free_if_not_null);
  res += atcommons_memlist_add(&memlist, params.normalized_manager_buf, true, free_if_not_null);
  // res won't overflow from summation as the function returns a max value of 2
  res += atcommons_memlist_add(&memlist, params.permitopen_hosts, true, free_if_not_null);
  res += atcommons_memlist_add(&memlist, params.permitopen_ports, true, free_if_not_null);
  res += atcommons_memlist_add(&memlist, params.permitopen_str, true, free_if_not_null);
  res += atcommons_memlist_add(&memlist, NULL, true, mbedtls_psa_crypto_free);
  if (res > 0) {
    free(params.manager_list);
    free(params.normalized_manager_buf);
    free(params.permitopen_hosts);
    free(params.permitopen_ports);
    free(params.permitopen_str);
    mbedtls_psa_crypto_free();
    exit(1);
  }

  // 3.  Configure the Logger
  // before the program exits
  if (params.verbose) {
    printf("Verbose mode enabled\n");
    atlogger_set_logging_level(ATLOGGER_LOGGING_LEVEL_DEBUG);
  } else {
    atlogger_set_logging_level(ATLOGGER_LOGGING_LEVEL_INFO);
  }

  // 4. Validate the environment
  home_dir = getenv(HOMEVAR);
  if (home_dir == NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Unable to determine your home directory: please "
                 "set %s environment variable\n",
                 HOMEVAR);
    atcommons_memlist_failure_free(&memlist);
    return 1;
  }

  const char *username = getenv(USERVAR);
  if (!params.hide && username == NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Unable to determine your username: please "
                 "set %s environment variable\n",
                 USERVAR);
    atcommons_memlist_failure_free(&memlist);
    return 1;
  }

  if (!should_run) {
    atcommons_memlist_failure_free(&memlist);
    return 1;
  }

  // 5.  Load the atKeys
  atclient_atkeys_init(&atkeys);
  res = atcommons_memlist_add(&memlist, &atkeys, true, atclient_atkeys_free);
  if (res != 0) {
    atclient_atkeys_free(&atkeys);
    atcommons_memlist_failure_free(&memlist);
    return res;
  }
  if (params.key_file == NULL) {
    char filename[FILENAME_BUFFER_SIZE];
    snprintf(filename, FILENAME_BUFFER_SIZE, "%s/.atsign/keys/%s_key.atKeys", home_dir, params.atsign);
    res = atclient_atkeys_populate_from_path(&atkeys, filename);
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Using atkeysfile: %s\n", filename);
  } else {
    res = atclient_atkeys_populate_from_path(&atkeys, (const char *)params.key_file);
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Using atkeysfile: %s\n", (const char *)params.key_file);
  }

  if (res != 0 || !should_run) {
    if (res != 0) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Unable to load the atkeys file\n");
    }
    atcommons_memlist_failure_free(&memlist);
    return res;
  }

  // 5.3 create a key copy for signing
  atchops_rsa_key_private_key_init(&signingkey);
  res = atcommons_memlist_add(&memlist, &signingkey, true, atchops_rsa_key_private_key_free);
  if (res != 0) {
    atchops_rsa_key_private_key_free(&signingkey);
    atcommons_memlist_failure_free(&memlist);
    return res;
  }

  res = atchops_rsa_key_private_key_clone(&atkeys.encrypt_private_key, &signingkey);
  if (res != 0) {
    atcommons_memlist_failure_free(&memlist);
    return res;
  }

  // 6. Get root host and port
  const size_t host_name_max_length = 253;
  const size_t root_host_size = host_name_max_length + 1; // 253 is the max length of a hostname, +1 for null terminator
  char *root_host = malloc(sizeof(char) * root_host_size); 
  if(root_host == NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to allocate memory for root_host\n");
    atcommons_memlist_failure_free(&memlist);
    res = 1;
    return res;
  }
  res = atcommons_memlist_add(&memlist, root_host, true, free_if_not_null);
  if (res != 0) {
    free(root_host);
    atcommons_memlist_failure_free(&memlist);
    return res;
  }
  memset(root_host, 0, sizeof(char) * root_host_size);
  uint16_t root_port = 0;
  if (params.root_domain != NULL) {
    // root_domain is something like 'root.atsign.wtf:64'
    // get the host and port and set them
    char *colon_pos = strchr(params.root_domain, ':');
    if (colon_pos != NULL) {
      size_t host_len = colon_pos - params.root_domain;
      if (host_len >= host_name_max_length) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Root domain host name is too long (it is >= %lu\n", host_name_max_length);
        atcommons_memlist_failure_free(&memlist);
        res = 1;
        return res;
      }
      snprintf(root_host, root_host_size, "%.*s", (int)host_len, params.root_domain);
      char *port_str = colon_pos + 1;
      root_port = (uint16_t)atoi(port_str);
      if (root_port == 0) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Root domain port is not a valid number: %s\n", port_str);
        atcommons_memlist_failure_free(&memlist);
        res = 1;
        return res;
      }
    } else {
      // no port specified, use the default port
      snprintf(root_host, root_host_size, "%s", params.root_domain);
      root_port = DEFAULT_ROOT_PORT;
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_INFO, "Using root_host: \"%s\" and root_port: %d\n", root_host, root_port);
    }
  } else {
    // use the default root domain
    snprintf(root_host, root_host_size, "%s", DEFAULT_ROOT_HOST);
    root_port = DEFAULT_ROOT_PORT;
  }
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Using root_host: \"%s\" and root_port: %d\n", root_host, root_port);

  // 7.a Initialize the monitor atclient
  atclient_monitor_init(&monitor_ctx);
  res = atcommons_memlist_add(&memlist, &monitor_ctx, false, atclient_monitor_free);
  if (res != 0) {
    atclient_monitor_free(&monitor_ctx);
    atcommons_memlist_failure_free(&memlist);
    return res;
  }

  // 7.a.2 Build monitor_options
  atclient_authenticate_options_init(&monitor_options);
  res = atcommons_memlist_add(&memlist, &monitor_options, true, atclient_authenticate_options_free);
  if (res != 0) {
    atclient_authenticate_options_free(&monitor_options);
    atcommons_memlist_failure_free(&memlist);
    return res;
  }
  atclient_authenticate_options_set_atdirectory_host(&monitor_options, root_host);
  atclient_authenticate_options_set_atdirectory_port(&monitor_options, root_port);

  // 7.a.3 pkam auth the monitor client
  atclient_monitor_set_read_timeout(&monitor_ctx, MONITOR_READ_TIMEOUT_MS); // 5 seconds for timeout
  res = atclient_monitor_pkam_authenticate(&monitor_ctx, params.atsign, &atkeys, &monitor_options);
  if (res != 0 || !should_run) {
    atcommons_memlist_failure_free(&memlist);
    return res;
  }

  // 7.b Initialize the worker atclient
  atclient_init(&worker);
  res = atcommons_memlist_add(&memlist, &worker, false, atclient_free);
  if (res != 0) {
    atclient_free(&worker);
    atcommons_memlist_failure_free(&memlist);
    return res;
  }

  atclient_authenticate_options_init(&worker_options);
  res = atcommons_memlist_add(&memlist, &worker_options, true, atclient_authenticate_options_free);
  if(res != 0) {
    atclient_authenticate_options_free(&worker_options);
    atcommons_memlist_failure_free(&memlist);
    return res;
  }
  atclient_authenticate_options_set_atdirectory_host(&worker_options, root_host);
  atclient_authenticate_options_set_atdirectory_port(&worker_options, root_port);


  res = atclient_pkam_authenticate(&worker, params.atsign, &atkeys, &worker_options, NULL);
  if (res != 0 || !should_run) {
    atcommons_memlist_failure_free(&memlist);
    return res;
  }

  // 7.c setup hooks to restart the worker atclient
  res = set_worker_hooks();
  if (res != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to set atclient hooks\n");
    atcommons_memlist_failure_free(&memlist);
    return res;
  }

  // 8. cache the manager public keys
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Manager List: %lu - ", params.manager_list_len);
  for (size_t i = 0; i < params.manager_list_len; i++) {
    printf("%s,", params.manager_list[i]);

    // char public_encryption_key[1024];
    // atclient_get_public_encryption_key(&atclient, params.manager_list[i], &public_encryption_key);
    // TODO: finish caching
  }
  printf("\n");
  if (params.policy == NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Policy Manager: NULL\n");
  } else {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Policy Manager: %s\n", params.policy);
  }

  if (!should_run) {
    atcommons_memlist_failure_free(&memlist);
    return res;
  }

  cJSON *ping_response_json = cJSON_CreateObject();

  cJSON_AddItemToObject(ping_response_json, "devicename", cJSON_CreateString(params.device));
  cJSON_AddItemToObject(ping_response_json, "version", cJSON_CreateString(SSHNPD_VERSION));
  cJSON_AddItemToObject(ping_response_json, "corePackageVersion", cJSON_CreateString("c0.1.0"));

  cJSON *supported_features = cJSON_CreateObject();
  cJSON_AddItemToObject(supported_features, "srAuth", cJSON_CreateBool(true));
  cJSON_AddItemToObject(supported_features, "srE2ee", cJSON_CreateBool(true));
  cJSON_bool acceptsPublicKeys = params.sshpublickey;
  cJSON_AddItemToObject(supported_features, "acceptsPublicKeys", cJSON_CreateBool(acceptsPublicKeys));
  cJSON_AddItemToObject(supported_features, "supportsPortChoice", cJSON_CreateBool(true));
  cJSON_AddItemToObject(supported_features, "adjustableTimeout", cJSON_CreateBool(true));
  cJSON_AddItemToObject(supported_features, "supportsRamEscr", cJSON_CreateBool(true));
  cJSON_AddItemToObject(supported_features, "twinKeys", cJSON_CreateBool(true));
  cJSON_AddItemToObject(ping_response_json, "supportedFeatures", supported_features);

  cJSON *auth_modes = cJSON_CreateArray();
  cJSON_AddItemToArray(auth_modes, cJSON_CreateString("payload"));
  cJSON_AddItemToArray(auth_modes, cJSON_CreateString("escr"));
  cJSON_AddItemToObject(ping_response_json, "authModes", auth_modes);

  // Clients pre-fetch this uri via the relay so the relay can verify our escr
  // auth signatures
  char *signing_key_uri = public_signing_key_uri(&atkeys, params.atsign);
  if (signing_key_uri == NULL) {
    atcommons_memlist_failure_free(&memlist);
    return 1;
  }
  res = atcommons_memlist_add(&memlist, signing_key_uri, true, free_if_not_null);
  if (res != 0) {
    free(signing_key_uri);
    atcommons_memlist_failure_free(&memlist);
    return res;
  }
  cJSON_AddItemToObject(ping_response_json, "publicSigningKeyUri", cJSON_CreateString(signing_key_uri));

  cJSON *allowed_services = cJSON_CreateArray();
  char *buf = malloc(sizeof(char) * 1024);
  for (size_t i = 0; i < params.permitopen_len; i++) {
    sprintf(buf, "%s:%u", params.permitopen_hosts[i], (unsigned int)params.permitopen_ports[i]);
    cJSON_AddItemToArray(allowed_services, cJSON_CreateString(buf));
  }
  free(buf);

  cJSON_AddItemToObject(ping_response_json, "allowedServices", allowed_services);

  //
  ping_response = cJSON_PrintUnformatted(ping_response_json);
  cJSON_Delete(ping_response_json);

  if (ping_response == NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "cJSON_Print failed\n");
    atcommons_memlist_failure_free(&memlist);
    return res;
  }
  res = atcommons_memlist_add(&memlist, ping_response, true, NULL);
  if (res != 0) {
    free(ping_response);
    atcommons_memlist_failure_free(&memlist);
    return res;
  }
  if (!should_run) {
    atcommons_memlist_failure_free(&memlist);
    return res;
  }

  // 8.b Publish the public signing key (the PKAM public key) at the uri
  // advertised in the ping response, so relays can verify escr auth
  // signatures. Failure is not fatal: legacy relay auth still works.
  {
    const char *enrollment_id = "primary";
    if (atkeys.enrollment_id != NULL && atkeys.enrollment_id[0] != '\0') {
      enrollment_id = atkeys.enrollment_id;
    }
    char sk_keyname[128];
    snprintf(sk_keyname, sizeof(sk_keyname), "_apsk.%s", enrollment_id);

    atclient_atkey sk_key;
    atclient_atkey_init(&sk_key);
    res = atclient_atkey_create_public_key(&sk_key, sk_keyname, params.atsign, "a.__e");
    if (res == 0) {
      char *existing = NULL;
      if (atclient_get_public_key(&worker, &sk_key, &existing, NULL) == 0 && existing != NULL) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Public signing key already published at %s\n",
                     signing_key_uri);
        free(existing);
      } else {
        res = atclient_put_public_key(&worker, &sk_key, atkeys.pkam_public_key_base64, NULL, NULL);
        if (res == 0) {
          atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_INFO, "Published public signing key at %s\n",
                       signing_key_uri);
        }
      }
    }
    if (res != 0) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_WARN,
                   "Failed to publish the public signing key (%d) - escr relay auth will not work this session\n", res);
      res = 0;
    }
    atclient_atkey_free(&sk_key);
  }

  // 9. Start the device refresh loop - if hide is off
  res = handle_username_keys(&worker, (const char **)params.manager_list, params.manager_list_len, username,
                             params.device, params.atsign, !params.hide);
  if (res != 0) {
    atcommons_memlist_failure_free(&memlist);
    return res;
  }

  // 10. Start monitor
  size_t regexlen = strlen(params.device) + strlen(SSHNP_NS) + 3;
  regex = malloc(sizeof(char) * regexlen); // needs to be declared before any gotos
  if (regex == NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to allocate memory for the monitor regex\n");
    atcommons_memlist_failure_free(&memlist);
    return res;
  }
  res = atcommons_memlist_add(&memlist, regex, true, NULL);
  if (res != 0) {
    free(regex);
    atcommons_memlist_failure_free(&memlist);
    return res;
  }

  snprintf(regex, regexlen, "%s.%s@", params.device, SSHNP_NS);
  res = atclient_monitor_start(&monitor_ctx, regex);
  if (res != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to start monitor\n");
    atcommons_memlist_failure_free(&memlist);
    return res;
  }

  if (!should_run) {
    atcommons_memlist_failure_free(&memlist);
    return res;
  }

  // 11. Get a pointer to the authorized_keys file
  authkeys_filename = malloc(sizeof(char) + (strlen(home_dir) + 22));
  if (authkeys_filename == NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to allocate memory for authkeys_filename\n");
    atcommons_memlist_failure_free(&memlist);
    return res;
  }
  res = atcommons_memlist_add(&memlist, authkeys_filename, true, NULL);
  if (res != 0) {
    free(authkeys_filename);
    atcommons_memlist_failure_free(&memlist);
    return res;
  }
  sprintf(authkeys_filename, "%s/.ssh/authorized_keys", home_dir);

  atlogger_log("AUTH SSH KEY", ATLOGGER_LOGGING_LEVEL_DEBUG, "Using authorized_keys file: %s\n", authkeys_filename);
  authkeys_file = fopen(authkeys_filename, "r"); // readonly for now, we will freopen this file later

  if (authkeys_file == NULL) {
    atlogger_log("AUTH SSH KEY", ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to open authorized_keys file: %s\n",
                 strerror(errno));
    if (errno != 0) {
      res = errno;
    } else {
      res = 1;
    }
    atcommons_memlist_failure_free(&memlist);
    return res;
  }

  res = atcommons_memlist_add(&memlist, authkeys_file, true, fclose);
  if (res != 0) {
    atcommons_memlist_failure_free(&memlist);
    return res;
  }

  if (!should_run) {
    atcommons_memlist_failure_free(&memlist);
    return res;
  }

  // 13. Main notification handler loop
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_INFO, "Starting main loop\n");
  main_loop();
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_INFO, "Exited main loop\n");
  if (is_child_process) {
    atcommons_memlist_success_free(&memlist);
  } else {
    atcommons_memlist_failure_free(&memlist);
  }
  return res;
}
