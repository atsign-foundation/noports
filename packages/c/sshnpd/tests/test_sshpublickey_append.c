#define _GNU_SOURCE
#include "ssh_public_key_fixtures.h"
#include "sshnpd/file_utils.h"
#include <atchops/base64.h>
#include <dlfcn.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

#define K0_LINE "ssh-ed25519 " K0 " user@laptop"

static char home[256];
static char ssh_dir[300];
static char authkeys[340];

static bool counting;
static dev_t counted_dev;
static ino_t counted_ino;
static int counted_writes;
static size_t counted_bytes;

// NOTE: this binary's write(2) wrapper; it passes every call through and
// counts the calls on authorized_keys while counting is set
ssize_t write(int fd, const void *buf, size_t count) {
  static ssize_t (*real_write)(int, const void *, size_t) = NULL;
  if (real_write == NULL) {
    *(void **)&real_write = dlsym(RTLD_NEXT, "write");
    if (real_write == NULL) {
      abort();
    }
  }
  struct stat st;
  if (counting && fstat(fd, &st) == 0 && st.st_dev == counted_dev && st.st_ino == counted_ino) {
    counted_writes++;
    counted_bytes += count;
  }
  return real_write(fd, buf, count);
}

static int make_home(void) {
  snprintf(home, sizeof(home), "/tmp/sshnpd_sshpublickey_XXXXXX");
  if (mkdtemp(home) == NULL) {
    return 1;
  }
  snprintf(ssh_dir, sizeof(ssh_dir), "%s/.ssh", home);
  snprintf(authkeys, sizeof(authkeys), "%s/authorized_keys", ssh_dir);
  return mkdir(ssh_dir, 0700);
}

static void remove_home(void) {
  unlink(authkeys);
  rmdir(ssh_dir);
  rmdir(home);
}

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
    fclose(f);
    return NULL;
  }
  size_t n = fread(content, 1, (size_t)size, f);
  content[n] = '\0';
  fclose(f);
  return content;
}

// An ssh-ed25519 value whose key data carries extra_bytes key bytes, making
// its line longer than a stdio buffer
static int long_value(size_t extra_bytes, char *out, size_t out_size) {
  const char *type = "ssh-ed25519";
  size_t type_len = strlen(type);
  size_t raw_len = 4 + type_len + extra_bytes;
  unsigned char *raw = calloc(raw_len, 1);
  if (raw == NULL) {
    return 1;
  }
  raw[3] = (unsigned char)type_len;
  memcpy(raw + 4, type, type_len);
  memset(raw + 4 + type_len, 7, extra_bytes);
  int prefix = snprintf(out, out_size, "%s ", type);
  size_t encoded_len = 0;
  int ret = atchops_base64_encode(raw, raw_len, out + prefix, out_size - (size_t)prefix, &encoded_len);
  free(raw);
  if (ret != 0) {
    return 1;
  }
  snprintf(out + prefix + encoded_len, out_size - (size_t)prefix - encoded_len, " user@host");
  return 0;
}

static int test_line_and_separator_in_one_write(void) {
  const char *test = "a key's line and the newline before it reach authorized_keys in one write";
  static char value[SSHNPD_SSHPUBLICKEY_MAX_BYTES + 1];
  if (make_home() != 0 || long_value(6000, value, sizeof(value)) != 0) {
    printf("%s: setup failed\n", test);
    return 1;
  }
  FILE *f = fopen(authkeys, "w");
  if (f == NULL) {
    printf("%s: setup failed\n", test);
    remove_home();
    return 1;
  }
  fputs(K0_LINE, f);
  fclose(f);
  struct stat st;
  stat(authkeys, &st);

  sshnpd_authorized_key key;
  const char *reason = NULL;
  if (sshnpd_authorized_key_build(value, NULL, &key, &reason) != 0) {
    printf("%s: the value was refused, as %s\n", test, reason);
    remove_home();
    return 1;
  }
  size_t line_len = strlen(key.line);

  counted_dev = st.st_dev;
  counted_ino = st.st_ino;
  counted_writes = 0;
  counted_bytes = 0;
  counting = true;
  bool added = false;
  int authorized = authorize_ssh_public_key(authkeys, &key, &added);
  counting = false;

  int ret = 0;
  if (line_len <= 4096) {
    printf("%s: the line is only %zu bytes\n", test, line_len);
    ret++;
  }
  if (authorized != 0 || !added) {
    printf("%s: authorize_ssh_public_key returned %d, added %d\n", test, authorized, added);
    ret++;
  }
  if (counted_writes != 1 || counted_bytes != line_len + 1) {
    printf("%s: authorized_keys took %d writes of %zu bytes in all, for a %zu-byte line\n", test, counted_writes,
           counted_bytes, line_len);
    ret++;
  }
  char *content = read_authkeys();
  size_t expected_len = strlen(K0_LINE) + 1 + line_len;
  if (content == NULL || strlen(content) != expected_len || strncmp(content, K0_LINE "\n", strlen(K0_LINE) + 1) != 0 ||
      strcmp(content + strlen(K0_LINE) + 1, key.line) != 0) {
    printf("%s: authorized_keys does not hold the first line then the key's line\n", test);
    ret++;
  }
  free(content);
  sshnpd_authorized_key_free(&key);
  remove_home();
  return ret;
}

int main(void) {
  int failed = test_line_and_separator_in_one_write();
  printf("Tests failed: %d\n", failed);
  return failed;
}
