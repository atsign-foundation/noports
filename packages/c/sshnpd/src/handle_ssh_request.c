#include "sshnpd/params.h"
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
#include <sshnpd/daemon.h>
#include <sshnpd/handle_ssh_request.h>
#include <sshnpd/handler_commons.h>
#include <sshnpd/run_srv_process.h>
#include <srv/params.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

#define LOGGER_TAG "SSH_REQUEST"

// TODO: refactor this to call the new common handlers
void handle_ssh_request(atclient *atclient, sshnpd_params *params, bool *is_child_process,
                        atclient_monitor_message *message, atchops_rsa_key_private_key signing_key) {
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

  // First validate the types of everything we expect to be in the envelope
  res = verify_envelope_contents(envelope, payload_type_ssh);

  if (res != 0) {
    cJSON_Delete(envelope);
    return;
  }
  cJSON *payload = cJSON_GetObjectItem(envelope, "payload");

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
        escr_context.signing_key = &atkeys.pkam_private_key;
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

    char *rvd_host_str = cJSON_GetStringValue(cJSON_GetObjectItem(payload, "host"));
    uint16_t rvd_port_int = cJSON_GetNumberValue(cJSON_GetObjectItem(payload, "port"));
    char *requested_host_str = "localhost";
    uint16_t requested_port_int = params->local_sshd_port;

    const bool multi = false;

    // ssh_request payloads don't carry a timeout - only npt session requests do
    int res = run_srv_process(rvd_host_str, rvd_port_int, requested_host_str, requested_port_int, authenticate_to_rvd,
                              rvd_auth_string, use_escr ? &escr_context : NULL, encrypt_rvd_traffic, multi,
                              SRV_DEFAULT_TIMEOUT_SECONDS, session_aes_key_c2d, session_iv_c2d, session_aes_key_d2c,
                              session_iv_d2c);
    if (res != 0) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "srv process exited with code: %d\n", res);
    }
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
  if (!*is_child_process) {
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
  }
  return;
}
