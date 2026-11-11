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
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

#define LOGGER_TAG "daemon"

int set_worker_hooks() {
  atclient_connection_hooks_enable(&worker.atserver_connection);
  return atclient_connection_hooks_set(&worker.atserver_connection, ATCLIENT_CONNECTION_HOOK_TYPE_PRE_WRITE,
                                       reconnect_atclient);
}

int reconnect_atclient() {
  char *TAG = "reconnect";
  int ret = 0;

  if (!atclient_is_connected(&worker)) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_INFO, "Worker client is not connected, attempting to reconnect:\n");
    ret = atclient_pkam_authenticate(&worker, params.atsign, &atkeys, &worker_options, NULL);

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

unsigned sshnpd_reconnect_delay_s(unsigned failures) {
  if (failures == 0) {
    return 0;
  }
  // 1, 2, 4, 8, ... up to the cap; the shift is skipped once it could only
  // exceed the cap, so a long outage can't overflow it
  if (failures - 1 >= 8 * sizeof(unsigned) - 1 || (1u << (failures - 1)) > MONITOR_RECONNECT_MAX_DELAY_S) {
    return MONITOR_RECONNECT_MAX_DELAY_S;
  }
  return 1u << (failures - 1);
}

// Monitor reconnect attempts that have failed in a row; reset by a success
static unsigned monitor_reconnect_failures = 0;

// Logs a failed monitor reconnect attempt and pauses before the next: the
// main loop calls reconnect_monitor again at once, so without the pause an
// atServer outage would be hammered with a TLS handshake per iteration
static void monitor_reconnect_failed(const char *what) {
  if (monitor_reconnect_failures < UINT_MAX) {
    monitor_reconnect_failures++;
  }
  unsigned delay_s = sshnpd_reconnect_delay_s(monitor_reconnect_failures);
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "%s (attempt %u), trying again in %u second%s...\n", what,
               monitor_reconnect_failures, delay_s, delay_s == 1 ? "" : "s");
  sleep(delay_s);
}

int reconnect_monitor() {
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Seems the monitor connection is down, trying to reconnect\n");

  int ret = atclient_monitor_pkam_authenticate(&monitor_ctx, params.atsign, &atkeys, &monitor_options);
  if (ret != 0) {
    monitor_reconnect_failed("Monitor connection failed to reconnect");
    return ret;
  }

  ret = atclient_monitor_start(&monitor_ctx, regex);
  if (ret != 0) {
    monitor_reconnect_failed("Monitor verb failed to restart");
    return ret;
  }

  if (monitor_reconnect_failures > 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_INFO, "Reconnected the monitor connection after %u failed attempt%s.\n",
                 monitor_reconnect_failures, monitor_reconnect_failures == 1 ? "" : "s");
  } else {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_INFO, "Reconnected the monitor connection.\n");
  }
  monitor_reconnect_failures = 0;
  return 0;
}

void free_atclient_without_disconnect(atclient *atclient) {
  if (atclient_is_atsign_initialized(atclient)) {
    atclient_unset_atsign(atclient);
  }
  atclient_connection *conn = &atclient->atserver_connection;

  if (atclient_connection_hooks_is_enabled(conn)) {
    atclient_connection_hooks_disable(conn);
  }
  free(conn->host);
  // clear the pointer and its initialized flag so a later atclient_free
  // cannot double-free it
  conn->host = NULL;
  conn->_is_host_initialized = false;

  // commented until https://github.com/atsign-foundation/at_c/issues/555
  // has been addressed
  // atclient_tls_socket_free(&conn->_socket);
}

size_t sshnpd_next_timeout_counter(int read_ret, enum atclient_monitor_message_type type, size_t counter) {
  size_t next = read_ret != 0 ? MONITOR_RECONNECT_COUNTER : counter;
  switch (type) {
  case ATCLIENT_MONITOR_MESSAGE_TYPE_EMPTY:
    return next + 1;
  case ATCLIENT_MONITOR_MESSAGE_TYPE_NOTIFICATION:
  case ATCLIENT_MONITOR_MESSAGE_TYPE_DATA_RESPONSE:
  case ATCLIENT_MONITOR_MESSAGE_TYPE_ERROR_RESPONSE:
  case ATCLIENT_MONITOR_ERROR_DECRYPT_NOTIFICATION:
    return 0;
  default:
    return next;
  }
}

enum notification_key sshnpd_notification_kind(const char *key, const char *to, const char *device, const char *from) {
  if (key == NULL || to == NULL || device == NULL || from == NULL) {
    return NK_NONE;
  }
  char tail[strlen(device) + strlen(SSHNP_NS) + strlen(from) + 3];
  snprintf(tail, sizeof(tail), ".%s.%s%s", device, SSHNP_NS, from);
  const char *tail_start = strstr(key, tail);
  size_t head_len = strlen(to);
  if (tail_start == NULL || (size_t)(tail_start - key) <= head_len || strncmp(key, to, head_len) != 0) {
    return NK_NONE;
  }
  const char *name = key + head_len + 1;
  size_t name_len = (size_t)(tail_start - name);
#ifdef SSHNPD_ENABLE_TESTING_SHUTDOWN_NOTIFICATION
  int keys_length = NOTIFICATION_KEYS_LEN + 1;
#else
  int keys_length = NOTIFICATION_KEYS_LEN;
#endif
  for (int i = 1; i < keys_length; i++) {
    if (strlen(notification_key_map[i].str) == name_len && strncmp(name, notification_key_map[i].str, name_len) == 0) {
      return notification_key_map[i].key;
    }
  }
  return NK_NONE;
}
