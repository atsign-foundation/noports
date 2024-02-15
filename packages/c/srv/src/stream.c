#include "srv/srv.h"
#include <atlogger/atlogger.h>
#include <srv/stream.h>
#include <stdlib.h>

#define TAG "aes - transform"
int aes_ctr_encrypt_stream(const chunked_transformer_t *self, unsigned char *buffer, size_t *len) {
  // Access the state from the self pointer
  aes_ctr_transformer_state_t *state = (aes_ctr_transformer_state_t *)&self->aes_ctr;

  unsigned char *output = malloc(*len * sizeof(unsigned char));
  atclient_atlogger_log(TAG, DEBUG, "Encrypting %lu bytes\n", *len);
  // Encrypt the buffer to the chunk
  int res = mbedtls_aes_crypt_ctr(&state->ctx, *len, &state->nc_off, state->nonce_counter, state->stream_block, output,
                                  buffer);

  if (res != 0) {
    atclient_atlogger_log(TAG, ERROR, "Failed to encrypt chunk\n");
    free(output);
    return res;
  }
  // Free the old chunk and assign the address of the encrypted one
  unsigned char *temp = buffer;
  buffer = output;
  free(temp);

  return 0;
}

int aes_ctr_decrypt_stream(const chunked_transformer_t *self, unsigned char *buffer, size_t *len) {
  // Access the state from the self pointer
  aes_ctr_transformer_state_t *state = (aes_ctr_transformer_state_t *)&self->aes_ctr;

  unsigned char *output = malloc(*len * sizeof(unsigned char));
  atclient_atlogger_log(TAG, DEBUG, "Decrypting %lu bytes\n", *len);
  // Decrypt the buffer to the chunk
  int res = mbedtls_aes_crypt_ctr(&state->ctx, *len, &state->nc_off, state->nonce_counter, state->stream_block, output,
                                  buffer);
  if (res != 0) {
    atclient_atlogger_log(TAG, ERROR, "Failed to decrypt chunk\n");
    free(output);
    return res;
  }
  // Free the old chunk and assign the address of the decrypted one
  unsigned char *temp = buffer;
  buffer = output;
  free(temp);

  return 0;
}
