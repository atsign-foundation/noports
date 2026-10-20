#ifndef SSHNPD_POLICY_LIMITS_H
#define SSHNPD_POLICY_LIMITS_H

#include <sshnpd/authorization.h>
#include <sshnpd/policy.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

// How long a policy decision is reused for its client
#define POLICY_CACHE_TTL_MS 15000

// How many decisions are held by default, and at most
#define POLICY_CACHE_DEFAULT_SIZE 8
#define POLICY_CACHE_MAX_SIZE 64

// How many senders' last checks are remembered, and how far apart one
// sender's checks must be
#define POLICY_THROTTLE_SLOTS 8
#define POLICY_THROTTLE_MS 2000

// How long one policy check may wait without progress, and in all
#define POLICY_WAIT_MS 10000
#define POLICY_WAIT_CAP_MS 30000

typedef struct {
  bool used;
  char atsign[SSHNPD_ATSIGN_BUFFER_LEN];
  int64_t checked_at_ms;
  sshnpd_policy_decision decision;
} policy_cache_entry;

typedef struct {
  policy_cache_entry *entries;
  size_t size;
} policy_cache;

typedef struct {
  bool used;
  char atsign[SSHNPD_ATSIGN_BUFFER_LEN];
  int kind;
  int64_t checked_at_ms;
} policy_throttle_slot;

typedef struct {
  policy_throttle_slot slots[POLICY_THROTTLE_SLOTS];
} policy_throttle;

/**
 * @brief Milliseconds on a clock that wall-clock changes don't move, as the
 * policy limits measure time.
 */
int64_t policy_now_millis(void);

/**
 * @brief Prepare a cache holding up to size decisions; a size of 0 holds
 * none, so every request is checked.
 *
 * @return int 0 on success, non-zero if size is above POLICY_CACHE_MAX_SIZE
 * or the entries can't be allocated
 */
int policy_cache_init(policy_cache *cache, size_t size);

/**
 * @brief Free every decision the cache holds, and its entries.
 */
void policy_cache_free(policy_cache *cache);

/**
 * @brief Copy into decision the decision for atsign checked less than
 * POLICY_CACHE_TTL_MS before now_ms, if the cache holds one.
 *
 * @return bool true when the cache held a decision; the copy is the caller's
 * to free with policy_decision_free
 */
bool policy_cache_lookup(policy_cache *cache, const char *atsign, int64_t now_ms, sshnpd_policy_decision *decision);

/**
 * @brief Hold a copy of decision for atsign, checked at now_ms, replacing any
 * decision already held for atsign, or else the oldest when the cache is
 * full. Does nothing for a cache of size 0.
 *
 * @return int 0 on success, non-zero if the copy can't be made
 */
int policy_cache_store(policy_cache *cache, const char *atsign, const sshnpd_policy_decision *decision,
                       int64_t now_ms);

/**
 * @brief Forget every sender.
 */
void policy_throttle_init(policy_throttle *throttle);

/**
 * @brief Whether atsign may be checked at now_ms for a request of the given
 * kind, its last check for that kind being at least POLICY_THROTTLE_MS
 * earlier; when it may, records now_ms as that check, replacing the one made
 * longest ago when the table is full.
 */
bool policy_throttle_allows(policy_throttle *throttle, const char *atsign, int kind, int64_t now_ms);

/**
 * @brief Asks the policy service whether client_atsign may be served, filling
 * decision; returns 0 once it decided or the wait ran out (a denial), and
 * non-zero when the question couldn't be sent.
 */
typedef int (*policy_check_fn)(void *ctx, const char *client_atsign, sshnpd_policy_decision *decision);

typedef enum {
  POLICY_GATE_ALLOW,
  POLICY_GATE_DENY,
  POLICY_GATE_DROP,
} policy_gate_result;

/**
 * @brief Decides a request of the given kind from client_atsign: from a cached
 * decision when there is one, else by a check that the throttle allows, whose
 * outcome is cached unless the question couldn't be sent. DROP means the
 * throttle refused the check. decision holds what was decided, for the caller
 * to free with policy_decision_free.
 */
policy_gate_result policy_gate(policy_cache *cache, policy_throttle *throttle, const char *client_atsign, int kind,
                               int64_t (*now_ms)(void), policy_check_fn check, void *check_ctx,
                               sshnpd_policy_decision *decision);

/**
 * @brief When a policy check started at started_ms, whose last progress was
 * at last_progress_ms, stops waiting: POLICY_WAIT_MS after its last
 * progress, but never later than POLICY_WAIT_CAP_MS after it started.
 */
int64_t policy_wait_deadline(int64_t started_ms, int64_t last_progress_ms);

#endif
