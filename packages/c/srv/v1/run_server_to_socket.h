#ifndef SRV_RUN_SERVER_TO_SOCKET_H
#define SRV_RUN_SERVER_TO_SOCKET_H
#ifdef __cplusplus
extern "C" {
#endif

#include "session.h"
#include <srv/params.h>

int run_server_to_socket(const struct srv_params *params,
                         struct control_session *session);

#ifdef __cplusplus
}
#endif
#endif
