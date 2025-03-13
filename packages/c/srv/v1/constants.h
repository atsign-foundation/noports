#ifndef SRV_CONFIG_H
#define SRV_CONFIG_H
#ifdef __cplusplus
extern "C" {
#endif

#include "stdint.h"

// Maximum number of concurrent child channels (multiple of 8)
enum { srv_max_concurrent_channels = 512 };
enum { srv_channel_bitmask_bytes = (srv_max_concurrent_channels / 8) };

#define channel_transform_ctx_initializer                                      \
  (struct channel_transform_ctx) {                                             \
    .type = unset_transform_type, .buffer = {0}, .buffer_len = 0,              \
  }

#define channel_sink_initializer                                               \
  (struct channel_sink) {                                                      \
    .io = {NULL}, .buffer = ring_initializer,                                  \
    .transform_ctx = channel_transform_ctx_initializer,                        \
    .pthread_handle = NULL,                                                    \
  }
// TODO add back io
#define channel_initializer                                                    \
  (struct channel) {                                                           \
    .sinks = {channel_sink_initializer}, .channel_bitmask = NULL,              \
    .channel_handle = -1, .pthread_handle = NULL,                              \
    .pthread_mode = pthread_mode_wait,                                         \
  }

#define single_session_initializer                                             \
  (struct single_session) { .channel = channel_initializer }

// TODO add back control_io
#define control_session_initializer                                            \
  (struct control_session) { .channels_head = NULL }

#define channel_bitmask_initializer                                            \
  (struct channel_bitmask) { .opened_channels = {0}, .closed_channels = {0}, }

// controls the stack size for channel sink threads:
// - run_channel_sink_drain
// - run_channel_sink_fill
#define run_channel_sink_stacksize (sizeof(void *) * 4) // 4 = 32/8

// controls the stack size of channel manager threads:
// - run_channel
#define run_channel_stacksize (sizeof(void *) * 2) // 2 = 16 /8

#ifdef __cplusplus
}
#endif
#endif
