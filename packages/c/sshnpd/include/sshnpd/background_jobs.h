#ifndef BACKGROUND_JOBS_H
#define BACKGROUND_JOBS_H

#include "sshnpd/params.h"
#include <atclient/atclient.h>
#include <atclient/atkey.h>
#include <pthread.h>
#include <signal.h>

/**
 * @brief a struct which gets passed to refresh_device_entry as a void pointer
 *
 * @param atclient the atclient context to use to send the device entry
 * @param params the sshnpd_params which provide the device name and manager (list)
 * @param fds a pair of file descriptors to communicate with the main thread
 */
struct refresh_device_entry_params {
  atclient *atclient;
  pthread_mutex_t *atclient_lock;
  const sshnpd_params *params;
  const char *payload;
  const char *username;
  volatile sig_atomic_t *should_run;
  atclient_atkey *infokeys;
  atclient_atkey *usernamekeys;
};

/**
 * @brief A handler function pointer to update the device entry
 *
 * refresh_device_entry_params a void pointer to a struct refresh_device_entry_params
 */
void *refresh_device_entry(void *refresh_device_entry_params);

#endif
