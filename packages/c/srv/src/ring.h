#ifndef SRV_RING_H
#define SRV_RING_H
#ifdef __cplusplus
extern "C" {
#endif
#include <stdlib.h>

// Ring buffer backlog config (index is dependent on backlog_size)
enum { ring_backlog_size = 3 };
#define ring_index_t uint8_t
enum { ring_index_bits = 2 }; // bits required to represent backlog_size + 1

// Ring buffer config
enum { ring_buffer_size = UINT16_MAX };
#define ring_next_pos(current)                                                 \
  (current >= (ring_backlog_size - 1) ? 0 : current + 1)
enum { ring_advance_timeout = 10 };

struct ring {
  size_t lengths[ring_backlog_size];
  unsigned char buffers[ring_backlog_size][ring_buffer_size];
  ring_index_t fill_pos : ring_index_bits;
  ring_index_t drain_pos : ring_index_bits;
};

#define ring_initializer                                                       \
  (struct ring) {                                                              \
    .lengths = {0}, .buffers = {0}, .fill_pos = 0,                             \
    .drain_pos = ring_backlog_size,                                            \
  }

// pointers to one of the buffers / lengths in ring
struct ring_buffer {
  size_t *length;
  unsigned char *buffer;
};

struct ring_buffer ring_get_current_fill_buffer(struct ring *);
struct ring_buffer ring_get_current_drain_buffer(struct ring *);

ring_index_t ring_advance_fill_buffer(struct ring *);
ring_index_t ring_advance_drain_buffer(struct ring *);

#ifdef __cplusplus
}
#endif
#endif
