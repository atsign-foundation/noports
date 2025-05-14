#include "sshnpd/device_info.h"
#include "sshnpd/handle_npt_request.h"
#include "sshnpd/handle_ping.h"
#include "sshnpd/handle_ssh_request.h"
#include "sshnpd/handle_sshpublickey.h"
#include "sshnpd/permitopen.h"
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
#include <atclient/atkeys_file.h>
#include <atclient/connection.h>
#include <atclient/connection_hooks.h>
#include <atclient/json.h>
#include <atclient/monitor.h>
#include <atclient/notify.h>
#include <atclient/string_utils.h>
#include <atlogger/atlogger.h>
#include <libgen.h>
#include <mbedtls/psa_util.h>
#include <sshnpd/daemon.h>
#include <sshnpd/file_utils.h>
#include <sshnpd/run_srv_process.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

#define LOGGER_TAG "sshnpd - loop"

struct _notification_key_map notification_key_map[] = {
    {"", NK_NONE},
    {"sshpublickey", NK_SSHPUBLICKEY},
    {"ping", NK_PING},
    {"ssh_request", NK_SSH_REQUEST},
    {"npt_request", NK_NPT_REQUEST},
    {"graceful_shutdown", NK_GRACEFUL_SHUTDOWN},
};

atclient worker;
atclient monitor_ctx;
char *ping_response;
char *atserver_host;
uint16_t atserver_port;
atclient_atkeys atkeys;
sshnpd_params params;
char *regex;
FILE *authkeys_file;
char *authkeys_filename;
char *home_dir;
atchops_rsa_key_private_key signingkey;
bool is_child_process;

volatile sig_atomic_t should_run;

// device info
size_t device_info_pos;
time_t *device_info_last_sent;
uint8_t device_info_attempts;

void main_loop() {
  atlogger_log("E2E TESTS", ATLOGGER_LOGGING_LEVEL_INFO, "Monitor .*monitor started\n");

  atclient_monitor_message message;

  permitopen_params permitopen;
  permitopen.permitopen_len = params.permitopen_len;
  permitopen.permitopen_hosts = params.permitopen_hosts;
  permitopen.permitopen_ports = params.permitopen_ports;

  size_t timeout_counter = 0;

  while (should_run == 1) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Sending next device info\n");
    send_next_device_info(&worker, &params);

    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Waiting for next monitor thread message\n");
    atclient_monitor_message_init(&message);

    int ret;
    if (timeout_counter * MONITOR_READ_TIMEOUT_MS > MONITOR_NOOP_TIMEOUT_MS) {
      // Do noop & reconnect if needed
      ret = reconnect_monitor();
      if (ret != 0) {
        timeout_counter = MONITOR_NOOP_TIMEOUT_MS / MONITOR_READ_TIMEOUT_MS + 1;
        atclient_monitor_message_free(&message);
        continue;
      } else {
        timeout_counter = 0;
      }
    }

    // Read the next monitor message
    ret = atclient_monitor_read(&monitor_ctx, &worker, &message, NULL);
    if (ret != 0) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                   "Possible bad state: monitor read failed, resetting connection (ret: %d)\n", ret);
      timeout_counter = MONITOR_NOOP_TIMEOUT_MS / MONITOR_READ_TIMEOUT_MS + 1;
    }

    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Received message of type: %d\n", message.type);
    switch (message.type) {
    case ATCLIENT_MONITOR_MESSAGE_TYPE_EMPTY:
      timeout_counter++;
      break;
    case ATCLIENT_MONITOR_ERROR_READ:
      timeout_counter = MONITOR_NOOP_TIMEOUT_MS / MONITOR_READ_TIMEOUT_MS + 1;
      break;
    case ATCLIENT_MONITOR_MESSAGE_TYPE_DATA_RESPONSE:
      timeout_counter = 0;
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Received a data response: %s\n", message.data_response);
      break;
    case ATCLIENT_MONITOR_MESSAGE_TYPE_ERROR_RESPONSE:
      timeout_counter = 0;
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Received an error response: %s\n",
                   message.error_response);
      break;
    case ATCLIENT_MONITOR_MESSAGE_TYPE_NONE:
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Received a NONE notification type\n");
      break;
    case ATCLIENT_MONITOR_ERROR_PARSE_NOTIFICATION:
      timeout_counter = MONITOR_NOOP_TIMEOUT_MS + 1;
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to parse the notification\n");
      break;
    case ATCLIENT_MONITOR_ERROR_DECRYPT_NOTIFICATION:
      timeout_counter = MONITOR_NOOP_TIMEOUT_MS + 1;
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to decrypt the notification\n");
      break;
    case ATCLIENT_MONITOR_MESSAGE_TYPE_NOTIFICATION: {
      timeout_counter = 0;
      bool is_init = atclient_atnotification_is_decrypted_value_initialized(message.notification);
      bool has_key = atclient_atnotification_is_key_initialized(message.notification);
      if (is_init) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Notification value received: %s\n",
                     message.notification->decrypted_value);
        if (!has_key || strcmp(message.notification->id, "-1") == 0) {
          break;
        }

        char *key = message.notification->key;

        // strip '.$device.${DefaultArgs.namespace}${notification.from}' from the back
        char tail[strlen(params.device) + strlen(SSHNP_NS) + strlen(message.notification->from) + 3];
        sprintf(tail, ".%s.%s%s", params.device, SSHNP_NS, message.notification->from);
        char *tailstart = strstr(key, tail);
        if (tailstart == NULL) {
          atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Skipping message: couldn't find the tail\n");
          break;
        }
        *tailstart = '\0'; // reterminate the string at the start of the trail

        // strip notification.to from the front
        // first let's validate that notification.to is on the front
        char *head = message.notification->to;
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
        int keys_length;
