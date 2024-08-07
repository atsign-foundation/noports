#include "sshnpd/background_jobs.h"
#include "sshnpd/handle_npt_request.h"
#include "sshnpd/handle_ping.h"
#include "sshnpd/handle_ssh_request.h"
#include "sshnpd/handle_sshpublickey.h"
#include "sshnpd/sshnpd.h"
#include <atchops/aes.h>
#include <atchops/iv.h>
#include <atchops/rsa.h>
#include <atchops/rsa_key.h>
#include <atchops/sha.h>
#include <atclient/atclient.h>
#include <atclient/atclient_utils.h>
#include <atclient/atkey.h>
#include <atclient/atkeys.h>
#include <atclient/atkeysfile.h>
#include <atclient/connection.h>
#include <atclient/connection_hooks.h>
#include <atclient/monitor.h>
#include <atclient/notify.h>
#include <atclient/string_utils.h>
#include <atlogger/atlogger.h>
#include <cJSON.h>
#include <libgen.h>
#include <pthread.h>
#include <signal.h>
#include <sshnpd/file_utils.h>
#include <sshnpd/run_srv_process.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/errno.h>
#include <sys/wait.h>
#include <unistd.h>

#define FILENAME_BUFFER_SIZE 500
#define LOGGER_TAG "sshnpd"

static struct {
  char *str;
  enum notification_key key;
} notification_key_map[] = {
    {"", NK_NONE},
    {"sshpublickey", NK_SSHPUBLICKEY},
    {"ping", NK_PING},
    {"ssh_request", NK_SSH_REQUEST},
    {"npt_request", NK_NPT_REQUEST},
};

static unsigned long min(unsigned long a, unsigned long b) { return a < b ? a : b; }

static pthread_mutex_t atclient_lock = PTHREAD_MUTEX_INITIALIZER;
static int lock_atclient(void);
static int unlock_atclient(int);

static int reconnect_atclient(const unsigned char *src, const size_t srclen, unsigned char *recv, const size_t recvsize,
                              size_t *recvlen);

static int set_worker_hooks();
static void main_loop();

// information to be shared between functions in this file
static atclient worker;
static char *atserver_host;
static int atserver_port;
static atclient_atkeys atkeys;
static sshnpd_params params;
static atclient monitor_ctx;
static char *regex;
static FILE *authkeys_file;
static char *authkeys_filename;
static char *ping_response;
static char *home_dir;
static atchops_rsa_key_private_key signingkey;
static bool is_child_process = false;

// Signal handling
static volatile sig_atomic_t should_run = 1;
static void exit_handler(int sig) {
  atlogger_log("exit_handler", ATLOGGER_LOGGING_LEVEL_WARN, "Received signal: %d\n");
  if (should_run == 1) {
    atlogger_log("exit_handler", ATLOGGER_LOGGING_LEVEL_WARN, "Received SIGINT, attempting a safe exit\n");
    should_run = 0;
  } else if (should_run == 0) {
    atlogger_log("exit_handler", ATLOGGER_LOGGING_LEVEL_WARN, "Received SIGINT again, exiting forcefully\n");
    exit(1);
  }
}
static void child_exit_handler(int sig) {
  atlogger_log("child_exit_handler", ATLOGGER_LOGGING_LEVEL_WARN, "Received signal: %d\n");
  int status;
  pid_t pid = waitpid(-1, &status, WNOHANG);
  if (pid > 0 && WIFEXITED(status)) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "pid %d exited\n", pid);
  }
}

