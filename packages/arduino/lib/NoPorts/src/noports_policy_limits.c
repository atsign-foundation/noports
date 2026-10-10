#include "noports/noports_policy_limits.h"
#include <stdlib.h>
#include <string.h>

static const char *const reserved_characters = "!*'`();:&=+$,/?#[]{}";

int noports_normalize_atsign(const char *atsign, char *out, size_t out_len) {
  if (atsign == NULL || out == NULL || out_len < 2 || atsign[0] == '\0') {
    return 1;
  }
  size_t o = 0;
  out[o++] = '@';
  for (const char *p = atsign[0] == '@' ? atsign + 1 : atsign; *p != '\0'; p++) {
    unsigned char c = (unsigned char)*p;
    if (c == '@' || c <= 0x1F || c == 0x7F || c == ' ' || strchr(reserved_characters, c) != NULL) {
      return 1;
    }
    if (c == '.') {
      continue;
    }
    if (c >= 'A' && c <= 'Z') {
      c = (unsigned char)(c + ('a' - 'A'));
    }
    if (o + 1 >= out_len) {
      return 1;
    }
    out[o++] = (char)c;
  }
  if (o == 1) {
    return 1;
  }
  out[o] = '\0';
  return 0;
}

bool noports_atsign_equals(const char *a, const char *b) {
  char na[NOPORTS_ATSIGN_BUFFER_LEN];
  char nb[NOPORTS_ATSIGN_BUFFER_LEN];
  return noports_normalize_atsign(a, na, sizeof(na)) == 0 && noports_normalize_atsign(b, nb, sizeof(nb)) == 0 &&
         strcmp(na, nb) == 0;
}

void noports_policy_decision_free(noports_policy_decision *decision) {
  for (size_t i = 0; i < decision->permit_open_len; i++) {
    free(decision->permit_open[i]);
  }
  free(decision->permit_open);
  memset(decision, 0, sizeof(*decision));
}

static int copy_decision(noports_policy_decision *dst, const noports_policy_decision *src) {
  memset(dst, 0, sizeof(*dst));
  dst->authorized = src->authorized;
  if (src->permit_open_len == 0) {
    return 0;
  }
  dst->permit_open = (char **)calloc(src->permit_open_len, sizeof(char *));
  if (dst->permit_open == NULL) {
    return 1;
  }
  for (size_t i = 0; i < src->permit_open_len; i++) {
    dst->permit_open[i] = strdup(src->permit_open[i]);
    if (dst->permit_open[i] == NULL) {
      dst->permit_open_len = i;
      noports_policy_decision_free(dst);
      return 1;
    }
  }
  dst->permit_open_len = src->permit_open_len;
  return 0;
}

int noports_policy_cache_init(noports_policy_cache *cache, size_t size) {
  memset(cache, 0, sizeof(*cache));
  if (size > NOPORTS_POLICY_CACHE_MAX_SIZE) {
    return 1;
  }
  if (size == 0) {
    return 0;
  }
  cache->entries = (noports_policy_cache_entry *)calloc(size, sizeof(noports_policy_cache_entry));
  if (cache->entries == NULL) {
    return 1;
  }
  cache->size = size;
  return 0;
}

void noports_policy_cache_free(noports_policy_cache *cache) {
  for (size_t i = 0; i < cache->size; i++) {
    noports_policy_decision_free(&cache->entries[i].decision);
  }
  free(cache->entries);
  memset(cache, 0, sizeof(*cache));
}

bool noports_policy_cache_lookup(noports_policy_cache *cache, const char *atsign, int64_t now_ms,
                                 noports_policy_decision *decision) {
  char normalized[NOPORTS_ATSIGN_BUFFER_LEN];
  if (noports_normalize_atsign(atsign, normalized, sizeof(normalized)) != 0) {
    return false;
  }
  for (size_t i = 0; i < cache->size; i++) {
    noports_policy_cache_entry *entry = &cache->entries[i];
    if (!entry->used || strcmp(entry->atsign, normalized) != 0) {
      continue;
    }
    if (now_ms - entry->checked_at_ms >= NOPORTS_POLICY_CACHE_TTL_MS) {
      return false;
    }
    return copy_decision(decision, &entry->decision) == 0;
  }
  return false;
}

