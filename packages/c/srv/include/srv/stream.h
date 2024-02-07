#ifndef STREAM_H
#define STREAM_H
#include <MbedTLS/aes.h>
#include <stddef.h>

#define AES_256_KEY_BYTES 32 // 256 bits = 32 bytes
#define AES_256_KEY_BITS 256

#define AES_BLOCK_LEN 16 // 128 bits = 16 bytes

// Transformer struct typedef
typedef struct _chunked_transformer chunked_transformer_t;

// Tranform function typedef
typedef int(chunk_transform_t)(const struct _chunked_transformer *self,
                               unsigned char *chunk, const size_t len,
                               size_t *olen);

// AES transformer state struct typedef
typedef struct _aes_ctr_transformer_state aes_ctr_transformer_state_t;
struct _aes_ctr_transformer_state {
  mbedtls_aes_context ctx;
  unsigned char nonce_counter[AES_BLOCK_LEN];
  unsigned char stream_block[AES_BLOCK_LEN];
  size_t nc_off;
};

// Tranformer struct definition
struct _chunked_transformer {
  // Different transform functions expect different parameters/state union types
  chunk_transform_t *transform;

  // Transformer State
  union {
    aes_ctr_transformer_state_t aes_ctr;
  };
};

int aes_ctr_crypt_stream(const chunked_transformer_t *self,
                         unsigned char *chunk, const size_t len, size_t *olen);

#endif
