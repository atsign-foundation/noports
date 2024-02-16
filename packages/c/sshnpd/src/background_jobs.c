#include <atclient/connection.h>
#include <atlogger/atlogger.h>
#include <pthread.h>
#include <sshnpd/background_jobs.h>
#include <string.h>

void *heartbeat(void *void_heartbeat_params) {
  struct heartbeat_params *params = void_heartbeat_params;
  int res;
  const size_t recvlen = 50;
  unsigned char recv[recvlen];
  size_t olen;
  bool last_heartbeat_ok = 1;
  while (true) {
    // TODO: mutex blocks
    res = atclient_connection_send(&params->atclient->secondary_connection, (unsigned char *)NOOP_COMMAND,
                                   NOOP_COMMAND_LEN, recv, recvlen, &olen);
    // TODO: mutex unblocks
    if (res == 0 && olen >= 7 && strncmp((const char *)recv, "data:ok", 7) == 0) {
      if (last_heartbeat_ok != 1) {
        atclient_atlogger_log(HEARTBEAT_TAG, ATLOGGER_LOGGING_LEVEL_INFO, "connection available\n");
        last_heartbeat_ok = 1;
      }
    } else {
      if (last_heartbeat_ok != 0) {
        atclient_atlogger_log(HEARTBEAT_TAG, ATLOGGER_LOGGING_LEVEL_INFO, "connection lost\n");
        last_heartbeat_ok = 0;
      }
    }
    sleep(15 * MIN_IN_MS); // Once every 15 mins
  }
}

void *refresh_device_entry(void *refresh_device_entry_params) {
  // TODO: device entry
  pthread_exit(NULL);
}
