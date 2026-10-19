// Given a daemon in policy mode, with policy service @policy and authorised
// client @alice: its decision cache, sender throttle, policy-wait cap,
// cache-size option and the gate that combines them
#include <sshnpd/params.h>
#include <sshnpd/policy_limits.h>
#include <sshnpd/sshnpd.h>
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

static sshnpd_policy_decision decision(bool authorized, const char *permit_open) {
  sshnpd_policy_decision d;
  memset(&d, 0, sizeof(d));
  d.authorized = authorized;
  if (permit_open != NULL) {
    d.permit_open = calloc(1, sizeof(char *));
    d.permit_open[0] = strdup(permit_open);
    d.permit_open_len = 1;
  }
  return d;
}

static void test_reuse_within_ttl(void) {
  policy_cache cache;
  policy_cache_init(&cache, POLICY_CACHE_DEFAULT_SIZE);
  sshnpd_policy_decision allowed = decision(true, "localhost:22");
  policy_cache_store(&cache, "@alice", &allowed, 1000);

  sshnpd_policy_decision got;
  memset(&got, 0, sizeof(got));
  bool hit = policy_cache_lookup(&cache, "@alice", 1000 + POLICY_CACHE_TTL_MS - 1, &got);
  check(hit && got.authorized && got.permit_open_len == 1 && strcmp(got.permit_open[0], "localhost:22") == 0,
        "when @alice sends another request within 15 seconds of that check, then the daemon reuses the decision");
  policy_decision_free(&got);
  policy_decision_free(&allowed);
  policy_cache_free(&cache);
}

static void test_denial_reused(void) {
  policy_cache cache;
  policy_cache_init(&cache, POLICY_CACHE_DEFAULT_SIZE);
  sshnpd_policy_decision denied = decision(false, NULL);
  policy_cache_store(&cache, "@carol", &denied, 1000);

  sshnpd_policy_decision got;
  memset(&got, 0, sizeof(got));
  bool hit = policy_cache_lookup(&cache, "@carol", 1000 + POLICY_CACHE_TTL_MS - 1, &got);
  check(hit && !got.authorized,
        "when @carol sends another request within 15 seconds of a check that denied her, then the daemon denies it "
        "without asking again");
  policy_decision_free(&got);
  policy_cache_free(&cache);
}

static void test_asks_again_after_ttl(void) {
  policy_cache cache;
  policy_cache_init(&cache, POLICY_CACHE_DEFAULT_SIZE);
  sshnpd_policy_decision allowed = decision(true, "localhost:22");
  policy_cache_store(&cache, "@alice", &allowed, 1000);

  sshnpd_policy_decision got;
  memset(&got, 0, sizeof(got));
  check(!policy_cache_lookup(&cache, "@alice", 1000 + POLICY_CACHE_TTL_MS, &got),
        "when @alice sends a request 15 seconds or more after the check, then the daemon asks @policy again");
  policy_decision_free(&got);
  policy_decision_free(&allowed);
  policy_cache_free(&cache);
}

static void test_throttle(void) {
  policy_throttle throttle;
  policy_throttle_init(&throttle);
  bool first = policy_throttle_allows(&throttle, "@alice", NK_NPT_REQUEST, 1000);
  bool soon = policy_throttle_allows(&throttle, "@alice", NK_NPT_REQUEST, 1000 + POLICY_THROTTLE_MS - 1);
  bool other = policy_throttle_allows(&throttle, "@bob", NK_NPT_REQUEST, 1000 + POLICY_THROTTLE_MS - 1);
  bool later = policy_throttle_allows(&throttle, "@alice", NK_NPT_REQUEST, 1000 + POLICY_THROTTLE_MS);
  check(first && !soon && other && later,
        "when one sender's requests of one kind come less than 2 seconds apart, then the daemon checks at most one "
        "of them in any 2 seconds");
}

static int64_t fake_now_ms = 0;

static int64_t fake_clock(void) { return fake_now_ms; }

