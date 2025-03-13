#include "ring.h"
#include <unistd.h>

struct ring_buffer ring_get_current_fill_buffer(struct ring *ring) {
  ring_index_t pos = ring->fill_pos;
  return (struct ring_buffer){
      .buffer = ring->buffers[pos],
      .length = &ring->lengths[pos],
  };
}
struct ring_buffer ring_get_current_drain_buffer(struct ring *ring) {
  ring_index_t pos = ring->drain_pos;
  return (struct ring_buffer){
      .buffer = ring->buffers[pos],
      .length = &ring->lengths[pos],
  };
}

ring_index_t ring_advance_fill_buffer(struct ring *ring) {
  ring_index_t next_pos = ring_next_pos(ring->fill_pos);
  // Wait until the next position is not in use by the other side
  while (ring->drain_pos == next_pos) {
    usleep(ring_advance_timeout);
  }
  ring->fill_pos = next_pos;
  return next_pos;
}

ring_index_t ring_advance_drain_buffer(struct ring *ring) {
  ring_index_t next_pos = ring_next_pos(ring->drain_pos);
  // Wait until the next position is not in use by the other side
  while (ring->fill_pos == next_pos) {
    usleep(ring_advance_timeout);
  }
  ring->drain_pos = next_pos;
  return next_pos;
}
