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
#include <pthread.h>
#include <sshnpd/handle_ssh_request.h>
#include <sshnpd/handler_commons.h>
#include <sshnpd/run_srv_process.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

#define LOGGER_TAG "NPT_REQUEST"

void handle_npt_request(atclient *atclient, pthread_mutex_t *atclient_lock, sshnpd_params *params,
                        bool *is_child_process, atclient_monitor_response *message,
                        atchops_rsa_key_private_key signing_key) {
  int res = 0;

  cJSON *envelope = extract_envelope_from_notification(message);
  if (envelope == NULL) {
    return;
  }
  // allocated: envelope

  // log envelope
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Received envelope: %s\n", cJSON_Print(envelope));

  char *requesting_atsign = message->notification.from;
  res = verify_envelope_signature_from(envelope, requesting_atsign, atclient, atclient_lock);
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

  if (!should_permitopen(&permitopen)) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Ignoring request to localhost:%d\n",
                 permitopen.requested_port);
    cJSON_Delete(envelope);
    return;
  }

  bool authenticate_to_rvd = cJSON_IsTrue(cJSON_GetObjectItem(payload, "authenticateToRvd"));
  char *rvd_auth_string;

  if (authenticate_to_rvd) {
    res = create_rvd_auth_string(payload, &signing_key, &rvd_auth_string);
    if (res != 0) {
      cJSON_Delete(envelope);
      return;
    }
    // allocated: rvd_auth_string
  }

  bool encrypt_rvd_traffic = cJSON_IsTrue(cJSON_GetObjectItem(payload, "encryptRvdTraffic"));
  unsigned char *session_aes_key = NULL;
  unsigned char *session_iv = NULL;
  char *session_aes_key_base64 = NULL;
  char *session_iv_base64 = NULL;

  if (encrypt_rvd_traffic) {
    res = setup_rvd_session_encryption(payload, &session_aes_key, &session_aes_key_base64, &session_iv,
                                       &session_iv_base64);
    if (res != 0) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to setup rvd session encryption\n");
      cJSON_Delete(envelope);
      if (authenticate_to_rvd) {
        free(rvd_auth_string);
      }
      return;
    }
  }
  // At this point, allocated memory:
  // - envelope (always)
  // - rvd_auth_string (if authenticate_to_rvd == true)
  // - session_aes_key (if encrypt_rvd_traffic == true)
  // - session_iv (if encrypt_rvd_traffic == true)
  // - session_aes_key_base64 (if encrypt_rvd_traffic == true)
  // - session_iv_base64 (if encrypt_rvd_traffic == true)

  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Running fork()...\n");

  pid_t pid = fork();
  int status;

  if (pid == 0) {
    // child process

    // free this immediately, we don't need it on the child fork
    if (encrypt_rvd_traffic) {
      free(session_aes_key_base64);
      free(session_iv_base64);
    }
    char *rvd_host_str = cJSON_GetStringValue(cJSON_GetObjectItem(payload, "rvdHost"));
    uint16_t rvd_port_int = cJSON_GetNumberValue(cJSON_GetObjectItem(payload, "rvdPort"));

    char *requested_host_str = cJSON_GetStringValue(requested_host);
    uint16_t requested_port_int = cJSON_GetNumberValue(requested_port);

    const bool multi = true;

    int res = run_srv_process(rvd_host_str, rvd_port_int, requested_host_str, requested_port_int, authenticate_to_rvd,
                              rvd_auth_string, encrypt_rvd_traffic, multi, session_aes_key, session_iv);
    *is_child_process = true;

    if (encrypt_rvd_traffic) {
      free(session_aes_key);
      free(session_iv);
    }
    if (authenticate_to_rvd) {
      cJSON_free(rvd_auth_string);
    }
    cJSON_Delete(envelope);
    exit(res);

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

    res = send_success_payload(payload, atclient, atclient_lock, params, session_aes_key_base64, session_iv_base64,
                               &signing_key, requesting_atsign);
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
  if (authenticate_to_rvd) {
    cJSON_free(rvd_auth_string);
  }
  if (encrypt_rvd_traffic) {
    free(session_iv);
    free(session_aes_key);
    free(session_iv_base64);
    free(session_aes_key_base64);
  }
  cJSON_Delete(envelope);
  return;
}
