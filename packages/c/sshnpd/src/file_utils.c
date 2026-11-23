#include "sshnpd/file_utils.h"
#include <atchops/base64.h>
#include <atlogger/atlogger.h>
#include <errno.h>
#include <fcntl.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <unistd.h>

#define TAG "AUTH SSH KEY"

// Each key type accepted, with the type its key data must name
static const struct {
  const char *type;
  const char *key_data_type;
} key_types[] = {
    {"ssh-ed25519", "ssh-ed25519"},
    {"ssh-rsa", "ssh-rsa"},
    {"rsa-sha2-256", "ssh-rsa"},
    {"rsa-sha2-512", "ssh-rsa"},
    {"ecdsa-sha2-nistp256", "ecdsa-sha2-nistp256"},
    {"ecdsa-sha2-nistp384", "ecdsa-sha2-nistp384"},
    {"ecdsa-sha2-nistp521", "ecdsa-sha2-nistp521"},
};

static bool is_ascii_space(char c) {
  return c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == '\v' || c == '\f';
}

// Whether s starts with a control character, or with U+0085, U+2028 or
// U+2029 in UTF-8
static bool breaks_lines(const unsigned char *s, size_t len) {
  if (s[0] < 0x20 || s[0] == 0x7f) {
    return true;
  }
  if (len >= 2 && s[0] == 0xc2 && s[1] == 0x85) {
    return true;
  }
  return len >= 3 && s[0] == 0xe2 && s[1] == 0x80 && (s[2] == 0xa8 || s[2] == 0xa9);
}

static const char *key_data_type_for(const char *type, size_t len) {
  for (size_t i = 0; i < sizeof(key_types) / sizeof(key_types[0]); i++) {
    if (strlen(key_types[i].type) == len && memcmp(key_types[i].type, type, len) == 0) {
      return key_types[i].key_data_type;
    }
  }
  return NULL;
}

