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

#define SRV_COMPLETION_STRING "rv started successfully"
int run_srv(srv_params_t *params);

#endif
