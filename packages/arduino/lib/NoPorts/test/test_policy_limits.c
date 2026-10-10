// Given a daemon in policy mode, with policy service @policy and authorised
// client @alice: its decision cache, sender cooldown and policy-wait cap
#include "noports/noports_policy_limits.h"
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

static noports_policy_decision decision(bool authorized, const char *permit_open) {
  noports_policy_decision d;
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
  noports_policy_cache cache;
  noports_policy_cache_init(&cache, NOPORTS_POLICY_CACHE_DEFAULT_SIZE);
  noports_policy_decision allowed = decision(true, "localhost:22");
  noports_policy_cache_store(&cache, "@alice", &allowed, 1000);

  noports_policy_decision got;
  memset(&got, 0, sizeof(got));
  bool hit = noports_policy_cache_lookup(&cache, "@alice", 1000 + NOPORTS_POLICY_CACHE_TTL_MS - 1, &got);
  check(hit && got.authorized && got.permit_open_len == 1 && strcmp(got.permit_open[0], "localhost:22") == 0,
        "when @alice sends another request within 15 seconds of that check, then the daemon reuses the decision");
  noports_policy_decision_free(&got);
  noports_policy_decision_free(&allowed);
  noports_policy_cache_free(&cache);
}

static void test_denial_reused(void) {
  noports_policy_cache cache;
  noports_policy_cache_init(&cache, NOPORTS_POLICY_CACHE_DEFAULT_SIZE);
  noports_policy_decision denied = decision(false, NULL);
  noports_policy_cache_store(&cache, "@carol", &denied, 1000);

  noports_policy_decision got;
  memset(&got, 0, sizeof(got));
  bool hit = noports_policy_cache_lookup(&cache, "@carol", 1000 + NOPORTS_POLICY_CACHE_TTL_MS - 1, &got);
  check(hit && !got.authorized,
        "when @carol sends another request within 15 seconds of a check that denied her, then the daemon denies it "
        "without asking again");
  noports_policy_decision_free(&got);
  noports_policy_cache_free(&cache);
}

static void test_asks_again_after_ttl(void) {
  noports_policy_cache cache;
  noports_policy_cache_init(&cache, NOPORTS_POLICY_CACHE_DEFAULT_SIZE);
  noports_policy_decision allowed = decision(true, "localhost:22");
  noports_policy_cache_store(&cache, "@alice", &allowed, 1000);

  noports_policy_decision got;
  memset(&got, 0, sizeof(got));
  check(!noports_policy_cache_lookup(&cache, "@alice", 1000 + NOPORTS_POLICY_CACHE_TTL_MS, &got),
        "when @alice sends a request 15 seconds or more after the check, then the daemon asks @policy again");
  noports_policy_decision_free(&got);
  noports_policy_decision_free(&allowed);
  noports_policy_cache_free(&cache);
}

static void test_cooldown(void) {
  noports_policy_cooldown cooldown;
  noports_policy_cooldown_init(&cooldown);
  bool first = noports_policy_cooldown_allows(&cooldown, "@alice", NOPORTS_POLICY_CHECK_NPT, 1000);
  bool soon = noports_policy_cooldown_allows(&cooldown, "@alice", NOPORTS_POLICY_CHECK_NPT,
                                             1000 + NOPORTS_POLICY_COOLDOWN_MS - 1);
  bool other = noports_policy_cooldown_allows(&cooldown, "@bob", NOPORTS_POLICY_CHECK_NPT,
                                              1000 + NOPORTS_POLICY_COOLDOWN_MS - 1);
  bool later = noports_policy_cooldown_allows(&cooldown, "@alice", NOPORTS_POLICY_CHECK_NPT,
                                              1000 + NOPORTS_POLICY_COOLDOWN_MS);
  check(first && !soon && other && later,
        "when one sender's requests come less than 2 seconds apart, then the daemon checks at most one of them in "
        "any 2 seconds and drops the rest");

  noports_policy_cooldown_init(&cooldown);
  bool ping = noports_policy_cooldown_allows(&cooldown, "@alice", NOPORTS_POLICY_CHECK_PING, 1000);
  bool npt = noports_policy_cooldown_allows(&cooldown, "@alice", NOPORTS_POLICY_CHECK_NPT, 1001);
  check(ping && npt, "a ping doesn't hold back the session request that follows it");
}

