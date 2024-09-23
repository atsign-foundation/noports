#ifndef SSHNPD_PARAMS_H
#define SSHNPD_PARAMS_H

#include <argparse/argparse.h>
#include <getopt.h>
#include <stdbool.h>
#include <stddef.h>

typedef struct argparse_option ArgparseOption;
typedef struct argparse Argparse;

enum SupportedSshAlgorithm {
  ED25519,
  RSA,
};

struct _sshnpd_params {
  char *atsign;
  char *device;

  size_t manager_list_len;
  char **manager_list;

  size_t permitopen_len;
  char **permitopen;
  char *permitopen_str;
  bool should_free_permitopen_str;

  bool sshpublickey;
  bool hide;
  bool verbose;

  enum SupportedSshAlgorithm ssh_algorithm;
  char *ephemeral_permission;

  char *root_domain;
  uint16_t local_sshd_port;

  char *key_file;
  char *storage_path;
};
typedef struct _sshnpd_params sshnpd_params;

void apply_default_values_to_sshnpd_params(sshnpd_params *params);
int parse_sshnpd_params(sshnpd_params *params, int argc, const char **argv);

#endif
