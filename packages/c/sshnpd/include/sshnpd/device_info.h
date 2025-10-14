#ifndef SSHNPD_DEVICE_INFO_H
#define SSHNPD_DEVICE_INFO_H
#include "atclient/notify_params.h"
#include "sshnpd/params.h"
#ifdef __cplusplus
extern "C" {
#endif

#include "atclient/atclient.h"
#include <stdlib.h>

#define SSHNPD_DEVICE_INFO_MAX_ATTEMPTS 3

struct sshnpd_device_info_state {
  atclient_notify_params *params;
  time_t *last_sent_at;
  size_t len;
  size_t pos;
  uint8_t attempts;
};

int handle_username_keys(atclient *atclient, const char **atsigns, size_t num_atsigns, const char *username,
                         const char *device_name, const char *device_atsign, bool make_visible);
void send_next_device_info(atclient *atclient, sshnpd_params *params);

#ifdef __cplusplus
}
#endif
#endif
