#ifndef SOCKET_TO_SOCKET_H
#define SOCKET_TO_SOCKET_H
#include "srv/params.h"
#include "srv/stream.h"

int socket_to_socket(const srv_params_t *params, const char *auth_string,
                     aes_transformer_t *encrypter,
                     aes_transformer_t *decrypter);

#endif
