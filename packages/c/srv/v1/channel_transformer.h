#ifndef SRV_CHANNEL_TRANSFORMER_H
#define SRV_CHANNEL_TRANSFORMER_H
#include "ring_buffer.h"
#include <srv/params.h>
#ifdef __cplusplus
extern "C" {
#endif

#include "constants.h"
#include <srv/params.h>
#include <stdint.h>

struct channel_transform_ctx {
  // buffer for storing the current transformation output
  struct ring buffer;

  // Methods
  void (*free)(struct channel_transform_ctx *self);
  // TODO modify this to use internal ring buffer
  int (*transform)(struct channel_transform_ctx *self, const unsigned *buffer,
                   uint16_t len, unsigned char *output, uint16_t *olen);
};

int create_transform_ctx(enum srv_transformer_type type,
                         struct channel_transform_ctx *decrypt_ctx,
                         struct channel_transform_ctx *encrypt_ctx);

int channel_transform(struct channel_transform_ctx *ctx,
                      const unsigned char *buffer, uint16_t len,
                      unsigned char *output, uint16_t *olen);

void free_channel_transform_ctx(struct channel_transform_ctx *);

#ifdef __cplusplus
}
#endif
#endif