int main(int argc, char **argv) {
  int res = 0;
  int exit_res = 0;

  // Catch sigint and pass to the handler
  signal(SIGINT, exit_handler);
  signal(SIGCHLD, child_exit_handler);

  // 1.  Load default values
  apply_default_values_to_sshnpd_params(&params);

  // 2.  Parse the command line arguments
  if (parse_sshnpd_params(&params, argc, (const char **)argv) != 0) {
    return 1;
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
    exit_res = 1;
    goto exit;
  }

  const char *username = getenv(USERVAR);
  if (!params.hide && username == NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Unable to determine your username: please "
                 "set %s environment variable\n",
                 USERVAR);
    exit_res = 1;
    goto exit;
  }

  if (!should_run) {
    exit_res = res;
    goto exit;
  }

  // 5.  Load the atKeys
  atclient_atkeys_init(&atkeys);
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
    atclient_atkeys_free(&atkeys);
    exit_res = res;
    goto exit;
  }

  // 5.3 create a key copy for signing
  atchops_rsa_key_private_key_init(&signingkey);
  atchops_rsa_key_private_key_clone(&atkeys.encrypt_private_key, &signingkey);

  // 6. Get atServer address
  res = atclient_utils_find_atserver_address(params.root_domain, ROOT_PORT, params.atsign, &atserver_host,
                                             &atserver_port);
  if (res != 0) {
    exit_res = res;
    goto clean_atkeys;
  }

  // 7.a Initialize the monitor atclient
  atclient_init(&monitor_ctx);
  res = atclient_pkam_authenticate(&monitor_ctx, atserver_host, atserver_port, &atkeys, params.atsign);
  if (res != 0 || !should_run) {
    exit_res = res;
    goto cancel_monitor_ctx;
  }

  // 7.b Initialize the worker atclient
  atclient_init(&worker);
  bool free_ping_response = false;
  res = atclient_pkam_authenticate(&worker, atserver_host, atserver_port, &atkeys, params.atsign);
  if (res != 0 || !should_run) {
    exit_res = res;
    goto cancel_atclient;
  }

  // 7.c setup hooks to restart the worker atclient
  set_worker_hooks();

  // 8. cache the manager public keys
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Manager List: %lu - ", params.manager_list_len);
  for (int i = 0; i < params.manager_list_len; i++) {
    printf("%s,", params.manager_list[i]);

    // char public_encryption_key[1024];
    // atclient_get_public_encryption_key(&atclient, params.manager_list[i], &public_encryption_key);
    // TODO: finish caching
  }
  printf("\n");

  if (!should_run) {
    exit_res = res;
    goto cancel_atclient;
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
  cJSON_AddItemToObject(ping_response_json, "supportedFeatures", supported_features);

  cJSON *allowed_services = cJSON_CreateArray();
  for (int i = 0; i < params.permitopen_len; i++) {
    cJSON_AddItemToArray(allowed_services, cJSON_CreateString(params.permitopen[i]));
  }
  cJSON_AddItemToObject(ping_response_json, "allowedServices", allowed_services);

  //
  ping_response = cJSON_PrintUnformatted(ping_response_json);
  cJSON_Delete(ping_response_json);

  if (ping_response == NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "cJSON_Print failed\n");
    goto cancel_atclient;
  } else {
    free_ping_response = true;
  }

  if (!should_run) {
    goto cancel_atclient;
  }

  // 9. Start the device refresh loop - if hide is off
  pthread_t refresh_tid;
  atclient_atkey *infokeys = malloc(sizeof(atclient_atkey) * params.manager_list_len);
  if (infokeys == NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to allocate memory for infokeys\n");
    exit_res = 1;
    goto cancel_atclient;
  }

  for (int i = 0; i < params.manager_list_len; i++) {
    atclient_atkey_init(infokeys + i);
  }

  atclient_atkey *usernamekeys = malloc(sizeof(atclient_atkey) * params.manager_list_len);
  if (usernamekeys == NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to allocate memory for usernamekeys\n");
    exit_res = 1;
    goto clean_info_keys;
  }

  for (int i = 0; i < params.manager_list_len; i++) {
    atclient_atkey_init(usernamekeys + i);
  }

  struct refresh_device_entry_params refresh_params = {&worker,  &atclient_lock, &params,  ping_response,
                                                       username, &should_run,    infokeys, usernamekeys};
  res = pthread_create(&refresh_tid, NULL, refresh_device_entry, (void *)&refresh_params);
  if (res != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to start refresh device entry thread\n");
    exit_res = res;
    goto clean_username_keys;
  }

  if (!should_run) {
    goto cancel_refresh;
  }

  // 10. Start monitor
  regex = malloc((strlen(params.device) + strlen(SSHNP_NS) + 3)); // needs to be declared before any gotos
  if (regex == NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to allocate memory for the monitor regex\n");
    exit_res = 1;
    goto cancel_refresh;
  }

  sprintf(regex, "%s.%s@", params.device, SSHNP_NS);
  res = atclient_monitor_start(&monitor_ctx, regex);
  if (res != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to start monitor\n");
    exit_res = res;
    goto cancel_refresh;
  }

  if (!should_run) {
    goto cancel_refresh;
  }

  // 11. Get a pointer to the authorized_keys file
  authkeys_filename = malloc(sizeof(char) + (strlen(home_dir) + 22));
  if (authkeys_filename == NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to allocate memory for authkeys_filename\n");
    exit_res = 1;
    goto cancel_refresh;
  }
  sprintf(authkeys_filename, "%s/.ssh/authorized_keys", home_dir);

  atlogger_log("AUTH SSH KEY", ATLOGGER_LOGGING_LEVEL_DEBUG, "Using authorized_keys file: %s\n", authkeys_filename);
  authkeys_file = fopen(authkeys_filename, "r"); // readonly for now, we will freopen this file later

  if (authkeys_file == NULL) {
    atlogger_log("AUTH SSH KEY", ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to open authorized_keys file: %s\n",
                 strerror(errno));
    if (errno != 0) {
      exit_res = errno;
    } else {
      exit_res = 1;
    }
    goto close_authkeys;
  }

  if (!should_run) {
    goto close_authkeys;
  }

  // 13. Main notification handler loop
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_INFO, "Starting main loop\n");
  main_loop();
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_INFO, "Exited main loop\n");

