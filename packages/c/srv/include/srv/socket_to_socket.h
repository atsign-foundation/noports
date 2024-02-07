#ifndef SOCKET_TO_SOCKET_H
#define SOCKET_TO_SOCKET_H
#include "srv/params.h"
#include "srv/stream.h"

int socket_to_socket(const srv_params_t *params, const char *auth_string,
                     chunked_transformer_t *encrypter,
                     chunked_transformer_t *decrypter);

#endif
