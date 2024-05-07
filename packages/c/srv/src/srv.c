#include "srv/srv.h"
#include "srv/params.h"
#include "srv/side.h"
#include <atchops/base64.h>
#include <atlogger/atlogger.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define TAG "srv - run"

int run_srv(srv_params_t *params) {
  chunked_transformer_t encrypter;
  chunked_transformer_t decrypter;
  int res;
  if (params->rv_e2ee == 1) {
    atlogger_log(TAG, INFO, "Configuring encrypter/decrypter for srv\n");

    // Temporary buffer for decoding the key
    unsigned char aes_key[AES_256_KEY_BYTES];
    size_t aes_key_len;

    // Decode the key
    res = atchops_base64_decode((unsigned char *)params->session_aes_key_string, strlen(params->session_aes_key_string),
                                aes_key, AES_256_KEY_BYTES, &aes_key_len);

    if (res != 0 || aes_key_len != AES_256_KEY_BYTES) {
      atlogger_log(TAG, ERROR, "Error decoding session_aes_key_string\n");
      return res;
    }

    mbedtls_aes_init(&encrypter.aes_ctr.ctx); // FREE
    res = mbedtls_aes_setkey_enc(&encrypter.aes_ctr.ctx, aes_key, AES_256_KEY_BITS);
    if (res != 0) {
      atlogger_log(TAG, ERROR, "Error setting encryption key\n");
      mbedtls_aes_free(&encrypter.aes_ctr.ctx);
      return res;
    }

    mbedtls_aes_init(&decrypter.aes_ctr.ctx); // FREE
    res = mbedtls_aes_setkey_enc(&decrypter.aes_ctr.ctx, aes_key, AES_256_KEY_BITS);
    if (res != 0) {
      atlogger_log(TAG, ERROR, "Error setting decryption key\n");
      mbedtls_aes_free(&encrypter.aes_ctr.ctx);
      mbedtls_aes_free(&decrypter.aes_ctr.ctx);
      return res;
    }

    // Decode the iv
    size_t iv_len;
    res = atchops_base64_decode((unsigned char *)params->session_aes_iv_string, strlen(params->session_aes_iv_string),
                                encrypter.aes_ctr.nonce_counter, AES_BLOCK_LEN, &iv_len);
    if (res != 0 || iv_len != AES_BLOCK_LEN) {
      atlogger_log(TAG, ERROR, "Error decoding session_aes_iv_string\n");
      mbedtls_aes_free(&encrypter.aes_ctr.ctx);
      mbedtls_aes_free(&decrypter.aes_ctr.ctx);
      return res;
    }

    // Copy the iv to the decrypter
    memcpy(decrypter.aes_ctr.nonce_counter, encrypter.aes_ctr.nonce_counter, AES_BLOCK_LEN);

    // Set the stream blocks to 0
    memset(encrypter.aes_ctr.stream_block, 0, AES_BLOCK_LEN);
    memset(decrypter.aes_ctr.stream_block, 0, AES_BLOCK_LEN);

    // Set the iv offset to 0
    encrypter.aes_ctr.nc_off = 0;
    decrypter.aes_ctr.nc_off = 0;

    // Set the transform functions
    encrypter.transform = aes_ctr_crypt_stream;
    decrypter.transform = aes_ctr_crypt_stream;
  }

  if (params->bind_local_port == 0) {
    atlogger_log(TAG, INFO, "Starting socket to socket srv\n");
    res = socket_to_socket(params, params->rvd_auth_string, &encrypter, &decrypter);
  } else {
    atlogger_log("srv - bind", ATLOGGER_LOGGING_LEVEL_ERROR, "--local-bind-port is disabled\n");
    exit(1);

    atlogger_log(TAG, INFO, "Starting server to socket srv\n");
    res = server_to_socket(params, params->rvd_auth_string, &encrypter, &decrypter);
  }

  if (params->rv_e2ee == 1) {
    mbedtls_aes_free(&encrypter.aes_ctr.ctx);
    mbedtls_aes_free(&decrypter.aes_ctr.ctx);
  }

  return res;
}

