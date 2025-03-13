#ifndef SRV_CHANNEL_H
#define SRV_CHANNEL_H
#ifdef __cplusplus
extern "C" {
#endif

#include "channel_sink.h"
#include <stdlib.h>

struct channel {
  // sinks[0] is the decrypt side
  // sinks[1] is the encrypt side
  struct channel_sink sinks[2];
  // io[0] is the local side
  // io[1] is the remote side
  struct channel_io io[2];

  // callback called on close
  struct channel_bitmask *channel_bitmask;
  int channel_handle;

  struct pthread_handle *pthread_handle;
  enum pthread_mode pthread_mode;
};

void free_channel(struct channel *);

// pthread functions
void *run_channel(void *_channel);

#ifdef __cplusplus
}
#endif
#endif
