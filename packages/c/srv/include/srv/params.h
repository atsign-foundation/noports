#ifndef PARAMS_H
#define PARAMS_H
#define SRV_VERSION "0.1.0"

#include <argparse/argparse.h>
#include <getopt.h>
#include <stdbool.h>
#include <stdint.h>

typedef struct argparse_option argparse_option_t;
typedef struct argparse argparse_t;

typedef struct
{
  char *host;
  uint16_t port;
  uint16_t local_port;

  bool bind_local_port;
  bool rv_auth;
  bool rv_e2ee;

  char *rvd_auth_string;
  char *session_aes_key_string;
  char *session_aes_iv_string;

} srv_params_t;

void apply_default_values_to_params(srv_params_t *params);
int parse_params(srv_params_t *params, int argc, const char **argv);

#endif
