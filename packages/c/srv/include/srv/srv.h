#ifndef SRV_H
#define SRV_H
#include "srv/params.h"
#include "srv/stream.h"
#include <atlogger/atlogger.h>

// LOGGING
#define ERROR ATLOGGER_LOGGING_LEVEL_ERROR
#define WARN ATLOGGER_LOGGING_LEVEL_WARN
#define INFO ATLOGGER_LOGGING_LEVEL_INFO
#define DEBUG ATLOGGER_LOGGING_LEVEL_DEBUG

// NETWORKING
#define MAX_PORT_LEN 6 // 5 digits + null terminator

// BUFFER SIZES
// NB: This is currently hard coded to support AES, but may need to be modified
// for other transformation algorithms
#define READ_BLOCKS 4
#define READ_LEN (AES_BLOCK_LEN * READ_BLOCKS)
#define BUFFER_LEN (READ_LEN + AES_BLOCK_LEN + 1)

// Disable local bind for now
#define ALLOW_BIND_LOCAL_PORT 0

// A macro which will print an error and exit if local bind is attempted, and
// disabled - local bind won't be available in the parser either
#if ALLOW_BIND_LOCAL_PORT
void no_op() {}
#define halt_if_cant_bind_local_port() no_op();
#else
#define halt_if_cant_bind_local_port()                                                                                 \
  atclient_atlogger_log("srv - bind", ERROR, "--local-bind-port is disabled\n");                                       \
  exit(1);
#endif

// GENERAL SRV definitions
#define SRV_COMPLETION_STRING "rv started successfully"
int run_srv(srv_params_t *params);

int socket_to_socket(const srv_params_t *params, const char *auth_string, chunked_transformer_t *encrypter,
                     chunked_transformer_t *decrypter);

int server_to_socket(const srv_params_t *params, const char *auth_string, chunked_transformer_t *encrypter,
                     chunked_transformer_t *decrypter);

void uft8_safe_log(const char *tag, atclient_atlogger_logging_level level, const unsigned char *data, size_t len);
#endif
