#include "srv/server_to_socket.h"
#include "srv/params.h"
#include "srv/stream.h"

int server_to_socket(const srv_params_t *params, const char *auth_string,
                     chunked_transformer_t *encrypter,
                     chunked_transformer_t *decrypter) {
  return 0;
}
