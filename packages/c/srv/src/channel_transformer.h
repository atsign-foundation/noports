#ifndef SRC_CHANNEL_TRANSFORMER_H
#define SRC_CHANNEL_TRANSFORMER_H
#ifdef __cplusplus
extern "C" {
#endif

#include "ring.h"
#include <srv/params.h>
#include <stdlib.h>

struct channel_transformer {
  // buffer for storing the current transformation output
  struct ring buffer;

  // Methods
  void (*free)(struct channel_transformer *self);
  // TODO modify this to use internal ring buffer
  int (*transform)(struct channel_transformer *self,
                   const unsigned char *buffer, size_t len,
                   unsigned char *output, size_t *olen);
};

// typedef for easy casting
// (rhs size_t gets expanded into unsigned long during assignment)
typedef int(channel_transformer_transform)(struct channel_transformer *self,
                                           const unsigned char *buffer,
                                           size_t len, unsigned char *output,
                                           size_t *olen);

#define channel_transformer_initializer                                        \
  (struct channel_transformer) {                                               \
    .buffer = ring_initializer, .free = NULL, .transform = NULL,               \
  }

int create_local_to_remote_channel_transformer(struct srv_params,
                                               struct channel_transformer **);
int create_remote_to_local_channel_transformer(struct srv_params,
                                               struct channel_transformer **);

#ifdef __cplusplus
}
#endif
#endif
