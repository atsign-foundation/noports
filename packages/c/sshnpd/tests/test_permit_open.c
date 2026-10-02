#include "sshnpd/permitopen.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int star_star_test();
int localhost_star_test();
int star_port_test();
int localhost_port_test();
int list_test();
int parse_valid_test();
int parse_invalid_test();

int main() {
  int ret = 0;

  if (star_star_test()) {
    printf("*:* test failed\n");
    ret++;
  }

  if (localhost_star_test()) {
    printf("localhost:* test failed\n");
    ret++;
  }
  if (star_port_test()) {
    printf("*:22 test failed\n");
    ret++;
  }
  if (localhost_port_test()) {
    printf("localhost:22 test failed\n");
    ret++;
  }
  if (list_test()) {
    printf("localhost:22,foo.bar.com:3389 test failed\n");
    ret++;
  }
  if (parse_valid_test()) {
    printf("parse_permitopen valid input test failed\n");
    ret++;
  }
  if (parse_invalid_test()) {
    printf("parse_permitopen invalid input test failed\n");
    ret++;
  }

  printf("Tests failed: %d\n", ret);
  return ret;
}

int parse_valid_test() {
  char **hosts = NULL;
  uint16_t *ports = NULL;
  size_t len = 0;

  char input1[] = "localhost:22,foo.bar.com:3389";
  if (parse_permitopen(input1, &hosts, &ports, &len, false) != 0 || len != 2 || strcmp(hosts[0], "localhost") != 0 ||
      ports[0] != 22 || strcmp(hosts[1], "foo.bar.com") != 0 || ports[1] != 3389) {
    return 1;
  }
  free(hosts);
  free(ports);

  char input2[] = "\"localhost:*\"";
  if (parse_permitopen(input2, &hosts, &ports, &len, false) != 0 || len != 1 || strcmp(hosts[0], "localhost") != 0 ||
      ports[0] != 0) {
    return 1;
  }
  free(hosts);
  free(ports);

  char input3[] = "'*:65535'";
  if (parse_permitopen(input3, &hosts, &ports, &len, false) != 0 || len != 1 || strcmp(hosts[0], "*") != 0 ||
      ports[0] != 65535) {
    return 1;
  }
  free(hosts);
  free(ports);

  return 0;
}

int parse_invalid_test() {
  char **hosts = NULL;
  uint16_t *ports = NULL;
  size_t len = 0;

  // empty and quote-only inputs previously read out of bounds
  char input1[] = "";
  if (parse_permitopen(input1, &hosts, &ports, &len, false) == 0) {
    return 1;
  }
  char input2[] = "\"\"";
  if (parse_permitopen(input2, &hosts, &ports, &len, false) == 0) {
    return 1;
  }
  // extra colons previously desynchronized the token walk
  char input3[] = "localhost:22:33";
  if (parse_permitopen(input3, &hosts, &ports, &len, false) == 0) {
    return 1;
  }
  // port 0 is the internal wildcard encoding and must not be accepted
  char input4[] = "localhost:0";
  if (parse_permitopen(input4, &hosts, &ports, &len, false) == 0) {
    return 1;
  }
  // out-of-range ports previously wrapped to a different port
  char input5[] = "localhost:65536";
  if (parse_permitopen(input5, &hosts, &ports, &len, false) == 0) {
    return 1;
  }
  char input6[] = "localhost:-1";
  if (parse_permitopen(input6, &hosts, &ports, &len, false) == 0) {
    return 1;
  }
  // non-numeric port
  char input7[] = "localhost:ssh";
  if (parse_permitopen(input7, &hosts, &ports, &len, false) == 0) {
    return 1;
  }

  return 0;
}

