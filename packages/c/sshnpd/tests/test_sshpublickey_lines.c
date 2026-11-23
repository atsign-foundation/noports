#include "ssh_public_key_fixtures.h"
#include "sshnpd/file_utils.h"
#include "sshnpd/handle_sshpublickey.h"
#include "sshnpd/params.h"
#include <atchops/base64.h>
#include <atclient/atnotification.h>
#include <atclient/monitor.h>
#include <atlogger/atlogger.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#define ALICE "@alice"
#define K0_LINE "ssh-ed25519 " K0 " user@laptop\n"

static char home[256];
static char ssh_dir[300];
static char authkeys[340];
static char log_text[32768];

// A fresh home directory, holding an empty ~/.ssh when with_ssh_dir
static int make_home(bool with_ssh_dir) {
  snprintf(home, sizeof(home), "/tmp/sshnpd_sshpublickey_XXXXXX");
  if (mkdtemp(home) == NULL) {
    return 1;
  }
  snprintf(ssh_dir, sizeof(ssh_dir), "%s/.ssh", home);
  snprintf(authkeys, sizeof(authkeys), "%s/authorized_keys", ssh_dir);
  if (with_ssh_dir && mkdir(ssh_dir, 0700) != 0) {
    return 1;
  }
  return 0;
}

static void remove_home(void) {
  unlink(authkeys);
  rmdir(ssh_dir);
  rmdir(home);
}

static void write_authkeys(const char *content) {
  FILE *f = fopen(authkeys, "w");
  if (f == NULL) {
    printf("Failed to write %s\n", authkeys);
    exit(1);
  }
  fputs(content, f);
  fclose(f);
}

// authorized_keys' content, or NULL when there is no authorized_keys; the
// caller frees it
static char *read_authkeys(void) {
  FILE *f = fopen(authkeys, "r");
  if (f == NULL) {
    return NULL;
  }
  fseek(f, 0, SEEK_END);
  long size = ftell(f);
  fseek(f, 0, SEEK_SET);
  char *content = malloc((size_t)size + 1);
  if (content == NULL) {
    printf("Failed to allocate a buffer for %s\n", authkeys);
    exit(1);
  }
  size_t n = fread(content, 1, (size_t)size, f);
  content[n] = '\0';
  fclose(f);
  return content;
}

static void default_params(sshnpd_params *params) {
  apply_default_values_to_sshnpd_params(params);
  params->sshpublickey = true;
}

// Delivers value to handle_sshpublickey as ALICE's sshpublickey, keeping what
// it logs in log_text
static void send_key(sshnpd_params *params, const char *value) {
  atclient_atnotification notification;
  atclient_atnotification_init(&notification);
  atclient_atnotification_set_decrypted_value(&notification, value);
  atclient_atnotification_set_from(&notification, ALICE);

  atclient_monitor_message message;
  atclient_monitor_message_init(&message);
  message.type = ATCLIENT_MONITOR_MESSAGE_TYPE_NOTIFICATION;
  message.notification = &notification;

  FILE *log = tmpfile();
  if (log == NULL) {
    printf("Failed to open a log file\n");
    exit(1);
  }
  atlogger_set_logging_stream(log);
  atlogger_set_logging_level(ATLOGGER_LOGGING_LEVEL_INFO);
  handle_sshpublickey(params, &message, authkeys);
  atlogger_set_logging_stream(stdout);
  atlogger_set_logging_level(ATLOGGER_LOGGING_LEVEL_NONE);
  rewind(log);
  size_t n = fread(log_text, 1, sizeof(log_text) - 1, log);
  log_text[n] = '\0';
  fclose(log);
  atclient_atnotification_free(&notification);
}

static void send_default(const char *value) {
  sshnpd_params params;
  default_params(&params);
  send_key(&params, value);
}

