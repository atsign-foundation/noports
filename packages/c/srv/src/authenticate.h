#ifndef SRC_AUTHENTICATE_H
#define SRC_AUTHENTICATE_H
#ifdef __cplusplus
extern "C" {
#endif

#include "channel_io.h"

int authenticate_remote(struct srv_params, struct channel_io *);
int authenticate_local(struct srv_params, struct channel_io *);

#ifdef __cplusplus
}
#endif
#endif