// The policy service as the gate sees it: counts the checks it is asked for,
// and either can't be asked (result non-zero) or decides as told
typedef struct {
  int calls;
  int result;
  bool authorized;
} fake_policy;

static int fake_check(void *ctx, const char *client_atsign, sshnpd_policy_decision *decision) {
  (void)client_atsign;
  fake_policy *policy = ctx;
  policy->calls++;
  memset(decision, 0, sizeof(*decision));
  decision->authorized = policy->result == 0 && policy->authorized;
  return policy->result;
}

static policy_gate_result gate_at(policy_cache *cache, policy_throttle *throttle, fake_policy *policy, int kind,
                                  int64_t now_ms) {
  fake_now_ms = now_ms;
  sshnpd_policy_decision decision;
  memset(&decision, 0, sizeof(decision));
  policy_gate_result result =
      policy_gate(cache, throttle, "@alice", kind, fake_clock, fake_check, policy, &decision);
  policy_decision_free(&decision);
  return result;
}

static void test_gate_checks_each_kind_with_no_cache(void) {
  policy_cache cache;
  policy_cache_init(&cache, 0);
  policy_throttle throttle;
  policy_throttle_init(&throttle);
  fake_policy policy = {.result = 0, .authorized = true};
  policy_gate_result ping = gate_at(&cache, &throttle, &policy, NK_PING, 1000);
  policy_gate_result request = gate_at(&cache, &throttle, &policy, NK_NPT_REQUEST, 2000);
  check(ping == POLICY_GATE_ALLOW && request == POLICY_GATE_ALLOW && policy.calls == 2,
        "given --policy-cache-size 0, when @alice sends ping and then npt_request 1 second later, then each is "
        "checked with @policy and the npt_request is served");
  policy_cache_free(&cache);
}

static void test_gate_drops_a_repeat_of_one_kind(void) {
  policy_cache cache;
  policy_cache_init(&cache, 0);
  policy_throttle throttle;
  policy_throttle_init(&throttle);
  fake_policy policy = {.result = 0, .authorized = true};
  gate_at(&cache, &throttle, &policy, NK_NPT_REQUEST, 1000);
  policy_gate_result second = gate_at(&cache, &throttle, &policy, NK_NPT_REQUEST, 2000);
  check(second == POLICY_GATE_DROP && policy.calls == 1,
        "given --policy-cache-size 0, when @alice sends two npt_requests 1 second apart, then the second is dropped "
        "without a check");
  policy_cache_free(&cache);
}

static void test_gate_keeps_no_decision_from_a_failed_send(void) {
  policy_cache cache;
  policy_cache_init(&cache, POLICY_CACHE_DEFAULT_SIZE);
  policy_throttle throttle;
  policy_throttle_init(&throttle);
  fake_policy policy = {.result = 1};
  policy_gate_result first = gate_at(&cache, &throttle, &policy, NK_NPT_REQUEST, 1000);
  policy.result = 0;
  policy.authorized = true;
  policy_gate_result next = gate_at(&cache, &throttle, &policy, NK_NPT_REQUEST, 1000 + POLICY_THROTTLE_MS);
  check(first == POLICY_GATE_DENY && next == POLICY_GATE_ALLOW && policy.calls == 2,
        "when sending @alice's check to @policy fails, then her request is denied, and her next request asks "
        "@policy again");
  policy_cache_free(&cache);
}

static void test_gate_reuses_an_unanswered_check(void) {
  policy_cache cache;
  policy_cache_init(&cache, POLICY_CACHE_DEFAULT_SIZE);
  policy_throttle throttle;
  policy_throttle_init(&throttle);
  fake_policy policy = {.result = 0, .authorized = false};
  policy_gate_result first = gate_at(&cache, &throttle, &policy, NK_NPT_REQUEST, 1000);
  policy_gate_result next = gate_at(&cache, &throttle, &policy, NK_NPT_REQUEST, 1000 + POLICY_THROTTLE_MS);
  check(first == POLICY_GATE_DENY && next == POLICY_GATE_DENY && policy.calls == 1,
        "when @policy doesn't answer @alice's check within the wait, then her request is denied, and her requests "
        "within 15 seconds of asking are denied without asking again");
  policy_cache_free(&cache);
}

