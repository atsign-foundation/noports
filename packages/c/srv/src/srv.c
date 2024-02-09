#include "srv/srv.h"
#include "srv/params.h"
#include "srv/side.h"
#include "srv/stream.h"
#include <atchops/base64.h>
#include <atlogger.h>
#include <stdlib.h>
#include <string.h>

#define TAG "srv - run"

int run_srv(srv_params_t *params) {
  chunked_transformer_t encrypter;
  chunked_transformer_t decrypter;
  int res;
  if (params->rv_e2ee == 1) {
    atclient_atlogger_log(TAG, INFO,
                          "Configuring encrypter/decrypter for srv\n");

    // Temporary buffer for decoding the key
    unsigned char aes_key[AES_256_KEY_BYTES];
    size_t aes_key_len;

    // Decode the key
    res = atchops_base64_decode((unsigned char *)params->session_aes_key_string,
                                strlen(params->session_aes_key_string), aes_key,
                                AES_256_KEY_BYTES, &aes_key_len);

    if (res != 0 || aes_key_len != AES_256_KEY_BYTES) {
      atclient_atlogger_log(TAG, ERROR,
                            "Error decoding session_aes_key_string\n");
      return res;
    }

    mbedtls_aes_init(&encrypter.aes_ctr.ctx); // FREE
    res = mbedtls_aes_setkey_enc(&encrypter.aes_ctr.ctx, aes_key,
                                 AES_256_KEY_BITS);
    if (res != 0) {
      atclient_atlogger_log(TAG, ERROR, "Error setting encryption key\n");
      mbedtls_aes_free(&encrypter.aes_ctr.ctx);
      return res;
    }

    mbedtls_aes_init(&decrypter.aes_ctr.ctx); // FREE
    res = mbedtls_aes_setkey_dec(&decrypter.aes_ctr.ctx, aes_key,
                                 AES_256_KEY_BITS);
    if (res != 0) {
      atclient_atlogger_log(TAG, ERROR, "Error setting decryption key\n");
      mbedtls_aes_free(&encrypter.aes_ctr.ctx);
      mbedtls_aes_free(&decrypter.aes_ctr.ctx);
      return res;
    }

    // Decode the iv
    size_t iv_len;
    res = atchops_base64_decode((unsigned char *)params->session_aes_iv_string,
                                strlen(params->session_aes_iv_string),
                                encrypter.aes_ctr.nonce_counter, AES_BLOCK_LEN,
                                &iv_len);
    if (res != 0 || iv_len != AES_BLOCK_LEN) {
      atclient_atlogger_log(TAG, ERROR,
                            "Error decoding session_aes_iv_string\n");
      mbedtls_aes_free(&encrypter.aes_ctr.ctx);
      mbedtls_aes_free(&decrypter.aes_ctr.ctx);
      return res;
    }
    // Copy the iv to the decrypter
    memcpy(decrypter.aes_ctr.nonce_counter, encrypter.aes_ctr.nonce_counter,
           AES_BLOCK_LEN);

    // Set the stream blocks to 0
    memset(encrypter.aes_ctr.stream_block, 0, AES_BLOCK_LEN);
    memset(decrypter.aes_ctr.stream_block, 0, AES_BLOCK_LEN);

    // Set the iv offset to 0
    encrypter.aes_ctr.nc_off = 0;
    decrypter.aes_ctr.nc_off = 0;

    // Set the transform functions
    encrypter.transform = aes_ctr_encrypt_stream;
    decrypter.transform = aes_ctr_decrypt_stream;
  };

  if (params->bind_local_port == 0) {
    atclient_atlogger_log(TAG, INFO, "Starting socket to socket srv\n");
    res = socket_to_socket(params, params->rvd_auth_string, &encrypter,
                           &decrypter);
  } else {
    atclient_atlogger_log("srv - bind", ATLOGGER_LOGGING_LEVEL_ERROR,
                          "--local-bind-port is disabled\n");
    exit(1);

    atclient_atlogger_log(TAG, INFO, "Starting server to socket srv\n");
    res = server_to_socket(params, params->rvd_auth_string, &encrypter,
                           &decrypter);
  }

  if (params->rv_e2ee == 1) {
    mbedtls_aes_free(&encrypter.aes_ctr.ctx);
    mbedtls_aes_free(&decrypter.aes_ctr.ctx);
  }

  return res;
}

int socket_to_socket(const srv_params_t *params, const char *auth_string,
                     chunked_transformer_t *encrypter,
                     chunked_transformer_t *decrypter) {
  side_t sides[2];
  side_hints_t hints_a = {1, 0, NULL, params->local_port};
  side_hints_t hints_b = {0, 0, params->host, params->port};

  atclient_atlogger_log(TAG, INFO, "Initializing connection for side a\n");
  int res = srv_side_init(&hints_a, &sides[0]);
  if (res != 0) {
    atclient_atlogger_log(TAG, ERROR,
                          "Failed to initialize connection for side a\n");
    return res;
  }

  atclient_atlogger_log(TAG, INFO, "Initializing connection for side b\n");
  res = srv_side_init(&hints_b, &sides[1]);
  if (res != 0) {
    atclient_atlogger_log(TAG, ERROR,
                          "Failed to initialize connection for side b\n");
    return res;
  }

  if (params->rv_e2ee) {
    hints_a.transformer = encrypter;
    hints_b.transformer = decrypter;
  }

  int fds[2];
  pthread_t threads[2];
  pipe(fds);

  srv_link_sides(&sides[0], &sides[1], fds);

  atclient_atlogger_log(TAG, INFO, "Starting threads\n");
  // send the auth string to side b
  if (params->rv_auth == 1) {
    atclient_atlogger_log(TAG, INFO, "Sending auth string\n");
    int len = strlen(auth_string);

    int slen =
        mbedtls_net_send(sides[1].socket, (unsigned char *)auth_string, len);
    slen += mbedtls_net_send(sides[1].socket, (unsigned char *)"\n", 1);
    if (slen != len + 1) {
      atclient_atlogger_log(TAG, ERROR, "Failed to send auth string\n");
      return -1;
    }
  }

  for (int i = 0; i < 2; i++) {
    pthread_create(&threads[i], NULL, srv_side_handle, &sides[i]);
  }

  // signal to sshnpd that we are done
  fprintf(stderr, "%s\n", SRV_COMPLETION_STRING);
  fflush(stderr);

  // Wait for all threads to finish and join them back to the main thread
  pthread_t tid;
  int retval = 0;
  for (int i = 0; i < 2; i++) {
    read(fds[0], &tid, sizeof(pthread_t));

    res = pthread_join(tid, (void *)&retval);
    if (res != 0) {
      atclient_atlogger_log(TAG, DEBUG,
                            "Joining pthread %l failed with code: %l\n",
                            threads[i], res);
      break;
    }
    atclient_atlogger_log(TAG, DEBUG, "pthread %l exited with code: %l\n",
                          threads[i], retval);
    if (retval != 0) {
      break;
    }
  }

  if (res != 0 || retval != 0) {
    atclient_atlogger_log(TAG, DEBUG, "Cancelling all open threads\n");
    for (int i = 0; i < 2; i++) {
      if (pthread_cancel(threads[i]) != 0) {
        atclient_atlogger_log(TAG, DEBUG, "Failed to cancel thread: %l\n",
                              threads[i]);
      }
    }
  }

  close(fds[0]);
  close(fds[1]);

  return 0;
}

int server_to_socket(const srv_params_t *params, const char *auth_string,
                     chunked_transformer_t *encrypter,
                     chunked_transformer_t *decrypter) {
  return 0;
}
