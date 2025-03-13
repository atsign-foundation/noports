#include "channel_transformer.h"
#include "channel_transformer_aes_ctr.h"
#include <srv/params.h>

int create_local_to_remote_channel_transformer(
    struct srv_params params, struct channel_transformer **transformer) {
  int ret;
  switch (params.transformer) {
  case srv_transformer_none:
    *transformer = NULL;
    ret = 0;
    break;
  case srv_transformer_aes_ctr:
    ret = create_local_to_remote_channel_transformer_aes_ctr(transformer);
    break;
  }
  return ret;
}

int create_remote_to_local_channel_transformer(
    struct srv_params params, struct channel_transformer **transformer) {
  int ret;
  switch (params.transformer) {
  case srv_transformer_none:
    *transformer = NULL;
    ret = 0;
    break;
  case srv_transformer_aes_ctr:
    ret = create_remote_to_local_channel_transformer_aes_ctr(transformer);
    break;
  }
  return ret;
}
