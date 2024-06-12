#include "sshnpd/params.h"
#include "sshnpd/sshnpd.h"
#include <atclient/atkey.h>
#include <atclient/monitor.h>
#include <atclient/notify.h>
#include <atlogger/atlogger.h>
#include <pthread.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#define LOGGER_TAG "PING RESPONSE"

void handle_ping(sshnpd_params *params, atclient_monitor_message *message, char *ping_response, atclient *atclient,
                 pthread_mutex_t *atclient_lock) {
  atclient_atkey pingkey;
  atclient_atkey_init(&pingkey);

  size_t keynamelen = strlen("heartbeat") + strlen(params->device) + 2; // + 1 for '.' +1 for '\0'
  char keyname[keynamelen];
  snprintf(keyname, keynamelen, "heartbeat.%s", params->device);
  atclient_atkey_create_sharedkey(&pingkey, keyname, keynamelen, params->atsign, strlen(params->atsign),
                                  message->notification.from, strlen(message->notification.from), SSHNP_NS,
                                  SSHNP_NS_LEN);

  atclient_atkey_metadata *metadata = &pingkey.metadata;
  atclient_atkey_metadata_set_ispublic(metadata, false);
  atclient_atkey_metadata_set_isencrypted(metadata, true);
  atclient_atkey_metadata_set_ttl(metadata, 10000);

  atclient_notify_params notify_params;
  atclient_notify_params_init(&notify_params);
  notify_params.key = pingkey;
  notify_params.value = ping_response;
  notify_params.operation = ATCLIENT_NOTIFY_OPERATION_UPDATE;

  int ret = pthread_mutex_lock(atclient_lock);
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
