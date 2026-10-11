#define _POSIX_C_SOURCE 200809L
#include "sshnpd/policy_limits.h"
#include <atlogger/atlogger.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define LOGGER_TAG "sshnpd - policy limits"

int64_t policy_now_millis(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (int64_t)ts.tv_sec * 1000 + ts.tv_nsec / 1000000;
}

static int copy_decision(sshnpd_policy_decision *dst, const sshnpd_policy_decision *src) {
  memset(dst, 0, sizeof(*dst));
  dst->authorized = src->authorized;
  if (src->permit_open_len == 0) {
    return 0;
  }
  dst->permit_open = calloc(src->permit_open_len, sizeof(char *));
  if (dst->permit_open == NULL) {
    return 1;
  }
  for (size_t i = 0; i < src->permit_open_len; i++) {
    dst->permit_open[i] = strdup(src->permit_open[i]);
    if (dst->permit_open[i] == NULL) {
      dst->permit_open_len = i;
      policy_decision_free(dst);
      return 1;
    }
  }
  dst->permit_open_len = src->permit_open_len;
  return 0;
}

int policy_cache_init(policy_cache *cache, size_t size) {
  memset(cache, 0, sizeof(*cache));
  if (size > POLICY_CACHE_MAX_SIZE) {
    return 1;
  }
  if (size == 0) {
    return 0;
  }
  cache->entries = calloc(size, sizeof(policy_cache_entry));
  if (cache->entries == NULL) {
    return 1;
  }
  cache->size = size;
  return 0;
}

void policy_cache_free(policy_cache *cache) {
  for (size_t i = 0; i < cache->size; i++) {
    policy_decision_free(&cache->entries[i].decision);
  }
  free(cache->entries);
  memset(cache, 0, sizeof(*cache));
}

bool policy_cache_lookup(policy_cache *cache, const char *atsign, int64_t now_ms, sshnpd_policy_decision *decision) {
  char normalized[SSHNPD_ATSIGN_BUFFER_LEN];
  if (sshnpd_normalize_atsign(atsign, normalized, sizeof(normalized)) != 0) {
    return false;
  }
  for (size_t i = 0; i < cache->size; i++) {
    policy_cache_entry *entry = &cache->entries[i];
    if (!entry->used || strcmp(entry->atsign, normalized) != 0) {
      continue;
    }
    if (now_ms - entry->checked_at_ms >= POLICY_CACHE_TTL_MS) {
      return false;
    }
    return copy_decision(decision, &entry->decision) == 0;
  }
  return false;
}

int policy_cache_store(policy_cache *cache, const char *atsign, const sshnpd_policy_decision *decision,
                       int64_t now_ms) {
  if (cache->size == 0) {
    return 0;
  }
  char normalized[SSHNPD_ATSIGN_BUFFER_LEN];
  if (sshnpd_normalize_atsign(atsign, normalized, sizeof(normalized)) != 0) {
    return 1;
  }
  policy_cache_entry *slot = NULL;
  for (size_t i = 0; i < cache->size && slot == NULL; i++) {
    if (cache->entries[i].used && strcmp(cache->entries[i].atsign, normalized) == 0) {
      slot = &cache->entries[i];
    }
  }
  for (size_t i = 0; i < cache->size && slot == NULL; i++) {
    if (!cache->entries[i].used) {
      slot = &cache->entries[i];
    }
  }
  if (slot == NULL) {
    slot = &cache->entries[0];
    for (size_t i = 1; i < cache->size; i++) {
      if (cache->entries[i].checked_at_ms < slot->checked_at_ms) {
        slot = &cache->entries[i];
      }
    }
  }
  policy_decision_free(&slot->decision);
  slot->used = false;
  if (copy_decision(&slot->decision, decision) != 0) {
    return 1;
  }
  strcpy(slot->atsign, normalized);
  slot->checked_at_ms = now_ms;
  slot->used = true;
  return 0;
}

void policy_throttle_init(policy_throttle *throttle) { memset(throttle, 0, sizeof(*throttle)); }

bool policy_throttle_allows(policy_throttle *throttle, const char *atsign, int kind, int64_t now_ms) {
  char normalized[SSHNPD_ATSIGN_BUFFER_LEN];
  if (sshnpd_normalize_atsign(atsign, normalized, sizeof(normalized)) != 0) {
    return false;
  }
  policy_throttle_slot *slot = NULL;
  for (size_t i = 0; i < POLICY_THROTTLE_SLOTS && slot == NULL; i++) {
    if (throttle->slots[i].used && throttle->slots[i].kind == kind &&
        strcmp(throttle->slots[i].atsign, normalized) == 0) {
      slot = &throttle->slots[i];
    }
  }
  if (slot != NULL && now_ms - slot->checked_at_ms < POLICY_THROTTLE_MS) {
    return false;
  }
  for (size_t i = 0; i < POLICY_THROTTLE_SLOTS && slot == NULL; i++) {
    if (!throttle->slots[i].used) {
      slot = &throttle->slots[i];
    }
  }
  if (slot == NULL) {
    slot = &throttle->slots[0];
    for (size_t i = 1; i < POLICY_THROTTLE_SLOTS; i++) {
      if (throttle->slots[i].checked_at_ms < slot->checked_at_ms) {
        slot = &throttle->slots[i];
      }
    }
  }
  strcpy(slot->atsign, normalized);
  slot->kind = kind;
  slot->checked_at_ms = now_ms;
  slot->used = true;
  return true;
}

policy_gate_result policy_gate(policy_cache *cache, policy_throttle *throttle, const char *client_atsign, int kind,
                               int64_t (*now_ms)(void), policy_check_fn check, void *check_ctx,
                               sshnpd_policy_decision *decision) {
  if (!policy_cache_lookup(cache, client_atsign, now_ms(), decision)) {
    if (!policy_throttle_allows(throttle, client_atsign, kind, now_ms())) {
      return POLICY_GATE_DROP;
    }
    if (check(check_ctx, client_atsign, decision) != 0) {
      return POLICY_GATE_DENY;
    }
    if (policy_cache_store(cache, client_atsign, decision, now_ms()) != 0) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_WARN, "Failed to cache the policy decision for %s\n",
                   client_atsign);
    }
  }
  return decision->authorized ? POLICY_GATE_ALLOW : POLICY_GATE_DENY;
}

int64_t policy_wait_deadline(int64_t started_ms, int64_t last_progress_ms) {
  int64_t deadline = last_progress_ms + POLICY_WAIT_MS;
  int64_t cap = started_ms + POLICY_WAIT_CAP_MS;
  return deadline < cap ? deadline : cap;
}
