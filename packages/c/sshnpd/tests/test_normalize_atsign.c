#include "sshnpd/authorization.h"
#include <stdio.h>
#include <string.h>

int test_lowercase() {
  char out[SSHNPD_ATSIGN_BUFFER_LEN];
  if (sshnpd_normalize_atsign("@Alice", out, sizeof(out)) != 0) {
    return 1;
  }
  return strcmp(out, "@alice") != 0;
}

int test_prepend_at() {
  char out[SSHNPD_ATSIGN_BUFFER_LEN];
  if (sshnpd_normalize_atsign("bob", out, sizeof(out)) != 0) {
    return 1;
  }
  return strcmp(out, "@bob") != 0;
}

int test_strip_dots() {
  char out[SSHNPD_ATSIGN_BUFFER_LEN];
  if (sshnpd_normalize_atsign("@colin.constable", out, sizeof(out)) != 0) {
    return 1;
  }
  return strcmp(out, "@colinconstable") != 0;
}

int test_combined() {
  char out[SSHNPD_ATSIGN_BUFFER_LEN];
  if (sshnpd_normalize_atsign("Colin.Constable", out, sizeof(out)) != 0) {
    return 1;
  }
  return strcmp(out, "@colinconstable") != 0;
}

int test_idempotent() {
  char first[SSHNPD_ATSIGN_BUFFER_LEN];
  char second[SSHNPD_ATSIGN_BUFFER_LEN];
  if (sshnpd_normalize_atsign("@Alice", first, sizeof(first)) != 0) {
    return 1;
  }
  if (sshnpd_normalize_atsign(first, second, sizeof(second)) != 0) {
    return 1;
  }
  return strcmp(first, second) != 0;
}

int test_reject_double_at() {
  char out[SSHNPD_ATSIGN_BUFFER_LEN];
  return sshnpd_normalize_atsign("@ali@ce", out, sizeof(out)) == 0;
}

int test_reject_empty() {
  char out[SSHNPD_ATSIGN_BUFFER_LEN];
  return sshnpd_normalize_atsign("", out, sizeof(out)) == 0;
}

int test_reject_at_only() {
  char out[SSHNPD_ATSIGN_BUFFER_LEN];
  return sshnpd_normalize_atsign("@", out, sizeof(out)) == 0;
}

int test_reject_null() {
  char out[SSHNPD_ATSIGN_BUFFER_LEN];
  return sshnpd_normalize_atsign(NULL, out, sizeof(out)) == 0;
}

int test_reject_reserved_colon() {
  char out[SSHNPD_ATSIGN_BUFFER_LEN];
  return sshnpd_normalize_atsign("@ali:ce", out, sizeof(out)) == 0;
}

int test_reject_space() {
  char out[SSHNPD_ATSIGN_BUFFER_LEN];
  return sshnpd_normalize_atsign("@ali ce", out, sizeof(out)) == 0;
}

int main() {
  int ret = 0;
  struct {
    const char *name;
    int (*fn)();
  } tests[] = {
    {"lowercase", test_lowercase},
    {"prepend_at", test_prepend_at},
    {"strip_dots", test_strip_dots},
    {"combined", test_combined},
    {"idempotent", test_idempotent},
    {"reject_double_at", test_reject_double_at},
    {"reject_empty", test_reject_empty},
    {"reject_at_only", test_reject_at_only},
    {"reject_null", test_reject_null},
    {"reject_reserved_colon", test_reject_reserved_colon},
    {"reject_space", test_reject_space},
  };
  int count = sizeof(tests) / sizeof(tests[0]);
  for (int i = 0; i < count; i++) {
    if (tests[i].fn()) {
      printf("%s failed\n", tests[i].name);
      ret++;
    }
  }
  printf("Tests failed: %d/%d\n", ret, count);
  return ret;
}
