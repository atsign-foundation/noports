#ifndef SRC_CHANNEL_SINK_H
#define SRC_CHANNEL_SINK_H
#include "ring.h"
#ifdef __cplusplus
extern "C" {
#endif

#include "channel_io.h"
#include "channel_transformer.h"
#include "pthread_handle.h"
#include <pthread.h>

enum channel_sink_side { drain_side, fill_side };

struct channel_sink {
  // io[0] is the fill side
  // io[1] is the drain side
  struct channel_io *io[2];

  // parent thread condition
  struct pthread_handle *pthread_handle;

  // transformer that modifies the buffer between read & write
  struct channel_transformer *transformer;

  // ring buffer for reading in
  struct ring buffer;
};

int fill_sink(struct channel_sink *sink);
int drain_sink(struct channel_sink *sink);
void free_channel_sink(struct channel_sink *sink);

// pthread functions
void *run_channel_sink_drain(void *channel_sink);
void *run_channel_sink_fill(void *channel_sink);

#define channel_sink_initializer                                               \
  (struct channel_sink) {                                                      \
    .io = {NULL}, .pthread_handle = NULL, .transformer = NULL,                 \
    .buffer = ring_initializer,                                                \
  }

#ifdef __cplusplus
}
#endif
#endif
