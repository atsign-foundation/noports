#ifndef SRV_PARAMS_H
#define SRV_PARAMS_H
#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>

enum srv_io_type {
  srv_io_type_tcp_client = 0,
  srv_io_type_tcp_bind = 1,
};

enum srv_transformer_type {
  srv_transformer_none = 0,
  srv_transformer_aes_ctr = 1,
};

enum srv_auth_type {
  srv_auth_type_none = 0,
  srv_auth_type_payload = 1,
};

enum srv_channel_mode {
  srv_mode_single = 0,
  srv_mode_stacking = 1,
  srv_mode_control = 2,
};

struct srv_params {
  char *host;
  char *port;
  char *local_host;
  char *local_port;

  int timeout;

  enum srv_channel_mode mode;
  enum srv_io_type remote_io;
  enum srv_io_type local_io;
  enum srv_transformer_type transformer;
  enum srv_auth_type remote_auth;
  uint8_t verbose : 1;
};

#define srv_params_initializer                                                 \
  (struct srv_params) {                                                        \
    .host = NULL, .port = NULL, .local_host = "localhost", .local_port = "0",  \
    .timeout = 60, .mode = srv_mode_single,                                    \
    .remote_io = srv_io_type_tcp_client, .local_io = srv_io_type_tcp_client,   \
    .transformer = srv_transformer_aes_ctr,                                    \
    .remote_auth = srv_auth_type_payload, .verbose = 0,                        \
  }

int parse_srv_params(int argc, char **argv, struct srv_params *params);

#ifdef __cplusplus
}
#endif
#endif
