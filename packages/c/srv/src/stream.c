#include "srv/srv.h"
#include <atlogger/atlogger.h>
#include <srv/stream.h>
#include <stdlib.h>
#include <string.h>

#define TAG "aes - transform"
int aes_ctr_encrypt_stream(const chunked_transformer_t *self,
                           unsigned char *chunk, const size_t len,
                           size_t *olen) {
  // Access the state from the self pointer
  aes_ctr_transformer_state_t *state =
      (aes_ctr_transformer_state_t *)&self->aes_ctr;

  // Allocate the output buffer which will replace the memory of chunk
  // unsigned char *buffer = malloc(BUFFER_LEN * sizeof(unsigned char));
  // // TODO: finish this
  // if (len < READ_LEN) {
  //   // This
  //   // Compute the padding length
  //   const size_t padding_len = AES_BLOCK_LEN - (len % AES_BLOCK_LEN);
  //   const unsigned char padval = padding_len;
  //
  //   // Allocate a buffer for the chunk and the padding
  //   *olen = len + padding_len;
  //
  //   // Fill the chunk and the padding
  //   memset(buffer + len, padval, padding_len);
  //   buffer[*olen] = '\0';
  // }
  // atclient_atlogger_log(TAG, INFO, "Encrypting %l bytes", olen);
  unsigned char *buffer = malloc(len * sizeof(unsigned char));
  // Encrypt the buffer to the chunk
  int res = mbedtls_aes_crypt_ctr(&state->ctx, *olen, &state->nc_off,
                                  state->nonce_counter, state->stream_block,
                                  buffer, chunk);

  if (res != 0) {
    atclient_atlogger_log(TAG, ERROR, "Failed to encrypt chunk");
    free(buffer);
    return res;
  } else {
    // Free the old chunk and assign the address of the encrypted one
    free(chunk);
    chunk = buffer;
  }

  return 0;
}

// TODO: Implement the aes_ctr_decrypt_stream function
int aes_ctr_decrypt_stream(const chunked_transformer_t *self,
                           unsigned char *chunk, const size_t len,
                           size_t *olen) {
  // Access the state from the self pointer
  aes_ctr_transformer_state_t *state =
      (aes_ctr_transformer_state_t *)&self->aes_ctr;

  // Compute the padding length
  size_t padding_len = AES_BLOCK_LEN - (len % AES_BLOCK_LEN);
  const unsigned char padval = padding_len;

  // Allocate a buffer for the chunk and the padding
  *olen = len + padding_len;
  unsigned char buffer[*olen + 1]; // +1 for the null terminator

  // Fill the chunk and the padding
  memcpy(buffer, chunk, len);
  memset(buffer + len, padval, padding_len);
  buffer[*olen] = '\0';

  atclient_atlogger_log(TAG, INFO, "Decrypting %l bytes", olen);
  // Encrypt the buffer to the chunk
  int res = mbedtls_aes_crypt_ctr(&state->ctx, *olen, &state->nc_off,
                                  state->nonce_counter, state->stream_block,
                                  buffer, chunk);
  if (res != 0) {
    atclient_atlogger_log(TAG, ERROR, "Failed to decrypt chunk");
    return res;
  }

  while (*(chunk + (*olen)++) != '\0')
    ;
  --olen; // don't count the null terminator

  return 0;
}
