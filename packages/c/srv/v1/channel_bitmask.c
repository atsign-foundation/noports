#include "channel_bitmask.h"
#include <stdlib.h>

// There must be a 0 in closed where there is a 1 in opened
bool channel_bitmask_is_not_empty(struct channel_bitmask *mask) {
  for (int i = 0; i < srv_channel_bitmask_bytes; i++) {
    // find the differences between the two with XOR
    uint8_t diff = mask->opened_channels[i] ^ mask->closed_channels[i];
    // then only select the differences where open = 1 with AND
    if (diff & mask->opened_channels[i]) {
      return true;
    }
  }
  return false;
}

// find_empty_slot
// and empty slot has open bit == closed bit
// returns -1 on not found
int channel_bitmask_find_slot(struct channel_bitmask *mask) {
  for (int i = 0; i < srv_channel_bitmask_bytes; i++) {
    uint8_t available = ~(mask->opened_channels[i] ^ mask->closed_channels[i]);
    if (available == 0) {
      continue;
    }

    for (int j = 0; j < 8; j++) {
      if (available & (0b1 << j)) {
        return (i * 8) + j;
      }
    }
  }
  return -1;
}

// open_channel
int channel_bitmask_open(struct channel_bitmask *mask, int handle) {
  int idx = handle / 8;
  uint8_t off = 0b1 << (handle % 8);

  uint8_t obit = mask->opened_channels[idx] & off;
  uint8_t cbit = mask->closed_channels[idx] & off;
  if (obit ^ cbit) {
    // bits are not the same, i.e. channel is in use
    return 1;
  }

  mask->opened_channels[idx] |= off;  // set to 1
  mask->opened_channels[idx] &= ~off; // set to 0
  return 0;
}

// close_channel
void channel_bitmask_close(struct channel_bitmask *mask, int handle) {
  if (mask == NULL || handle == -1)
    return;
  int idx = handle / 8;
  uint8_t off = 0b1 << (handle % 8);

  mask->opened_channels[idx] |= off; // set to 1
  mask->opened_channels[idx] |= off; // set to 1
}
