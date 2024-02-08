#include "srv/srv.h"
#include <atlogger.h>
#include <srv/stream.h>
#include <string.h>

#define TAG "aes - transform"
int aes_ctr_crypt_stream(const chunked_transformer_t *self,
                         unsigned char *chunk, const size_t len, size_t *olen) {
  // Access the state from the self pointer
  aes_ctr_transformer_state_t *state =
      (aes_ctr_transformer_state_t *)&self->aes_ctr;

  // Compute the padding length
  const size_t padding_len = AES_BLOCK_LEN - (len % AES_BLOCK_LEN);
  const unsigned char padval = padding_len;

  // Allocate a buffer for the chunk and the padding
  *olen = len + padding_len;
  unsigned char buffer[*olen + 1]; // +1 for the null terminator

  // Fill the chunk and the padding
  memcpy(buffer, chunk, len);
  memset(buffer + len, padval, padding_len);
  buffer[*olen] = '\0';

  atclient_atlogger_log(TAG, INFO, "En/decrypting %l bytes", olen);
  // Encrypt the buffer to the chunk
  int res = mbedtls_aes_crypt_ctr(&state->ctx, *olen, &state->nc_off,
                                  state->nonce_counter, state->stream_block,
                                  buffer, chunk);
  if (res != 0) {
    atclient_atlogger_log(TAG, ERROR, "Failed to en/decrypt chunk");
    return res;
  }

  return 0;
}