static int expect_authkeys(const char *test, const char *expected) {
  char *actual = read_authkeys();
  bool ok = actual != NULL && strcmp(actual, expected) == 0;
  if (!ok) {
    printf("%s:\n  authorized_keys holds [%s]\n  expected [%s]\n", test, actual == NULL ? "(no file)" : actual,
           expected);
  }
  free(actual);
  return ok ? 0 : 1;
}

static int expect_log(const char *test, bool contains, const char *text) {
  if ((strstr(log_text, text) != NULL) != contains) {
    printf("%s:\n  log %s [%s]: [%s]\n", test, contains ? "lacks" : "holds", text, log_text);
    return 1;
  }
  return 0;
}

// Runs parse_sshnpd_params, keeping what it prints in out
static int parse_capturing_stdout(sshnpd_params *params, int argc, const char **argv, char *out, size_t out_size) {
  fflush(stdout);
  int saved = dup(STDOUT_FILENO);
  FILE *capture = tmpfile();
  if (saved < 0 || capture == NULL) {
    printf("Failed to capture stdout\n");
    exit(1);
  }
  dup2(fileno(capture), STDOUT_FILENO);
  int ret = parse_sshnpd_params(params, argc, argv);
  fflush(stdout);
  dup2(saved, STDOUT_FILENO);
  close(saved);
  rewind(capture);
  size_t n = fread(out, 1, out_size - 1, capture);
  out[n] = '\0';
  fclose(capture);
  return ret;
}

static void free_parsed_params(sshnpd_params *params) {
  free(params->sshpublickey_permissions);
  free(params->manager_list);
  free(params->normalized_manager_buf);
  free(params->permitopen_str);
}

static int test_key_added_as_one_loopback_line(void) {
  const char *test = "a client's key is added as one line that allows only loopback logins";
  make_home(true);
  write_authkeys(K0_LINE);
  send_default("ssh-ed25519 " K1);
  int ret = expect_authkeys(test, K0_LINE LOOPBACK " ssh-ed25519 " K1 "\n");
  remove_home();
  return ret;
}

static int test_key_after_last_line_without_newline(void) {
  const char *test = "a key added after a last line with no newline starts a line of its own";
  make_home(true);
  write_authkeys("ssh-ed25519 " K0 " user@laptop");
  send_default("ssh-ed25519 " K1);
  int ret = expect_authkeys(test, K0_LINE LOOPBACK " ssh-ed25519 " K1 "\n");
  remove_home();
  return ret;
}

static int test_two_keys_one_after_the_other(void) {
  const char *test = "two keys sent one after the other are each on a line of their own";
  make_home(true);
  send_default("ssh-ed25519 " K1);
  send_default("ssh-ed25519 " K2);
  int ret = expect_authkeys(test, LOOPBACK " ssh-ed25519 " K1 "\n" LOOPBACK " ssh-ed25519 " K2 "\n");
  remove_home();
  return ret;
}

// The daemon's single monitor thread handles notifications that arrive
// together one at a time, in the order it reads them
static int test_two_keys_together(void) {
  const char *test = "two keys sent together are each on a line of their own";
  make_home(true);
  sshnpd_params params;
  default_params(&params);
  send_key(&params, "ssh-ed25519 " K1);
  send_key(&params, "ssh-ed25519 " K2);
  int ret = expect_authkeys(test, LOOPBACK " ssh-ed25519 " K1 "\n" LOOPBACK " ssh-ed25519 " K2 "\n");
  remove_home();
  return ret;
}

static int test_key_already_present(void) {
  const char *test = "a key already in authorized_keys is not added again";
  make_home(true);
  write_authkeys(LOOPBACK " ssh-ed25519 " K1 "\n");
  send_default("ssh-ed25519 " K1);
  int ret = expect_authkeys(test, LOOPBACK " ssh-ed25519 " K1 "\n");
  ret += expect_log(test, true, "already in authorized_keys");
  remove_home();
  return ret;
}

