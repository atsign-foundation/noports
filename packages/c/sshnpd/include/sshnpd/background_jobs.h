#ifndef BACKGROUND_JOBS_H
#define BACKGROUND_JOBS_H

#include "sshnpd/params.h"
#include <atclient/atclient.h>
#include <atclient/atkey.h>

#define SEC_IN_MS 1000
#define MIN_IN_MS (60 * SEC_IN_MS)
#define HOUR_IN_MS (60 * MIN_IN_MS)

#define NOOP_COMMAND "noop:0\r\n"
#define NOOP_COMMAND_LEN 8

#define HEARTBEAT_TAG "heartbeat thread"
#define REFRESH_TAG "refresh thread"

#define DEVICE_INFO "device_info"
#define DEVICE_INFO_LEN 11
/**
 * @brief a struct which gets passed to heartbeat as a void pointer
 *
 * @param atclient the atclient context to use to send the heartbeat
 * @param fds a pair of file descriptors to communicate with the main thread
 */
struct heartbeat_params {
  atclient *atclient;
  int fds[2];
};

/**
 * @brief A handler function pointer to heartbeat the atServer
 *
 * heartbeat_params a void pointer to a struct heartbeat_params
 */
void *heartbeat(void *heartbeat_params);

/**
 * @brief a struct which gets passed to refresh_device_entry as a void pointer
 *
 * @param atclient the atclient context to use to send the device entry
 * @param params the SshnpdParams which provide the device name and manager (list)
 * @param fds a pair of file descriptors to communicate with the main thread
 */
struct refresh_device_entry_params {
  atclient *atclient;
  pthread_mutex_t *atclient_lock;
  const SshnpdParams *params;
  const char *payload;
  const char *username;
  int fds[2];
};

/**
 * @brief A handler function pointer to update the device entry
 *
 * refresh_device_entry_params a void pointer to a struct refresh_device_entry_params
 */
void *refresh_device_entry(void *refresh_device_entry_params);
#endif
