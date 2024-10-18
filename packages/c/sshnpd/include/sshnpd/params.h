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

  char *policy;

  size_t permitopen_len;
  char **permitopen_hosts;
  uint16_t *permitopen_ports; // 0 = '*'
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

  int monitor_read_timeout; // the amount of time that the monitor connection will wait for data before giving up and then sending a noop:0 to check if we're still connected
};
typedef struct _sshnpd_params sshnpd_params;

void apply_default_values_to_sshnpd_params(sshnpd_params *params);
int parse_sshnpd_params(sshnpd_params *params, int argc, const char **argv);

#endif
