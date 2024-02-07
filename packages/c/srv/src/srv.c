#include "srv/srv.h"
#include "srv/params.h"
#include "srv/server_to_socket.h"
#include "srv/socket_to_socket.h"
#include "srv/stream.h"
#include <atlogger.h>
#include <stdlib.h>

#define TAG "srv - run"

int run_srv(srv_params_t *params) {
  aes_transformer_t *encrypter = NULL;
  aes_transformer_t *decrypter = NULL;

  if (params->session_aes_key_string != NULL &&
      params->session_aes_iv_string != NULL) {

    atclient_atlogger_log(TAG, INFO,
                          "Configuring encrypter/decrypter for srv\n");
    encrypter = malloc(sizeof(aes_transformer_t));
    encrypter->key = params->session_aes_key_string;
    encrypter->iv = params->session_aes_iv_string;
    encrypter->transform = aes_encrypt_stream;

    decrypter = malloc(sizeof(aes_transformer_t));
    decrypter->key = params->session_aes_key_string;
    decrypter->iv = params->session_aes_iv_string;
    encrypter->transform = aes_decrypt_stream;
  };

  int res;
  if (params->bind_local_port == 0) {
    atclient_atlogger_log(TAG, INFO, "Starting socket to socket srv\n");
    res =
        socket_to_socket(params, params->rvd_auth_string, encrypter, decrypter);
  } else {
    halt_if_cant_bind_local_port();
    atclient_atlogger_log(TAG, INFO, "Starting server to socket srv\n");
    res =
        server_to_socket(params, params->rvd_auth_string, encrypter, decrypter);
  }

  if (encrypter != NULL) {
    free(encrypter);
  }
  if (decrypter != NULL) {
    free(decrypter);
  }
  return res;
}
