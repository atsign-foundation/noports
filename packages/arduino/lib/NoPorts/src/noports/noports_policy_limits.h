#ifndef NOPORTS_POLICY_LIMITS_H
#define NOPORTS_POLICY_LIMITS_H

#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// How long a policy decision is reused for its client
#define NOPORTS_POLICY_CACHE_TTL_MS 15000

// How many decisions are held by default, and at most
#define NOPORTS_POLICY_CACHE_DEFAULT_SIZE 8
#define NOPORTS_POLICY_CACHE_MAX_SIZE 64

// How many senders' last checks are remembered, and how far apart one
// sender's checks of the same kind must be
#define NOPORTS_POLICY_COOLDOWN_SLOTS 8
#define NOPORTS_POLICY_COOLDOWN_MS 2000

// How long one policy check may wait without progress, and in all
#define NOPORTS_POLICY_WAIT_MS 10000
#define NOPORTS_POLICY_WAIT_CAP_MS 30000

// Longest atSign, and the buffer holding one in canonical form
#define NOPORTS_ATSIGN_MAX_LEN 55
#define NOPORTS_ATSIGN_BUFFER_LEN (NOPORTS_ATSIGN_MAX_LEN + 2)

typedef struct {
  bool authorized;
  char **permit_open;
  size_t permit_open_len;
} noports_policy_decision;

typedef struct {
  bool used;
  char atsign[NOPORTS_ATSIGN_BUFFER_LEN];
  int64_t checked_at_ms;
  noports_policy_decision decision;
} noports_policy_cache_entry;

typedef struct {
  noports_policy_cache_entry *entries;
  size_t size;
} noports_policy_cache;

typedef enum {
  NOPORTS_POLICY_CHECK_PING = 0,
  NOPORTS_POLICY_CHECK_NPT = 1,
} noports_policy_check_kind;

typedef struct {
  bool used;
  char atsign[NOPORTS_ATSIGN_BUFFER_LEN];
  bool checked[2];
  int64_t checked_at_ms[2];
} noports_policy_cooldown_slot;

typedef struct {
  noports_policy_cooldown_slot slots[NOPORTS_POLICY_COOLDOWN_SLOTS];
} noports_policy_cooldown;

/**
 * @brief Write atsign to out in canonical form: one leading '@', lower case,
 * no dots.
 *
 * @return int 0 on success, non-zero if atsign is empty, holds a character no
 * atSign may hold, or doesn't fit in out_len
 */
int noports_normalize_atsign(const char *atsign, char *out, size_t out_len);

/**
 * @brief Free the permitOpen rules a decision holds.
 */
void noports_policy_decision_free(noports_policy_decision *decision);

/**
 * @brief Prepare a cache holding up to size decisions; a size of 0 holds
 * none, so every request is checked.
 *
 * @return int 0 on success, non-zero if size is above
 * NOPORTS_POLICY_CACHE_MAX_SIZE or the entries can't be allocated
 */
int noports_policy_cache_init(noports_policy_cache *cache, size_t size);

/**
 * @brief Free every decision the cache holds, and its entries.
 */
void noports_policy_cache_free(noports_policy_cache *cache);

/**
 * @brief Copy into decision the decision for atsign checked less than
 * NOPORTS_POLICY_CACHE_TTL_MS before now_ms, if the cache holds one.
 *
 * @return bool true when the cache held a decision; the copy is the caller's
 * to free with noports_policy_decision_free
 */
bool noports_policy_cache_lookup(noports_policy_cache *cache, const char *atsign, int64_t now_ms,
                                 noports_policy_decision *decision);

/**
 * @brief Hold a copy of decision for atsign, checked at now_ms, replacing any
 * decision already held for atsign, or else the oldest when the cache is
 * full. Does nothing for a cache of size 0.
 *
 * @return int 0 on success, non-zero if the copy can't be made
 */
int noports_policy_cache_store(noports_policy_cache *cache, const char *atsign,
                               const noports_policy_decision *decision, int64_t now_ms);

/**
 * @brief Forget every sender.
 */
void noports_policy_cooldown_init(noports_policy_cooldown *cooldown);

/**
 * @brief Whether a check of the given kind for atsign may go ahead at now_ms,
 * its last one being at least NOPORTS_POLICY_COOLDOWN_MS earlier; when it
 * may, records now_ms as its last, replacing the sender active longest ago
 * when the table is full.
 */
bool noports_policy_cooldown_allows(noports_policy_cooldown *cooldown, const char *atsign,
                                    noports_policy_check_kind kind, int64_t now_ms);

/**
 * @brief Whether a policy check started at started_ms, whose last progress was
 * at progress_ms, has waited long enough at now_ms: NOPORTS_POLICY_WAIT_MS
 * after its last progress, or NOPORTS_POLICY_WAIT_CAP_MS after it started.
 */
bool noports_policy_wait_over(int64_t started_ms, int64_t progress_ms, int64_t now_ms);

#ifdef __cplusplus
}
#endif

#endif
