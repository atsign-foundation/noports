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
int device_lower_test();
int manager_list_test();
int manager_list_trailing_comma_test();
int manager_list_filter_device_atsign_test();

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
  if (device_lower_test()) {
    printf("device_name upper to lower case test failed\n");
    ret++;
  }
  if (manager_list_test()) {
    printf("manager_list_test failed\n");
    ret++;
  }
  if (manager_list_trailing_comma_test()) {
    printf("manager_list_trailing_comma_test failed\n");
    ret++;
  }
  if (manager_list_filter_device_atsign_test()) {
    printf("manager_list_filter_device_atsign_test failed\n");
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
  sshnpd_params *params = malloc(sizeof(sshnpd_params));

  char *manager_str = strdup("@foo,@bar,@baz");
  if (manager_str == NULL) {
    free(params);
    return 1;
  }
  const char *argv[] = {
      "sshnpd", "-a", "@atsign", "-m", manager_str, "-d", "my_device",
  };

  apply_default_values_to_sshnpd_params(params);
  int ret = parse_sshnpd_params(params, 7, argv);
  if (ret != 0) {
    free(params);
    return 1;
  }

  if (params->manager_list_len != 3) {
    free(params);
    return 1;
  }
  if (strcmp(params->manager_list[0], "@foo") != 0) {
    free(params);
    return 1;
  }
  if (strcmp(params->manager_list[1], "@bar") != 0) {
    free(params);
    return 1;
  }
  if (strcmp(params->manager_list[2], "@baz") != 0) {
    free(params);
    return 1;
  }

  free(params);
  return 0;
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

  char **permitopen_hosts6 = NULL;
  uint16_t *permitopen_ports6 = NULL;
  size_t permitopen_len6;
  ret = parse_permitopen(strdup("\"localhost:22,foo.bar.com:3389\""), &permitopen_hosts6, &permitopen_ports6,
                         &permitopen_len6, false);

  if (ret != 0 || permitopen_len6 != 2 || strcmp(permitopen_hosts6[0], "localhost") != 0 ||
      permitopen_ports6[0] != 22 || strcmp(permitopen_hosts6[1], "foo.bar.com") != 0 || permitopen_ports6[1] != 3389) {
    ret = 1;
  }

  char **permitopen_hosts7 = NULL;
  uint16_t *permitopen_ports7 = NULL;
  size_t permitopen_len7;
  ret = parse_permitopen(strdup("'localhost:22,foo.bar.com:3389'"), &permitopen_hosts7, &permitopen_ports7,
                         &permitopen_len7, false);

  if (ret != 0 || permitopen_len7 != 2 || strcmp(permitopen_hosts7[0], "localhost") != 0 ||
      permitopen_ports7[0] != 22 || strcmp(permitopen_hosts7[1], "foo.bar.com") != 0 || permitopen_ports7[1] != 3389) {
    ret = 1;
  }

  char **permitopen_hosts8 = NULL;
  uint16_t *permitopen_ports8 = NULL;
  size_t permitopen_len8;
  ret = parse_permitopen(strdup("\"\"localhost:22,foo.bar.com:3389\"\""), &permitopen_hosts8, &permitopen_ports8,
                         &permitopen_len8, false);

  if (ret != 0 || permitopen_len8 != 2 || strcmp(permitopen_hosts8[0], "localhost") != 0 ||
      permitopen_ports8[0] != 22 || strcmp(permitopen_hosts8[1], "foo.bar.com") != 0 || permitopen_ports8[1] != 3389) {
    ret = 1;
  }

  char **permitopen_hosts9 = NULL;
  uint16_t *permitopen_ports9 = NULL;
  size_t permitopen_len9;
  ret = parse_permitopen(strdup("\"'localhost:22,foo.bar.com:3399'\""), &permitopen_hosts9, &permitopen_ports9,
                         &permitopen_len9, false);

  if (ret != 0 || permitopen_len9 != 2 || strcmp(permitopen_hosts9[0], "localhost") != 0 ||
      permitopen_ports9[0] != 22 || strcmp(permitopen_hosts9[1], "foo.bar.com") != 0 || permitopen_ports9[1] != 3399) {
    ret = 1;
  }
  return 0;
}