#ifdef SSHNPD_ENABLE_TESTING_SHUTDOWN_NOTIFICATION
        keys_length = NOTIFICATION_KEYS_LEN + 1;
#else
        keys_length = NOTIFICATION_KEYS_LEN;
#endif
        for (int i = 1; i < keys_length; i++) {
          if (strcmp(key, notification_key_map[i].str) == 0) {
            notification_key = notification_key_map[i].key;
            break;
          }
        }

        if (!should_run) {
          break;
        }

        if (params.policy != NULL) {
          // TODO: implement a separate permitopen check for npa checks
          // DO NOT USE permitopen, use npa_permitopen
        }

        switch (notification_key) {
        case NK_SSHPUBLICKEY:
          atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Executing handle_sshpublickey\n");
          handle_sshpublickey(&params, &message, authkeys_file, authkeys_filename);
          break;
        case NK_PING:
          atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Executing handle_ping\n");
          handle_ping(&params, &message, ping_response, &worker);
          break;
        case NK_SSH_REQUEST:
          atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Executing handle_ssh_request\n");
          // permitopen happens first for ssh so we can avoid a bunch of unnecessary tasks
          permitopen.requested_host = "localhost";
          permitopen.requested_port = params.local_sshd_port;
          if (!should_permitopen(&permitopen)) {
            atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Ignoring request to localhost:%d\n",
                         params.local_sshd_port);
            // TODO notify daemon doesn't permit connections to $requested_host:$requested_port
            break;
          }
          handle_ssh_request(&worker, &params, &is_child_process, &message, signingkey);
          if (is_child_process) {
            atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Exiting child process\n");
            atclient_monitor_message_free(&message);
            return;
          }
          break;
        case NK_NPT_REQUEST:
          atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Executing handle_npt_request\n");
          // No permitopen here... since we need to parse the json first in order to check, it happens inside
          // handle_npt_request
          handle_npt_request(&worker, &params, &is_child_process, &message, signingkey);
          if (is_child_process) {
            atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Exiting child process\n");
            atclient_monitor_message_free(&message);
            return;
          }
          break;
        case NK_GRACEFUL_SHUTDOWN:
#ifdef SSHNPD_ENABLE_TESTING_SHUTDOWN_NOTIFICATION
#warning BINARY COMPILED WITH SHUTDOWN NOTIFICATION ENABLED NOT FOR PRODUCTION USE
          atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "TRIGGERING GRACEFUL SHUTDOWN\n");
          should_run = 0;
#endif
          break;
        case NK_NONE:
          break;
        }
      } else {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Skipping notification (no decryptedvalue): %s\n",
                     message.notification->id);
      }
      break;
    } // end of case ATCLIENT_MONITOR_MESSAGE_TYPE_NOTIFICATION
    } // end of switch
    atclient_monitor_message_free(&message);
  } // end of while loop
}
