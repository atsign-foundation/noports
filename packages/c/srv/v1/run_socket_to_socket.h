#ifndef SRV_RUN_SOCKET_TO_SOCKET_H
#define SRV_RUN_SOCKET_TO_SOCKET_H
#ifdef __cplusplus
extern "C" {
#endif

#include "session.h"
#include <srv/params.h>

int run_socket_to_socket(const struct srv_params *params,
                         struct session *session);

#ifdef __cplusplus
}
#endif
#endif
