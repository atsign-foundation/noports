#ifndef SRC_CHANNEL_IO_TCP_H
#define SRC_CHANNEL_IO_TCP_H
#ifdef __cplusplus
extern "C" {
#endif

#include "channel_io.h"

struct channel_io_tcp_socket {
  struct channel_io interface;
  int sock;
};

struct channel_io_tcp_info {
  struct channel_io interface;
  char *host;
  char *port;
};

int create_channel_io_tcp_connect_context(struct channel_io *self,
                                          const char *host, const char *port);
int bind_channel_io_tcp(struct channel_io *self, const char *host,
                        const char *port);
#ifdef __cplusplus
}
#endif
#endif