static int test_key_present_with_own_options(void) {
  const char *test = "a key already in authorized_keys on a line of its own options is left as it is";
  make_home(true);
  write_authkeys("ssh-ed25519 " K1 " user@laptop\n");
  send_default("ssh-ed25519 " K1);
  int ret = expect_authkeys(test, "ssh-ed25519 " K1 " user@laptop\n");
  remove_home();
  return ret;
}

static int test_trailing_newline_keeps_comment(void) {
  const char *test = "a key sent with a trailing newline keeps its comment";
  make_home(true);
  send_default("ssh-ed25519 " K1 " user@client\n");
  int ret = expect_authkeys(test, LOOPBACK " ssh-ed25519 " K1 " user@client\n");
  remove_home();
  return ret;
}

static int test_comment_left_out(void) {
  const char *test = "a key whose comment is not printable ASCII, or is over 256 characters, is added without it";
  char value[512];
  char comment[258];
  memset(comment, 'a', 257);
  comment[257] = '\0';
  snprintf(value, sizeof(value), "ssh-ed25519 " K1 " %s", comment);
  make_home(true);
  send_default(value);
  int ret = expect_authkeys(test, LOOPBACK " ssh-ed25519 " K1 "\n");
  ret += expect_log(test, true, "INFO");
  ret += expect_log(test, true, "Added the ssh public key from " ALICE " without its comment");
  ret += expect_log(test, false, "aaaaaaaaaaaaaaaaaaaa");
  remove_home();

  make_home(true);
  send_default("ssh-ed25519 " K1 " user@caf\xc3\xa9");
  ret += expect_authkeys(test, LOOPBACK " ssh-ed25519 " K1 "\n");
  ret += expect_log(test, false, "user@caf");
  remove_home();
  return ret;
}

static int test_rsa_signature_algorithm_written_as_ssh_rsa(void) {
  const char *test = "an RSA key named by its signature algorithm is written as ssh-rsa";
  make_home(true);
  send_default("rsa-sha2-256 " R1);
  int ret = expect_authkeys(test, LOOPBACK " ssh-rsa " R1 "\n");
  remove_home();
  return ret;
}

static int test_permissions_follow_loopback(void) {
  const char *test = "the --sshpublickey-permissions value follows the loopback restriction";
  const char *argv[] = {"sshnpd", "-a", "@device", "-m", ALICE, "-s", "--sshpublickey-permissions", "no-pty"};
  sshnpd_params params;
  apply_default_values_to_sshnpd_params(&params);
  char out[8192];
  if (parse_capturing_stdout(&params, 8, argv, out, sizeof(out)) != 0) {
    printf("%s: parse_sshnpd_params failed: %s\n", test, out);
    return 1;
  }
  make_home(true);
  send_key(&params, "ssh-ed25519 " K1);
  int ret = expect_authkeys(test, LOOPBACK ",no-pty ssh-ed25519 " K1 "\n");
  remove_home();
  free_parsed_params(&params);
  return ret;
}

static int test_permissions_holding_from_refused(void) {
  const char *test = "sshnpd refuses a --sshpublickey-permissions value holding its own from= option";
  const char *argv[] = {"sshnpd", "-a", "@device", "-m", ALICE, "--sshpublickey", "--sshpublickey-permissions",
                        "from=\"10.0.0.0/8\""};
  sshnpd_params params;
  apply_default_values_to_sshnpd_params(&params);
  char out[8192];
  int parsed = parse_capturing_stdout(&params, 8, argv, out, sizeof(out));
  int ret = 0;
  if (parsed == 0 || strstr(out, "sshnpd sets the from= option itself") == NULL) {
    printf("%s: parse_sshnpd_params returned %d, printing [%s]\n", test, parsed, out);
    ret = 1;
  }
  return ret;
}

static int test_two_key_lines_change_nothing(void) {
  const char *test = "a value holding two key lines changes nothing";
  make_home(true);
  write_authkeys(K0_LINE);
  send_default("ssh-ed25519 " K1 "\nssh-ed25519 " K2);
  int ret = expect_authkeys(test, K0_LINE);
  ret += expect_log(test, true, "WARN");
  ret += expect_log(test, true, "Refusing the sshpublickey from " ALICE);
  remove_home();
  return ret;
}

