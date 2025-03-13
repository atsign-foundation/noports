#ifndef SRV_CHANNEL_IO_TCP_H
#define SRV_CHANNEL_IO_TCP_H
#ifdef __cplusplus
extern "C" {
#endif

#include <netdb.h>
#include <sys/socket.h>

#include "arena.h"
#include "channel_io.h"

int channel_io_tcp_connect(struct arena *arena, struct channel_io *self,
                           const char *host, const char *port);
int channel_io_tcp_bind(struct arena *arena, struct channel_io *self,
                        const char *host, const char *port);

#ifdef __cplusplus
}
#endif
#endif
