#include "sshnpd/background_jobs.h"
#include "sshnpd/handle_npt_request.h"
#include "sshnpd/handle_ping.h"
#include "sshnpd/handle_ssh_request.h"
#include "sshnpd/handle_sshpublickey.h"
#include "sshnpd/sshnpd.h"
#include <atchops/aes.h>
#include <atchops/iv.h>
#include <atchops/rsa.h>
#include <atchops/rsakey.h>
#include <atchops/sha.h>
#include <atclient/atclient.h>
#include <atclient/atkey.h>
#include <atclient/atkeys.h>
#include <atclient/atkeysfile.h>
#include <atclient/connection.h>
#include <atclient/monitor.h>
#include <atclient/notify.h>
#include <atclient/stringutils.h>
#include <atlogger/atlogger.h>
#include <cJSON.h>
#include <libgen.h>
#include <pthread.h>
#include <sshnpd/file_utils.h>
#include <sshnpd/run_srv_process.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/errno.h>
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

static void main_loop(atclient *monitor_ctx, atclient *atclient, sshnpd_params *params, FILE *authkeys_file,
                      char *authkeys_filename, char *ping_response, char *home_dir,
                      atchops_rsakey_privatekey signingkey);

int main(int argc, char **argv) {
  sshnpd_params params;

  // 1.  Load default values
  apply_default_values_to_sshnpd_params(&params);

  // 2.  Parse the command line arguments
  if (parse_sshnpd_params(&params, argc, (const char **)argv) != 0) {
    return 1;
  }

  // 3.  Configure the Logger
  if (params.verbose) {
    printf("Verbose mode enabled\n");
    atlogger_set_logging_level(ATLOGGER_LOGGING_LEVEL_DEBUG);
  } else {
    atlogger_set_logging_level(ATLOGGER_LOGGING_LEVEL_INFO);
  }

  // 4. Validate the environment
  const char *home_dir = getenv(HOMEVAR);
  if (home_dir == NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Unable to determine your home directory: please "
                 "set %s environment variable\n",
                 HOMEVAR);
    return 1;
  }

  const char *username = getenv(USERVAR);
  if (!params.hide && username == NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Unable to determine your username: please "
                 "set %s environment variable\n",
                 USERVAR);
    return 1;
  }

  int res = 0;
  int exit_res = -1;

  // 5.  Load the atKeys
  atclient_atkeysfile atkeysfile;
  atclient_atkeysfile_init(&atkeysfile);

  // 5.1 Read the atKeys file
  if (params.key_file == NULL) {
    char filename[FILENAME_BUFFER_SIZE];
    snprintf(filename, FILENAME_BUFFER_SIZE, "%s/.atsign/keys/%s_key.atKeys", home_dir, params.atsign);
    res = atclient_atkeysfile_read(&atkeysfile, filename);
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Using atkeysfile: %s\n", filename);
  } else {
    res = atclient_atkeysfile_read(&atkeysfile, (const char *)params.key_file);
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Using atkeysfile: %s\n", (const char *)params.key_file);
  }

  if (res != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Unable to read the key file\n");
    atclient_atkeysfile_free(&atkeysfile);
    return res;
  }

  // 5.2 Read the atKeysFile into the atKeys struct
  atclient_atkeys atkeys;
  atclient_atkeys_init(&atkeys);

  res = atclient_atkeys_populate_from_atkeysfile(&atkeys, atkeysfile);
  atclient_atkeysfile_free(&atkeysfile);
  if (res != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Unable to parse the key file\n");
    atclient_atkeys_free(&atkeys);
    return res;
  }

  // 5.3 create a key copy for signing
  atchops_rsakey_privatekey signingkey;
  atchops_rsakey_privatekey_init(&signingkey);
  memcpy(&signingkey, &atkeys.encryptprivatekey, sizeof(atchops_rsakey_privatekey));

  // 6. Initialize the root connection
  atclient_connection root_conn;
  atclient_connection_init(&root_conn, ATCLIENT_CONNECTION_TYPE_DIRECTORY);
  res = atclient_connection_connect(&root_conn, params.root_domain, ROOT_PORT);
  if (res != 0) {
    exit_res = res;
    goto cancel_root;
  }

  // 7.a Initialize the monitor atclient
  atclient monitor_ctx;
  atclient_init(&monitor_ctx);
  res = atclient_pkam_authenticate(&monitor_ctx, &root_conn, &atkeys, params.atsign);
  if (res != 0) {
    exit_res = res;
    goto cancel_monitor_ctx;
  }

  // 7.b Initialize the worker atclient
  atclient atclient;
  atclient_init(&atclient);
  bool free_ping_response = false;
  res = atclient_pkam_authenticate(&atclient, &root_conn, &atkeys, params.atsign);
  if (res != 0) {
    exit_res = res;
    goto cancel_atclient;
  }

  // 8. cache the manager public keys
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Manager List: %lu - ", params.manager_list_len);
  for (int i = 0; i < params.manager_list_len; i++) {
    printf("%s,", params.manager_list[i]);

    // char public_encryption_key[1024];
    // atclient_get_public_encryption_key(&atclient, params.manager_list[i], &public_encryption_key);
    // TODO: finish caching
  }
  printf("\n");

  // pipe to communicate with the threads we will create in 9 & 10
  int fds[2];
  pipe(fds);

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
  char *ping_response = cJSON_PrintUnformatted(ping_response_json);
  cJSON_Delete(ping_response_json);

  if (ping_response == NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "cJSON_Print failed\n");
    goto cancel_atclient;
  } else {
    free_ping_response = true;
  }

  // 9. Start the device refresh loop - if hide is off
  pthread_t refresh_tid;
  struct refresh_device_entry_params refresh_params = {&atclient, &atclient_lock, &params, ping_response,
                                                       username,  fds[0],         fds[1]};
  res = pthread_create(&refresh_tid, NULL, refresh_device_entry, (void *)&refresh_params);
  if (res != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to start refresh device entry thread\n");
    exit_res = res;
    goto cancel_atclient;
  }

  // 10. Start monitor
  char *regex = malloc((strlen(params.device) + strlen(SSHNP_NS) + 3)); // needs to be declared before any gotos
  if (regex == NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to allocate memory for the monitor regex\n");
    exit_res = 1;
    goto cancel_atclient;
  }
  sprintf(regex, "%s.%s@", params.device, SSHNP_NS);
  size_t regex_len = strlen(regex);
  res = atclient_monitor_start(&monitor_ctx, regex, regex_len);
  if (res != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to start monitor\n");
    exit_res = res;
    goto cancel_refresh;
  }

  // 11.  Start heartbeat to the atServer
  pthread_t heartbeat_tid;
  struct heartbeat_params heartbeat_params = {&monitor_ctx, fds[0], fds[1]};
  res = pthread_create(&heartbeat_tid, NULL, heartbeat, (void *)&heartbeat_params);
  if (res != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to start heartbeat thread\n");
    exit_res = res;
    goto cancel_refresh;
  }

  char *authkeys_filename = malloc(sizeof(char) + (strlen(home_dir) + 22));
  if (authkeys_filename == NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to allocate memory for authkeys_filename\n");
    exit_res = 1;
    goto cancel_heartbeat;
  }
  sprintf(authkeys_filename, "%s/.ssh/authorized_keys", home_dir);

  atlogger_log("AUTH SSH KEY", ATLOGGER_LOGGING_LEVEL_DEBUG, "Using authorized_keys file: %s\n", authkeys_filename);
  FILE *authkeys_file = fopen(authkeys_filename, "r"); // readonly for now, we will freopen this file later

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

  // 12. Main notification handler loop
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_INFO, "Starting main loop\n");
  main_loop(&monitor_ctx, &atclient, &params, authkeys_file, authkeys_filename, ping_response, (char *)home_dir,
            signingkey);
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_INFO, "Exited main loop\n");

