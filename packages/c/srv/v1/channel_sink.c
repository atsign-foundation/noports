#include "channel_sink.h"
#include "channel_transformer.h"
#include "pthread_handle.h"
#include "ring_buffer.h"
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

  int ret = recv_channel_io(io, buffer.buffer, buffer.length);
  if (ret != 0) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to fill sink: failed to read from io\n");
    return ret;
  }

  ring_advance_fill_buffer(&sink->buffer);
  return 0;
}

int drain_sink(struct channel_sink *sink) {
  if (sink == NULL) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to drain sink: sink is NULL\n");
    return 1;
  }

  struct channel_transform_ctx *transform_ctx = &sink->transform_ctx;
  struct ring_buffer buffer = ring_get_current_drain_buffer(&sink->buffer);

  // pointer to where the drain side is
  // if we perform a transform, then this will be different
  unsigned char *drain_buffer = buffer.buffer;
  uint16_t *drain_len = buffer.length;

  int ret;
  if (transform_ctx != NULL) {
    ret = channel_transform(transform_ctx, drain_buffer, *drain_len,
                            transform_ctx->buffer, &transform_ctx->buffer_len);
    if (ret != 0) {
      atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                   "Failed to apply transformation to a packet\n");
      return ret;
    }

    drain_buffer = transform_ctx->buffer;
    drain_len = &transform_ctx->buffer_len;
  }

  // write to channel_io
  struct channel_io *io = sink->io[1];
  ret = recv_channel_io(io, drain_buffer, drain_len);
  if (ret < 0) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Error writing to drain io from sink\n");
    return ret;
  }

  ring_advance_drain_buffer(&sink->buffer);
  return 0;
}

void free_channel_sink(struct channel_sink *sink) {
  free_channel_transform_ctx(&sink->transform_ctx);
}

// pthread functions

// struct channel_sink* sink
void *run_channel_sink_drain(void *_channel_sink) {
  struct channel_sink *sink = (struct channel_sink *)_channel_sink;
  pthread_cleanup_push((void *)pthread_handle_signal, sink->pthread_handle);

  int ret;
  while (true) {
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