static int test_key_data_of_another_type(void) {
  const char *test = "a value whose key data is not of its stated key type changes nothing";
  make_home(true);
  write_authkeys(K0_LINE);
  send_default("ssh-ed25519 " R1);
  int ret = expect_authkeys(test, K0_LINE);
  remove_home();
  return ret;
}

static int test_unsupported_key_type(void) {
  const char *test = "a value with a key type outside the supported list changes nothing";
  make_home(true);
  write_authkeys(K0_LINE);
  send_default("ssh-dss " K1);
  int ret = expect_authkeys(test, K0_LINE);
  remove_home();
  return ret;
}

static int test_refused_value_on_one_line(void) {
  const char *test = "a refused value is logged on one line";
  make_home(true);
  send_default("ssh-ed25519 " K1 "\nsecond line");
  int ret = expect_log(test, true, "\"ssh-ed25519 " K1 "\\nsecond line\"");
  char *newline = strchr(log_text, '\n');
  if (newline == NULL || newline[1] != '\0') {
    printf("%s: the log is not one line: [%s]\n", test, log_text);
    ret++;
  }
  remove_home();
  return ret;
}

static int test_refused_value_cut_to_200(void) {
  const char *test = "a refused value over 200 characters is logged cut to 200 characters";
  char value[512];
  snprintf(value, sizeof(value), "ssh-ed25519 " K1 "\n%0300d", 0);
  make_home(true);
  send_default(value);
  int ret = 0;
  char *end = strrchr(log_text, '"');
  char *start = strstr(log_text, ": \"");
  if (start == NULL || end == NULL || end - (start + 3) != 200 || strncmp(start + 3, "ssh-ed25519 " K1 "\\n000", 85)) {
    printf("%s: [%s]\n", test, log_text);
    ret = 1;
  }
  remove_home();
  return ret;
}

static int test_value_over_8_kib(void) {
  const char *test = "a value over 8 KiB changes nothing";
  char value[8194];
  memset(value, 'a', sizeof(value) - 1);
  value[sizeof(value) - 1] = '\0';
  memcpy(value, "ssh-ed25519 " K1 " ", strlen("ssh-ed25519 " K1 " "));
  make_home(true);
  write_authkeys(K0_LINE);
  send_default(value);
  int ret = expect_authkeys(test, K0_LINE);
  remove_home();

  const char *control = "a value of exactly 8 KiB is added";
  value[8192] = '\0';
  make_home(true);
  send_default(value);
  ret += expect_authkeys(control, LOOPBACK " ssh-ed25519 " K1 "\n");
  remove_home();
  return ret;
}

static int test_ignored_without_sshpublickey(void) {
  const char *test = "sshnpd without --sshpublickey ignores a client's key";
  make_home(true);
  write_authkeys(K0_LINE);
  sshnpd_params params;
  apply_default_values_to_sshnpd_params(&params);
  send_key(&params, "ssh-ed25519 " K1);
  int ret = expect_authkeys(test, K0_LINE);
  remove_home();
  return ret;
}

static int test_no_ssh_directory(void) {
  const char *test = "a key sent to a device with no ~/.ssh is added to a new authorized_keys only its owner can read";
  make_home(false);
  mode_t umask_before = umask(0277);
  send_default("ssh-ed25519 " K1);
  umask(umask_before);
  int ret = 0;
  struct stat dir_stat;
  struct stat file_stat;
  if (stat(ssh_dir, &dir_stat) != 0 || (dir_stat.st_mode & 0777) != 0700) {
    printf("%s: ~/.ssh's mode is %o\n", test, (unsigned)(dir_stat.st_mode & 0777));
    ret++;
  }
  if (stat(authkeys, &file_stat) != 0 || (file_stat.st_mode & 0777) != 0600) {
    printf("%s: authorized_keys' mode is %o\n", test, (unsigned)(file_stat.st_mode & 0777));
    ret++;
  }
  ret += expect_authkeys(test, LOOPBACK " ssh-ed25519 " K1 "\n");
  remove_home();
  return ret;
}