close_authkeys: {
  fclose(authkeys_file);
  free(authkeys_filename);
}
cancel_heartbeat: {
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Cancelling heartbeat thread\n");
  if (pthread_cancel(heartbeat_tid) != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_WARN, "Failed to cancel heartbeat thread\n");
  } else {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Canceled heartbeat thread\n");
  }
}
cancel_refresh: {
  free(regex);
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Cancelling device entry refresh thread\n");
  if (pthread_cancel(heartbeat_tid) != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_WARN, "Failed to cancel device entry refresh thread\n");
  } else {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Canceled device entry refresh thread\n");
  }
}
cancel_atclient: {
  if (free_ping_response) {
    free(ping_response);
  }
  atclient_connection_disconnect(&atclient.secondary_connection);
  atclient_free(&atclient);
}
cancel_monitor_ctx: {
  atclient_connection_disconnect(&monitor_ctx.secondary_connection);
  atclient_free(&monitor_ctx);
}
cancel_root: {
  res = atclient_connection_disconnect(&root_conn);
  if (res != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_WARN, "Failed to disconnect from root server\n");
  }
  atclient_connection_free(&root_conn);
}
exit: {
  close(fds[0]);
  close(fds[1]);

  atclient_atkeys_free(&atkeys);

  if (params.free_permitopen) {
    free(params.permitopen);
  }

  if (exit_res != 0) {
    return exit_res;
  }

  // There actually is no positive exit scenario right now... the only way for sshnp to exit is through failure or
  // through an external signal
  return 0;
}
}

