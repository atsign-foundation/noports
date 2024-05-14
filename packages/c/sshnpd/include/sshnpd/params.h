#ifndef PARAMS_H
#define PARAMS_H
#define SSHNPD_VERSION "0.1.0"

#include <argparse/argparse.h>
#include <getopt.h>
#include <stdbool.h>

typedef struct argparse_option ArgparseOption;
typedef struct argparse Argparse;

enum SupportedSshAlgorithm {
  ED25519,
  RSA,
};

typedef struct {
  char *atsign;
  char *device;

  size_t manager_list_len;
  char **manager_list;

  size_t permitopen_len;
  char **permitopen;
  bool free_permitopen;

  bool sshpublickey;
  bool hide;
  bool verbose;

  enum SupportedSshAlgorithm ssh_algorithm;
  char *ephemeral_permission;

  char *root_domain;
  uint16_t local_sshd_port;

  char *key_file;
} SshnpdParams;

void apply_default_values_to_params(SshnpdParams *params);
int parse_params(SshnpdParams *params, int argc, const char **argv);

#endif