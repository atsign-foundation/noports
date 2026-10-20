#include "sshnpd/handler_commons.h"
#include <atclient/json.h>
#include <stdio.h>
#include <string.h>

int session_id_test();
int npt_payload_test();

int main() {
  int ret = 0;

  if (session_id_test()) {
    printf("is_valid_session_id test failed\n");
    ret++;
  }
  if (npt_payload_test()) {
    printf("verify_payload_contents sessionId test failed\n");
    ret++;
  }

  printf("Tests failed: %d\n", ret);
  return ret;
}

int session_id_test() {
  const char *valid[] = {
      "9e13521b-9ad0-4237-9104-5824e6e6c483",
      "9E13521B-9AD0-4237-9104-5824E6E6C483",
  };
  const char *invalid[] = {
      "",
      "not-a-uuid",
      "9e13521b9ad0423791045824e6e6c483",
      "9e13521b-9ad0-4237-9104-5824e6e6c48",
      "9e13521b-9ad0-4237-9104-5824e6e6c4833",
      "9e13521b-9ad0-4237-9104_5824e6e6c483",
      "9e13521g-9ad0-4237-9104-5824e6e6c483",
      "9e13521b-9ad0-4237-9104-5824e6e6\r\n83",
      "x\r\nupdate:public:k@device v\r\n",
  };
  for (size_t i = 0; i < sizeof(valid) / sizeof(valid[0]); i++) {
    if (!is_valid_session_id(valid[i])) {
      printf("refused valid session id %s\n", valid[i]);
      return 1;
    }
  }
  for (size_t i = 0; i < sizeof(invalid) / sizeof(invalid[0]); i++) {
    if (is_valid_session_id(invalid[i])) {
      printf("accepted invalid session id %zu\n", i);
      return 1;
    }
  }
  if (is_valid_session_id(NULL)) {
    printf("accepted a NULL session id\n");
    return 1;
  }
  return 0;
}

// An npt payload that verify_payload_contents accepts, but for its sessionId.
static int npt_payload_with(const char *session_id) {
  cJSON *payload = cJSON_CreateObject();
  cJSON_AddStringToObject(payload, "sessionId", session_id);
  cJSON_AddStringToObject(payload, "rvdHost", "127.0.0.1");
  cJSON_AddNumberToObject(payload, "rvdPort", 1234);
  cJSON_AddStringToObject(payload, "requestedHost", "localhost");
  cJSON_AddNumberToObject(payload, "requestedPort", 22);
  int res = verify_payload_contents(payload, payload_type_npt);
  cJSON_Delete(payload);
  return res;
}

int npt_payload_test() {
  if (npt_payload_with("9e13521b-9ad0-4237-9104-5824e6e6c483") != 0) {
    printf("refused an npt payload with a UUID sessionId\n");
    return 1;
  }
  if (npt_payload_with("9e13521b-9ad0-4237-9104-5824e6e6\r\n83") == 0) {
    printf("accepted an npt payload whose sessionId holds a line break\n");
    return 1;
  }
  return 0;
}