void main_loop(atclient *monitor_ctx, atclient *atclient, sshnpd_params *params, FILE *authkeys_file,
               char *authkeys_filename, char *ping_response, char *home_dir, atchops_rsakey_privatekey signingkey) {
  int res = 0;
  while (true) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Waiting for next monitor thread message\n");
    atclient_monitor_message *message;
    res = atclient_monitor_read(monitor_ctx, atclient, &message);

    if (message == NULL) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to read message: message was NULL\n");
      continue;
    } else {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Received message of type: %d\n", message->type);
    }

    // in code -> clang-format -> out code
    switch (message->type) {
    case ATCLIENT_MONITOR_ERROR_READ:
    case ATCLIENT_MONITOR_ERROR_PARSE:
      // TODO: handle errors
      break;
    case ATCLIENT_MONITOR_MESSAGE_TYPE_NOTIFICATION: {
      bool is_init = atclient_atnotification_decryptedvalue_is_initialized(&message->notification);
      bool has_key = atclient_atnotification_key_is_initialized(&message->notification);
      if (is_init) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Notification value received: %s\n",
                     message->notification.decryptedvalue);
        if (!has_key || strcmp(message->notification.id, "-1") == 0) {
          atclient_monitor_message_free(message);
          continue;
        }

        char *key = message->notification.key;

        // strip '.$device.${DefaultArgs.namespace}${notification.from}' from the back
        char tail[strlen(params->device) + strlen(SSHNP_NS) + strlen(message->notification.from) + 3];
        sprintf(tail, ".%s.%s%s", params->device, SSHNP_NS, message->notification.from);
        char *tailstart = strstr(key, tail);
        if (tailstart == NULL) {
          atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Skipping message: couldn't find the tail\n");
          atclient_monitor_message_free(message);
          continue;
        }
        *tailstart = '\0'; // reterminate the string at the start of the trail

        // strip notification.to from the front
        // first let's validate that notification.to is on the front
        char *head = message->notification.to;
        size_t head_len = strlen(head);
        if (strlen(key) < head_len) {
          atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                       "Skipping message: key length is shorter than the expected head\n");
          atclient_monitor_message_free(message);
          continue;
        }
        int is_equal = strncmp(key, head, head_len);
        if (is_equal != 0) {
          atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Skipping message: couldn't find the head\n");
          atclient_monitor_message_free(message);
          continue;
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

        // TODO: multithread these handlers
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Received key: '%s'\n", key);
        switch (notification_key) {
        case NK_SSHPUBLICKEY:
          handle_sshpublickey(params, message, authkeys_file, authkeys_filename);
          break;
        case NK_PING:
          handle_ping(params, message, ping_response, atclient, &atclient_lock);
          break;
        case NK_SSH_REQUEST:
          handle_ssh_request(atclient, &atclient_lock, params, message, home_dir, authkeys_file, authkeys_filename,
                             signingkey);
          break;
        case NK_NPT_REQUEST:
          handle_npt_request(params, message);
          break;
        case NK_NONE:
          break;
        }
      } else {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Skipping notification (no decryptedvalue): %s\n",
                     message->notification.id);
      }
      atclient_monitor_message_free(message);
      continue;
    }
    case ATCLIENT_MONITOR_MESSAGE_TYPE_DATA_RESPONSE:
    case ATCLIENT_MONITOR_MESSAGE_TYPE_NONE:
    case ATCLIENT_MONITOR_MESSAGE_TYPE_ERROR_RESPONSE:
      printf("message type-> %d\n", message->type);
      atclient_monitor_message_free(message);
      continue;
    }
  }
}
