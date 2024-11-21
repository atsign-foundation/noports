#include "sshnpd/permitopen.h"
#include <stdio.h>

int star_star_test();
int localhost_star_test();
int star_port_test();
int localhost_port_test();
int list_test();

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

  printf("Tests failed: %d\n", ret);
  return ret;
}

int star_star_test() {
  permitopen_params params;
  char *hosts[] = {"*"};
  uint16_t ports[] = {0};
  params.permitopen_hosts = hosts;
  params.permitopen_ports = ports;
  params.permitopen_len = 1;

  bool allow;

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
  bool allow;
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

  bool allow;

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

  bool allow;

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

  bool allow;

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
