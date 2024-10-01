#ifndef SSHNPD_PERMITOPEN_H
#define SSHNPD_PERMITOPEN_H
#include <atlogger/atlogger.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

// atlogger won't be available during the initial parsing of the parameters
// (since we are waiting for the verbose flag to be set)
int parse_permitopen(char *input, char ***permitopen_hosts, uint16_t **permitopen_ports, size_t *permitopen_len,
                     bool is_logger_available);

struct _permitopen_params {
  char *requested_host;
  uint16_t requested_port;

  char **permitopen_hosts;
  uint16_t *permitopen_ports;
  size_t permitopen_len;
};

typedef struct _permitopen_params permitopen_params;

bool should_permitopen(struct _permitopen_params *params);
#endif
