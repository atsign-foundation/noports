#include "srv/srv.h"
#include "srv/params.h"
#include "srv/server_to_socket.h"
#include "srv/socket_to_socket.h"
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
    encrypter.transform = aes_ctr_crypt_stream;
    decrypter.transform = aes_ctr_crypt_stream;
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
