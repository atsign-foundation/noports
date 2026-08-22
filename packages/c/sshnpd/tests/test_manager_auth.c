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

  printf("Tests failed: %d\n", ret);
  return ret;
}

int single_manager_authorized_test() {
  sshnpd_params params;
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
  params.manager_list = NULL;
  params.manager_list_len = 0;

  if (is_manager_atsign(&params, "@anyone")) {
    return 1;
  }
  return 0;
}
