#include "channel_sink.h"
#include "channel_transformer.h"
#include "pthread_handle.h"
#include "ring.h"
#include <atlogger/atlogger.h>
#include <pthread.h>
#include <stdbool.h>
#include <unistd.h>

#define TAG "channel_sink"

int fill_sink(struct channel_sink *sink) {
  if (sink == NULL) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to fill sink: sink is NULL\n");
    return 1;
  }

  struct channel_io *io = sink->io[0];

  struct ring_buffer buffer = ring_get_current_fill_buffer(&sink->buffer);
  // uint8_t pos = sink->fill_pos;
  // unsigned char *buffer = sink->ring[pos];
  // uint16_t *buffer_len = &sink->ring_lens[pos];

  int ret = io->recv(io, buffer.buffer, buffer.length);
  if (ret != 0) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to fill sink: failed to read from io\n");
    return ret;
  }

  ring_advance_fill_buffer(&sink->buffer);
  return 0;
}

int transform_sink(struct channel_sink *sink) {
  if (sink == NULL) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to transform sink: sink is NULL\n");
    return 1;
  }

  struct channel_transformer *transformer = sink->transformer;
  if (transformer == NULL) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to transform sink: transformer is NULL\n");
    return 1;
  }

  struct ring_buffer in = ring_get_current_drain_buffer(&sink->buffer);
  struct ring_buffer out =
      ring_get_current_fill_buffer(&sink->transformer->buffer);

  int ret = transformer->transform(transformer, in.buffer, *in.length,
                                   out.buffer, out.length);

  if (ret != 0) {
    return ret;
  }
  ring_advance_fill_buffer(&sink->transformer->buffer);
  ring_advance_drain_buffer(&sink->buffer);

  return 0;
}

int drain_sink(struct channel_sink *sink) {
  if (sink == NULL) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to drain sink: sink is NULL\n");
    return 1;
  }

  struct ring *ring;
  if (sink->transformer == NULL) {
    ring = &sink->buffer;
  } else {
    ring = &sink->transformer->buffer;
  }
  struct ring_buffer buffer = ring_get_current_drain_buffer(ring);
  int ret = sink->io[1]->send(sink->io[1], buffer.buffer, *buffer.length);
  if (ret != 0) {
    return ret;
  }
  ring_advance_drain_buffer(ring);
  return 0;
}

void free_channel_sink(struct channel_sink *sink) {
  struct channel_transformer *transformer = sink->transformer;
  transformer->free(transformer);
  // TODO no pthread handle free?
  free_channel_io(sink->io[0]);
  free_channel_io(sink->io[1]);
}

// pthread functions

// struct channel_sink* sink
void *run_channel_sink_drain(void *_channel_sink) {
  struct channel_sink *sink = (struct channel_sink *)_channel_sink;
  pthread_cleanup_push((void *)pthread_handle_signal, sink->pthread_handle);

  int ret;
  while (true) {
    if (sink->transformer != NULL) {
      ret = transform_sink(sink);
      if (ret != 0) {
        break;
      }
    }
    ret = drain_sink(sink);
    if (ret != 0) {
      break;
    }
  }
  pthread_cleanup_pop(true);
  pthread_exit(NULL);
}

void *run_channel_sink_fill(void *_channel_sink) {
  struct channel_sink *sink = (struct channel_sink *)_channel_sink;
  pthread_cleanup_push((void *)pthread_handle_signal, sink->pthread_handle);

  int ret;
  while (true) {
    ret = fill_sink(sink);
    if (ret != 0) {
      break;
    }
  }

  pthread_cleanup_pop(true);
  pthread_exit(NULL);
}
