#include "sshnpd/authorization.h"
#include <stdbool.h>
#include <stddef.h>
#include <string.h>

static const char *const reserved_characters = "!*'`();:&=+$,/?#[]{}";

static bool is_reserved_character(char c) { return strchr(reserved_characters, c) != NULL; }

static bool is_whitespace_or_control(unsigned char c) { return c <= 0x1F || c == 0x7F || c == ' '; }

int sshnpd_normalize_atsign(const char *input, char *out, size_t out_len) {
  if (input == NULL || out == NULL || out_len < 2) {
    return 1;
  }

  const size_t input_len = strlen(input);
  if (input_len == 0) {
    return 1;
  }

  size_t start = (input[0] == '@') ? 1 : 0;

  size_t o = 0;
  out[o++] = '@';

  for (size_t i = start; i < input_len; i++) {
    unsigned char c = (unsigned char)input[i];

    if (c == '@') {
      return 1;
    }
    if (is_whitespace_or_control(c) || is_reserved_character((char)c)) {
      return 1;
    }
    if (c == '.') {
      continue;
    }
    if (c >= 'A' && c <= 'Z') {
      c = (unsigned char)(c + ('a' - 'A'));
    }
    if (o + 1 >= out_len) {
      return 1;
    }
    out[o++] = (char)c;
  }

  if (o == 1) {
    return 1;
  }

  out[o] = '\0';
  return 0;
}
