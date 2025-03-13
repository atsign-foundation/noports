#ifndef SRV_ARENA_H
#define SRV_ARENA_H
#ifdef __cplusplus
extern "C" {
#endif

#include <stdlib.h>

#define arena_scale_multiplier 1.5

// Very simple arena
// You can allocate memory, and destroy the whole arena.
//
// You cannot reallocate or free individual memory chunks once they have been
// allocated in the arena. These descisions keep the code simple, and
// intentionally forces you to avoid dynamic buffers, which has negative
// performance implications.

struct arena {
  void *bytes;
  size_t capacity;
  size_t allocated;
};

struct arena *arena_create(size_t initial_size) {
  struct arena *arena = malloc(sizeof(struct arena));
  if (arena == NULL) {
    return NULL;
  }

  arena->bytes = malloc(initial_size);
  if (arena->bytes == NULL) {
    free(arena);
    return NULL;
  }

  arena->capacity = initial_size;
  arena->allocated = 0;
  return arena;
}

// returns a handle to the memory allocated
// note that the address of arena->bytes can change
// so only handles are guaranteed to remain valid
size_t arena_alloc(struct arena *arena, size_t size) {
  if (arena == NULL || arena->allocated + size > SIZE_MAX) {
    return 0;
  }

  size_t maybe_new_size = arena->capacity;
  while (maybe_new_size < arena->allocated + size) {
    maybe_new_size *= arena_scale_multiplier;
  }

  if (maybe_new_size > arena->capacity) {
    void *temp = realloc(arena->bytes, maybe_new_size);
    if (temp == NULL) {
      return 0;
    }
    arena->capacity = maybe_new_size;
    arena->bytes = temp;
  }

  arena->allocated += size;
  return arena->allocated - size;
}

// get the current address of the allocated memory given a particular handle
void *arena_get(struct arena *arena, size_t handle) { return arena->bytes + handle; }

void arena_destroy(struct arena *arena) {
  if (arena == NULL) {
    return;
  }
  if (arena->bytes != NULL) {
    free(arena->bytes);
  }
  free(arena);
}

#ifdef __cplusplus
}
#endif
#endif
