#ifndef SRV_CHANNEL_TRANSFORMER_AES_CTR_H
#define SRV_CHANNEL_TRANSFORMER_AES_CTR_H
#ifdef __cplusplus
extern "C" {
#endif

#include "channel_transformer.h"
#include <mbedtls/aes.h>
#include <srv/params.h>

struct aes_ctr_transformer_state {
  mbedtls_aes_context ctx;
  unsigned char nonce_counter[16];
  unsigned char stream_block[16];
  size_t nc_off;
};

struct aes_ctr_transformer_params {
  unsigned char decrypt_key[32];
  unsigned char decrypt_iv[16];
  unsigned char encrypt_key[32];
  unsigned char encrypt_iv[16];
  unsigned int decrypt_keybits;
  unsigned int encrypt_keybits;
};

#define aes_ctr_transformer_params_initializer                                 \
  (struct aes_ctr_transformer_params) {                                        \
    .decrypt_key = {0}, .decrypt_iv = {0}, .encrypt_key = {0},                 \
    .encrypt_iv = {0}, .decrypt_keybits = 0, .encrypt_keybits = 0,             \
  }

#ifdef __cplusplus
}
#endif
#endif