static void test_wait_cap(void) {
  check(policy_wait_deadline(0, 0) == POLICY_WAIT_MS, "a check with no progress stops waiting after 10 seconds");
  check(policy_wait_deadline(0, 8000) == 8000 + POLICY_WAIT_MS, "an ack moves the deadline on by 10 seconds");
  check(policy_wait_deadline(0, 25000) == POLICY_WAIT_CAP_MS,
        "when @policy keeps acknowledging a check without deciding, then the daemon denies it no later than 30 "
        "seconds after first asking");
}

static void test_oldest_dropped_when_full(void) {
  policy_cache cache;
  policy_cache_init(&cache, 2);
  sshnpd_policy_decision allowed = decision(true, "localhost:22");
  policy_cache_store(&cache, "@one", &allowed, 1000);
  policy_cache_store(&cache, "@two", &allowed, 2000);
  policy_cache_store(&cache, "@three", &allowed, 3000);

  sshnpd_policy_decision got;
  memset(&got, 0, sizeof(got));
  bool oldest = policy_cache_lookup(&cache, "@one", 4000, &got);
  policy_decision_free(&got);
  bool newest = policy_cache_lookup(&cache, "@three", 4000, &got);
  policy_decision_free(&got);
  check(!oldest && newest,
        "when more clients are checked within 15 seconds than the cache holds, then the oldest decision is dropped");
  policy_decision_free(&allowed);
  policy_cache_free(&cache);
}

static void test_size_zero(void) {
  policy_cache cache;
  check(policy_cache_init(&cache, 0) == 0, "a cache of size 0 can be set up");
  sshnpd_policy_decision allowed = decision(true, "localhost:22");
  policy_cache_store(&cache, "@alice", &allowed, 1000);
  sshnpd_policy_decision got;
  memset(&got, 0, sizeof(got));
  check(!policy_cache_lookup(&cache, "@alice", 1001, &got),
        "when the operator sets the cache size to 0, then every request is checked");
  policy_decision_free(&allowed);
  policy_cache_free(&cache);
}

static int parse_with_cache_size(const char *size, sshnpd_params *params) {
  const char *argv[] = {"sshnpd", "-a", "@device", "-p", "@policy", "--policy-cache-size", size};
  apply_default_values_to_sshnpd_params(params);
  return parse_sshnpd_params(params, size == NULL ? 5 : 7, argv);
}

static void test_cache_size_option(void) {
  sshnpd_params params;
  check(parse_with_cache_size(NULL, &params) == 0 && params.policy_cache_size == POLICY_CACHE_DEFAULT_SIZE,
        "the cache holds 8 decisions by default");
  check(parse_with_cache_size("64", &params) == 0 && params.policy_cache_size == POLICY_CACHE_MAX_SIZE,
        "the operator can set the cache size up to the cap");
  check(parse_with_cache_size("0", &params) == 0 && params.policy_cache_size == 0,
        "the operator can set the cache size to 0");
  check(parse_with_cache_size("65", &params) != 0,
        "when the operator sets a cache size above the cap, then the daemon refuses to start");
  policy_cache cache;
  check(policy_cache_init(&cache, POLICY_CACHE_MAX_SIZE + 1) != 0, "a cache above the cap can't be set up");
}

int main(void) {
  test_reuse_within_ttl();
  test_denial_reused();
  test_asks_again_after_ttl();
  test_throttle();
  test_gate_checks_each_kind_with_no_cache();
  test_gate_drops_a_repeat_of_one_kind();
  test_gate_keeps_no_decision_from_a_failed_send();
  test_gate_reuses_an_unanswered_check();
  test_wait_cap();
  test_oldest_dropped_when_full();
  test_size_zero();
  test_cache_size_option();
  if (failures > 0) {
    printf("%d check(s) failed\n", failures);
    return 1;
  }
  return 0;
}
