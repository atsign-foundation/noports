#include "sshnpd/policy.h"
#include "sshnpd/sshnpd.h"
#include <atclient/atkey.h>
#include <atclient/json.h>
#include <atclient/notify.h>
#include <atlogger/atlogger.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <time.h>

#define LOGGER_TAG "POLICY"

// How long to wait for the policy service before denying; an ack from the
// policy service resets the clock (it means the request was received and is
// being worked on)
#define POLICY_TIMEOUT_MS 10000

// The rpc request notification expires if undelivered after this long
#define POLICY_REQUEST_EXPIRY_MS 30000

// How often the device heartbeat is sent to the policy service
#define POLICY_HEARTBEAT_SECONDS 300

// AtRpc namespaces: requests/responses travel as
// <type>.<reqId>.auth_checks.__rpcs[.sshnp]@atsign
#define POLICY_RPC_INFIX ".auth_checks.__rpcs"

static int64_t now_millis(void) {
  struct timeval tv;
  gettimeofday(&tv, NULL);
  return (int64_t)tv.tv_sec * 1000 + tv.tv_usec / 1000;
}

// Compare two atsigns, tolerating a missing leading '@' on either side
static bool atsign_equals(const char *a, const char *b) {
  if (a == NULL || b == NULL) {
    return false;
  }
  if (a[0] == '@') {
    a++;
  }
  if (b[0] == '@') {
    b++;
  }
  return strcmp(a, b) == 0;
}

void policy_decision_free(sshnpd_policy_decision *decision) {
  for (size_t i = 0; i < decision->permit_open_len; i++) {
    free(decision->permit_open[i]);
  }
  free(decision->permit_open);
  memset(decision, 0, sizeof(*decision));
}

bool policy_permits_open(const sshnpd_policy_decision *decision, const char *host, uint16_t port) {
  // An authorized client with an empty permitOpen list is a known client
  // with no permitted services - deny
  for (size_t i = 0; i < decision->permit_open_len; i++) {
    const char *entry = decision->permit_open[i];
    const char *colon = strrchr(entry, ':');
    if (colon == NULL) {
      continue; // malformed entry - skip, don't fail the whole list
    }
    size_t host_len = (size_t)(colon - entry);
    const char *port_str = colon + 1;

    bool host_matches = (host_len == 1 && entry[0] == '*') ||
                        (strlen(host) == host_len && strncmp(entry, host, host_len) == 0);
    uint16_t entry_port = (uint16_t)strtoul(port_str, NULL, 10);
    bool port_matches = strcmp(port_str, "*") == 0 || entry_port == 0 || entry_port == port;

    if (host_matches && port_matches) {
      return true;
    }
  }
  return false;
}

int policy_parse_response_value(const char *json, int64_t expected_req_id, sshnpd_policy_decision *decision,
                                char *resp_type_out, size_t resp_type_size) {
  cJSON *root = cJSON_Parse(json);
  if (root == NULL) {
    return 1;
  }

  int ret = 1;

  // The reqId inside the value must match the one we sent - responses to
  // other (stale) requests are not ours to act on
  cJSON *req_id_json = cJSON_GetObjectItem(root, "reqId");
  if (!cJSON_IsNumber(req_id_json) || (int64_t)cJSON_GetNumberValue(req_id_json) != expected_req_id) {
    goto exit;
  }

  char *resp_type = cJSON_GetStringValue(cJSON_GetObjectItem(root, "respType"));
  if (resp_type == NULL) {
    goto exit;
  }
  snprintf(resp_type_out, resp_type_size, "%s", resp_type);

  if (strcmp(resp_type, "success") == 0) {
    cJSON *payload = cJSON_GetObjectItem(root, "payload");
    decision->authorized = cJSON_IsTrue(cJSON_GetObjectItem(payload, "authorized"));

    cJSON *permit_open = cJSON_GetObjectItem(payload, "permitOpen");
    if (cJSON_IsArray(permit_open)) {
      int len = cJSON_GetArraySize(permit_open);
      if (len > 0) {
        decision->permit_open = calloc(len, sizeof(char *));
        if (decision->permit_open == NULL) {
          decision->authorized = false;
          goto exit;
        }
        for (int i = 0; i < len; i++) {
          char *entry = cJSON_GetStringValue(cJSON_GetArrayItem(permit_open, i));
          if (entry == NULL) {
            continue;
          }
          decision->permit_open[decision->permit_open_len] = strdup(entry);
          if (decision->permit_open[decision->permit_open_len] == NULL) {
            policy_decision_free(decision);
            goto exit;
          }
          decision->permit_open_len++;
        }
      }
    }

    char *policy_message = cJSON_GetStringValue(cJSON_GetObjectItem(payload, "message"));
    if (policy_message != NULL) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_INFO, "Policy message: %s\n", policy_message);
    }
  } else if (strcmp(resp_type, "ack") != 0) {
    // nack / error / anything else: log why, decision stays deny
    char *policy_message = cJSON_GetStringValue(cJSON_GetObjectItem(root, "message"));
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_WARN, "Policy service replied %s: %s\n", resp_type,
                 policy_message != NULL ? policy_message : "(no message)");
  }

  ret = 0;

