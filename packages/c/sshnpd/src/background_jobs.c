#include "sshnpd/params.h"
#include <atclient/atkey.h>
#include <atclient/connection.h>
#include <atlogger/atlogger.h>
#include <pthread.h>
#include <sshnpd/background_jobs.h>
#include <sshnpd/sshnpd.h>
#include <stdio.h>
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
        atlogger_log(HEARTBEAT_TAG, ATLOGGER_LOGGING_LEVEL_INFO, "connection available\n");
        last_heartbeat_ok = 1;
      }
    } else {
      if (last_heartbeat_ok != 0) {
        atlogger_log(HEARTBEAT_TAG, ATLOGGER_LOGGING_LEVEL_INFO, "connection lost\n");
        last_heartbeat_ok = 0;
      }
    }
    sleep(15 * MIN_IN_MS); // Once every 15 mins
  }
}

void *refresh_device_entry(void *void_refresh_device_entry_params) {
  struct refresh_device_entry_params *params = void_refresh_device_entry_params;

  // Buffer for the atkeys
  size_t num_managers = params->params->manager_list_len;
  atclient_atkey atkeys[num_managers];

  // Buffer for the base portion of each atkey
  size_t key_base_len = strlen(params->params->device) + strlen(params->params->atsign) +
                        20; // +11 for device_info,+5 for sshnp, +3 for additional seperators, +1 for null term
  char key_base[key_base_len];
  // example: :device_info.device_name.sshnp@client_atsign
  snprintf(key_base, key_base_len, ":device_info.%s.sshnp.%s", params->params->device, params->params->atsign);

  // Build each atkey
  for (int i = 0; i < num_managers; i++) {
    atclient_atkey_init(atkeys + i);
    size_t buffer_len = strlen(params->params->manager_list[i]) + key_base_len;
    char atkey_buffer[buffer_len];
    // example: @client_atsign:device_info.device_name.sshnp@client_atsign
    snprintf(atkey_buffer, buffer_len, "%s%s", params->params->manager_list[i], key_base);
    atclient_atkey_from_string(atkeys + i, atkey_buffer, buffer_len);
  }

  while (true) {
    sleep(HOUR_IN_MS); // Once an hour
  }
}
