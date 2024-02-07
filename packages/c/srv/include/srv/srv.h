#ifndef SRV_H
#define SRV_H
#include "srv/params.h"

// LOGGING
#define ERROR ATLOGGER_LOGGING_LEVEL_ERROR
#define WARN ATLOGGER_LOGGING_LEVEL_WARN
#define INFO ATLOGGER_LOGGING_LEVEL_INFO
#define DEBUG ATLOGGER_LOGGING_LEVEL_DEBUG

// NETWORKING
#define MAX_PORT_DIGIT_COUNT 5
#define MAX_BUFFER_LEN 128 * 32 // =  4 AES blocks * 256 bits / 8 bits per byte
#define RECV_TIMEOUT 15000      // 15 seconds

// Disable local bind for now
#define ALLOW_BIND_LOCAL_PORT 0

// A macro which will print an error and exit if local bind is attempted, and
// disabled - local bind won't be available in the parser either
#if ALLOW_BIND_LOCAL_PORT
void no_op() {}
#define verify_bind_local_port() no_op();
#else
#define verify_bind_local_port()                                               \
  atclient_atlogger_log("srv - bind", ERROR, "--local-bind-port is disabled"); \
  exit(1);
#endif

// GENERAL SRV definitions
#define SRV_COMPLETION_STRING "rv started successfully"
int run_srv(srv_params_t *params);

#endif