close_authkeys:
  fclose(authkeys_file);
  free(authkeys_filename);
cancel_refresh:
  free(regex);
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Joining device entry refresh thread\n");
  should_run = 0;
  if (!is_child_process && pthread_join(refresh_tid, NULL) != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_WARN, "Failed to join device entry refresh thread\n");
  } else {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Joined device entry refresh thread\n");
  }
clean_username_keys:
  for (int i = 0; i < params.manager_list_len; i++) {
    atclient_atkey_free(usernamekeys + i);
  }
  free(usernamekeys);
clean_info_keys:
  for (int i = 0; i < params.manager_list_len; i++) {
    atclient_atkey_free(infokeys + i);
  }
  free(infokeys);
cancel_atclient:
  if (free_ping_response) {
    free(ping_response);
  }
  if (!is_child_process) {
    atclient_connection_disconnect(&worker.atserver_connection);
    atclient_free(&worker);
  }
cancel_monitor_ctx:
  if (!is_child_process) {
    atclient_connection_disconnect(&monitor_ctx.atserver_connection);
    atclient_free(&monitor_ctx);
  }
  free(atserver_host);

clean_atkeys:
  atchops_rsa_key_private_key_free(&signingkey);
  atclient_atkeys_free(&atkeys);

exit:
  free(params.manager_list);
  free(params.permitopen);
  free(params.permitopen_str);

  exit(exit_res);
}

