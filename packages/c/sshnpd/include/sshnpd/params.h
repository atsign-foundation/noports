#ifndef PARAMS_H
#define PARAMS_H
#define SSHNPD_VERSION "0.1.0"

#include <argparse/argparse.h>
#include <getopt.h>
#include <stdbool.h>
#include <stdint.h>

typedef struct argparse_option ArgparseOption;
typedef struct argparse Argparse;

enum SupportedSshAlgorithm {
  ED25519,
  RSA,
};

enum ManagerType {
  SingleManager,
  ManagerList,
};

typedef struct {
  char *atsign;
  enum ManagerType manager_type;
  union {
    char *manager;
    struct {
      size_t manager_list_len;
      char **manager_list;
    };
  };
  char *device;

  bool sshpublickey;
  bool unhide;
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
