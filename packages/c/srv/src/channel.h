#ifndef SRC_CHANNEL_H
#define SRC_CHANNEL_H
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
  struct channel_io *io[2];

  struct pthread_handle *pthread_handle;
  enum pthread_mode pthread_mode;
};

void free_channel(struct channel *);
void link_channel(struct channel *channel);
int start_channel(struct channel *, enum pthread_mode);

#define channel_initializer                                                    \
  (struct channel) {                                                           \
    .sinks = {channel_sink_initializer}, .io = {NULL}, .pthread_handle = NULL, \
    .pthread_mode = pthread_mode_wait,                                         \
  }

#ifdef __cplusplus
}
#endif
#endif
