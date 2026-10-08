#include "sshnpd/authorization.h"
#include "sshnpd/params.h"
#include <stdbool.h>
#include <stdio.h>
#include <string.h>

bool is_manager_atsign(const sshnpd_params *params, const char *atsign);

int single_manager_authorized_test();
int single_manager_unauthorized_test();
int multiple_managers_authorized_test();
int multiple_managers_unauthorized_test();
int empty_manager_list_test();
int null_sender_test();
int null_manager_list_test();
int case_and_prefix_normalization_test();
int policy_manager_denies_everyone_test();
int sender_canonical_equivalence_test();
int sender_near_miss_denied_test();
int sender_malformed_fails_closed_test();

int main() {
  int ret = 0;

  if (single_manager_authorized_test()) {
    printf("single_manager_authorized_test failed\n");
    ret++;
  }
  if (single_manager_unauthorized_test()) {
    printf("single_manager_unauthorized_test failed\n");
    ret++;
  }
  if (multiple_managers_authorized_test()) {
    printf("multiple_managers_authorized_test failed\n");
    ret++;
  }
  if (multiple_managers_unauthorized_test()) {
    printf("multiple_managers_unauthorized_test failed\n");
    ret++;
  }
  if (empty_manager_list_test()) {
    printf("empty_manager_list_test failed\n");
    ret++;
  }
  if (null_sender_test()) {
    printf("null_sender_test failed\n");
    ret++;
  }
  if (null_manager_list_test()) {
    printf("null_manager_list_test failed\n");
    ret++;
  }
  if (case_and_prefix_normalization_test()) {
    printf("case_and_prefix_normalization_test failed\n");
    ret++;
  }
  if (policy_manager_denies_everyone_test()) {
    printf("policy_manager_denies_everyone_test failed\n");
    ret++;
  }
  if (sender_canonical_equivalence_test()) {
    printf("sender_canonical_equivalence_test failed\n");
    ret++;
  }
  if (sender_near_miss_denied_test()) {
    printf("sender_near_miss_denied_test failed\n");
    ret++;
  }
  if (sender_malformed_fails_closed_test()) {
    printf("sender_malformed_fails_closed_test failed\n");
    ret++;
  }

  printf("Tests failed: %d\n", ret);
  return ret;
}

int single_manager_authorized_test() {
  sshnpd_params params;
  apply_default_values_to_sshnpd_params(&params);
  char *managers[] = {"@alice"};
  params.manager_list = managers;
  params.manager_list_len = 1;

  if (!is_manager_atsign(&params, "@alice")) {
    return 1;
  }
  return 0;
}

int single_manager_unauthorized_test() {
  sshnpd_params params;
  apply_default_values_to_sshnpd_params(&params);
  char *managers[] = {"@alice"};
  params.manager_list = managers;
  params.manager_list_len = 1;

  if (is_manager_atsign(&params, "@eve")) {
    return 1;
  }
  return 0;
}

int multiple_managers_authorized_test() {
  sshnpd_params params;
  apply_default_values_to_sshnpd_params(&params);
  char *managers[] = {"@alice", "@bob", "@charlie"};
  params.manager_list = managers;
  params.manager_list_len = 3;

  if (!is_manager_atsign(&params, "@alice")) {
    return 1;
  }
  if (!is_manager_atsign(&params, "@bob")) {
    return 1;
  }
  if (!is_manager_atsign(&params, "@charlie")) {
    return 1;
  }
  return 0;
}

int multiple_managers_unauthorized_test() {
  sshnpd_params params;
  apply_default_values_to_sshnpd_params(&params);
  char *managers[] = {"@alice", "@bob", "@charlie"};
  params.manager_list = managers;
  params.manager_list_len = 3;

  if (is_manager_atsign(&params, "@eve")) {
    return 1;
  }
  if (is_manager_atsign(&params, "@mallory")) {
    return 1;
  }
  return 0;
}

int empty_manager_list_test() {
  sshnpd_params params;
  apply_default_values_to_sshnpd_params(&params);
  params.manager_list = NULL;
  params.manager_list_len = 0;

  if (is_manager_atsign(&params, "@anyone")) {
    return 1;
  }
  return 0;
}

int null_sender_test() {
  sshnpd_params params;
  apply_default_values_to_sshnpd_params(&params);
  char *managers[] = {"@alice"};
  params.manager_list = managers;
  params.manager_list_len = 1;

  if (is_manager_atsign(&params, NULL)) {
    return 1;
  }
  if (is_manager_atsign(&params, "")) {
    return 1;
  }
  return 0;
}

