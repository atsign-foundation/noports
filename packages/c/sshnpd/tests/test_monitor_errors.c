// Given a running daemon: how its main loop reacts to each kind of monitor
// read
#include <sshnpd/daemon.h>
#include <stdio.h>

static int failures = 0;

static void check(bool ok, const char *what) {
  if (!ok) {
    printf("FAIL: %s\n", what);
    failures++;
  } else {
    printf("ok: %s\n", what);
  }
}

int main(void) {
  check(sshnpd_next_timeout_counter(1, ATCLIENT_MONITOR_ERROR_DECRYPT_NOTIFICATION, 3) == 0,
        "when @carol sends a notification the daemon can't decrypt, then the daemon doesn't reconnect and carries on "
        "serving");
  check(sshnpd_next_timeout_counter(0, ATCLIENT_MONITOR_MESSAGE_TYPE_NOTIFICATION, 3) == 0,
        "a notification resets the quiet count");
  check(sshnpd_next_timeout_counter(0, ATCLIENT_MONITOR_MESSAGE_TYPE_DATA_RESPONSE, 3) == 0 &&
            sshnpd_next_timeout_counter(0, ATCLIENT_MONITOR_MESSAGE_TYPE_ERROR_RESPONSE, 3) == 0,
        "a data or error response resets the quiet count");
  check(sshnpd_next_timeout_counter(0, ATCLIENT_MONITOR_MESSAGE_TYPE_EMPTY, 3) == 4,
        "an empty read adds one to the quiet count");
  check(sshnpd_next_timeout_counter(1, ATCLIENT_MONITOR_ERROR_READ, 0) == MONITOR_RECONNECT_COUNTER,
        "a failed read reconnects");
  check(sshnpd_next_timeout_counter(1, ATCLIENT_MONITOR_ERROR_PARSE_NOTIFICATION, 0) == MONITOR_RECONNECT_COUNTER,
        "a notification that can't be parsed reconnects");
  check(MONITOR_RECONNECT_COUNTER * MONITOR_READ_TIMEOUT_MS > MONITOR_NOOP_TIMEOUT_MS,
        "the reconnect count is past the main loop's threshold");
  if (failures > 0) {
    printf("%d check(s) failed\n", failures);
    return 1;
  }
  return 0;
}