static int test_starts_without_authorized_keys(void) {
  const char *test = "sshnpd starts on a device with no authorized_keys";
  make_home(false);
  char *filename = sshnpd_authorized_keys_filename(home);
  int ret = 0;
  if (filename == NULL || strcmp(filename, authkeys) != 0) {
    printf("%s: the authorized_keys path is %s\n", test, filename == NULL ? "(none)" : filename);
    ret++;
  }
  if (access(ssh_dir, F_OK) == 0 || access(authkeys, F_OK) == 0) {
    printf("%s: ~/.ssh or authorized_keys was created\n", test);
    ret++;
  }
  free(filename);
  remove_home();
  return ret;
}

// Key data whose first field names type, followed by some key bytes
static void key_data_naming(const char *type, char *out, size_t out_size) {
  unsigned char raw[128] = {0};
  size_t len = strlen(type);
  raw[0] = (unsigned char)(len >> 24);
  raw[1] = (unsigned char)(len >> 16);
  raw[2] = (unsigned char)(len >> 8);
  raw[3] = (unsigned char)len;
  memcpy(raw + 4, type, len);
  memset(raw + 4 + len, 7, 32);
  atchops_base64_encode(raw, 4 + len + 32, out, out_size, NULL);
}

static int expect_built(const char *value, const char *expected_line) {
  sshnpd_authorized_key key;
  const char *reason = NULL;
  int built = sshnpd_authorized_key_build(value, NULL, &key, &reason);
  if (built != 0 || (expected_line != NULL && strcmp(key.line, expected_line) != 0)) {
    printf("build [%s]: %s [%s]\n", value, built == 0 ? "wrote" : reason, built == 0 ? key.line : "");
    if (built == 0) {
      sshnpd_authorized_key_free(&key);
    }
    return 1;
  }
  sshnpd_authorized_key_free(&key);
  return 0;
}

static int expect_refused(const char *value) {
  sshnpd_authorized_key key;
  const char *reason = NULL;
  if (sshnpd_authorized_key_build(value, NULL, &key, &reason) == 0) {
    printf("build [%s] was not refused: [%s]\n", value, key.line);
    sshnpd_authorized_key_free(&key);
    return 1;
  }
  return 0;
}

static int test_build_accepts_each_supported_type(void) {
  const char *types[][2] = {
      {"ssh-ed25519", "ssh-ed25519"},
      {"ssh-rsa", "ssh-rsa"},
      {"rsa-sha2-256", "ssh-rsa"},
      {"rsa-sha2-512", "ssh-rsa"},
      {"ecdsa-sha2-nistp256", "ecdsa-sha2-nistp256"},
      {"ecdsa-sha2-nistp384", "ecdsa-sha2-nistp384"},
      {"ecdsa-sha2-nistp521", "ecdsa-sha2-nistp521"},
  };
  int ret = 0;
  for (size_t i = 0; i < sizeof(types) / sizeof(types[0]); i++) {
    char key_data[256];
    char value[512];
    char line[600];
    key_data_naming(types[i][1], key_data, sizeof(key_data));
    snprintf(value, sizeof(value), "%s %s", types[i][0], key_data);
    snprintf(line, sizeof(line), LOOPBACK " %s %s\n", types[i][1], key_data);
    ret += expect_built(value, line);
  }
  ret += expect_built("ecdsa-sha2-nistp256 " E1, LOOPBACK " ecdsa-sha2-nistp256 " E1 "\n");
  ret += expect_built("rsa-sha2-512 " R1, LOOPBACK " ssh-rsa " R1 "\n");
  ret += expect_built(" \t\r\nssh-ed25519 " K1 " me\r\n ", LOOPBACK " ssh-ed25519 " K1 " me\n");
  return ret;
}

