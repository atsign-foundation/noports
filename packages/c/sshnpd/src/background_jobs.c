#include "sshnpd/params.h"
#include <atclient/atkey.h>
#include <atclient/connection.h>
#include <atclient/metadata.h>
#include <atlogger/atlogger.h>
#include <pthread.h>
#include <sshnpd/background_jobs.h>
#include <sshnpd/sshnpd.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
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
  size_t num_username_keys = params->params->hide ? 0 : num_managers;

  atclient_atkey infokeys[num_managers];
  atclient_atkey usernamekeys[num_username_keys];

  // Buffer for the base portion of each atkey
  size_t infokey_base_len = strlen(params->params->device) + strlen(params->params->atsign) +
                            20; // +12 for ":device_info",+5 for sshnp, +2 for '.', +1 for null term
  char infokey_base[infokey_base_len];
  // example: :device_info.device_name.sshnp@client_atsign
  snprintf(infokey_base, infokey_base_len, ":device_info.%s.sshnp%s", params->params->device, params->params->atsign);

  // Buffer for the username keys
  size_t usernamekey_base_len = strlen(params->params->device) + strlen(params->params->atsign) +
                                17; // +9 for ":username",+5 for sshnp, +2 for '.', +1 for null term
  char username_key_base[usernamekey_base_len];
  snprintf(username_key_base, usernamekey_base_len, ":username.%s.sshnp%s", params->params->device,
           params->params->atsign);

  int ret = 0;
  if (params->params->hide) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_INFO,
                 "--hide enabled, deleting any existing username entries for this device\n");
  } else {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_INFO, "Saving username entries for this device\n");
  }
  ret = pthread_mutex_lock(params->atclient_lock);
  for (int i = 0; i < num_managers; i++) {
    // device_info
    atclient_atkey_init(infokeys + i);
    size_t buffer_len = strlen(params->params->manager_list[i]) + infokey_base_len;
    char atkey_buffer[buffer_len];
    // example: @client_atsign:device_info.device_name.sshnp@client_atsign
    snprintf(atkey_buffer, buffer_len, "%s%s", params->params->manager_list[i], infokey_base);
    ret = atclient_atkey_from_string(infokeys + i, atkey_buffer, buffer_len);

    if (ret != 0) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to create device_info atkey for %s\n",
                   params->params->manager_list[i]);
      exit(ret);
    }

    atclient_atkey_metadata *metadata = &(infokeys + i)->metadata;
    atclient_atkey_metadata_set_ispublic(metadata, false);
    atclient_atkey_metadata_set_isencrypted(metadata, true);
    atclient_atkey_metadata_set_ttr(metadata, -1);
    atclient_atkey_metadata_set_ccd(metadata, true);
    atclient_atkey_metadata_set_ttl(metadata, THIRTY_DAYS_IN_MS);

    // username
    atclient_atkey_init(usernamekeys + i);
    buffer_len = strlen(params->params->manager_list[i]) + usernamekey_base_len;
    // example: @client_atsign:device_info.device_name.sshnp@client_atsign
    snprintf(atkey_buffer, buffer_len, "%s%s", params->params->manager_list[i], username_key_base);
    ret = atclient_atkey_from_string(usernamekeys + i, atkey_buffer, buffer_len);
    if (ret != 0) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to create username atkey for %s\n",
                   params->params->manager_list[i]);
      exit(ret);
    }
    atclient_atkey_metadata *metadata2 = &(usernamekeys + i)->metadata;
    atclient_atkey_metadata_set_ispublic(metadata2, false);
    atclient_atkey_metadata_set_isencrypted(metadata2, true);
    atclient_atkey_metadata_set_ttr(metadata2, -1);
    atclient_atkey_metadata_set_ccd(metadata2, true);
    if (params->params->hide) {
      ret = atclient_delete(params->atclient, usernamekeys + i);
      if (ret != 0) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to delete username atkey for %s\n",
                     params->params->manager_list[i]);
        exit(ret);
      }
    } else {
      ret = atclient_put(params->atclient, usernamekeys + i, params->username, strlen(params->username), NULL);
      if (ret != 0) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to put username atkey for %s\n",
                     params->params->manager_list[i]);
        exit(ret);
      }
    }
  }

  do {
    ret = pthread_mutex_unlock(params->atclient_lock);
    if (ret != 0) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                   "Failed to release atclient lock, trying again in 1 second\n");
      sleep(1);
    }
  } while (ret != 0);

  for (int i = 0; i < num_managers; i++) {
    atclient_atkey_free(usernamekeys + i);
  }
  // Build each atkey
  int interval_seconds = 15;
  int counter = 0;
  while (true) {
    ret = pthread_mutex_lock(params->atclient_lock);
    // once an hour the counter will reset
    if (counter == 0) {
      if (params->params->hide) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_INFO,
                     "--hide enabled, deleting any existing device info entries for this device\n");
      } else {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_INFO, "Refreshing device info entries for this device\n");
      }
      for (int i = 0; i < num_managers; i++) {
        if (ret != 0) {
          atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                       "Failed to get a lock on atclient for performing device entry operation\n");
          continue;
        }
        if (params->params->hide) {
          ret = atclient_delete(params->atclient, infokeys + i);
        } else {
          ret = atclient_put(params->atclient, infokeys + i, params->payload, strlen(params->payload), NULL);
        }
        if (ret != 0) {
          atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to refresh device entry for %s\n",
                       params->params->manager_list[i]);
        }
      }
    } else {
      atclient_send_heartbeat(params->atclient);
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Sent a heartbeat on the worker connection\n");
    }
    do {
      ret = pthread_mutex_unlock(params->atclient_lock);
      if (ret != 0) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                     "Failed to release atclient lock, trying again in 1 second\n");
        sleep(1);
      }
    } while (ret != 0);
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Released the atclient lock\n");
    fflush(stdout);
    counter = (counter + 1) % (60 * 60 / interval_seconds); // reset back to 0 once an hour
    sleep(interval_seconds);
  }

  // Clean up upon exit
  for (int i = 0; i < num_managers; i++) {
    atclient_atkey_free(infokeys + i); // automatically cleans up metadata as well
  }
}