exit:
  cJSON_Delete(root);
  return ret;
}

bool policy_is_policy_service_message(const atclient_atnotification *notification, const sshnpd_params *params) {
  if (params->policy == NULL || notification->key == NULL || !atsign_equals(notification->from, params->policy)) {
    return false;
  }
  return strstr(notification->key, POLICY_RPC_INFIX) != NULL ||
         strstr(notification->key, ".devices.policy.") != NULL;
}

// Whether this notification is a response to our rpc request. The Dart AtRpc
// server sends response keys of the form
// '@daemon:<type>.<reqId>.auth_checks.__rpcs.sshnp@policy' - match on the
// rpcs infix and the reqId, and critically on the sender: only the
// configured policy atsign may answer auth checks (the key pattern alone
// binds the response to nothing).
static bool is_policy_response(const atclient_atnotification *notification, const sshnpd_params *params,
                               int64_t req_id) {
  if (!atsign_equals(notification->from, params->policy)) {
    return false;
  }
  if (strstr(notification->key, POLICY_RPC_INFIX) == NULL) {
    return false;
  }
  char req_id_str[32];
  snprintf(req_id_str, sizeof(req_id_str), ".%lld.", (long long)req_id);
  return strstr(notification->key, req_id_str) != NULL;
}

static int send_auth_check_request(atclient *worker, const sshnpd_params *params, const char *client_atsign,
                                   int64_t req_id) {
  int ret = 1;

  char keyname[96];
  snprintf(keyname, sizeof(keyname), "request.%lld" POLICY_RPC_INFIX, (long long)req_id);

  atclient_atkey key;
  atclient_atkey_init(&key);
  if (atclient_atkey_create_shared_key(&key, keyname, params->atsign, params->policy, SSHNP_NS) != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to create rpc request atkey\n");
    atclient_atkey_free(&key);
    return 1;
  }
  atclient_atkey_metadata_set_is_public(&key.metadata, false);
  atclient_atkey_metadata_set_is_encrypted(&key.metadata, true);

  // NPAAuthCheckRequest
  cJSON *payload = cJSON_CreateObject();
  cJSON_AddItemToObject(payload, "daemonAtsign", cJSON_CreateString(params->atsign));
  cJSON_AddItemToObject(payload, "daemonDeviceName", cJSON_CreateString(params->device));
  // csshnpd has no --device-group option; '__none__' is the Dart default
  cJSON_AddItemToObject(payload, "daemonDeviceGroupName", cJSON_CreateString("__none__"));
  cJSON_AddItemToObject(payload, "clientAtsign", cJSON_CreateString(client_atsign));
  char *payload_str = cJSON_PrintUnformatted(payload);
  cJSON_Delete(payload);
  if (payload_str == NULL) {
    atclient_atkey_free(&key);
    return 1;
  }

  // The reqId is written with snprintf rather than through cJSON so the
  // 64 bit value can't pick up floating point formatting
  size_t value_size = strlen(payload_str) + 64;
  char *value = malloc(value_size);
  if (value == NULL) {
    free(payload_str);
    atclient_atkey_free(&key);
    return 1;
  }
  snprintf(value, value_size, "{\"reqId\":%lld,\"payload\":%s}", (long long)req_id, payload_str);
  free(payload_str);

  atclient_notify_params notify_params;
  atclient_notify_params_init(&notify_params);
  if (atclient_notify_params_set_atkey(&notify_params, &key) != 0 ||
      atclient_notify_params_set_operation(&notify_params, ATCLIENT_NOTIFY_OPERATION_UPDATE) != 0 ||
      atclient_notify_params_set_value(&notify_params, value) != 0 ||
      atclient_notify_params_set_notification_expiry(&notify_params, POLICY_REQUEST_EXPIRY_MS) != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to build rpc request notify params\n");
    goto exit;
  }

  ret = atclient_notify(worker, &notify_params, NULL);
  if (ret != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to notify policy service %s: %d\n", params->policy,
                 ret);
  }

