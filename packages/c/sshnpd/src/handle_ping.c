#include "sshnpd/main.h"
#include "sshnpd/params.h"
#include <atclient/atkey.h>
#include <atclient/monitor.h>
#include <atclient/notify.h>
#include <atlogger/atlogger.h>
#include <pthread.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#define LOGGER_TAG "PING RESPONSE"

void handle_ping(sshnpd_params *params, atclient_monitor_response *message, char *ping_response, atclient *atclient,
                 pthread_mutex_t *atclient_lock) {
  int ret = 1;
  atclient_atkey pingkey;
  atclient_atkey_init(&pingkey);

  size_t keynamelen = strlen("heartbeat") + strlen(params->device) + 2; // + 1 for '.' +1 for '\0'
  char keyname[keynamelen];
  snprintf(keyname, keynamelen, "heartbeat.%s", params->device);
  atclient_atkey_create_shared_key(&pingkey, keyname, params->atsign, message->notification.from, SSHNP_NS);

  atclient_atkey_metadata *metadata = &pingkey.metadata;
  atclient_atkey_metadata_set_is_public(metadata, false);
  atclient_atkey_metadata_set_is_encrypted(metadata, true);
  atclient_atkey_metadata_set_ttl(metadata, 10000);

  atclient_notify_params notify_params;
  atclient_notify_params_init(&notify_params);
  if ((ret = atclient_notify_params_set_atkey(&notify_params, &pingkey)) != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to set atkey in notify params\n");
    goto exit_ping;
  }

  if ((ret = atclient_notify_params_set_operation(&notify_params, ATCLIENT_NOTIFY_OPERATION_UPDATE)) != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to set operation in notify params\n");
    goto exit_ping;
  }

  if ((ret = atclient_notify_params_set_value(&notify_params, ping_response)) != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to set value in notify params\n");
    goto exit_ping;
  }

  ret = pthread_mutex_lock(atclient_lock);
  if (ret != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to get a lock on atclient for sending a notification\n");
    goto exit_ping;
  }

  ret = atclient_notify(atclient, &notify_params, NULL);
  if (ret != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to send ping response to %s\n",
                 message->notification.from);
  }
  ret = pthread_mutex_unlock(atclient_lock);
  if (ret != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to release atclient lock\n");
  } else {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Released the atclient lock\n");
  }
exit_ping:
  atclient_notify_params_free(&notify_params);
  atclient_atkey_free(&pingkey);
  return;
}