int null_manager_list_test() {
  sshnpd_params params;
  apply_default_values_to_sshnpd_params(&params);
  params.manager_list = NULL;
  params.manager_list_len = 3;

  if (is_manager_atsign(&params, "@alice")) {
    return 1;
  }
  return 0;
}

int case_and_prefix_normalization_test() {
  char out[SSHNPD_ATSIGN_BUFFER_LEN];

  if (sshnpd_normalize_atsign("@Alice", out, sizeof(out)) != 0 || strcmp(out, "@alice") != 0) {
    return 1;
  }
  if (sshnpd_normalize_atsign("bob", out, sizeof(out)) != 0 || strcmp(out, "@bob") != 0) {
    return 1;
  }
  if (sshnpd_normalize_atsign("@colin.constable", out, sizeof(out)) != 0 ||
      strcmp(out, "@colinconstable") != 0) {
    return 1;
  }
  if (sshnpd_normalize_atsign("@alice", out, sizeof(out)) != 0 || strcmp(out, "@alice") != 0) {
    return 1;
  }
  if (sshnpd_normalize_atsign("", out, sizeof(out)) == 0) {
    return 1;
  }
  if (sshnpd_normalize_atsign("@ali:ce", out, sizeof(out)) == 0) {
    return 1;
  }
  if (sshnpd_normalize_atsign("@ali@ce", out, sizeof(out)) == 0) {
    return 1;
  }
  if (sshnpd_normalize_atsign("@", out, sizeof(out)) == 0) {
    return 1;
  }
  return 0;
}

int policy_manager_denies_everyone_test() {
  sshnpd_params params;
  apply_default_values_to_sshnpd_params(&params);
  char *managers[] = {"@alice"};
  params.manager_list = managers;
  params.manager_list_len = 1;
  params.policy = "@policy";

  // Managers are approved without a policy check even when a policy service
  // is configured; anyone else is not a manager (the daemon then refers them
  // to the policy service instead).
  if (!is_manager_atsign(&params, "@alice")) {
    return 1;
  }
  if (is_manager_atsign(&params, "@eve")) {
    return 1;
  }
  return 0;
}

// The atProtocol treats atSigns as case-insensitive and ignores dots
// (AtUtils.fixAtSign in at_utils): @Alice, @a.lice and @alice are the same
// identity. The sender must be canonicalized before comparison so that every
// spelling of an authorized atSign is accepted.
int sender_canonical_equivalence_test() {
  sshnpd_params params;
  apply_default_values_to_sshnpd_params(&params);
  char *managers[] = {"@alice", "@colinconstable"};
  params.manager_list = managers;
  params.manager_list_len = 2;

  if (!is_manager_atsign(&params, "@Alice")) {
    return 1;
  }
  if (!is_manager_atsign(&params, "@a.lice")) {
    return 1;
  }
  if (!is_manager_atsign(&params, "@colin.constable")) {
    return 1;
  }
  if (!is_manager_atsign(&params, "@Colin.Constable")) {
    return 1;
  }
  return 0;
}

// A requesting atSign must be a perfect (canonical) match for a -m entry:
// prefixes, suffixes and lookalikes of an authorized atSign are all denied.
int sender_near_miss_denied_test() {
  sshnpd_params params;
  apply_default_values_to_sshnpd_params(&params);
  char *managers[] = {"@alice"};
  params.manager_list = managers;
  params.manager_list_len = 1;

  const char *near_misses[] = {"@alice1", "@alic", "@aalice", "@malice", "@lice", "alice1"};
  for (size_t i = 0; i < sizeof(near_misses) / sizeof(near_misses[0]); i++) {
    if (is_manager_atsign(&params, near_misses[i])) {
      printf("  near miss \"%s\" was wrongly authorized\n", near_misses[i]);
      return 1;
    }
  }
  return 0;
}

// Anything that is not a valid atSign must fail closed, never match.
int sender_malformed_fails_closed_test() {
  sshnpd_params params;
  apply_default_values_to_sshnpd_params(&params);
  char *managers[] = {"@alice"};
  params.manager_list = managers;
  params.manager_list_len = 1;

  // 60 x 'a' exceeds SSHNPD_ATSIGN_MAX_LEN (55)
  char too_long[63];
  too_long[0] = '@';
  memset(too_long + 1, 'a', 60);
  too_long[61] = '\0';

  const char *malformed[] = {"@ali@ce", "@ali:ce", "@ali ce", "@alice,", "@alice\n", "@", "@..", too_long};
  for (size_t i = 0; i < sizeof(malformed) / sizeof(malformed[0]); i++) {
    if (is_manager_atsign(&params, malformed[i])) {
      printf("  malformed sender at index %zu was wrongly authorized\n", i);
      return 1;
    }
  }
  return 0;
}
