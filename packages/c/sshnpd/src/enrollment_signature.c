#include <atchops/base64.h>
#include <atchops/rsa.h>
#include <atchops/rsa_key.h>
#include <atchops/sha.h>
#include <sshnpd/enrollment_signature.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// The algorithm names the Dart SDK knows, so a name outside them reads as
// unknown rather than as unsupported
static const char *const signing_algorithms[] = {"ecc_secp256r1", "rsa2048", "rsa4096", "ed25519", "mldsa65", NULL};
static const char *const hashing_algorithms[] = {"sha256", "sha512", "md5", "argon2id", NULL};

static const char id_chars[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-";

static bool is_one_of(const char *s, const char *const *names) {
  for (; *names != NULL; names++) {
    if (strcmp(s, *names) == 0) {
      return true;
    }
  }
  return false;
}

static enum enrollment_signature_result explain(enum enrollment_signature_result result, char *why, size_t why_size,
                                                const char *fmt, ...) {
  va_list args;
  va_start(args, fmt);
  vsnprintf(why, why_size, fmt, args);
  va_end(args);
  return result;
}

// Whether uri is `[public:]_apsk.<enrollmentId>.a.__e@<atSign>`, the only
// shape a signing key uri may take, so the atSign read from it is the
// record's owner
static bool is_signing_key_uri(const char *uri) {
  const char *p = strncmp(uri, "public:", strlen("public:")) == 0 ? uri + strlen("public:") : uri;
  if (strncmp(p, "_apsk.", strlen("_apsk.")) != 0) {
    return false;
  }
  p += strlen("_apsk.");
  size_t id_len = strspn(p, id_chars);
  if (id_len == 0 || strncmp(p + id_len, ".a.__e@", strlen(".a.__e@")) != 0) {
    return false;
  }
  p += id_len + strlen(".a.__e@");
  return *p != '\0' && strpbrk(p, "@: \t\r\n\f\v") == NULL;
}

static void lower_ascii(char *s) {
  for (; *s != '\0'; s++) {
    if (*s >= 'A' && *s <= 'Z') {
      *s = (char)(*s - 'A' + 'a');
    }
  }
}

// The kid at_auth derives for a key: the first 8 bytes, as hex, of the
// SHA-256 of its decoded bytes. Returns non-zero when pub isn't base64.
static int kid_of(const char *pub, char kid[17]) {
  size_t len = strlen(pub);
  size_t cap = len / 4 * 3 + 3;
  unsigned char *raw = malloc(cap);
  size_t raw_len = 0;
  if (raw == NULL || atchops_base64_decode(pub, len, raw, cap, &raw_len) != 0) {
    free(raw);
    return 1;
  }
  unsigned char hash[32];
  int res = atchops_sha_hash(ATCHOPS_MD_SHA256, raw, raw_len, hash);
  free(raw);
  if (res != 0) {
    return 1;
  }
  for (int i = 0; i < 8; i++) {
    snprintf(kid + 2 * i, 3, "%02x", hash[i]);
  }
  return 0;
}

typedef struct {
  char kid[17];
  const char *kid_text; // the advertised kid, or kid when derived
  const char *alg;
  const char *pub;
} apsk_key;

// The keys apsk, the value of the `_apsk` record uri, offers for new
// signatures under an algorithm NoPorts verifies: a value starting with '{'
// is at_auth's JSON advertisement, anything else one bare RSA key. On
// success *keys (malloc'd) points into apsk and *json, which the caller frees.
static enum enrollment_signature_result active_apsk_keys(const char *uri, char *apsk, cJSON **json, apsk_key **keys,
                                                         size_t *count, char *why, size_t why_size) {
  *json = NULL;
  *keys = NULL;
  *count = 0;
  char *value = apsk;
  while (*value == ' ' || *value == '\t' || *value == '\r' || *value == '\n') {
    value++;
  }
  for (size_t end = strlen(value); end > 0 && strchr(" \t\r\n", value[end - 1]) != NULL; end--) {
    value[end - 1] = '\0';
  }
  if (value[0] != '{') {
    *keys = calloc(1, sizeof(apsk_key));
    if (*keys == NULL) {
      return explain(ENROLLMENT_SIGNATURE_UNCHECKED, why, why_size, "out of memory");
    }
    if (kid_of(value, (*keys)[0].kid) != 0) {
      free(*keys);
      *keys = NULL;
      return explain(ENROLLMENT_SIGNATURE_REFUSED, why, why_size, "%s holds a key that is not base64", uri);
    }
    (*keys)[0].kid_text = (*keys)[0].kid;
    (*keys)[0].alg = "rsa2048";
    (*keys)[0].pub = value;
    *count = 1;
    return ENROLLMENT_SIGNATURE_VERIFIED;
  }
  *json = cJSON_ParseWithOpts(value, NULL, true);
  if (*json == NULL) {
    return explain(ENROLLMENT_SIGNATURE_REFUSED, why, why_size, "%s holds an advertisement that is not JSON", uri);
  }
  if (!cJSON_IsObject(*json)) {
    return explain(ENROLLMENT_SIGNATURE_REFUSED, why, why_size, "%s holds an advertisement that is not a JSON object",
                   uri);
  }
  const cJSON *entries = cJSON_GetObjectItemCaseSensitive(*json, "keys");
  if (!cJSON_IsArray(entries)) {
    entries = NULL;
  }
  size_t max = entries == NULL ? 0 : (size_t)cJSON_GetArraySize(entries);
  *keys = calloc(max == 0 ? 1 : max, sizeof(apsk_key));
  if (*keys == NULL) {
    return explain(ENROLLMENT_SIGNATURE_UNCHECKED, why, why_size, "out of memory");
  }
  const cJSON *entry = NULL;
  cJSON_ArrayForEach(entry, entries) {
    if (!cJSON_IsObject(entry)) {
      continue;
    }
    const cJSON *kid = cJSON_GetObjectItemCaseSensitive(entry, "kid");
    const cJSON *use = cJSON_GetObjectItemCaseSensitive(entry, "use");
    const cJSON *alg = cJSON_GetObjectItemCaseSensitive(entry, "alg");
    const cJSON *pub = cJSON_GetObjectItemCaseSensitive(entry, "pub");
    const cJSON *status = cJSON_GetObjectItemCaseSensitive(entry, "status");
    if (!cJSON_IsString(kid) || !cJSON_IsString(use) || !cJSON_IsString(alg) || !cJSON_IsString(pub) ||
        strcmp(use->valuestring, "sign") != 0 || !is_one_of(alg->valuestring, signing_algorithms)) {
      continue;
    }
    bool active = status == NULL || cJSON_IsNull(status) ||
                  (cJSON_IsString(status) && strcmp(status->valuestring, "active") == 0);
    if (!active || (strcmp(alg->valuestring, "rsa2048") != 0 && strcmp(alg->valuestring, "mldsa65") != 0)) {
      continue;
    }
    apsk_key *key = &(*keys)[(*count)++];
    key->kid_text = kid->valuestring;
    key->alg = alg->valuestring;
    key->pub = pub->valuestring;
  }
  if (*count == 0) {
    return explain(ENROLLMENT_SIGNATURE_REFUSED, why, why_size, "%s advertises no key NoPorts can verify", uri);
  }
  return ENROLLMENT_SIGNATURE_VERIFIED;
}

// The modulus length of key in bytes, which an RSA signature by it must be
static size_t rsa_modulus_bytes(const atchops_rsa_key_public_key *key) {
  const unsigned char *n = key->n.value;
  size_t len = key->n.len;
  while (len > 0 && n[0] == 0x00) {
    n++;
    len--;
  }
  return len;
}

static enum enrollment_signature_result verify_rsa(const apsk_key *key, const char *signed_text,
                                                   const char *signature, atchops_md_type hashing, char *why,
                                                   size_t why_size) {
  atchops_rsa_key_public_key public_key;
  atchops_rsa_key_public_key_init(&public_key);
  enum enrollment_signature_result result;
  size_t sig_len = strlen(signature);
  size_t cap = sig_len / 4 * 3 + 3;
  unsigned char *raw = malloc(cap);
  size_t raw_len = 0;
  if (raw == NULL) {
    result = explain(ENROLLMENT_SIGNATURE_UNCHECKED, why, why_size, "out of memory");
  } else if (atchops_rsa_key_populate_public_key(&public_key, key->pub, strlen(key->pub)) != 0) {
    result = explain(ENROLLMENT_SIGNATURE_REFUSED, why, why_size, "Key %s is not an RSA public key", key->kid_text);
  } else if (atchops_base64_decode(signature, sig_len, raw, cap, &raw_len) != 0) {
    result = explain(ENROLLMENT_SIGNATURE_REFUSED, why, why_size, "The signature is not base64");
  } else if (raw_len != rsa_modulus_bytes(&public_key) ||
             atchops_rsa_verify(&public_key, hashing, (const unsigned char *)signed_text, strlen(signed_text),
                                raw) != 0) {
    result = explain(ENROLLMENT_SIGNATURE_REFUSED, why, why_size, "Signatures did not match.");
  } else {
    result = ENROLLMENT_SIGNATURE_VERIFIED;
  }
  free(raw);
  atchops_rsa_key_public_key_free(&public_key);
  return result;
}

enum enrollment_signature_result verify_enrollment_signature(const cJSON *envelope, const char *requester,
                                                             enrollment_signature_lookup_fn lookup, void *ctx,
                                                             char **signing_key, char *why, size_t why_size) {
  *signing_key = NULL;
  why[0] = '\0';
  const cJSON *field = cJSON_GetObjectItemCaseSensitive(envelope, ENROLLMENT_SIGNATURE_FIELD);
  if (field == NULL || cJSON_IsNull(field)) {
    return ENROLLMENT_SIGNATURE_ABSENT;
  }
  if (!cJSON_IsObject(field)) {
    return explain(ENROLLMENT_SIGNATURE_REFUSED, why, why_size, "%s is not an object", ENROLLMENT_SIGNATURE_FIELD);
  }
  static const char *const text_names[] = {"sk", "sa", "ha", "s"};
  const char *text[4];
  for (size_t i = 0; i < 4; i++) {
    const cJSON *item = cJSON_GetObjectItemCaseSensitive(field, text_names[i]);
    if (!cJSON_IsString(item)) {
      return explain(ENROLLMENT_SIGNATURE_REFUSED, why, why_size, "%s has no string \"%s\"",
                     ENROLLMENT_SIGNATURE_FIELD, text_names[i]);
    }
    text[i] = item->valuestring;
  }
  const char *uri = text[0], *sa = text[1], *ha = text[2], *signature = text[3];
  if (!is_signing_key_uri(uri)) {
    return explain(ENROLLMENT_SIGNATURE_REFUSED, why, why_size,
                   "Signing key (%s) is not of the form public:_apsk.<enrollmentId>.a.__e@<atSign>", uri);
  }
  char *signer = strdup(strrchr(uri, '@'));
  char *requester_lower = strdup(requester);
  char *canonical = malloc(strlen(uri) + strlen("public:") + 1);
  if (signer == NULL || requester_lower == NULL || canonical == NULL) {
    free(signer);
    free(requester_lower);
    free(canonical);
    return explain(ENROLLMENT_SIGNATURE_UNCHECKED, why, why_size, "out of memory");
  }
  lower_ascii(signer);
  lower_ascii(requester_lower);
  bool signer_is_requester = strcmp(signer, requester_lower) == 0;
  free(requester_lower);
  if (!signer_is_requester) {
    explain(ENROLLMENT_SIGNATURE_REFUSED, why, why_size, "Signing key %s belongs to %s, not the requester %s", uri,
            signer, requester);
    free(signer);
    free(canonical);
    return ENROLLMENT_SIGNATURE_REFUSED;
  }
  free(signer);
  if (!is_one_of(sa, signing_algorithms) || !is_one_of(ha, hashing_algorithms)) {
    free(canonical);
    return explain(ENROLLMENT_SIGNATURE_REFUSED, why, why_size, "%s names an algorithm NoPorts does not know",
                   ENROLLMENT_SIGNATURE_FIELD);
  }
  if (strcmp(sa, "mldsa65") == 0) {
    free(canonical);
    return explain(ENROLLMENT_SIGNATURE_REFUSED, why, why_size,
                   "Unsupported signing algorithm mldsa65: this daemon can't verify ML-DSA signatures");
  }
  if (strcmp(sa, "rsa2048") != 0) {
    free(canonical);
    return explain(ENROLLMENT_SIGNATURE_REFUSED, why, why_size, "Unsupported signing algorithm %s", sa);
  }
  const cJSON *kid_item = cJSON_GetObjectItemCaseSensitive(field, "kid");
  if (kid_item != NULL && !cJSON_IsNull(kid_item) && !cJSON_IsString(kid_item)) {
    free(canonical);
    return explain(ENROLLMENT_SIGNATURE_REFUSED, why, why_size, "%s has a \"kid\" that is not a string",
                   ENROLLMENT_SIGNATURE_FIELD);
  }
  const char *kid = cJSON_IsString(kid_item) ? kid_item->valuestring : NULL;

  const char *unprefixed = strncmp(uri, "public:", strlen("public:")) == 0 ? uri + strlen("public:") : uri;
  snprintf(canonical, strlen(uri) + strlen("public:") + 1, "public:%s", unprefixed);
  lower_ascii(canonical);

  char *apsk = NULL;
  enum public_lookup_result looked_up = lookup(canonical, &apsk, ctx);
  if (looked_up != PUBLIC_LOOKUP_FOUND) {
    explain(ENROLLMENT_SIGNATURE_UNCHECKED, why, why_size,
            looked_up == PUBLIC_LOOKUP_NOT_FOUND ? "%s does not exist" : "%s could not be looked up", canonical);
    free(apsk);
    free(canonical);
    return ENROLLMENT_SIGNATURE_UNCHECKED;
  }

  cJSON *json = NULL;
  apsk_key *keys = NULL;
  size_t count = 0;
  enum enrollment_signature_result result = active_apsk_keys(canonical, apsk, &json, &keys, &count, why, why_size);
  if (result == ENROLLMENT_SIGNATURE_VERIFIED) {
    bool offers_mldsa = false;
    size_t candidates = 0;
    const apsk_key *key = NULL;
    for (size_t i = 0; i < count; i++) {
      if (strcmp(keys[i].alg, "mldsa65") == 0) {
        offers_mldsa = true;
      } else {
        candidates++;
        if (key == NULL && (kid == NULL || strcmp(keys[i].kid_text, kid) == 0)) {
          key = &keys[i];
        }
      }
    }
    if (offers_mldsa) {
      result = explain(ENROLLMENT_SIGNATURE_REFUSED, why, why_size,
                       "Signed with rsa2048, but %s advertises mldsa65, the strongest algorithm it offers", canonical);
    } else if (kid == NULL && candidates != 1) {
      result = explain(ENROLLMENT_SIGNATURE_REFUSED, why, why_size,
                       "The signature names no key, and %s advertises %zu rsa2048 keys", canonical, candidates);
    } else if (key == NULL) {
      result = explain(ENROLLMENT_SIGNATURE_REFUSED, why, why_size,
                       "The signature names key %s, which %s does not advertise", kid, canonical);
    } else if (strcmp(ha, "sha256") != 0 && strcmp(ha, "sha512") != 0) {
      result = explain(ENROLLMENT_SIGNATURE_REFUSED, why, why_size, "Unsupported hashing algorithm %s", ha);
    } else {
      char *signed_text = cJSON_PrintUnformatted(cJSON_GetObjectItemCaseSensitive(envelope, "payload"));
      if (signed_text == NULL) {
        result = explain(ENROLLMENT_SIGNATURE_UNCHECKED, why, why_size, "the payload could not be serialized");
      } else {
        result = verify_rsa(key, signed_text, signature,
                            strcmp(ha, "sha256") == 0 ? ATCHOPS_MD_SHA256 : ATCHOPS_MD_SHA512, why, why_size);
        cJSON_free(signed_text);
      }
    }
  }
  free(keys);
  cJSON_Delete(json);
  free(apsk);
  if (result == ENROLLMENT_SIGNATURE_VERIFIED) {
    *signing_key = canonical;
  } else {
    free(canonical);
  }
  return result;
}