int noports_policy_cache_store(noports_policy_cache *cache, const char *atsign,
                               const noports_policy_decision *decision, int64_t now_ms) {
  if (cache->size == 0) {
    return 0;
  }
  char normalized[NOPORTS_ATSIGN_BUFFER_LEN];
  if (noports_normalize_atsign(atsign, normalized, sizeof(normalized)) != 0) {
    return 1;
  }
  noports_policy_cache_entry *slot = NULL;
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
  noports_policy_decision_free(&slot->decision);
  slot->used = false;
  if (copy_decision(&slot->decision, decision) != 0) {
    return 1;
  }
  strcpy(slot->atsign, normalized);
  slot->checked_at_ms = now_ms;
  slot->used = true;
  return 0;
}

void noports_policy_cooldown_init(noports_policy_cooldown *cooldown) { memset(cooldown, 0, sizeof(*cooldown)); }

static int64_t last_active_ms(const noports_policy_cooldown_slot *slot) {
  int64_t ping = slot->checked[NOPORTS_POLICY_CHECK_PING] ? slot->checked_at_ms[NOPORTS_POLICY_CHECK_PING] : INT64_MIN;
  int64_t npt = slot->checked[NOPORTS_POLICY_CHECK_NPT] ? slot->checked_at_ms[NOPORTS_POLICY_CHECK_NPT] : INT64_MIN;
  return ping > npt ? ping : npt;
}

bool noports_policy_cooldown_allows(noports_policy_cooldown *cooldown, const char *atsign,
                                    noports_policy_check_kind kind, int64_t now_ms) {
  char normalized[NOPORTS_ATSIGN_BUFFER_LEN];
  if (noports_normalize_atsign(atsign, normalized, sizeof(normalized)) != 0) {
    return false;
  }
  noports_policy_cooldown_slot *slot = NULL;
  for (size_t i = 0; i < NOPORTS_POLICY_COOLDOWN_SLOTS && slot == NULL; i++) {
    if (cooldown->slots[i].used && strcmp(cooldown->slots[i].atsign, normalized) == 0) {
      slot = &cooldown->slots[i];
    }
  }
  if (slot != NULL) {
    if (slot->checked[kind] && now_ms - slot->checked_at_ms[kind] < NOPORTS_POLICY_COOLDOWN_MS) {
      return false;
    }
  } else {
    for (size_t i = 0; i < NOPORTS_POLICY_COOLDOWN_SLOTS && slot == NULL; i++) {
      if (!cooldown->slots[i].used) {
        slot = &cooldown->slots[i];
      }
    }
    if (slot == NULL) {
      slot = &cooldown->slots[0];
      for (size_t i = 1; i < NOPORTS_POLICY_COOLDOWN_SLOTS; i++) {
        if (last_active_ms(&cooldown->slots[i]) < last_active_ms(slot)) {
          slot = &cooldown->slots[i];
        }
      }
    }
    memset(slot, 0, sizeof(*slot));
    strcpy(slot->atsign, normalized);
    slot->used = true;
  }
  slot->checked[kind] = true;
  slot->checked_at_ms[kind] = now_ms;
  return true;
}

bool noports_policy_wait_over(int64_t started_ms, int64_t progress_ms, int64_t now_ms) {
  return now_ms - progress_ms > NOPORTS_POLICY_WAIT_MS || now_ms - started_ms > NOPORTS_POLICY_WAIT_CAP_MS;
}

bool noports_policy_resend_after_decrypt_failure(bool pending, const char *from, const char *policy_atsign) {
  return pending && noports_atsign_equals(from, policy_atsign);
}
