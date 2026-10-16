#include "sshnpd/client_sessions.h"
#include "sshnpd/device_info.h"
#include "sshnpd/handle_npt_request.h"
#include "sshnpd/handle_ping.h"
#include "sshnpd/handle_ssh_request.h"
#include "sshnpd/handle_sshpublickey.h"
#include "sshnpd/handler_commons.h"
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
#include <sshnpd/policy.h>
#include <sshnpd/policy_limits.h>
#include <sshnpd/run_srv_process.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <time.h>
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

atclient_authenticate_options worker_options;
atclient worker;
atclient_authenticate_options monitor_options;
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

// Reaps every child that has exited: a session's srv or a key check, which
// only this loop reaps, so a pid the daemon signals is never one reused
static void reap_children(void) {
  int status;
  pid_t pid;
  while ((pid = waitpid(-1, &status, WNOHANG)) > 0) {
    srv_starts_reaped(pid);
    client_sessions_reaped(pid, status);
  }
}

static int check_with_policy_service(void *ctx, const char *client_atsign, sshnpd_policy_decision *decision) {
  (void)ctx;
  return policy_auth_check(&worker, &monitor_ctx, &params, client_atsign, decision);
}

void main_loop() {
  atlogger_log("E2E TESTS", ATLOGGER_LOGGING_LEVEL_INFO, "Monitor .*monitor started\n");

  atclient_monitor_message message;

  // The policy service's decision for the request currently being handled;
  // policy_checked is true only when the decision came from the policy
  // service (manager atsigns bypass it)
  sshnpd_policy_decision policy_decision;
  memset(&policy_decision, 0, sizeof(policy_decision));
  bool policy_checked = false;

  policy_cache decisions;
  if (policy_cache_init(&decisions, params.policy_cache_size) != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to set up the policy decision cache\n");
    return;
  }
  policy_throttle checked_senders;
  policy_throttle_init(&checked_senders);

  size_t timeout_counter = 0;

  while (should_run == 1) {
    reap_children();
    srv_starts_poll(sshnpd_monotonic_ms());
    client_sessions_tick(time(NULL));

    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Sending next device info\n");
    send_next_device_info(&worker, &params);
    policy_send_heartbeat(&worker, &params, ping_response);

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
    timeout_counter = sshnpd_next_timeout_counter(ret, message.type, timeout_counter);
    if (ret != 0 && message.type != ATCLIENT_MONITOR_ERROR_DECRYPT_NOTIFICATION) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                   "Possible bad state: monitor read failed, resetting connection (ret: %d)\n", ret);
    }

    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Received message of type: %d\n", message.type);
    switch (message.type) {
    case ATCLIENT_MONITOR_MESSAGE_TYPE_EMPTY:
    case ATCLIENT_MONITOR_ERROR_READ:
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
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_WARN, "Ignoring a notification from %s that couldn't be decrypted\n",
                   message.notification != NULL && atclient_atnotification_is_from_initialized(message.notification)
                       ? message.notification->from
                       : "(unknown)");
      break;
    case ATCLIENT_MONITOR_MESSAGE_TYPE_NOTIFICATION: {
      bool is_init = atclient_atnotification_is_decrypted_value_initialized(message.notification);
      bool has_key = atclient_atnotification_is_key_initialized(message.notification);
      bool has_id = atclient_atnotification_is_id_initialized(message.notification) && message.notification->id != NULL;
      if (is_init) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Notification received: %s\n",
                     has_key && message.notification->key != NULL ? message.notification->key : "(no key)");
        if (!has_key || !has_id || strcmp(message.notification->id, "-1") == 0) {
          break;
        }

        // Policy service traffic (config pushes replying to our heartbeats,
        // rpc responses that missed their wait window) is not a session
        // request - drop it before the auth gate, or the daemon would run an
        // auth check asking the policy service about the policy service
        if (params.policy != NULL && policy_is_policy_service_message(message.notification, &params)) {
          atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Ignoring policy service message: %s\n",
                       message.notification->key);
          break;
        }

        enum notification_key notification_key = sshnpd_notification_kind(
            message.notification->key,
            atclient_atnotification_is_to_initialized(message.notification) ? message.notification->to : NULL,
            params.device, message.notification->from);

        // Managers are approved without a policy check; everyone else is
        // referred to the policy service when one is configured
        policy_checked = false;
        if (!is_manager_atsign(&params, message.notification->from)) {
          if (params.policy != NULL && message.notification->from != NULL) {
            const char *from = message.notification->from;
            policy_gate_result gate = policy_gate(&decisions, &checked_senders, from, notification_key,
                                                  policy_now_millis, check_with_policy_service, NULL, &policy_decision);
            if (gate == POLICY_GATE_DROP) {
              atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_WARN,
                           "Dropping a request from %s, whose last policy check for it was under %d ms ago\n", from,
                           POLICY_THROTTLE_MS);
              break;
            }
            if (gate == POLICY_GATE_DENY) {
              atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_WARN,
                           "Rejecting request from atSign not authorized by the policy service: %s\n", from);
              break;
            }
            policy_checked = true;
          } else {
            atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_WARN, "Rejecting request from unauthorized atSign: %s\n",
                         message.notification->from == NULL ? "(none)" : message.notification->from);
            break;
          }
        }

        if (notification_key == NK_NONE) {
          atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Skipping message: %s names no request handled here\n",
                       message.notification->key);
          break;
        }

        if (!should_run) {
          break;
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
          // permit-open checks (daemon list and policy list) happen inside
          // the handler, which can tell the client why a request was denied
          handle_ssh_request(&worker, &params, &is_child_process, &message, signingkey,
                             policy_checked ? &policy_decision : NULL);
          if (is_child_process) {
            atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Exiting child process\n");
            atclient_monitor_message_free(&message);
            policy_decision_free(&policy_decision);
            policy_cache_free(&decisions);
            return;
          }
          break;
        case NK_NPT_REQUEST:
          atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Executing handle_npt_request\n");
          // No permitopen here... since we need to parse the json first in order to check, it happens inside
          // handle_npt_request
          handle_npt_request(&worker, &params, &is_child_process, &message, signingkey,
                             policy_checked ? &policy_decision : NULL);
          if (is_child_process) {
            atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Exiting child process\n");
            atclient_monitor_message_free(&message);
            policy_decision_free(&policy_decision);
            policy_cache_free(&decisions);
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
    policy_decision_free(&policy_decision); // safe when nothing was allocated
  } // end of while loop
  policy_cache_free(&decisions);
}
