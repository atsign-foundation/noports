#include "sshnpd/enrollment_signature.h"
#include <atchops/base64.h>
#include <atchops/rsa.h>
#include <atchops/rsa_key.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "test_keys.h"

// The kid at_auth derives for TEST_PUBLIC_KEY_B64: the first 16 hex digits
// of the SHA-256 of its decoded bytes, worked out with Python's hashlib
static const char *TEST_KID = "f4fba07315b9dcf8";

static const char *PAYLOAD = "{\"sessionId\":\"9e13521b-9ad0-4237-9104-5824e6e6c483\",\"requestedPort\":22}";
static const char *OTHER_PAYLOAD = "{\"sessionId\":\"9e13521b-9ad0-4237-9104-5824e6e6c483\",\"requestedPort\":23}";

typedef struct {
  enum public_lookup_result result;
  const char *value;
  int calls;
  char uri[256];
} fake_lookup;

static enum public_lookup_result lookup(const char *uri, char **value, void *ctx) {
  fake_lookup *f = ctx;
  f->calls++;
  snprintf(f->uri, sizeof(f->uri), "%s", uri);
  *value = f->value == NULL ? NULL : strdup(f->value);
  return f->result;
}

// The test key's base64 signature over the serialized payload_json
static char *sign(const char *payload_json) {
  atchops_rsa_key_private_key private_key;
  atchops_rsa_key_private_key_init(&private_key);
  cJSON *payload = cJSON_Parse(payload_json);
  char *text = cJSON_PrintUnformatted(payload);
  unsigned char signature[256];
  char *encoded = calloc(1, 512);
  size_t encoded_len = 0;
  if (atchops_rsa_key_populate_private_key(&private_key, TEST_PRIVATE_KEY_B64, strlen(TEST_PRIVATE_KEY_B64)) != 0 ||
      atchops_rsa_sign(&private_key, ATCHOPS_MD_SHA256, (const unsigned char *)text, strlen(text), signature) != 0 ||
      atchops_base64_encode(signature, sizeof(signature), encoded, 512, &encoded_len) != 0) {
    free(encoded);
    encoded = NULL;
  }
  cJSON_free(text);
  cJSON_Delete(payload);
  atchops_rsa_key_private_key_free(&private_key);
  return encoded;
}

// A request envelope carrying payload_json, with an enrollment signature by
// the test key over signed_json naming sk, sa, ha and kid (each omitted when
// NULL), or with field_json as the whole field when it isn't NULL
static cJSON *envelope(const char *payload_json, const char *signed_json, const char *sk, const char *sa,
                       const char *ha, const char *kid, const char *field_json) {
  cJSON *e = cJSON_CreateObject();
  cJSON_AddItemToObject(e, "payload", cJSON_Parse(payload_json));
  if (field_json != NULL) {
    cJSON_AddItemToObject(e, ENROLLMENT_SIGNATURE_FIELD, cJSON_Parse(field_json));
    return e;
  }
  cJSON *field = cJSON_CreateObject();
  if (sk != NULL) {
    cJSON_AddStringToObject(field, "sk", sk);
  }
  if (kid != NULL) {
    cJSON_AddStringToObject(field, "kid", kid);
  }
  if (sa != NULL) {
    cJSON_AddStringToObject(field, "sa", sa);
  }
  if (ha != NULL) {
    cJSON_AddStringToObject(field, "ha", ha);
  }
  char *s = sign(signed_json);
  cJSON_AddStringToObject(field, "s", s);
  free(s);
  cJSON_AddItemToObject(e, ENROLLMENT_SIGNATURE_FIELD, field);
  return e;
}

static const char *SK = "public:_apsk.alice-enrollment.a.__e@alice";

static char *advertisement(const char *keys_json) {
  char *ad = malloc(4096);
  snprintf(ad, 4096, "{\"v\":1,\"keys\":%s}", keys_json);
  return ad;
}

static int failures = 0;

