#ifndef SSHNPD_PARAMS_H
#define SSHNPD_PARAMS_H

#include "argparse.h"
#include <getopt.h>
#include <stdbool.h>
#include <stdint.h>

typedef struct argparse_option argparse_option;
typedef struct argparse argparse;

enum supported_ssh_algorithm {
  ED25519,
  RSA,
};

typedef struct sshnpd_params {
  char *atsign;
  char *manager;
  char *device;

  bool sshpublickey;
  bool unhide;
  bool verbose;

  enum supported_ssh_algorithm ssh_algorithm;
  char *ephemeral_permission;

  char *root_domain;
  uint16_t local_sshd_port;

  char *key_file;
} sshnpd_params;

void apply_default_values_to_params(sshnpd_params *params);
int parse_params(sshnpd_params *params, int argc, const char **argv);

#endif
