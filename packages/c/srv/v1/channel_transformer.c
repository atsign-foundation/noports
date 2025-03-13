#include "channel_transformer.h"
#include "atlogger/atlogger.h"
#include "channel_transformer_aes_ctr.h"

#define TAG "channel_transformer"

int create_transform_ctx(enum srv_transformer_type type,
                         struct channel_transformer *decrypt_ctx,
                         struct channel_transformer *encrypt_ctx) {
  int ret;
  switch (type) {
  case srv_transformer_none:
    return 0;
  case srv_transformer_aes_ctr:
    ret =
        create_aes_ctr_transform_ctx_from_environment(decrypt_ctx, encrypt_ctx);
    if (ret != 0) {
      atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                   "Failed to create aes ctr tranformer context\n");
      return ret;
    }
  }

  return 0;
}

int channel_transform(struct channel_transformer *ctx,
                      const unsigned char *buffer, uint16_t len,
                      unsigned char *output, uint16_t *olen) {
  switch (ctx->type) {
  case unset_transform_type:
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Cannot apply transformation: unset transform type\n");
    return 1;
  case aes_ctr:
    return aes_ctr_transform(ctx, buffer, len, output, olen);
  }
}

void free_channel_transform_ctx(struct channel_transformer *ctx) {
  if (ctx == NULL) {
    return;
  }
  switch (ctx->type) {
  case unset_transform_type:
    break;
  case aes_ctr:
    free_aes_ctr_transform_ctx(ctx);
  }
  ctx->type = unset_transform_type;
}
