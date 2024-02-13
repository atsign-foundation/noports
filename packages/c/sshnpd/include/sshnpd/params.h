#ifndef PARAMS_H
#define PARAMS_H
#define SSHNPD_VERSION "0.1.0"

#include <argparse/argparse.h>
#include <getopt.h>
#include <stdbool.h>
#include <stdint.h>

typedef struct argparse_option argparse_option_t;
typedef struct argparse argparse_t;

enum supported_ssh_algorithm {
  ED25519,
  RSA,
};

typedef struct {
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
} sshnpd_params_t;

void apply_default_values_to_params(sshnpd_params_t *params);
int parse_params(sshnpd_params_t *params, int argc, const char **argv);

#endif