exit:
  atclient_notify_params_free(&notify_params);
  free(value);
  atclient_atkey_free(&key);
  return ret;
}

int policy_auth_check(atclient *worker, atclient *monitor, const sshnpd_params *params, const char *client_atsign,
                      sshnpd_policy_decision *decision) {
  memset(decision, 0, sizeof(*decision));

  int64_t req_id = 0;
  {
    struct timeval tv;
    gettimeofday(&tv, NULL);
    req_id = (int64_t)tv.tv_sec * 1000000 + tv.tv_usec;
  }

  if (send_auth_check_request(worker, params, client_atsign, req_id) != 0) {
    return 1; // fail closed
  }
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_INFO, "Sent auth check for %s to policy service %s (reqId %lld)\n",
               client_atsign, params->policy, (long long)req_id);

  int64_t deadline = now_millis() + POLICY_TIMEOUT_MS;
  while (now_millis() < deadline) {
    atclient_monitor_message message;
    atclient_monitor_message_init(&message);
    int read_res = atclient_monitor_read(monitor, worker, &message, NULL);
    if (read_res != 0) {
      atclient_monitor_message_free(&message);
      continue; // let the deadline decide; the main loop repairs the monitor
    }

    if (message.type == ATCLIENT_MONITOR_MESSAGE_TYPE_NOTIFICATION &&
        atclient_atnotification_is_key_initialized(message.notification) &&
        atclient_atnotification_is_from_initialized(message.notification) &&
        atclient_atnotification_is_decrypted_value_initialized(message.notification)) {
      if (is_policy_response(message.notification, params, req_id)) {
        char resp_type[16] = "";
        if (policy_parse_response_value(message.notification->decrypted_value, req_id, decision, resp_type,
                                        sizeof(resp_type)) == 0) {
          if (strcmp(resp_type, "ack") == 0) {
            // Request received and being worked on - restart the clock
            deadline = now_millis() + POLICY_TIMEOUT_MS;
            atclient_monitor_message_free(&message);
            continue;
          }
          atclient_monitor_message_free(&message);
          return 0; // definite decision (success / nack / error)
        }
      } else if (atsign_equals(message.notification->from, params->policy)) {
        // Config pushes and stale rpc responses from the policy service are
        // routine while a check is in flight - not worth a warning
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG,
                     "Ignoring policy service message %s while waiting for the auth check response\n",
                     message.notification->key);
      } else {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_WARN,
                     "Dropping notification %s received while waiting for the policy service\n",
                     message.notification->key);
      }
    }
    atclient_monitor_message_free(&message);
  }

  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_WARN, "Timed out waiting for policy service %s - denying %s\n",
               params->policy, client_atsign);
  policy_decision_free(decision);
  return 0;
}

void policy_send_heartbeat(atclient *worker, const sshnpd_params *params, const char *ping_response) {
  static time_t last_sent = 0;

  if (params->policy == NULL || ping_response == NULL) {
    return;
  }
  time_t now = time(NULL);
  if (last_sent != 0 && now - last_sent < POLICY_HEARTBEAT_SECONDS) {
    return;
  }
  last_sent = now;

  char keyname[128];
  snprintf(keyname, sizeof(keyname), "%s.devices.policy", params->device);

  atclient_atkey key;
  atclient_atkey_init(&key);
  if (atclient_atkey_create_shared_key(&key, keyname, params->atsign, params->policy, SSHNP_NS) != 0) {
    atclient_atkey_free(&key);
    return;
  }
  atclient_atkey_metadata_set_is_public(&key.metadata, false);
  atclient_atkey_metadata_set_is_encrypted(&key.metadata, true);

  atclient_notify_params notify_params;
  atclient_notify_params_init(&notify_params);
  if (atclient_notify_params_set_atkey(&notify_params, &key) == 0 &&
      atclient_notify_params_set_operation(&notify_params, ATCLIENT_NOTIFY_OPERATION_UPDATE) == 0 &&
      atclient_notify_params_set_value(&notify_params, ping_response) == 0 &&
      atclient_notify_params_set_notification_expiry(&notify_params, POLICY_HEARTBEAT_SECONDS * 1000) == 0) {
    if (atclient_notify(worker, &notify_params, NULL) == 0) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Sent device heartbeat to policy service %s\n",
                   params->policy);
    } else {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_WARN, "Failed to send device heartbeat to policy service %s\n",
                   params->policy);
    }
  }
  atclient_notify_params_free(&notify_params);
  atclient_atkey_free(&key);
}
