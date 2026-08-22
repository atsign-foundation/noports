#include "sshnpd/file_utils.h"
#include <stdbool.h>
#include <stdio.h>
#include <string.h>

int valid_ed25519_test();
int valid_rsa_test();
int valid_ecdsa_test();
int valid_rsa_sha2_test();
int invalid_garbage_test();
int invalid_empty_test();
int invalid_null_test();
int newline_injection_test();

int main() {
  int ret = 0;

  if (valid_ed25519_test()) {
    printf("valid_ed25519_test failed\n");
    ret++;
  }
  if (valid_rsa_test()) {
    printf("valid_rsa_test failed\n");
    ret++;
  }
  if (valid_ecdsa_test()) {
    printf("valid_ecdsa_test failed\n");
    ret++;
  }
  if (valid_rsa_sha2_test()) {
    printf("valid_rsa_sha2_test failed\n");
    ret++;
  }
  if (invalid_garbage_test()) {
    printf("invalid_garbage_test failed\n");
    ret++;
  }
  if (invalid_empty_test()) {
    printf("invalid_empty_test failed\n");
    ret++;
  }
  if (invalid_null_test()) {
    printf("invalid_null_test failed\n");
    ret++;
  }
  if (newline_injection_test()) {
    printf("newline_injection_test failed\n");
    ret++;
  }

  printf("Tests failed: %d\n", ret);
  return ret;
}

int valid_ed25519_test() {
  if (!is_valid_ssh_public_key("ssh-ed25519 AAAAC3NzaC1lZDI1NTE5 user@host")) {
    return 1;
  }
  return 0;
}

int valid_rsa_test() {
  if (!is_valid_ssh_public_key("ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQ user@host")) {
    return 1;
  }
  return 0;
}

int valid_ecdsa_test() {
  if (!is_valid_ssh_public_key("ecdsa-sha2-nistp256 AAAAE2VjZHNh user@host")) {
    return 1;
  }
  return 0;
}

int valid_rsa_sha2_test() {
  if (!is_valid_ssh_public_key("rsa-sha2-512 AAAAB3NzaC1yc2EAAAADAQABAAABgQ user@host")) {
    return 1;
  }
  return 0;
}

int invalid_garbage_test() {
  if (is_valid_ssh_public_key("this is not a key at all")) {
    return 1;
  }
  if (is_valid_ssh_public_key("rm -rf / # not a key")) {
    return 1;
  }
  return 0;
}

int invalid_empty_test() {
  if (is_valid_ssh_public_key("")) {
    return 1;
  }
  return 0;
}

int invalid_null_test() {
  if (is_valid_ssh_public_key(NULL)) {
    return 1;
  }
  return 0;
}

int newline_injection_test() {
  if (is_valid_ssh_public_key("ssh-ed25519 AAAAC3NzaC1lZDI1NTE5\nssh-rsa AAAAB3 injected@evil")) {
    return 1;
  }
  if (is_valid_ssh_public_key("ssh-ed25519 AAAAC3NzaC1lZDI1NTE5\rssh-rsa AAAAB3 injected@evil")) {
    return 1;
  }
  return 0;
}
