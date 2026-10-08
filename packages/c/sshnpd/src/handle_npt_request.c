#include "sshnpd/params.h"
#include "sshnpd/permitopen.h"
#include <atchops/aes.h>
#include <atchops/base64.h>
#include <atchops/iv.h>
#include <atchops/rsa_key.h>
#include <atclient/json.h>
#include <atclient/monitor.h>
#include <atclient/notify.h>
#include <atclient/string_utils.h>
#include <atlogger/atlogger.h>
#include <errno.h>
#include <srv/params.h>
#include <sshnpd/daemon.h>
#include <sshnpd/handle_npt_request.h>
#include <sshnpd/handle_ssh_request.h>
#include <sshnpd/handler_commons.h>
#include <sshnpd/run_srv_process.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

#define LOGGER_TAG "NPT_REQUEST"

void handle_npt_request(atclient *atclient, sshnpd_params *params, bool *is_child_process,
                        atclient_monitor_message *message, atchops_rsa_key_private_key signing_key,
                        const sshnpd_policy_decision *policy) {
  int res = 0;

  cJSON *envelope = extract_envelope_from_notification(message);
  if (envelope == NULL) {
    return;
  }
  // allocated: envelope

  // log envelope
  if (atlogger_get_logging_level() >= ATLOGGER_LOGGING_LEVEL_DEBUG) {
    char *envelope_str = cJSON_Print(envelope);
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Received envelope: %s\n", envelope_str);
    free(envelope_str);
  }

  char *requesting_atsign = message->notification->from;
  res = verify_envelope_signature_from(envelope, requesting_atsign, atclient);
  if (res != 0) {
    cJSON_Delete(envelope);
    return;
  }

  res = verify_envelope_contents(envelope, payload_type_npt);

  if (res != 0) {
    cJSON_Delete(envelope);
    return;
  }
  // Passed to various handlers in handler_commons
  cJSON *payload = cJSON_GetObjectItem(envelope, "payload");

  // Used by permitopen check
  cJSON *requested_host = cJSON_GetObjectItem(payload, "requestedHost");
  cJSON *requested_port = cJSON_GetObjectItem(payload, "requestedPort");

  // Don't try optimizing this to reuse the permitopen struct from main.c.
  // none of the memory duplication here is expensive, and it's a surface for bugs
  permitopen_params permitopen;
  permitopen.permitopen_len = params->permitopen_len;
  permitopen.permitopen_hosts = params->permitopen_hosts;
  permitopen.permitopen_ports = params->permitopen_ports;
  permitopen.requested_host = cJSON_GetStringValue(requested_host);
  permitopen.requested_port = cJSON_GetNumberValue(requested_port);

  char *session_id_for_errors = cJSON_GetStringValue(cJSON_GetObjectItem(payload, "sessionId"));

  if (!should_permitopen(&permitopen)) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_WARN, "Denying request to %s:%d\n", permitopen.requested_host,
                 permitopen.requested_port);
    char po_list[256];
    format_permitopen_list(params->permitopen_hosts, params->permitopen_ports, params->permitopen_len, po_list,
                           sizeof(po_list));
    char error_message[512];
    snprintf(error_message, sizeof(error_message), "Connection to %s:%d denied based on daemon --permit-open %s",
             permitopen.requested_host, permitopen.requested_port, po_list);
    send_session_error(atclient, params, requesting_atsign, session_id_for_errors, error_message);
    cJSON_Delete(envelope);
    return;
  }

  // Both the daemon's own permit-open list and the policy service's must
  // allow the connection
  if (policy != NULL && !policy_permits_open(policy, permitopen.requested_host, (uint16_t)permitopen.requested_port)) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_WARN,
                 "Denying request to %s:%d - not in the policy service's permitOpen list\n", permitopen.requested_host,
                 permitopen.requested_port);
    char po_list[256];
    format_string_list(policy->permit_open, policy->permit_open_len, po_list, sizeof(po_list));
    char error_message[512];
    snprintf(error_message, sizeof(error_message), "Connection to %s:%d denied based on POLICY --permit-open %s",
             permitopen.requested_host, permitopen.requested_port, po_list);
    send_session_error(atclient, params, requesting_atsign, session_id_for_errors, error_message);
    cJSON_Delete(envelope);
    return;
  }

  bool authenticate_to_rvd = cJSON_IsTrue(cJSON_GetObjectItem(payload, "authenticateToRvd"));
  char *rvd_auth_string = NULL;
  char *escr_signing_key_uri = NULL;
  sshnpd_escr_context escr_context;
  bool use_escr = false;

  if (authenticate_to_rvd) {
    // RelayAuthMode: absent or "payload" means the legacy signed auth string,
    // "escr" means encrypted signed challenge response (required for relays
    // running on a single shared port, e.g. 443)
    char *relay_auth_mode = cJSON_GetStringValue(cJSON_GetObjectItem(payload, "relayAuthMode"));
    if (relay_auth_mode != NULL && strcmp(relay_auth_mode, "escr") == 0) {
      char *relay_auth_aes_key = cJSON_GetStringValue(cJSON_GetObjectItem(payload, "relayAuthAesKey"));
      char *session_id_str = cJSON_GetStringValue(cJSON_GetObjectItem(payload, "sessionId"));
      if (relay_auth_aes_key != NULL && session_id_str != NULL) {
        escr_signing_key_uri = public_signing_key_uri(&atkeys, params->atsign);
      }
      if (escr_signing_key_uri != NULL) {
        escr_context.session_id = session_id_str;
        escr_context.aes_key_base64 = relay_auth_aes_key;
        escr_context.signing_key_uri = escr_signing_key_uri;
        escr_context.signing_key_base64 = atkeys.pkam_private_key_base64;
        use_escr = true;
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_INFO, "Session will use escr relay auth\n");
      } else {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_WARN,
                     "escr relay auth requested but request is missing relayAuthAesKey or sessionId - falling back to "
                     "legacy relay auth\n");
      }
    }
    if (!use_escr) {
      res = create_rvd_auth_string(payload, &signing_key, &rvd_auth_string);
      if (res != 0) {
        cJSON_Delete(envelope);
        return;
      }
      // allocated: rvd_auth_string
    }
  }

  bool encrypt_rvd_traffic = cJSON_IsTrue(cJSON_GetObjectItem(payload, "encryptRvdTraffic"));
  bool twin_keys = encrypt_rvd_traffic && cJSON_IsTrue(cJSON_GetObjectItem(payload, "twinKeys"));
  unsigned char *session_aes_key_c2d = NULL;
  unsigned char *session_iv_c2d = NULL;
  char *session_aes_key_c2d_base64 = NULL;
  char *session_iv_c2d_base64 = NULL;
  unsigned char *session_aes_key_d2c = NULL;
  unsigned char *session_iv_d2c = NULL;
  char *session_aes_key_d2c_base64 = NULL;
  char *session_iv_d2c_base64 = NULL;

  if (encrypt_rvd_traffic) {
    res = setup_rvd_session_encryption(payload, &session_aes_key_c2d, &session_aes_key_c2d_base64, &session_iv_c2d,
                                       &session_iv_c2d_base64);
    if (res != 0) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to setup rvd session encryption\n");
      cJSON_Delete(envelope);
      if (rvd_auth_string != NULL) {
        free(rvd_auth_string);
      }
      free(escr_signing_key_uri);
      return;
    }
  }

  if (twin_keys) {
    // Generate a second key and iv for the daemon to client direction
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_INFO, "Session will use twinned keys\n");
    res = setup_rvd_session_encryption(payload, &session_aes_key_d2c, &session_aes_key_d2c_base64, &session_iv_d2c,
                                       &session_iv_d2c_base64);
    if (res != 0) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to setup rvd session d2c encryption\n");
      free(session_aes_key_c2d);
      free(session_iv_c2d);
      free(session_aes_key_c2d_base64);
      free(session_iv_c2d_base64);
      cJSON_Delete(envelope);
      if (rvd_auth_string != NULL) {
        free(rvd_auth_string);
      }
      free(escr_signing_key_uri);
      return;
    }
  }
  // At this point, allocated memory:
  // - envelope (always)
  // - rvd_auth_string (if authenticate_to_rvd == true)
  // - session_aes_key_c2d (if encrypt_rvd_traffic == true)
  // - session_iv_c2d (if encrypt_rvd_traffic == true)
  // - session_aes_key_c2d_base64 (if encrypt_rvd_traffic == true)
  // - session_iv_c2d_base64 (if encrypt_rvd_traffic == true)
  // - the four session_*_d2c* equivalents (if twin_keys == true)

  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Running fork()...\n");

  pid_t pid = fork();
  int status;

  if (pid == 0) {
    // child process

    // free this immediately, we don't need it on the child fork
    if (encrypt_rvd_traffic) {
      free(session_aes_key_c2d_base64);
      free(session_iv_c2d_base64);
    }
    if (twin_keys) {
      free(session_aes_key_d2c_base64);
      free(session_iv_d2c_base64);
    }
    char *rvd_host_str = cJSON_GetStringValue(cJSON_GetObjectItem(payload, "rvdHost"));
    uint16_t rvd_port_int = cJSON_GetNumberValue(cJSON_GetObjectItem(payload, "rvdPort"));

    char *requested_host_str = cJSON_GetStringValue(requested_host);
    uint16_t requested_port_int = cJSON_GetNumberValue(requested_port);

    const bool multi = true;

    // The npt session request carries the timeout in milliseconds; the srv
    // works in whole seconds, so round up (DaemonFeature.adjustableTimeout)
    int timeout_seconds = SRV_DEFAULT_TIMEOUT_SECONDS;
    cJSON *timeout_json = cJSON_GetObjectItem(payload, "timeout");
    if (cJSON_IsNumber(timeout_json) && cJSON_GetNumberValue(timeout_json) > 0) {
      double timeout_ms = cJSON_GetNumberValue(timeout_json);
      // Clamp before the cast: an out-of-range double -> int conversion is UB.
      // The cap matches the npt client's "never" timeout (-T 0 -> 365 days),
      // the largest value a well-behaved client sends.
      if (timeout_ms > (double)SRV_MAX_TIMEOUT_SECONDS * 1000.0) {
        timeout_ms = (double)SRV_MAX_TIMEOUT_SECONDS * 1000.0;
      }
      timeout_seconds = (int)((timeout_ms + 999) / 1000);
      if (timeout_seconds < 1) {
        timeout_seconds = 1;
      }
    }

    run_srv_process(rvd_host_str, rvd_port_int, requested_host_str, requested_port_int, authenticate_to_rvd,
                    rvd_auth_string, use_escr ? &escr_context : NULL, encrypt_rvd_traffic, multi, timeout_seconds,
                    session_aes_key_c2d, session_iv_c2d, session_aes_key_d2c, session_iv_d2c);

    *is_child_process = true;

    if (encrypt_rvd_traffic) {
      free(session_aes_key_c2d);
      free(session_iv_c2d);
    }
    if (twin_keys) {
      free(session_aes_key_d2c);
      free(session_iv_d2c);
    }
    if (rvd_auth_string != NULL) {
      cJSON_free(rvd_auth_string);
    }
    free(escr_signing_key_uri);
    cJSON_Delete(envelope);
    return;

    // end of child process
  } else if (pid > 0) {
    // parent process

    // since we use WNOHANG,
    // waitpid will return -1, if an error occurred
    // waitpid will return 0, if the child process has not exited
    // waitpid will return the pid of the child process if it has exited
    int waitpid_return = waitpid(pid, &status, WNOHANG); // Don't wait for srv - we want it to be running in the bg
    if (waitpid_return > 0) {
      // child process has already exited
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "srv process has already exited\n");
      if (WIFEXITED(status)) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "srv process exited with status %d\n", status);
      } else {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "srv process exited abnormally\n");
      }
      goto cancel;
    } else if (waitpid_return == -1) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to wait for srv process: %s\n", strerror(errno));
      goto cancel;
    }

    res = send_success_payload(payload, atclient, params, session_aes_key_c2d_base64, session_iv_c2d_base64,
                               session_aes_key_d2c_base64, session_iv_d2c_base64, &signing_key, requesting_atsign);
    if (res != 0) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                   "Failed to send success message to the requesting atsign: %s\n", requesting_atsign);
      goto cancel;
    }

    // end of parent process
  } else {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to fork the srv process: %s\n", strerror(errno));
  }
cancel:
  if (rvd_auth_string != NULL) {
    cJSON_free(rvd_auth_string);
  }
  free(escr_signing_key_uri);
  if (encrypt_rvd_traffic) {
    free(session_iv_c2d);
    free(session_aes_key_c2d);
    free(session_iv_c2d_base64);
    free(session_aes_key_c2d_base64);
  }
  if (twin_keys) {
    free(session_iv_d2c);
    free(session_aes_key_d2c);
    free(session_iv_d2c_base64);
    free(session_aes_key_d2c_base64);
  }
  cJSON_Delete(envelope);
  return;
}
