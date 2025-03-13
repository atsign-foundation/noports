#ifndef SRC_CHANNEL_BITMASK_H
#define SRC_CHANNEL_BITMASK_H
#ifdef __cplusplus
extern "C" {
#endif

#include "constants.h"
#include <stdbool.h>
#include <stdint.h>

struct channel_bitmask {
  uint8_t opened_channels[srv_channel_bitmask_bytes];
  uint8_t closed_channels[srv_channel_bitmask_bytes];
};

bool channel_bitmask_is_not_empty(struct channel_bitmask *mask);
int channel_bitmask_find_slot(struct channel_bitmask *mask);
int channel_bitmask_open(struct channel_bitmask *mask, int handle);
void channel_bitmask_close(struct channel_bitmask *mask, int handle);

#ifdef __cplusplus
}
#endif
#endif