static bool is_base64(const char *s, size_t len) {
  if (len == 0 || len % 4 != 0) {
    return false;
  }
  size_t padding = 0;
  while (padding < len && s[len - 1 - padding] == '=') {
    padding++;
  }
  if (padding > 2 || padding == len) {
    return false;
  }
  for (size_t i = 0; i < len - padding; i++) {
    char c = s[i];
    if (!((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || c == '+' || c == '/')) {
      return false;
    }
  }
  return true;
}

// Whether key_data is base64 whose first field (a big-endian uint32 length,
// then that many bytes) is type
static bool key_data_names(const char *key_data, size_t len, const char *type) {
  if (!is_base64(key_data, len)) {
    return false;
  }
  size_t size = atchops_base64_decoded_size(len);
  unsigned char *decoded = malloc(size);
  if (decoded == NULL) {
    return false;
  }
  size_t decoded_len = 0;
  bool names = false;
  if (atchops_base64_decode(key_data, len, decoded, size, &decoded_len) == 0 && decoded_len >= 4) {
    uint32_t name_len = ((uint32_t)decoded[0] << 24) | ((uint32_t)decoded[1] << 16) | ((uint32_t)decoded[2] << 8) |
                        (uint32_t)decoded[3];
    names = name_len <= decoded_len - 4 && name_len == strlen(type) && memcmp(decoded + 4, type, name_len) == 0;
  }
  free(decoded);
  return names;
}

static bool is_kept_comment(const char *comment, size_t len) {
  if (len > SSHNPD_SSHPUBLICKEY_MAX_COMMENT_LEN) {
    return false;
  }
  for (size_t i = 0; i < len; i++) {
    unsigned char c = (unsigned char)comment[i];
    if (c < 0x20 || c > 0x7e) {
      return false;
    }
  }
  return true;
}

int sshnpd_authorized_key_build(const char *value, const char *permissions, sshnpd_authorized_key *key,
                                const char **reason) {
  memset(key, 0, sizeof(*key));
  if (value == NULL) {
    value = "";
  }
  size_t len = strlen(value);
  if (len > SSHNPD_SSHPUBLICKEY_MAX_BYTES) {
    *reason = "it is over 8192 bytes";
    return 1;
  }

  const char *start = value;
  const char *end = value + len;
  while (start < end && is_ascii_space(*start)) {
    start++;
  }
  while (end > start && is_ascii_space(end[-1])) {
    end--;
  }
  for (const char *c = start; c < end; c++) {
    if (breaks_lines((const unsigned char *)c, (size_t)(end - c))) {
      *reason = "it holds a control character";
      return 1;
    }
  }

  const char *type_end = memchr(start, ' ', (size_t)(end - start));
  if (type_end == NULL) {
    *reason = "it is not \"<type> <key data>\"";
    return 1;
  }
  const char *data_type = key_data_type_for(start, (size_t)(type_end - start));
  if (data_type == NULL) {
    *reason = "its key type is not one sshnpd accepts";
    return 1;
  }

  const char *key_data = type_end + 1;
  const char *key_data_end = memchr(key_data, ' ', (size_t)(end - key_data));
  const char *comment = "";
  size_t comment_len = 0;
  bool has_comment = key_data_end != NULL;
  if (has_comment) {
    comment = key_data_end + 1;
    comment_len = (size_t)(end - comment);
  } else {
    key_data_end = end;
  }
  size_t key_data_len = (size_t)(key_data_end - key_data);
  if (!key_data_names(key_data, key_data_len, data_type)) {
    *reason = "its key data is not of its stated key type";
    return 1;
  }

  bool keep_comment = has_comment && is_kept_comment(comment, comment_len);
  bool has_permissions = permissions != NULL && permissions[0] != '\0';
  if (!has_permissions) {
    permissions = "";
  }
  size_t line_size = strlen(SSHNPD_LOOPBACK_FROM_OPTION) + 1 + strlen(permissions) + 1 + strlen(data_type) + 1 +
                     key_data_len + 1 + comment_len + 2;
  key->line = malloc(line_size);
  key->key_data = malloc(key_data_len + 1);
  if (key->line == NULL || key->key_data == NULL) {
    sshnpd_authorized_key_free(key);
    *reason = "sshnpd is out of memory";
    return 1;
  }
  snprintf(key->line, line_size, "%s%s%s %s %.*s%s%.*s\n", SSHNPD_LOOPBACK_FROM_OPTION, has_permissions ? "," : "",
           permissions, data_type, (int)key_data_len, key_data, keep_comment ? " " : "",
           keep_comment ? (int)comment_len : 0, comment);
  memcpy(key->key_data, key_data, key_data_len);
  key->key_data[key_data_len] = '\0';
  key->comment_left_out = has_comment && !keep_comment;
  return 0;
}

void sshnpd_authorized_key_free(sshnpd_authorized_key *key) {
  free(key->line);
  free(key->key_data);
  key->line = NULL;
  key->key_data = NULL;
}

bool sshnpd_permissions_hold_from(const char *permissions) {
  if (permissions == NULL) {
    return false;
  }
  const char *option = permissions;
  bool quoted = false;
  for (const char *c = permissions;; c++) {
    if (*c == '\\' && c[1] == '"') {
      c++;
    } else if (*c == '"') {
      quoted = !quoted;
    } else if (*c == '\0' || (*c == ',' && !quoted)) {
      const char *name_end = option;
      while (name_end < c && *name_end != '=') {
        name_end++;
      }
      while (option < name_end && is_ascii_space(*option)) {
        option++;
      }
      while (name_end > option && is_ascii_space(name_end[-1])) {
        name_end--;
      }
      if (name_end - option == 4 && strncasecmp(option, "from", 4) == 0) {
        return true;
      }
      if (*c == '\0') {
        return false;
      }
      option = c + 1;
    }
  }
}

void sshnpd_one_line_for_log(const char *value, char *out, size_t out_size) {
  if (out_size == 0) {
    return;
  }
  size_t n = 0;
  for (const unsigned char *c = (const unsigned char *)(value == NULL ? "" : value); *c != '\0'; c++) {
    char shown[5];
    if (*c == '\n') {
      strcpy(shown, "\\n");
    } else if (*c == '\r') {
      strcpy(shown, "\\r");
    } else if (*c == '\t') {
      strcpy(shown, "\\t");
    } else if (*c < 0x20 || *c > 0x7e) {
      snprintf(shown, sizeof(shown), "\\x%02x", *c);
    } else {
      shown[0] = (char)*c;
      shown[1] = '\0';
    }
    size_t shown_len = strlen(shown);
    if (n + shown_len > out_size - 1) {
      break;
    }
    memcpy(out + n, shown, shown_len);
    n += shown_len;
  }
  out[n] = '\0';
}

char *sshnpd_authorized_keys_filename(const char *home_dir) {
  const char *suffix = "/.ssh/authorized_keys";
  size_t size = strlen(home_dir) + strlen(suffix) + 1;
  char *filename = malloc(size);
  if (filename != NULL) {
    snprintf(filename, size, "%s%s", home_dir, suffix);
  }
  return filename;
}

static int create_parent_directory(const char *filename) {
  const char *slash = strrchr(filename, '/');
  if (slash == NULL || slash == filename) {
    return 0;
  }
  size_t len = (size_t)(slash - filename);
  char *dir = malloc(len + 1);
  if (dir == NULL) {
    return ENOMEM;
  }
  memcpy(dir, filename, len);
  dir[len] = '\0';
  int ret = 0;
  if (mkdir(dir, 0700) == 0) {
    if (chmod(dir, 0700) != 0) {
      ret = errno;
    }
  } else if (errno != EEXIST) {
    ret = errno;
  }
  free(dir);
  return ret;
}

static FILE *open_authorized_keys(const char *filename) {
  int fd = open(filename, O_RDWR | O_APPEND | O_CREAT | O_EXCL, 0600);
  if (fd >= 0) {
    if (fchmod(fd, 0600) != 0) {
      int err = errno;
      close(fd);
      errno = err;
      return NULL;
    }
  } else if (errno == EEXIST) {
    fd = open(filename, O_RDWR | O_APPEND);
  }
  if (fd < 0) {
    return NULL;
  }
  FILE *file = fdopen(fd, "a+");
  if (file == NULL) {
    int err = errno;
    close(fd);
    errno = err;
  }
  return file;
}

int authorize_ssh_public_key(const char *filename, const sshnpd_authorized_key *key, bool *added) {
  *added = false;
  int ret = create_parent_directory(filename);
  if (ret != 0) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to create the directory of %s: %s\n", filename,
                 strerror(ret));
    return ret;
  }

  errno = 0;
  FILE *file = open_authorized_keys(filename);
  if (file == NULL) {
    ret = errno != 0 ? errno : 1;
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to open %s: %s\n", filename, strerror(ret));
    return ret;
  }

  char *buf = NULL;
  size_t bufsize = 0;
  ssize_t read_len;
  char last = '\n';
  bool present = false;
  if (fseek(file, 0, SEEK_SET) != 0) {
    ret = errno != 0 ? errno : 1;
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to read %s: %s\n", filename, strerror(ret));
    goto exit;
  }
  while (!present && (read_len = getline(&buf, &bufsize, file)) > 0) {
    last = buf[read_len - 1];
    char *saveptr = NULL;
    for (char *token = strtok_r(buf, " \t\r\n", &saveptr); token != NULL; token = strtok_r(NULL, " \t\r\n", &saveptr)) {
      if (strcmp(token, key->key_data) == 0) {
        present = true;
        break;
      }
    }
  }
  if (ferror(file)) {
    ret = errno != 0 ? errno : 1;
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to read %s: %s\n", filename, strerror(ret));
    goto exit;
  }
  if (present) {
    goto exit;
  }

  if (fseek(file, 0, SEEK_END) != 0 || (last != '\n' && fputc('\n', file) == EOF) || fputs(key->line, file) == EOF ||
      fflush(file) != 0) {
    ret = errno != 0 ? errno : 1;
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to append to %s: %s\n", filename, strerror(ret));
    goto exit;
  }
  *added = true;

exit:
  free(buf);
  fclose(file);
  return ret;
}
