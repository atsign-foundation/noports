#include "srv/srv.h"
#include <atlogger/atlogger.h>
#include <srv/stream.h>

#define TAG "aes - transform"
int aes_ctr_crypt_stream(const chunked_transformer_t *self, size_t len, const unsigned char *input,
                         unsigned char *output) {
  // Access the state from the self pointer
  aes_ctr_transformer_state_t *state = (aes_ctr_transformer_state_t *)&self->aes_ctr;

  // **crypt the buffer to the chunk
  int res =
      mbedtls_aes_crypt_ctr(&state->ctx, len, &state->nc_off, state->nonce_counter, state->stream_block, input, output);

  if (res != 0) {
    atclient_atlogger_log(TAG, ERROR, "Failed to crypt chunk\n");
    return res;
  }

  return 0;
}