int star_star_test() {
  permitopen_params params;
  char *hosts[] = {"*"};
  uint16_t ports[] = {0};
  params.permitopen_hosts = hosts;
  params.permitopen_ports = ports;
  params.permitopen_len = 1;

  params.requested_host = "localhost";
  params.requested_port = 22;
  if (!should_permitopen(&params)) {
    return 1;
  }

  params.requested_host = "123.123.123.123";
  params.requested_port = 7878;
  if (!should_permitopen(&params)) {
    return 1;
  }

  params.requested_host = "foo.bar.com";
  params.requested_port = 53;
  if (!should_permitopen(&params)) {
    return 1;
  }

  return 0;
}

int localhost_star_test() {
  permitopen_params params;
  char *hosts[] = {"localhost"};
  uint16_t ports[] = {0};
  params.permitopen_hosts = hosts;
  params.permitopen_ports = ports;
  params.permitopen_len = 1;
  params.requested_host = "localhost";
  params.requested_port = 22;
  if (!should_permitopen(&params)) {
    return 1;
  }
  params.requested_host = "localhost";
  params.requested_port = 7878;
  if (!should_permitopen(&params)) {
    return 1;
  }

  params.requested_host = "foo.bar.com";
  params.requested_port = 53;
  if (should_permitopen(&params)) {
    return 1;
  }

  return 0;
}
int star_port_test() {
  permitopen_params params;
  char *hosts[] = {"*"};
  uint16_t ports[] = {22};
  params.permitopen_hosts = hosts;
  params.permitopen_ports = ports;
  params.permitopen_len = 1;

  params.requested_host = "localhost";
  params.requested_port = 22;
  if (!should_permitopen(&params)) {
    return 1;
  }

  params.requested_host = "123.123.123.123";
  params.requested_port = 22;
  if (!should_permitopen(&params)) {
    return 1;
  }

  params.requested_host = "foo.bar.com";
  params.requested_port = 53;
  if (should_permitopen(&params)) {
    return 1;
  }

  return 0;
}
int localhost_port_test() {
  permitopen_params params;
  char *hosts[] = {"localhost"};
  uint16_t ports[] = {22};
  params.permitopen_hosts = hosts;
  params.permitopen_ports = ports;
  params.permitopen_len = 1;

  params.requested_host = "localhost";
  params.requested_port = 22;
  if (!should_permitopen(&params)) {
    return 1;
  }

  params.requested_host = "123.123.123.123";
  params.requested_port = 22;
  if (should_permitopen(&params)) {
    return 1;
  }

  params.requested_host = "localhost";
  params.requested_port = 7878;
  if (should_permitopen(&params)) {
    return 1;
  }

  params.requested_host = "foo.bar.com";
  params.requested_port = 53;
  if (should_permitopen(&params)) {
    return 1;
  }

  return 0;
}
int list_test() {
  permitopen_params params;
  char *hosts[] = {"localhost", "foo.bar.com"};
  uint16_t ports[] = {22, 3389};
  params.permitopen_hosts = hosts;
  params.permitopen_ports = ports;
  params.permitopen_len = 2;

  params.requested_host = "localhost";
  params.requested_port = 22;
  if (!should_permitopen(&params)) {
    return 1;
  }

  params.requested_host = "123.123.123.123";
  params.requested_port = 22;
  if (should_permitopen(&params)) {
    return 1;
  }

  params.requested_host = "localhost";
  params.requested_port = 7878;
  if (should_permitopen(&params)) {
    return 1;
  }

  params.requested_host = "foo.bar.com";
  params.requested_port = 3389;
  if (!should_permitopen(&params)) {
    return 1;
  }

  params.requested_host = "123.123.123.123";
  params.requested_port = 3389;
  if (should_permitopen(&params)) {
    return 1;
  }

  params.requested_host = "foo.bar.com";
  params.requested_port = 7878;
  if (should_permitopen(&params)) {
    return 1;
  }

  // mixed and matched, these should fail
  params.requested_host = "localhost";
  params.requested_port = 3389;
  if (should_permitopen(&params)) {
    return 1;
  }

  params.requested_host = "foo.bar.com";
  params.requested_port = 22;
  if (should_permitopen(&params)) {
    return 1;
  }

  return 0;
}