int socket_to_socket(const srv_params_t *params, const char *auth_string, chunked_transformer_t *encrypter,
                     chunked_transformer_t *decrypter) {
  side_t sides[2];
  side_hints_t hints_a = {1, 0, params->local_host, params->local_port};
  side_hints_t hints_b = {0, 0, params->host, params->port};

  if (params->rv_e2ee) {
    hints_a.transformer = encrypter;
    hints_b.transformer = decrypter;
  }

  atlogger_log(TAG, INFO, "Initializing connection for side a\n");
  int res = srv_side_init(&hints_a, &sides[0]);
  if (res != 0) {
    atlogger_log(TAG, ERROR, "Failed to initialize connection for side a\n");
    return res;
  }

  atlogger_log(TAG, INFO, "Initializing connection for side b\n");
  res = srv_side_init(&hints_b, &sides[1]);
  if (res != 0) {
    atlogger_log(TAG, ERROR, "Failed to initialize connection for side b\n");
    return res;
  }

  int fds[2], tidx;
  int exit_res = 0;
  pthread_t threads[2], tid;
  pipe(fds);

  srv_link_sides(&sides[0], &sides[1], fds);

  atlogger_log(TAG, INFO, "Starting threads\n");
  // send the auth string to side b
  if (params->rv_auth == 1) {
    atlogger_log(TAG, INFO, "Sending auth string\n");
    int len = strlen(auth_string);

    int slen = mbedtls_net_send(&sides[1].socket, (unsigned char *)auth_string, len);
    slen += mbedtls_net_send(&sides[1].socket, (unsigned char *)"\n", 1);
    if (slen != len + 1) {
      atlogger_log(TAG, ERROR, "Failed to send auth string\n");
      return -1;
    }
  }

  res = pthread_create(&threads[0], NULL, srv_side_handle, &sides[0]);
  if (res != 0) {
    atlogger_log(TAG, ERROR, "Failed to create thread: 0\n");
    exit_res = res;
    goto exit;
  }

  res = pthread_create(&threads[1], NULL, srv_side_handle, &sides[1]);
  if (res != 0) {
    atlogger_log(TAG, ERROR, "Failed to create thread: 1\n");
    exit_res = res;
    goto cancel;
  }

  // signal to sshnpd that we are done
  fprintf(stderr, "%s\n", SRV_COMPLETION_STRING);
  fflush(stderr);
  // Wait for all threads to finish and join them back to the main thread
  int retval = 0;

  // Wait for any pthread to exit
  read(fds[0], &tid, sizeof(pthread_t));

  atlogger_log(TAG, DEBUG, "Joining exited thread\n");
  res = pthread_join(tid, (void *)&retval);

cancel:
  if (pthread_equal(threads[0], tid) > 0) {
    // If threads[0] exited normally then we will cancel threads[1]
    // In all other cases, cancel threads[0] (could be because threads[1] exited or errored)
    tidx = 1;
  }

  atlogger_log(TAG, DEBUG, "Cancelling remaining open thread: %d\n", tidx);
  if (pthread_cancel(threads[tidx]) != 0) {
    atlogger_log(TAG, WARN, "Failed to cancel thread: %d\n", tidx);
  } else {
    atlogger_log(TAG, DEBUG, "Canceled thread: %d\n", tidx);
  }

exit:
  close(fds[0]);
  close(fds[1]);

  if (exit_res != 0) {
    return exit_res;
  }

  return 0;
}

int server_to_socket(const srv_params_t *params, const char *auth_string, chunked_transformer_t *encrypter,
                     chunked_transformer_t *decrypter) {
  return 0;
}

int aes_ctr_crypt_stream(const chunked_transformer_t *self, size_t len, const unsigned char *input,
                         unsigned char *output) {
  // Access the state from the self pointer
  aes_ctr_transformer_state_t *state = (aes_ctr_transformer_state_t *)&self->aes_ctr;

  // **crypt the buffer to the chunk
  int res =
      mbedtls_aes_crypt_ctr(&state->ctx, len, &state->nc_off, state->nonce_counter, state->stream_block, input, output);

  if (res != 0) {
    atlogger_log(TAG, ERROR, "Failed to crypt chunk\n");
    return res;
  }

  return 0;
}