void main_loop() {
  int res = 0;
  atlogger_log("E2E TESTS", ATLOGGER_LOGGING_LEVEL_INFO, "Monitor .*monitor started\n");
  atclient_monitor_hooks monitor_hooks;

  monitor_hooks.pre_decrypt_notification = lock_atclient;
  monitor_hooks.post_decrypt_notification = unlock_atclient;

  atclient_monitor_response message;

  while (should_run) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Waiting for next monitor thread message\n");
    atclient_monitor_response_init(&message);

    // Read the next monitor message
    res = atclient_monitor_read(&monitor_ctx, &worker, &message, &monitor_hooks);

    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Received message of type: %d\n", message.type);

    // in code -> clang-format -> out code
    switch (message.type) {
    case ATCLIENT_MONITOR_ERROR_READ:
      if (!atclient_monitor_is_connected(&monitor_ctx)) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                     "Seems the monitor connection is down, trying to reconnect\n");

        int ret =
            atclient_monitor_pkam_authenticate(&monitor_ctx, atserver_host, atserver_port, &atkeys, params.atsign);
        if (ret != 0) {
          atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                       "Monitor connection failed to reconnect, trying again in 1 second...\n");
          sleep(1);
          break;
        }

        ret = atclient_monitor_start(&monitor_ctx, regex);
        if (ret != 0) {
          atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Monitor verb failed to restart.\n");
          break;
        }

        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_INFO, "Reconnected the monitor connection.\n");
      }
      break;
    case ATCLIENT_MONITOR_MESSAGE_TYPE_DATA_RESPONSE:
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Received a data response: %s\n", message.data_response);
      break;
    case ATCLIENT_MONITOR_MESSAGE_TYPE_ERROR_RESPONSE:
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Received an error response: %s\n",
                   message.error_response);
      break;
    case ATCLIENT_MONITOR_MESSAGE_TYPE_NONE:
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Received a NONE notification type\n");
      break;
    case ATCLIENT_MONITOR_ERROR_PARSE_NOTIFICATION:
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to parse the notification\n");
      break;
    case ATCLIENT_MONITOR_ERROR_DECRYPT_NOTIFICATION:
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to decrypt the notification\n");
      break;
    case ATCLIENT_MONITOR_MESSAGE_TYPE_NOTIFICATION: {
      bool is_init = atclient_atnotification_is_decrypted_value_initialized(&message.notification);
      bool has_key = atclient_atnotification_is_key_initialized(&message.notification);
      if (is_init) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Notification value received: %s\n",
                     message.notification.decrypted_value);
        if (!has_key || strcmp(message.notification.id, "-1") == 0) {
          break;
        }

        char *key = message.notification.key;

        // strip '.$device.${DefaultArgs.namespace}${notification.from}' from the back
        char tail[strlen(params.device) + strlen(SSHNP_NS) + strlen(message.notification.from) + 3];
        sprintf(tail, ".%s.%s%s", params.device, SSHNP_NS, message.notification.from);
        char *tailstart = strstr(key, tail);
        if (tailstart == NULL) {
          atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Skipping message: couldn't find the tail\n");
          break;
        }
        *tailstart = '\0'; // reterminate the string at the start of the trail

        // strip notification.to from the front
        // first let's validate that notification.to is on the front
        char *head = message.notification.to;
        size_t head_len = strlen(head);
        if (strlen(key) < head_len) {
          atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                       "Skipping message: key length is shorter than the expected head\n");
          break;
        }
        int is_equal = strncmp(key, head, head_len);
        if (is_equal != 0) {
          atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Skipping message: couldn't find the head\n");
          break;
        }

        // Now that we've confirmed it to be at the front, just do a pointer shift
        key += head_len + 1; // shift the pointer over (+1 for ":")

        // Do the string compare for this key in place, that way we can use a switch/case instead of endless if
        // statements
        enum notification_key notification_key = NK_NONE;
        for (int i = 1; i < NOTIFICATION_KEYS_LEN; i++) {
          if (strcmp(key, notification_key_map[i].str) == 0) {
            notification_key = notification_key_map[i].key;
            break;
          }
        }

        if (!should_run) {
          break;
        }

        // TODO: maybe multithread these handlers
        switch (notification_key) {
        case NK_SSHPUBLICKEY:
          atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Executing handle_sshpublickey\n");
          handle_sshpublickey(&params, &message, authkeys_file, authkeys_filename);
          break;
        case NK_PING:
          atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Executing handle_ping\n");
          handle_ping(&params, &message, ping_response, &worker, &atclient_lock);
          break;
        case NK_SSH_REQUEST:
          atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Executing handle_ssh_request\n");
          handle_ssh_request(&worker, &atclient_lock, &params, &is_child_process, &message, home_dir, authkeys_file,
                             authkeys_filename, signingkey);
          if (is_child_process) {
            atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Exiting child process\n");
            atclient_monitor_response_free(&message);
            return;
          }
          break;
        case NK_NPT_REQUEST:
          atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Executing handle_npt_request\n");
          handle_npt_request(&params, &message);
          break;
        case NK_NONE:
          break;
        }
      } else {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Skipping notification (no decryptedvalue): %s\n",
                     message.notification.id);
      }
      break;
    } // end of case ATCLIENT_MONITOR_MESSAGE_TYPE_NOTIFICATION
    } // end of switch
    atclient_monitor_response_free(&message);
  } // end of while loop
}

static int lock_atclient(void) {
  int ret = pthread_mutex_lock(&atclient_lock);
  if (ret != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to get a lock on atclient for sending a notification\n");
  } else {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Locked the atclient\n");
  }
  return ret;
}

static int unlock_atclient(int ret) {
  ret = pthread_mutex_unlock(&atclient_lock);
  if (ret != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to release atclient lock\n");
  } else {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Released the atclient lock\n");
  }
  return ret;
}

static int set_worker_hooks() {
  atclient_connection_hooks_enable(&worker.atserver_connection);
  return atclient_connection_hooks_set(&worker.atserver_connection, ATCLIENT_CONNECTION_HOOK_TYPE_PRE_WRITE,
                                       reconnect_atclient);
}

static int reconnect_atclient(const unsigned char *src, const size_t srclen, unsigned char *recv, const size_t recvsize,
                              size_t *recvlen) {
  char *TAG = "reconnect";
  int ret = 0;

  if (!atclient_is_connected(&worker)) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_INFO, "Worker client is not connected, attempting to reconnect:\n");
    ret = atclient_pkam_authenticate(&worker, atserver_host, atserver_port, &atkeys, params.atsign);

    if (ret != 0) {
      atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to reconnect to the atServer.\n");
      goto exit;
    }

    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_INFO, "Reconnected to the atServer!\n");
    ret = set_worker_hooks();

    if (ret != 0) {
      atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to set worker hooks for the atServer.\n");
    }
  }

exit:
  return ret;
}
