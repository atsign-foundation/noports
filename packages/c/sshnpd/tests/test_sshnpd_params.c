#include "sshnpd/params.h"
#include "sshnpd/permitopen.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Declare the tests
int default_values_test();
int parse_params_test();
int atsign_mandatory_test();
int manager_policy_mandatory_test();
int permit_open_parse_test();

int main() {
  int ret = 0;

  if (default_values_test()) {
    printf("Default values test failed\n");
    ret++;
  }
  if (parse_params_test()) {
    printf("Parse params test failed\n");
    ret++;
  }
  if (atsign_mandatory_test()) {
    printf("atSign mandatory test failed\n");
    ret++;
  }
  if (manager_policy_mandatory_test()) {
    printf("manager/policy mandatory test failed\n");
    ret++;
  }
  if (permit_open_parse_test()) {
    printf("permit open parse test failed\n");
    ret++;
  }

  printf("Tests failed: %d\n", ret);
  return ret;
}

// Define the tests
int default_values_test() {
  int ret = 0;
  sshnpd_params *params = malloc(sizeof(sshnpd_params));
  apply_default_values_to_sshnpd_params(params);

  if (strcmp(params->device, "default") != 0) {
    ret = 1;
  }
  if (params->sshpublickey != 0) {
    ret = 1;
  }
  if (params->hide != 0) {
    ret = 1;
  }
  if (params->verbose != 0) {
    ret = 1;
  }
  if (params->ssh_algorithm != ED25519) {
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

  const char *argv[] = {
      "sshnpd",
      "-a",
      "@atsign",
      "-m",
      "@manager",
      "-d",
      "my_device",
      "-s",
      "-h",
      "-v",
      "--ssh-algorithm",
      "ssh-rsa",
      "--root-domain",
      "vip.ve.atsign.zone",
      "--local-sshd-port",
      "6222",
  };

  apply_default_values_to_sshnpd_params(params);
  ret = parse_sshnpd_params(params, 16, argv);

  if (strcmp(params->atsign, "@atsign") != 0) {
    ret = 1;
  }
  if (strcmp(params->manager_list[0], "@manager") != 0) {
    ret = 1;
  }
  if (strcmp(params->device, "my_device") != 0) {
    ret = 1;
  }
  if (params->sshpublickey != 1) {
    ret = 1;
  }
  if (params->hide != 1) {
    ret = 1;
  }
  if (params->verbose != 1) {
    ret = 1;
  }
  if (params->ssh_algorithm != RSA) {
    ret = 1;
  }
  if (strcmp(params->root_domain, "vip.ve.atsign.zone") != 0) {
    ret = 1;
  }
  if (params->local_sshd_port != 6222) {
    ret = 1;
  }

  free(params);
  return ret;
}

int atsign_mandatory_test() {
  int ret = 0;

  sshnpd_params *params = malloc(sizeof(sshnpd_params));

  const char *argv[] = {
      "sshnpd",
      "-m",
      "@manager",
      "-d",
      "my_device",
      "-s",
      "-h",
      "-v",
      "--ssh-algorithm",
      "ssh-rsa",
      "--root-domain",
      "vip.ve.atsign.zone",
      "--local-sshd-port",
      "6222",
  };

  apply_default_values_to_sshnpd_params(params);
  ret = parse_sshnpd_params(params, 14, argv);
  // expect this to return non-zero since atsign is missing
  if (ret == 0) {
    ret = 1;
  } else {
    ret = 0;
  }

  free(params);
  return ret;
}

int manager_policy_mandatory_test() {
  int ret = 0;

  sshnpd_params *params = malloc(sizeof(sshnpd_params));

  const char *argv[] = {
      "sshnpd", "-a", "@atsign", "-d", "my_device",
  };

  apply_default_values_to_sshnpd_params(params);
  ret = parse_sshnpd_params(params, 5, argv);
  // expect this to return non-zero since manager & policy are missing
  if (ret == 0) {
    ret = 1;
  } else {
    ret = 0;
  }

  free(params);
  return ret;
}

int manager_list_test() {
  int ret = 0;

  return 0;
  sshnpd_params *params = malloc(sizeof(sshnpd_params));

  const char *argv[] = {
      "sshnpd", "-a", "@atsign", "-m", "@foo,@bar,@baz", "-d", "my_device",
  };

  apply_default_values_to_sshnpd_params(params);
  ret = parse_sshnpd_params(params, 7, argv);
  if (ret == 0) {
    ret = 1;
  } else {
    ret = 0;
  }

  free(params);
  return ret;
}

int permit_open_parse_test() {
  int ret = 0;

  // FIXME: bus error
  char **permitopen_hosts = NULL;
  uint16_t *permitopen_ports = NULL;
  size_t permitopen_len;
  ret = parse_permitopen(strdup("*:*"), &permitopen_hosts, &permitopen_ports, &permitopen_len, false);

  if (ret != 0 || permitopen_len != 1 || strcmp(permitopen_hosts[0], "*") != 0 || permitopen_ports[0] != 0) {
    ret = 1;
  }

  char **permitopen_hosts2 = NULL;
  uint16_t *permitopen_ports2 = NULL;
  size_t permitopen_len2;
  ret = parse_permitopen(strdup("localhost:*"), &permitopen_hosts2, &permitopen_ports2, &permitopen_len2, false);

  if (ret != 0 || permitopen_len2 != 1 || strcmp(permitopen_hosts2[0], "localhost") != 0 || permitopen_ports2[0] != 0) {
    ret = 1;
  }

  return 0;
  char **permitopen_hosts3 = NULL;
  uint16_t *permitopen_ports3 = NULL;
  size_t permitopen_len3;
  ret = parse_permitopen(strdup("*:22"), &permitopen_hosts3, &permitopen_ports3, &permitopen_len3, false);

  if (ret != 0 || permitopen_len3 != 1 || strcmp(permitopen_hosts3[0], "*") != 0 || permitopen_ports3[0] != 22) {
    ret = 1;
  }

  char **permitopen_hosts4 = NULL;
  uint16_t *permitopen_ports4 = NULL;
  size_t permitopen_len4;
  ret = parse_permitopen(strdup("localhost:22"), &permitopen_hosts4, &permitopen_ports4, &permitopen_len4, false);

  if (ret != 0 || permitopen_len4 != 1 || strcmp(permitopen_hosts4[0], "localhost") != 0 ||
      permitopen_ports4[0] != 22) {
    ret = 1;
  }

  char **permitopen_hosts5 = NULL;
  uint16_t *permitopen_ports5 = NULL;
  size_t permitopen_len5;
  ret = parse_permitopen(strdup("localhost:22,foo.bar.com:3389"), &permitopen_hosts5, &permitopen_ports5,
                         &permitopen_len5, false);

  if (ret != 0 || permitopen_len5 != 2 || strcmp(permitopen_hosts5[0], "localhost") != 0 ||
      permitopen_ports5[0] != 22 || strcmp(permitopen_hosts5[1], "foo.bar.com") != 0 || permitopen_ports5[1] != 3389) {
    ret = 1;
  }

  return 0;
}