// Runs one case, checking the result, that why contains why_part, and, when
// expected_key isn't NULL, the signing key returned
static void check(const char *name, cJSON *e, fake_lookup *f, const char *requester,
                  enum enrollment_signature_result expected, const char *why_part, const char *expected_key) {
  char *signing_key = NULL;
  char why[1024];
  enum enrollment_signature_result result =
      verify_enrollment_signature(e, requester, lookup, f, &signing_key, why, sizeof(why));
  bool ok = result == expected && (why_part == NULL || strstr(why, why_part) != NULL) &&
            (expected_key == NULL ? (expected != ENROLLMENT_SIGNATURE_VERIFIED || signing_key != NULL)
                                  : (signing_key != NULL && strcmp(signing_key, expected_key) == 0));
  if (!ok) {
    printf("FAILED %s: result %d (expected %d), why \"%s\", signing key %s\n", name, result, expected, why,
           signing_key == NULL ? "(none)" : signing_key);
    failures++;
  }
  free(signing_key);
  cJSON_Delete(e);
}

int main() {
  char single_rsa[2048];
  snprintf(single_rsa, sizeof(single_rsa), "[{\"kid\":\"%s\",\"use\":\"sign\",\"alg\":\"rsa2048\",\"pub\":\"%s\"}]",
           TEST_KID, TEST_PUBLIC_KEY_B64);
  char two_rsa[2048];
  snprintf(two_rsa, sizeof(two_rsa),
           "[{\"kid\":\"%s\",\"use\":\"sign\",\"alg\":\"rsa2048\",\"pub\":\"%s\"},"
           "{\"kid\":\"0011223344556677\",\"use\":\"sign\",\"alg\":\"rsa2048\",\"pub\":\"AAAA\"}]",
           TEST_KID, TEST_PUBLIC_KEY_B64);
  char retired[2048];
  snprintf(retired, sizeof(retired),
           "[{\"kid\":\"%s\",\"use\":\"sign\",\"alg\":\"rsa2048\",\"pub\":\"%s\",\"status\":\"retired\"}]", TEST_KID,
           TEST_PUBLIC_KEY_B64);
  char with_mldsa[2048];
  snprintf(with_mldsa, sizeof(with_mldsa),
           "[{\"kid\":\"8899aabbccddeeff\",\"use\":\"sign\",\"alg\":\"mldsa65\",\"pub\":\"AAAA\"},"
           "{\"kid\":\"%s\",\"use\":\"sign\",\"alg\":\"rsa2048\",\"pub\":\"%s\"}]",
           TEST_KID, TEST_PUBLIC_KEY_B64);
  char *ad_single = advertisement(single_rsa);
  char *ad_two = advertisement(two_rsa);
  char *ad_retired = advertisement(retired);
  char *ad_mldsa = advertisement(with_mldsa);

  fake_lookup bare = {PUBLIC_LOOKUP_FOUND, TEST_PUBLIC_KEY_B64, 0, ""};
  check("verifies against a bare RSA key", envelope(PAYLOAD, PAYLOAD, SK, "rsa2048", "sha256", NULL, NULL), &bare,
        "@alice", ENROLLMENT_SIGNATURE_VERIFIED, NULL, SK);

  fake_lookup absent = {PUBLIC_LOOKUP_FOUND, TEST_PUBLIC_KEY_B64, 0, ""};
  cJSON *unsigned_envelope = cJSON_CreateObject();
  cJSON_AddItemToObject(unsigned_envelope, "payload", cJSON_Parse(PAYLOAD));
  check("absent", unsigned_envelope, &absent, "@alice", ENROLLMENT_SIGNATURE_ABSENT, NULL, NULL);
  if (absent.calls != 0) {
    printf("FAILED absent: looked up %s\n", absent.uri);
    failures++;
  }

  fake_lookup f = {PUBLIC_LOOKUP_FOUND, TEST_PUBLIC_KEY_B64, 0, ""};
  check("not an object", envelope(PAYLOAD, PAYLOAD, NULL, NULL, NULL, NULL, "\"x\""), &f, "@alice",
        ENROLLMENT_SIGNATURE_REFUSED, "is not an object", NULL);
  check("no s", envelope(PAYLOAD, PAYLOAD, NULL, NULL, NULL, NULL, "{\"sk\":\"x\",\"sa\":\"rsa2048\",\"ha\":\"sha256\"}"),
        &f, "@alice", ENROLLMENT_SIGNATURE_REFUSED, "no string \"s\"", NULL);
  check("not an _apsk uri",
        envelope(PAYLOAD, PAYLOAD, "public:publickey@alice", "rsa2048", "sha256", NULL, NULL), &f, "@alice",
        ENROLLMENT_SIGNATURE_REFUSED, "is not of the form", NULL);
  check("another atSign's key",
        envelope(PAYLOAD, PAYLOAD, "public:_apsk.m.a.__e@mallory", "rsa2048", "sha256", NULL, NULL), &f, "@alice",
        ENROLLMENT_SIGNATURE_REFUSED, "belongs to @mallory, not the requester @alice", NULL);

  fake_lookup canonical = {PUBLIC_LOOKUP_FOUND, TEST_PUBLIC_KEY_B64, 0, ""};
  check("looks up the canonical uri",
        envelope(PAYLOAD, PAYLOAD, "_apsk.Alice-Enrollment.a.__e@Alice", "rsa2048", "sha256", NULL, NULL),
        &canonical, "@alice", ENROLLMENT_SIGNATURE_VERIFIED, NULL, SK);
  if (strcmp(canonical.uri, SK) != 0) {
    printf("FAILED looks up the canonical uri: looked up %s\n", canonical.uri);
    failures++;
  }

  check("an unknown algorithm", envelope(PAYLOAD, PAYLOAD, SK, "rsa1024", "sha256", NULL, NULL), &f, "@alice",
        ENROLLMENT_SIGNATURE_REFUSED, "an algorithm NoPorts does not know", NULL);
  fake_lookup mldsa = {PUBLIC_LOOKUP_FOUND, ad_mldsa, 0, ""};
  check("ML-DSA", envelope(PAYLOAD, PAYLOAD, SK, "mldsa65", "sha256", NULL, NULL), &mldsa, "@alice",
        ENROLLMENT_SIGNATURE_REFUSED, "can't verify ML-DSA", NULL);
  if (mldsa.calls != 0) {
    printf("FAILED ML-DSA: looked up %s before refusing\n", mldsa.uri);
    failures++;
  }
  check("an algorithm NoPorts doesn't sign with", envelope(PAYLOAD, PAYLOAD, SK, "ecc_secp256r1", "sha256", NULL, NULL),
        &f, "@alice", ENROLLMENT_SIGNATURE_REFUSED, "Unsupported signing algorithm ecc_secp256r1", NULL);
  check("a kid that isn't a string",
        envelope(PAYLOAD, PAYLOAD, NULL, NULL, NULL, NULL,
                 "{\"sk\":\"public:_apsk.alice-enrollment.a.__e@alice\",\"sa\":\"rsa2048\",\"ha\":\"sha256\",\"kid\":7,"
                 "\"s\":\"AAAA\"}"),
        &f, "@alice", ENROLLMENT_SIGNATURE_REFUSED, "\"kid\" that is not a string", NULL);
  check("an unsupported hashing algorithm", envelope(PAYLOAD, PAYLOAD, SK, "rsa2048", "md5", NULL, NULL), &f, "@alice",
        ENROLLMENT_SIGNATURE_REFUSED, "Unsupported hashing algorithm md5", NULL);

  fake_lookup missing = {PUBLIC_LOOKUP_NOT_FOUND, NULL, 0, ""};
  check("a record that doesn't exist", envelope(PAYLOAD, PAYLOAD, SK, "rsa2048", "sha256", NULL, NULL), &missing,
        "@alice", ENROLLMENT_SIGNATURE_UNCHECKED, "does not exist", NULL);
  fake_lookup failed = {PUBLIC_LOOKUP_FAILED, NULL, 0, ""};
  check("a lookup that fails", envelope(PAYLOAD, PAYLOAD, SK, "rsa2048", "sha256", NULL, NULL), &failed, "@alice",
        ENROLLMENT_SIGNATURE_UNCHECKED, "could not be looked up", NULL);

  check("a signature over another payload", envelope(PAYLOAD, OTHER_PAYLOAD, SK, "rsa2048", "sha256", NULL, NULL),
        &bare, "@alice", ENROLLMENT_SIGNATURE_REFUSED, "Signatures did not match.", NULL);
  check("the kid derived for a bare key", envelope(PAYLOAD, PAYLOAD, SK, "rsa2048", "sha256", TEST_KID, NULL), &bare,
        "@alice", ENROLLMENT_SIGNATURE_VERIFIED, NULL, SK);
  check("a kid a bare key doesn't have",
        envelope(PAYLOAD, PAYLOAD, SK, "rsa2048", "sha256", "0000000000000000", NULL), &bare, "@alice",
        ENROLLMENT_SIGNATURE_REFUSED, "names key 0000000000000000", NULL);
  fake_lookup not_base64 = {PUBLIC_LOOKUP_FOUND, "!!!", 0, ""};
  check("a bare value that isn't base64", envelope(PAYLOAD, PAYLOAD, SK, "rsa2048", "sha256", NULL, NULL), &not_base64,
        "@alice", ENROLLMENT_SIGNATURE_REFUSED, "holds a key that is not base64", NULL);
  fake_lookup not_json = {PUBLIC_LOOKUP_FOUND, "{\"v\":1,", 0, ""};
  check("an advertisement that isn't JSON", envelope(PAYLOAD, PAYLOAD, SK, "rsa2048", "sha256", NULL, NULL), &not_json,
        "@alice", ENROLLMENT_SIGNATURE_REFUSED, "is not JSON", NULL);

  fake_lookup single = {PUBLIC_LOOKUP_FOUND, ad_single, 0, ""};
  check("an advertised key named by kid", envelope(PAYLOAD, PAYLOAD, SK, "rsa2048", "sha256", TEST_KID, NULL),
        &single, "@alice", ENROLLMENT_SIGNATURE_VERIFIED, NULL, SK);
  check("the only advertised key", envelope(PAYLOAD, PAYLOAD, SK, "rsa2048", "sha256", NULL, NULL), &single, "@alice",
        ENROLLMENT_SIGNATURE_VERIFIED, NULL, SK);
  fake_lookup two = {PUBLIC_LOOKUP_FOUND, ad_two, 0, ""};
  check("two advertised keys and no kid", envelope(PAYLOAD, PAYLOAD, SK, "rsa2048", "sha256", NULL, NULL), &two,
        "@alice", ENROLLMENT_SIGNATURE_REFUSED, "names no key", NULL);
  fake_lookup only_retired = {PUBLIC_LOOKUP_FOUND, ad_retired, 0, ""};
  check("only a retired key", envelope(PAYLOAD, PAYLOAD, SK, "rsa2048", "sha256", TEST_KID, NULL), &only_retired,
        "@alice", ENROLLMENT_SIGNATURE_REFUSED, "advertises no key NoPorts can verify", NULL);
  check("RSA where ML-DSA is offered", envelope(PAYLOAD, PAYLOAD, SK, "rsa2048", "sha256", TEST_KID, NULL), &mldsa,
        "@alice", ENROLLMENT_SIGNATURE_REFUSED, "the strongest algorithm it offers", NULL);

  free(ad_single);
  free(ad_two);
  free(ad_retired);
  free(ad_mldsa);
  printf("Tests failed: %d\n", failures);
  return failures;
}
