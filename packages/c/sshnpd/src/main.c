#include "sshnpd/background_jobs.h"
#include "sshnpd/sshnpd.h"
#include <atclient/atclient.h>
#include <atclient/atkey.h>
#include <atclient/atkeys.h>
#include <atclient/atkeysfile.h>
#include <atclient/connection.h>
#include <atclient/monitor.h>
#include <atclient/notify.h>
#include <atlogger/atlogger.h>
#include <cJSON.h>
#include <pthread.h>
#include <sshnpd/params.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define FILENAME_BUFFER_SIZE 500
#define LOGGER_TAG "sshnpd"

struct {
  char *str;
  enum notification_key key;
} notification_key_map[] = {
    {"sshpublickey", NK_SSHPUBLICKEY},
    {"ping", NK_PING},
    {"ssh_request", NK_SSH_REQUEST},
    {"npt_request", NK_NPT_REQUEST},
};

static unsigned long min(unsigned long a, unsigned long b) { return a < b ? a : b; }
static pthread_mutex_t atclient_lock = PTHREAD_MUTEX_INITIALIZER;

int main(int argc, char **argv) {
  SshnpdParams params;

  // 1.  Load default values
  apply_default_values_to_params(&params);

  // 2.  Parse the command line arguments
  if (parse_params(&params, argc, (const char **)argv) != 0) {
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
  const char *homedir = getenv(HOMEVAR);
  if (homedir == NULL) {
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
    snprintf(filename, FILENAME_BUFFER_SIZE, "%s/.atsign/keys/%s_key.atKeys", homedir, params.atsign);
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

  // 6. Initialize the root connection
  atclient_connection root_conn;
  atclient_connection_init(&root_conn);
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
  cJSON_AddItemToObject(supported_features, "srAuth", cJSON_CreateBool(cJSON_True));
  cJSON_AddItemToObject(supported_features, "srE2ee", cJSON_CreateBool(cJSON_True));
  cJSON_bool acceptsPublicKeys = (params.sshpublickey) ? cJSON_True : cJSON_False;
  cJSON_AddItemToObject(supported_features, "acceptsPublicKeys", cJSON_CreateBool(acceptsPublicKeys));
  cJSON_AddItemToObject(supported_features, "supportsPortChoice", cJSON_CreateBool(cJSON_True));
  cJSON_AddItemToObject(ping_response_json, "supportedFeatures", supported_features);

  cJSON *allowed_services = cJSON_CreateArray();
  for (int i = 0; i < params.permitopen_len; i++) {
    cJSON_AddItemToArray(allowed_services, cJSON_CreateString(params.permitopen[i]));
  }
  cJSON_AddItemToObject(ping_response_json, "allowedServices", allowed_services);

  //
  char *ping_response = cJSON_Print(ping_response_json);
  cJSON_Delete(ping_response_json);

  if (ping_response == NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "cJSON_Print failed\n");
    goto cancel_atclient;
  }

  // 9. Start the device refresh loop - if hide is off
  pthread_t refresh_tid;
  struct refresh_device_entry_params refresh_params = {&atclient,     &atclient_lock, &params,
                                                       ping_response, fds[0],         fds[1]};
  res = pthread_create(&refresh_tid, NULL, refresh_device_entry, (void *)&refresh_params);
  if (res != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to start refresh device entry thread\n");
    exit_res = res;
    goto cancel_atclient;
  }

  // 10. Start monitor
  char *regex = malloc((strlen(params.device) + strlen(SSHNP_NS) + 3)); // needs to be declared before any gotos
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
  // 12. Main notification handler loop
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_INFO, "Starting monitor loop:\n");

  while (true) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Waiting for next monitor thread message\n");
    atclient_monitor_message *message;
    res = atclient_monitor_read(&monitor_ctx, &atclient, &message);
    if (res != 0) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to read monitor message: %d\n", res);
      continue;
    }

    switch (message->type) {

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
        char tail[strlen(params.device) + strlen(SSHNP_NS) + strlen(message->notification.from) + 3];
        sprintf(tail, ".%s.%s%s", params.device, SSHNP_NS, message->notification.from);
        char *tailstart = strstr(key, tail);
        if (tailstart == NULL) {
          // TODO: handle error
          atclient_monitor_message_free(message);
          continue;
        }
        *tailstart = '\0'; // reterminate the string at the start of the trail

        // strip notification.to from the front
        // first let's validate that notification.to is on the front
        char *head = message->notification.to;
        size_t head_len = strlen(head);
        if (strlen(key) < head_len) {
          // TODO: handle error
          atclient_monitor_message_free(message);
          continue;
        }
        int is_equal = strncmp(key, head, head_len);
        if (is_equal != 0) {
          // TODO: handle error
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

        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Received key: %s\n", key);
        switch (notification_key) {
        case NK_SSHPUBLICKEY: {
          // TODO  implement public key authorizer
          break;
        }
        case NK_PING: {
          atclient_atkey pingkey;
          atclient_atkey_init(&pingkey);

          size_t keynamelen = strlen("heartbeat") + strlen(params.device) + 2; // + 1 for '.' +1 for '\0'
          char keyname[keynamelen];
          snprintf(keyname, keynamelen, "heartbeat.%s", params.device);
          printf("keyname: %s\n", keyname);
          atclient_atkey_create_sharedkey(&pingkey, keyname, keynamelen, params.atsign, strlen(params.atsign),
                                          message->notification.from, strlen(message->notification.from), SSHNP_NS,
                                          SSHNP_NS_LEN);

          atclient_atkey_metadata *metadata = &pingkey.metadata;
          atclient_atkey_metadata_set_ispublic(metadata, false);
          atclient_atkey_metadata_set_isencrypted(metadata, true);
          atclient_atkey_metadata_set_ttl(metadata, 10000);

          atclient_notify_params notify_params;
          atclient_notify_params_init(&notify_params);
          notify_params.key = pingkey;
          notify_params.value = ping_response;
          notify_params.operation = ATCLIENT_NOTIFY_OPERATION_UPDATE;

          int ret = pthread_mutex_lock(&atclient_lock);
          if (ret != 0) {
            atlogger_log("PING RESPONSE", ATLOGGER_LOGGING_LEVEL_ERROR,
                         "Failed to get a lock on atclient for sending a notification\n");
            goto exit_ping;
          }

          ret = atclient_notify(&atclient, &notify_params, NULL);
          if (ret != 0) {
            atlogger_log("PING RESPONSE", ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to send ping response to %s\n",
                         message->notification.from);
          }
          do {
            ret = pthread_mutex_unlock(&atclient_lock);
            if (ret != 0) {
              atlogger_log("PING RESPONSE", ATLOGGER_LOGGING_LEVEL_ERROR,
                           "Failed to release atclient lock, trying again in 1 second\n");
              sleep(1);
            }
          } while (ret != 0);
          atlogger_log("PING RESPONSE", ATLOGGER_LOGGING_LEVEL_DEBUG, "Released the atclient lock\n");
        exit_ping:
          atclient_notify_params_free(&notify_params);
          atclient_atkey_free(&pingkey);
          break;
        }
        case NK_SSH_REQUEST: {
          // TODO  implement ssh req
          break;
        }
        case NK_NPT_REQUEST: {
          // TODO  implement npt req
          break;
        }
        case NK_NONE:
          break;
        }
      }
      atclient_monitor_message_free(message);
      continue;
    }
    case ATCLIENT_MONITOR_MESSAGE_TYPE_DATA_RESPONSE:
    case ATCLIENT_MONITOR_MESSAGE_TYPE_NONE:
    case ATCLIENT_MONITOR_MESSAGE_TYPE_ERROR_RESPONSE:
      atclient_monitor_message_free(message);
      continue;
    }
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