static void test_cooldown_forgets_least_recent(void) {
  noports_policy_cooldown cooldown;
  noports_policy_cooldown_init(&cooldown);
  char atsign[16];
  for (int i = 0; i < NOPORTS_POLICY_COOLDOWN_SLOTS; i++) {
    snprintf(atsign, sizeof(atsign), "@sender%d", i);
    noports_policy_cooldown_allows(&cooldown, atsign, NOPORTS_POLICY_CHECK_NPT, 1000 + i);
  }
  noports_policy_cooldown_allows(&cooldown, "@newcomer", NOPORTS_POLICY_CHECK_NPT, 1500);
  bool oldest = noports_policy_cooldown_allows(&cooldown, "@sender0", NOPORTS_POLICY_CHECK_NPT, 1600);
  bool newest = noports_policy_cooldown_allows(&cooldown, "@sender7", NOPORTS_POLICY_CHECK_NPT, 1600);
  check(oldest && !newest, "when the cooldown table is full, then the sender active longest ago is forgotten");
}

static void test_wait_cap(void) {
  check(!noports_policy_wait_over(0, 0, NOPORTS_POLICY_WAIT_MS) &&
            noports_policy_wait_over(0, 0, NOPORTS_POLICY_WAIT_MS + 1),
        "a check with no progress stops waiting after 10 seconds");
  check(!noports_policy_wait_over(0, 8000, 8000 + NOPORTS_POLICY_WAIT_MS),
        "an ack moves the deadline on by 10 seconds");
  check(noports_policy_wait_over(0, 25000, NOPORTS_POLICY_WAIT_CAP_MS + 1),
        "when @policy keeps acknowledging a check without deciding, then the daemon denies it no later than 30 "
        "seconds after first asking");
}

static void test_oldest_dropped_when_full(void) {
  noports_policy_cache cache;
  noports_policy_cache_init(&cache, 2);
  noports_policy_decision allowed = decision(true, "localhost:22");
  noports_policy_cache_store(&cache, "@one", &allowed, 1000);
  noports_policy_cache_store(&cache, "@two", &allowed, 2000);
  noports_policy_cache_store(&cache, "@three", &allowed, 3000);

  noports_policy_decision got;
  memset(&got, 0, sizeof(got));
  bool oldest = noports_policy_cache_lookup(&cache, "@one", 4000, &got);
  noports_policy_decision_free(&got);
  bool newest = noports_policy_cache_lookup(&cache, "@three", 4000, &got);
  noports_policy_decision_free(&got);
  check(!oldest && newest,
        "when more clients are checked within 15 seconds than the cache holds, then the oldest decision is dropped");
  noports_policy_decision_free(&allowed);
  noports_policy_cache_free(&cache);
}

static void test_size_zero(void) {
  noports_policy_cache cache;
  check(noports_policy_cache_init(&cache, 0) == 0, "a cache of size 0 can be set up");
  noports_policy_decision allowed = decision(true, "localhost:22");
  noports_policy_cache_store(&cache, "@alice", &allowed, 1000);
  noports_policy_decision got;
  memset(&got, 0, sizeof(got));
  check(!noports_policy_cache_lookup(&cache, "@alice", 1001, &got),
        "when the operator sets the cache size to 0, then every request is checked");
  noports_policy_decision_free(&allowed);
  noports_policy_cache_free(&cache);
}

static void test_size_cap(void) {
  noports_policy_cache cache;
  check(noports_policy_cache_init(&cache, NOPORTS_POLICY_CACHE_MAX_SIZE) == 0,
        "the operator can set the cache size up to the cap");
  noports_policy_cache_free(&cache);
  check(noports_policy_cache_init(&cache, NOPORTS_POLICY_CACHE_MAX_SIZE + 1) != 0,
        "when the operator sets a cache size above the cap, then the daemon refuses to start");
}

int main(void) {
  test_reuse_within_ttl();
  test_denial_reused();
  test_asks_again_after_ttl();
  test_cooldown();
  test_cooldown_forgets_least_recent();
  test_wait_cap();
  test_oldest_dropped_when_full();
  test_size_zero();
  test_size_cap();
  if (failures > 0) {
    printf("%d check(s) failed\n", failures);
    return 1;
  }
  return 0;
}
