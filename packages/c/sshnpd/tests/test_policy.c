// Tests for the policy service response parsing and permitOpen matching
#include <sshnpd/policy.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int failures = 0;

static void check(bool ok, const char *what) {
  if (!ok) {
    printf("FAIL: %s\n", what);
    failures++;
  } else {
    printf("ok: %s\n", what);
  }
}

static void test_parse_success(void) {
  sshnpd_policy_decision decision;
  memset(&decision, 0, sizeof(decision));
  char resp_type[16] = "";

  const char *json = "{\"reqId\":1756215032123456,\"respType\":\"success\","
                     "\"payload\":{\"authorized\":true,\"message\":null,"
                     "\"permitOpen\":[\"localhost:22\",\"*:3389\"]},\"message\":null}";
  check(policy_parse_response_value(json, 1756215032123456LL, &decision, resp_type, sizeof(resp_type)) == 0,
        "success response parses");
  check(strcmp(resp_type, "success") == 0, "respType is success");
  check(decision.authorized, "authorized is true");
  check(decision.permit_open_len == 2, "two permitOpen entries");
  check(decision.permit_open_len == 2 && strcmp(decision.permit_open[0], "localhost:22") == 0 &&
            strcmp(decision.permit_open[1], "*:3389") == 0,
        "permitOpen entries round trip");
  policy_decision_free(&decision);
  // double free must be safe
  policy_decision_free(&decision);
}

static void test_parse_req_id_mismatch(void) {
  sshnpd_policy_decision decision;
  memset(&decision, 0, sizeof(decision));
  char resp_type[16] = "";
  const char *json = "{\"reqId\":42,\"respType\":\"success\","
                     "\"payload\":{\"authorized\":true,\"permitOpen\":[\"*:*\"]}}";
  check(policy_parse_response_value(json, 43, &decision, resp_type, sizeof(resp_type)) != 0,
        "mismatched reqId is rejected");
  check(!decision.authorized, "mismatched reqId does not authorize");
  policy_decision_free(&decision);
}

static void test_parse_nack_and_garbage(void) {
  sshnpd_policy_decision decision;
  memset(&decision, 0, sizeof(decision));
  char resp_type[16] = "";

  const char *nack = "{\"reqId\":7,\"respType\":\"nack\",\"payload\":{},\"message\":\"no\"}";
  check(policy_parse_response_value(nack, 7, &decision, resp_type, sizeof(resp_type)) == 0 && !decision.authorized &&
            strcmp(resp_type, "nack") == 0,
        "nack parses as deny");

  check(policy_parse_response_value("not json at all", 7, &decision, resp_type, sizeof(resp_type)) != 0,
        "garbage is rejected");
  check(policy_parse_response_value("{\"respType\":\"success\"}", 7, &decision, resp_type, sizeof(resp_type)) != 0,
        "missing reqId is rejected");

  const char *ack = "{\"reqId\":7,\"respType\":\"ack\",\"payload\":{}}";
  check(policy_parse_response_value(ack, 7, &decision, resp_type, sizeof(resp_type)) == 0 &&
            strcmp(resp_type, "ack") == 0 && !decision.authorized,
        "ack parses without authorizing");
  policy_decision_free(&decision);
}

static void test_permits_open(void) {
  sshnpd_policy_decision decision;
  memset(&decision, 0, sizeof(decision));

  check(!policy_permits_open(&decision, "localhost", 22), "empty list permits nothing");

  char *entries[] = {"localhost:22", "*:3389", "webserver:*", "bad-entry-no-colon", "10.0.0.1:8080"};
  decision.permit_open = calloc(5, sizeof(char *));
  for (int i = 0; i < 5; i++) {
    decision.permit_open[i] = strdup(entries[i]);
  }
  decision.permit_open_len = 5;
  decision.authorized = true;

  check(policy_permits_open(&decision, "localhost", 22), "exact host:port match");
  check(!policy_permits_open(&decision, "localhost", 23), "port mismatch denied");
  check(policy_permits_open(&decision, "anyhost", 3389), "wildcard host matches");
  check(policy_permits_open(&decision, "webserver", 443), "wildcard port matches");
  check(!policy_permits_open(&decision, "webserve", 443), "host prefix does not match");
  check(!policy_permits_open(&decision, "webserverx", 443), "host with suffix does not match");
  check(policy_permits_open(&decision, "10.0.0.1", 8080), "ip entry matches");
  check(!policy_permits_open(&decision, "bad-entry-no-colon", 0), "malformed entry is skipped");

  policy_decision_free(&decision);

  // *:* permits everything
  decision.permit_open = calloc(1, sizeof(char *));
  decision.permit_open[0] = strdup("*:*");
  decision.permit_open_len = 1;
  check(policy_permits_open(&decision, "anything", 12345), "*:* permits everything");
  policy_decision_free(&decision);
}

int main() {
  test_parse_success();
  test_parse_req_id_mismatch();
  test_parse_nack_and_garbage();
  test_permits_open();

  if (failures > 0) {
    printf("%d failures\n", failures);
    return 1;
  }
  printf("all passed\n");
  return 0;
}