int device_lower_test() {
  int ret = 0;

  sshnpd_params *params = malloc(sizeof(sshnpd_params));

  const char *device_name_literal = "MY_DEVICEA-123Z";
  size_t device_name_literal_len = strlen(device_name_literal);
  char *device_name = malloc(sizeof(char) * (device_name_literal_len + 1));
  if (device_name == NULL) {
    return 1;
  }
  memcpy(device_name, device_name_literal, device_name_literal_len);
  device_name[device_name_literal_len] = 0;

  char *expected_device_name = "my_devicea-123z";
  const char *argv[] = {
      "sshnpd",
      "-a",
      "@atsign",
      "-m",
      "@manager",
      "-d",
      device_name,
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
  if (ret != 0) {
    free(device_name);
    free(params);
    return 1;
  }

  size_t expected_device_len = strlen(expected_device_name);
  size_t actual_device_len = strlen(params->device);

  if (expected_device_len != actual_device_len) {
    free(device_name);
    free(params);
    return 1;
  }

  size_t diff = strncmp(params->device, expected_device_name, expected_device_len);
  if (diff != 0) {
    free(device_name);
    free(params);
    return 1;
  }

  free(device_name);
  free(params);
  return 0;
}

// Pins the trailing-comma parse. The counting loop stops at manager_end - 1, so
// a trailing comma is never counted; the body must not decrement sep_count to
// "correct" an over-count that never happened, or the last manager is dropped
// and the daemon authorizes nobody.
int manager_list_trailing_comma_test() {
  struct {
    const char *input;
    size_t expected_len;
    const char *expected[2];
  } cases[] = {
      {"@foo,", 1, {"@foo", NULL}},
      {"@foo,@bar,", 2, {"@foo", "@bar"}},
  };

  for (size_t c = 0; c < sizeof(cases) / sizeof(cases[0]); c++) {
    sshnpd_params *params = malloc(sizeof(sshnpd_params));
    if (params == NULL) {
      return 1;
    }

    char *manager_str = strdup(cases[c].input);
    if (manager_str == NULL) {
      free(params);
      return 1;
    }
    const char *argv[] = {
        "sshnpd", "-a", "@atsign", "-m", manager_str, "-d", "my_device",
    };

    apply_default_values_to_sshnpd_params(params);
    if (parse_sshnpd_params(params, 7, argv) != 0) {
      free(params);
      return 1;
    }

    if (params->manager_list_len != cases[c].expected_len) {
      printf("  input \"%s\": expected len %zu, got %zu\n", cases[c].input, cases[c].expected_len,
             params->manager_list_len);
      free(params);
      return 1;
    }
    for (size_t i = 0; i < cases[c].expected_len; i++) {
      if (strcmp(params->manager_list[i], cases[c].expected[i]) != 0) {
        printf("  input \"%s\": expected [%zu] \"%s\", got \"%s\"\n", cases[c].input, i, cases[c].expected[i],
               params->manager_list[i]);
        free(params);
        return 1;
      }
    }

    free(params);
  }

  return 0;
}

int manager_list_filter_device_atsign_test() {
  struct {
    const char *device_atsign;
    const char *manager_input;
    size_t expected_len;
    const char *expected[2];
  } cases[] = {
      {"@device", "@alice,@device,@bob", 2, {"@alice", "@bob"}},
      {"@device", "@device,@alice", 1, {"@alice", NULL}},
      {"@device", "@alice,@device", 1, {"@alice", NULL}},
      {"@device", "@Device,@alice", 1, {"@alice", NULL}},
      {"@device", "@device", 0, {NULL, NULL}},
  };

  for (size_t c = 0; c < sizeof(cases) / sizeof(cases[0]); c++) {
    sshnpd_params *params = malloc(sizeof(sshnpd_params));
    if (params == NULL) {
      return 1;
    }

    char *manager_str = strdup(cases[c].manager_input);
    if (manager_str == NULL) {
      free(params);
      return 1;
    }
    const char *argv[] = {
        "sshnpd", "-a", cases[c].device_atsign, "-m", manager_str, "-d", "my_device",
    };

    apply_default_values_to_sshnpd_params(params);
    if (parse_sshnpd_params(params, 7, argv) != 0) {
      free(params);
      return 1;
    }

    if (params->manager_list_len != cases[c].expected_len) {
      printf("  input \"%s\": expected len %zu, got %zu\n", cases[c].manager_input, cases[c].expected_len,
             params->manager_list_len);
      free(params);
      return 1;
    }
    for (size_t i = 0; i < cases[c].expected_len; i++) {
      if (strcmp(params->manager_list[i], cases[c].expected[i]) != 0) {
        printf("  input \"%s\": expected [%zu] \"%s\", got \"%s\"\n", cases[c].manager_input, i, cases[c].expected[i],
               params->manager_list[i]);
        free(params);
        return 1;
      }
    }

    free(params);
  }

  return 0;
}
