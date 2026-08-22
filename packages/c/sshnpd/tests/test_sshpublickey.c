#include "sshnpd/file_utils.h"
#include "sshnpd/handle_sshpublickey.h"
#include "sshnpd/params.h"
#include <atclient/atnotification.h>
#include <atclient/monitor.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static char authkeys_path[256];

static int setup_authkeys_file(FILE **file) {
  snprintf(authkeys_path, sizeof(authkeys_path), "/tmp/test_sshpublickey_%d", getpid());
  *file = fopen(authkeys_path, "w+");
  if (*file == NULL) {
    return 1;
  }
  return 0;
}

static void cleanup_authkeys_file(FILE *file) {
  if (file != NULL) {
    fclose(file);
  }
  unlink(authkeys_path);
}

static bool file_contains(const char *needle) {
  FILE *f = fopen(authkeys_path, "r");
  if (f == NULL) {
    return false;
  }
  fseek(f, 0, SEEK_END);
  long size = ftell(f);
  fseek(f, 0, SEEK_SET);
  if (size <= 0) {
    fclose(f);
    return false;
  }
  char *buf = malloc(size + 1);
  fread(buf, 1, size, f);
  buf[size] = '\0';
  fclose(f);
  bool found = strstr(buf, needle) != NULL;
  free(buf);
  return found;
}

static int run_e2e_test(const char *ssh_key, bool should_be_authorized) {
  FILE *authkeys_file = NULL;
  if (setup_authkeys_file(&authkeys_file)) {
    return 1;
  }

  sshnpd_params params;
  apply_default_values_to_sshnpd_params(&params);
  params.sshpublickey = true;

  atclient_atnotification notification;
  atclient_atnotification_init(&notification);
  atclient_atnotification_set_decrypted_value(&notification, ssh_key);
  atclient_atnotification_set_from(&notification, "@testatsign");

  atclient_monitor_message message;
  atclient_monitor_message_init(&message);
  message.type = ATCLIENT_MONITOR_MESSAGE_TYPE_NOTIFICATION;
  message.notification = &notification;

  handle_sshpublickey(&params, &message, authkeys_file, authkeys_path);

  bool found = file_contains(ssh_key);
  int result = (found == should_be_authorized) ? 0 : 1;

  cleanup_authkeys_file(authkeys_file);
  atclient_atnotification_free(&notification);
  return result;
}

int test_valid_ed25519_e2e();
int test_valid_rsa_e2e();
int test_valid_ecdsa_e2e();
int test_invalid_garbage_e2e();
int test_invalid_empty_e2e();
int test_newline_injection_e2e();
int test_carriage_return_injection_e2e();
int test_empty_prefix_does_not_match_e2e();

int main() {
  int ret = 0;

  if (test_valid_ed25519_e2e()) {
    printf("e2e: valid ed25519 key was NOT written to authorized_keys\n");
    ret++;
  }

  if (test_valid_rsa_e2e()) {
    printf("e2e: valid rsa key was NOT written to authorized_keys\n");
    ret++;
  }

  if (test_valid_ecdsa_e2e()) {
    printf("e2e: valid ecdsa key was NOT written to authorized_keys\n");
    ret++;
  }

  if (test_invalid_garbage_e2e()) {
    printf("e2e: invalid garbage key WAS written to authorized_keys\n");
    ret++;
  }

  if (test_invalid_empty_e2e()) {
    printf("e2e: invalid empty key WAS written to authorized_keys\n");
    ret++;
  }

  if (test_newline_injection_e2e()) {
    printf("e2e: newline-injected key WAS written to authorized_keys\n");
    ret++;
  }

  if (test_carriage_return_injection_e2e()) {
    printf("e2e: carriage-return-injected key WAS written to authorized_keys\n");
    ret++;
  }

  if (test_empty_prefix_does_not_match_e2e()) {
    printf("e2e: key with no recognized prefix WAS written to authorized_keys\n");
    ret++;
  }

  printf("Tests failed: %d\n", ret);
  return ret;
}

int test_valid_ed25519_e2e() {
  return run_e2e_test("ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIExample test@host", true);
}

int test_valid_rsa_e2e() {
  return run_e2e_test("ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgExample test@host", true);
}

int test_valid_ecdsa_e2e() {
  return run_e2e_test("ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHA test@host", true);
}

int test_invalid_garbage_e2e() {
  return run_e2e_test("not-a-real-ssh-key malicious-payload", false);
}

int test_invalid_empty_e2e() {
  return run_e2e_test("", false);
}

int test_newline_injection_e2e() {
  return run_e2e_test("ssh-rsa AAAA_legit\nssh-rsa AAAA_attacker attacker@evil", false);
}

int test_carriage_return_injection_e2e() {
  return run_e2e_test("ssh-ed25519 AAAA_legit\rssh-ed25519 AAAA_attacker attacker@evil", false);
}

int test_empty_prefix_does_not_match_e2e() {
  return run_e2e_test("unknown-keytype AAAA_something test@host", false);
}
