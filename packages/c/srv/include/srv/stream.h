#ifndef STREAM_H
#define STREAM_H
#include <MbedTLS/aes.h>

#define AES_256_KEY_BYTES 32 // 256 bits = 32 bytes
#define AES_256_KEY_BITS 256

#define AES_BLOCK_LEN 16 // 128 bits = 16 bytes
struct _chunked_transformer;

/**
 * @brief type definition for a chunk based transform function
 *
 * @param self a pointer to the structure storing the context accessed by this function
 * @param len the output length of the buffer
 * @param input the buffer to crypt
 * @param output the output buffer to crypt
 * @return int 0 on success, non-zero on error
 */
typedef int(chunk_transform_t)(const struct _chunked_transformer *self, size_t len, const unsigned char *input,
                               unsigned char *output);

/**
 * @brief structure for storing the state behind aesctr stream encyption / decryption
 */
typedef struct _aes_ctr_transformer_state {
  mbedtls_aes_context ctx;
  unsigned char nonce_counter[AES_BLOCK_LEN];
  unsigned char stream_block[AES_BLOCK_LEN];
  size_t nc_off;
} aes_ctr_transformer_state_t;

/**
 * @brief a structure for handling a chunk based tranformer
 *
 * Contains the function pointer for the transform function, and the state/context required by that function.
 */
typedef struct _chunked_transformer {
  // Different transform functions expect different parameters/state union types
  chunk_transform_t *transform;

  // Transformer state/context
  union {
    aes_ctr_transformer_state_t aes_ctr;
  };
} chunked_transformer_t;

/**
 * @brief encrypt a chunk of a stream using aesctr
 *
 * @param self a pointer to the structure storing the context accessed by this function
 * @param len the output length of the buffer
 * @param input the buffer to crypt
 * @param output the output buffer to crypt
 * @return int 0 on success, non-zero on error
 */
int aes_ctr_crypt_stream(const chunked_transformer_t *self, size_t len, const unsigned char *input,
                         unsigned char *output);
#endif