static int test_build_refuses_malformed_values(void) {
  char named[256];
  char value[300];
  int ret = 0;
  const char *refused[] = {
      "",
      "ssh-ed25519",
      K1,
      "ssh-ed25519  " K1,
      "SSH-ED25519 " K1,
      "ssh-rsa " K1,
      "rsa-sha2-256 " K1,
      "ecdsa-sha2-nistp384 " E1,
      "ssh-ed25519 AAAA",
      "ssh-ed25519 AAAAC3Nz",
      "ssh-ed25519 =AAA",
      "ssh-ed25519 A===",
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBKm94wiGMQ7pOM6hG1bW4EAAkv-GjahbkzLo48iFnZT",
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBKm94wiGMQ7pOM6hG1bW4EAAkv+GjahbkzLo48iFnZ",
      "ssh-ed25519 " K1 " a\tb",
      "ssh-ed25519 " K1 " a\x01" "b",
      "ssh-ed25519 " K1 " a\x1b" "b",
      "ssh-ed25519 " K1 " a\x7f" "b",
      "ssh-ed25519 " K1 " a\xc2\x85" "b",
      "ssh-ed25519 " K1 " a\xe2\x80\xa8" "b",
      "ssh-ed25519 " K1 " a\xe2\x80\xa9" "b",
  };
  for (size_t i = 0; i < sizeof(refused) / sizeof(refused[0]); i++) {
    ret += expect_refused(refused[i]);
  }
  key_data_naming("ssh-ed25519x", named, sizeof(named));
  snprintf(value, sizeof(value), "ssh-ed25519 %s", named);
  ret += expect_refused(value);
  key_data_naming("ssh-ed2551", named, sizeof(named));
  snprintf(value, sizeof(value), "ssh-ed25519 %s", named);
  ret += expect_refused(value);
  return ret;
}

static int test_build_keeps_a_256_character_comment(void) {
  char comment[257];
  char value[400];
  char line[500];
  memset(comment, 'x', 256);
  comment[0] = ' ';
  comment[1] = '!';
  comment[2] = '~';
  comment[256] = '\0';
  snprintf(value, sizeof(value), "ssh-ed25519 " K1 " %s", comment);
  snprintf(line, sizeof(line), LOOPBACK " ssh-ed25519 " K1 " %s\n", comment);
  return expect_built(value, line);
}

static int test_permissions_hold_from(void) {
  const char *holding[] = {
      "from=\"10.0.0.0/8\"",
      "FROM=\"10.0.0.0/8\"",
      "no-pty,From=\"10.0.0.0/8\"",
      "command=\"echo a,b\",from=\"10.0.0.0/8\"",
      "no-pty, from=\"10.0.0.0/8\"",
      "no-pty,from",
  };
  const char *not_holding[] = {
      "",
      "no-pty",
      "no-port-forwarding,no-pty",
      "command=\"echo a,from=b\"",
      "command=\"echo \\\",from=b\"",
      "environment=\"FROM=x\"",
      "fromage",
  };
  int ret = 0;
  for (size_t i = 0; i < sizeof(holding) / sizeof(holding[0]); i++) {
    if (!sshnpd_permissions_hold_from(holding[i])) {
      printf("permissions [%s] should hold from\n", holding[i]);
      ret++;
    }
  }
  for (size_t i = 0; i < sizeof(not_holding) / sizeof(not_holding[0]); i++) {
    if (sshnpd_permissions_hold_from(not_holding[i])) {
      printf("permissions [%s] should not hold from\n", not_holding[i]);
      ret++;
    }
  }
  if (sshnpd_permissions_hold_from(NULL)) {
    printf("NULL permissions should not hold from\n");
    ret++;
  }
  return ret;
}

