#include "sshnpd/params.h"
#include <atclient/atkey.h>
#include <atclient/connection.h>
#include <atclient/metadata.h>
#include <atlogger/atlogger.h>
#include <pthread.h>
#include <sshnpd/background_jobs.h>
#include <sshnpd/sshnpd.h>
#include <stdio.h>
#include <string.h>

#define LOGGER_TAG "heartbeat"
#define THIRTY_DAYS_IN_MS ((long)1000 * 60 * 60 * 24 * 30)

void *heartbeat(void *void_heartbeat_params) {
  struct heartbeat_params *params = void_heartbeat_params;
  int res;
  while (true) {
    atclient_send_heartbeat(params->atclient);
    sleep(15 * MIN_IN_MS); // Once every 15 mins
  }
}

void *refresh_device_entry(void *void_refresh_device_entry_params) {
  struct refresh_device_entry_params *params = void_refresh_device_entry_params;

  // TODO: also send the USERNAME key

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
  int ret = 0;
  for (int i = 0; i < num_managers; i++) {
    atclient_atkey_init(atkeys + i);
    size_t buffer_len = strlen(params->params->manager_list[i]) + key_base_len;
    char atkey_buffer[buffer_len];
    // example: @client_atsign:device_info.device_name.sshnp@client_atsign
    snprintf(atkey_buffer, buffer_len, "%s%s", params->params->manager_list[i], key_base);
    ret = atclient_atkey_from_string(atkeys + i, atkey_buffer, buffer_len);

    atclient_atkey_metadata *metadata = &(atkeys + 1)->metadata;
    atclient_atkey_metadata_set_ispublic(metadata, false);
    atclient_atkey_metadata_set_isencrypted(metadata, true);
    atclient_atkey_metadata_set_ttr(metadata, -1);
    atclient_atkey_metadata_set_ccd(metadata, true);
    atclient_atkey_metadata_set_ttl(metadata, THIRTY_DAYS_IN_MS);
  }
  // from dart code:
  // const ttl = 1000 * 60 * 60 * 24 * 30; // 30 days
  // var metaData = Metadata()
  //   ..isPublic = false
  //   ..isEncrypted = true
  //   ..ttr = -1 // we want this to be cacheable by managerAtsign
  //   ..ccd = true // we want cached copies to be deleted if the key is deleted
  //   ..ttl = ttl // but to expire after 30 days
  //   TODO: these don't exist in at_c... do we need them?
  //   ..updatedAt = DateTime.now()
  //   ..namespaceAware = true;

  while (true) {
    for (int i = 0; i < num_managers; i++) {
      pthread_mutex_lock(&ATCLIENT_LOCK);
      if (params->params->hide) {
        ret = atclient_delete(params->atclient, atkeys + i);
      } else {
        ret = atclient_put(params->atclient, atkeys + i, params->payload, strlen(params->payload), NULL);
      }
      pthread_mutex_unlock(&ATCLIENT_LOCK);
      if (ret != 0) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to refresh device entry for %s\n",
                     params->params->manager_list[i]);
      }
    }
    sleep(HOUR_IN_MS); // Once an hour
  }

  // Clean up upon exit
  for (int i = 0; i < num_managers; i++) {
    atclient_atkey_free(atkeys + i); // automatically cleans up metadata as well
  }
}
