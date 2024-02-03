#include "sshnpd_params.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Declare the tests
int default_values_test();
int parse_params_test();
int atsign_mandatory_test();
int manager_mandatory_test();
int ssh_algorithm_parse_test();

int main() {
  int ret = 0;

  if (default_values_test()) {
    ret++;
  }
  if (parse_params_test()) {
    ret++;
  }
  if (atsign_mandatory_test()) {
    ret++;
  }
  if (manager_mandatory_test()) {
    ret++;
  }
  if (ssh_algorithm_parse_test()) {
    ret++;
  }

  printf("Tests failed: %d\n", ret);
  return ret;
}

// Define the tests
int default_values_test() {
  int ret = 0;
  sshnpd_params *params = malloc(sizeof(sshnpd_params));
  apply_default_values_to_params(params);

  if (strcmp(params->device, "default") != 0) {
    ret = 1;
  }
  if (params->sshpublickey != 0) {
    ret = 1;
  }
  if (params->unhide != 0) {
    ret = 1;
  }
  if (params->verbose != 0) {
    ret = 1;
  }
  if (params->ssh_algorithm != ED25519) {
    ret = 1;
  }
  if (strcmp(params->ephemeral_permission, "") != 0) {
    ret = 1;
  }
  if (strcmp(params->root_domain, "root.atsign.org") != 0) {
    ret = 1;
  }
  if (params->local_sshd_port != 22) {
    ret = 1;
  }

  free(params);
  return ret;
}

int parse_params_test() {
  int ret = 0;

  sshnpd_params *params = malloc(sizeof(sshnpd_params));

  const char *argv[] = {"sshnpd", "-a", "atsign", "-m", "manager"};
  int argc = 4;

  free(params);
  return ret;
}

int atsign_mandatory_test() { return 0; }

int manager_mandatory_test() { return 0; }

int ssh_algorithm_parse_test() { return 0; }