static int test_permissions_values_joined(void) {
  const char *argv[] = {"sshnpd", "-a", "@device", "-m", ALICE, "-S", "no-pty", "-S",
                        "command=\"echo hi\" , no-X11-forwarding"};
  sshnpd_params params;
  apply_default_values_to_sshnpd_params(&params);
  char out[8192];
  int ret = 0;
  if (parse_capturing_stdout(&params, 9, argv, out, sizeof(out)) != 0 || params.sshpublickey_permissions == NULL ||
      strcmp(params.sshpublickey_permissions, "no-pty,command=\"echo hi\",no-X11-forwarding") != 0) {
    printf("-S values were joined as [%s]\n",
           params.sshpublickey_permissions == NULL ? "(none)" : params.sshpublickey_permissions);
    ret = 1;
  }
  free_parsed_params(&params);
  return ret;
}

static int test_permissions_with_newline_refused(void) {
  const char *values[] = {"no-pty\nssh-ed25519 " K2, "no-pty\rno-X11-forwarding"};
  int ret = 0;
  for (size_t i = 0; i < 2; i++) {
    const char *argv[] = {"sshnpd", "-a", "@device", "-m", ALICE, "-S", values[i]};
    sshnpd_params params;
    apply_default_values_to_sshnpd_params(&params);
    char out[8192];
    if (parse_capturing_stdout(&params, 7, argv, out, sizeof(out)) == 0 ||
        strstr(out, "Detected newline characters") == NULL) {
      printf("-S [%s] was not refused: [%s]\n", values[i], out);
      ret++;
    }
  }
  return ret;
}

static int test_one_line_for_log(void) {
  char out[SSHNPD_SSHPUBLICKEY_LOG_MAX_LEN + 1];
  int ret = 0;
  sshnpd_one_line_for_log("a\nb\rc\td\x01" "e\x7f" "f\xc2\x85g\xe2\x80\xa8h", out, sizeof(out));
  if (strcmp(out, "a\\nb\\rc\\td\\x01e\\x7ff\\xc2\\x85g\\xe2\\x80\\xa8h") != 0) {
    printf("one_line_for_log escaped to [%s]\n", out);
    ret++;
  }
  char value[301];
  memset(value, 'x', 300);
  value[300] = '\0';
  sshnpd_one_line_for_log(value, out, sizeof(out));
  if (strlen(out) != 200) {
    printf("one_line_for_log kept %zu characters of 300\n", strlen(out));
    ret++;
  }
  value[199] = '\n';
  value[200] = '\0';
  sshnpd_one_line_for_log(value, out, sizeof(out));
  if (strlen(out) != 199) {
    printf("one_line_for_log split an escape: [%s]\n", out + 190);
    ret++;
  }
  return ret;
}

int main(void) {
  int (*tests[])(void) = {
      test_key_added_as_one_loopback_line,
      test_key_after_last_line_without_newline,
      test_two_keys_one_after_the_other,
      test_two_keys_together,
      test_key_already_present,
      test_key_present_with_own_options,
      test_trailing_newline_keeps_comment,
      test_comment_left_out,
      test_rsa_signature_algorithm_written_as_ssh_rsa,
      test_permissions_follow_loopback,
      test_permissions_holding_from_refused,
      test_two_key_lines_change_nothing,
      test_key_data_of_another_type,
      test_unsupported_key_type,
      test_refused_value_on_one_line,
      test_refused_value_cut_to_200,
      test_value_over_8_kib,
      test_ignored_without_sshpublickey,
      test_no_ssh_directory,
      test_starts_without_authorized_keys,
      test_build_accepts_each_supported_type,
      test_build_refuses_malformed_values,
      test_build_keeps_a_256_character_comment,
      test_permissions_hold_from,
      test_permissions_values_joined,
      test_permissions_with_newline_refused,
      test_one_line_for_log,
  };
  int failed = 0;
  for (size_t i = 0; i < sizeof(tests) / sizeof(tests[0]); i++) {
    failed += tests[i]() != 0;
  }
  printf("Tests failed: %d\n", failed);
  return failed;
}
