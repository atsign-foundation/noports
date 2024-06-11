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
#include <unistd.h>

#define LOGGER_TAG "refresh_device_entry"

void *refresh_device_entry(void *void_refresh_device_entry_params) {
  struct refresh_device_entry_params *params = void_refresh_device_entry_params;

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
  if (ret != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to lock the atclient\n");
    *params->should_run = 0;
    pthread_exit(NULL);
  }

  int index;
  for (index = 0; index < num_managers; index++) {
    // device_info
    atclient_atkey_init(infokeys + index);
    size_t buffer_len = strlen(params->params->manager_list[index]) + infokey_base_len;
    char atkey_buffer[buffer_len];
    // example: @client_atsign:device_info.device_name.sshnp@client_atsign
    snprintf(atkey_buffer, buffer_len, "%s%s", params->params->manager_list[index], infokey_base);
    ret = atclient_atkey_from_string(infokeys + index, atkey_buffer, buffer_len);

    if (ret != 0) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to create device_info atkey for %s\n",
                   params->params->manager_list[index]);
      atclient_atkey_free(infokeys + index);
      break;
    }

    atclient_atkey_metadata *metadata = &(infokeys + index)->metadata;
    atclient_atkey_metadata_set_ispublic(metadata, false);
    atclient_atkey_metadata_set_isencrypted(metadata, true);
    atclient_atkey_metadata_set_ttr(metadata, -1);
    atclient_atkey_metadata_set_ccd(metadata, true);
    atclient_atkey_metadata_set_ttl(metadata, (long)30 * 24 * 60 * 60 * 1000); // 30 days in ms

    // username
    atclient_atkey_init(usernamekeys + index);
    buffer_len = strlen(params->params->manager_list[index]) + usernamekey_base_len;
    // example: @client_atsign:device_info.device_name.sshnp@client_atsign
    snprintf(atkey_buffer, buffer_len, "%s%s", params->params->manager_list[index], username_key_base);
    ret = atclient_atkey_from_string(usernamekeys + index, atkey_buffer, buffer_len);
    if (ret != 0) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to create username atkey for %s\n",
                   params->params->manager_list[index]);
      atclient_atkey_free(infokeys + index);
      atclient_atkey_free(usernamekeys + index);
      break;
    }

    atclient_atkey_metadata *metadata2 = &(usernamekeys + index)->metadata;
    atclient_atkey_metadata_set_ispublic(metadata2, false);
    atclient_atkey_metadata_set_isencrypted(metadata2, true);
    atclient_atkey_metadata_set_ttr(metadata2, -1);
    atclient_atkey_metadata_set_ccd(metadata2, true);
    if (params->params->hide) {
      ret = atclient_delete(params->atclient, usernamekeys + index);
      if (ret != 0) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to delete username atkey for %s\n",
                     params->params->manager_list[index]);
        atclient_atkey_free(infokeys + index);
        atclient_atkey_free(usernamekeys + index);
        break;
      }
    } else {
      ret = atclient_put(params->atclient, usernamekeys + index, params->username, strlen(params->username), NULL);
      if (ret != 0) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to put username atkey for %s\n",
                     params->params->manager_list[index]);
        atclient_atkey_free(infokeys + index);
        atclient_atkey_free(usernamekeys + index);
        break;
      }
    }
  }

  if (ret != 0) {
    for (int i = 0; i < index; i++) {
      atclient_atkey_free(infokeys + i);
      atclient_atkey_free(usernamekeys + i);
    }
    *params->should_run = 0;
  }

  ret = pthread_mutex_unlock(params->atclient_lock);
  if (ret != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to release atclient lock\n");
    *params->should_run = 0;
    pthread_exit(NULL);
  }

  if (!*params->should_run) {
    pthread_exit(NULL);
  }

  for (int i = 0; i < num_managers; i++) {
    atclient_atkey_free(usernamekeys + i);
  }

  // Build each atkey
  int interval_seconds = 60 * 60; // once an hour
  int counter = 0;
  while (*params->should_run) {
    if (counter == 0) {
      ret = pthread_mutex_lock(params->atclient_lock);
      if (ret != 0) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to get a lock on atclient\n");
        *params->should_run = 0;
        break;
      }
      // once an hour the counter will reset
      if (params->params->hide) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_INFO,
                     "--hide enabled, deleting any existing device info entries for this device\n");
      } else {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_INFO, "Refreshing device info entries for this device\n");
      }

      fflush(stdout);

      for (int i = 0; i < num_managers; i++) {
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

      ret = pthread_mutex_unlock(params->atclient_lock);
      if (ret != 0) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to release atclient lock\n");
        *params->should_run = 0;
        break;
      }
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Released the atclient lock\n");
      fflush(stdout);
    }

    if (counter == interval_seconds) {
      counter = 0;
    } else {
      counter++;
    }
    sleep(1);
  }

  // Clean up upon exit
  for (int i = 0; i < num_managers; i++) {
    atclient_atkey_free(infokeys + i); // automatically cleans up metadata as well
  }

  pthread_exit(NULL);
}
