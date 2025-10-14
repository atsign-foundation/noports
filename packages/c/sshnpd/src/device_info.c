#include "atlogger/atlogger.h"
#include "sshnpd/daemon.h"
#include "sshnpd/params.h"
#include <atclient/atclient.h>
#include <sshnpd/device_info.h>
#include <string.h>
#include <time.h>

int handle_username_keys(atclient *atclient, const char **atsigns, size_t num_atsigns, const char *username,
                         const char *device_name, const char *device_atsign, bool make_visible) {
  int ret;
  const char *TAG = "send_username_keys";

  if (num_atsigns <= 0) {
    return 0;
  }

  for (size_t i = 0; i < num_atsigns; i++) {
    const char *atsign = atsigns[i];
    // example: @client:username.devicename.sshnp@device
    size_t atkey_strlen = strlen(atsign) + strlen(device_name) + strlen(device_atsign) + 17;
    char atkey_str[atkey_strlen];
    snprintf(atkey_str, atkey_strlen, "%s:username.%s.sshnp%s", atsign, device_name, device_atsign);

    atclient_atkey atkey;
    atclient_atkey_init(&atkey);
    ret = atclient_atkey_from_string(&atkey, atkey_str);
    if (ret != 0) {
      atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to build username key for %s\n", atsign);
      continue;
    }

    atclient_atkey_metadata *metadata = &atkey.metadata;
    ret = atclient_atkey_metadata_set_is_public(metadata, false);
    if (ret != 0) {
      atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to set is_public on metadata for %s username key\n",
                   atsign);
      atclient_atkey_free(&atkey);
      continue;
    }

    ret = atclient_atkey_metadata_set_is_encrypted(metadata, true);
    if (ret != 0) {
      atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to set is_encrypted on metadata for %s username key\n",
                   atsign);
      atclient_atkey_free(&atkey);
      continue;
    }
    ret = atclient_atkey_metadata_set_ttr(metadata, -1);
    if (ret != 0) {
      atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to set ttr on metadata for %s username key\n", atsign);
      atclient_atkey_free(&atkey);
      continue;
    }
    ret = atclient_atkey_metadata_set_ccd(metadata, true);
    if (ret != 0) {
      atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to set ccd on metadata for %s username key\n", atsign);
      atclient_atkey_free(&atkey);
      continue;
    }
    if (make_visible) {
      ret = atclient_put_shared_key(atclient, &atkey, username, NULL, NULL);
      atclient_atkey_free(&atkey);
      if (ret != 0) {
        atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to put username key for %s\n", atsign);
        continue;
      }
    } else {
      ret = atclient_delete(atclient, &atkey, NULL, NULL);
      atclient_atkey_free(&atkey);
      if (ret != 0) {
        atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to delete username key for %s\n", atsign);
        continue;
      }
    }
  }

  return ret;
}

void send_next_device_info(atclient *atclient, sshnpd_params *params) {
  int ret;
  const char *TAG = "send_next_device_info";
  if (params->manager_list_len == 0 || params->manager_list == NULL || device_info_last_sent == NULL) {
    return;
  }
  if (device_info_pos >= params->manager_list_len) {
    device_info_pos = 0;
  }

  time_t now = time(NULL);                                   // in seconds
  if (now < device_info_last_sent[device_info_pos] + 3600) { // wait at least an hour before refreshing again
    return;
  }

  const char *atsign = params->manager_list[device_info_pos];
  // example: @client:device_info.devicename.sshnp@device
  size_t atkey_strlen = strlen(atsign) + strlen(params->device) + strlen(params->atsign) + 20;
  char atkey_str[atkey_strlen];
  snprintf(atkey_str, atkey_strlen, "%s:device_info.%s.sshnp%s", atsign, params->device, params->atsign);

  // setup atkey
  atclient_atkey atkey;
  atclient_atkey_init(&atkey);
  ret = atclient_atkey_from_string(&atkey, atkey_str);

  if (ret != 0) {
    atclient_atkey_free(&atkey);
    device_info_attempts++;
    return;
  }

  atclient_atkey_metadata *metadata = &atkey.metadata;
  ret = atclient_atkey_metadata_set_is_public(metadata, false);
  if (ret != 0) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to set is_public on metadata for %s devicee_info key\n",
                 atsign);
    atclient_atkey_free(&atkey);
    return;
  }

  ret = atclient_atkey_metadata_set_is_encrypted(metadata, true);
  if (ret != 0) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to set is_encrypted on metadata for %s device_info key\n",
                 atsign);
    atclient_atkey_free(&atkey);
    return;
  }
  ret = atclient_atkey_metadata_set_ttr(metadata, -1);
  if (ret != 0) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to set ttr on metadata for %s device_info key\n", atsign);
    atclient_atkey_free(&atkey);
    return;
  }
  ret = atclient_atkey_metadata_set_ccd(metadata, true);
  if (ret != 0) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to set ccd on metadata for %s device_info key\n", atsign);
    atclient_atkey_free(&atkey);
    return;
  }
  ret = atclient_atkey_metadata_set_ttl(metadata, (int64_t)30 * 24 * 60 * 60 * 1000);
  if (ret != 0) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to set ttl on metadata for %s device_info key\n", atsign);
    atclient_atkey_free(&atkey);
    return;
  }

  if (!params->hide) {
    ret = atclient_put_shared_key(atclient, &atkey, ping_response, NULL, NULL);
    atclient_atkey_free(&atkey);
    if (ret != 0) {
      atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to refresh device info entry for %s\n", atsign);
      device_info_attempts++;
      return;
    }
  } else {
    enum atlogger_logging_level previous_level = atlogger_get_logging_level();
    atlogger_set_logging_level(ATLOGGER_LOGGING_LEVEL_NONE);
    atclient_delete(atclient, &atkey, NULL, NULL); // don't care about ret
    atlogger_set_logging_level(previous_level);
    atclient_atkey_free(&atkey);
  }

  device_info_attempts = 0;
  device_info_pos++;
}
