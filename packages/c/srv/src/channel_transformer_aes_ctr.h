#ifndef SRC_CHANNEL_TRANSFORMER_AES_CTR_H
#define SRC_CHANNEL_TRANSFORMER_AES_CTR_H
#ifdef __cplusplus
extern "C" {
#endif

#include "channel_transformer.h"
#include <srv/params.h>

int create_local_to_remote_channel_transformer_aes_ctr(
    struct channel_transformer **transformer);

int create_remote_to_local_channel_transformer_aes_ctr(
    struct channel_transformer **transformer);
#ifdef __cplusplus
}
#endif
#endif
