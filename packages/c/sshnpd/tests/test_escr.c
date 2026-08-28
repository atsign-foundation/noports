// Round-trip test for the srv ESCR response builder: build a response line,
// then take it apart the way the relay's RelayAuthVerifierESCR does - split,
// base64 decode, AES-256-CTR decrypt, PKCS#7 unpad, parse the envelope and
// verify the RSA signature over the inner payload.
//
// Byte-level compatibility with the Dart verifier is additionally covered by
// a manual interop check (see the PR description); this test keeps the C
// construction honest without needing a Dart runtime.
#include <atchops/base64.h>
#include <atchops/rsa.h>
#include <atchops/rsa_key.h>
#include <atclient/json.h>
#include <mbedtls/aes.h>
#include <srv/escr.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Throwaway RSA-2048 keypair generated for this test only
static const char *TEST_PRIVATE_KEY_B64 =
    "MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCWkE9G3HhNcsSi1z1R0N3z0ep1shnlQooP96l09sa5TnJk"
    "yBj21M5RCgMmqVVWWeYTI6fUh80d4ImCZrygaR52vSV9nfMPomBxsWRLImgbB6Hvudlf8TWkpMIfF4SBqC97aqG9eXsfrEiU"
    "jPCj6xPJG3D4cBjsZGbmnn67wiXe3EV+eHDXO6leQ+lEaWN6vFm4ddCJ6d1f6S9Wiyy3nCL95xxzkYSiSUYTTvv2Kn+qcFX9"
    "PA0P5MF68/zTKXw4WJy9xDlK75hBrkvddnYXwu3qKJzisUelsWUiDy8xzvksor23QxnU1NL0KcFpkuFN3bMY/zd8+gPfL65K"
    "nbGbbi4RAgMBAAECggEABiN8F/eFMCMtwTXlWiCZ7Aby+Dl6tM4xstT2I76r+4InR9Sgr++dOdCesETXJd4kc0NQ5GllA4LU"
    "GGz349JlW5H6pVR7RHfqVrhUzntoozF8eLmrEy5ScZQGFh5vWJny1aVTUtZRHsl3bBcS+JvtApYL1RU87uZpC54KrL0Nrjhc"
    "2ImQ4ZmsUMHcx+9hS/QXGkuyCRbKkkIKYIRKf5Lem7ECY/eSh3uXOMkKuoOcysDAhTqsxploaIS6l+j+JUI6NJRFVXuKwUnq"
    "kyYvT3/cka++QBTXgGlpTZzQyrMNuy42N7UXMJU6KMGwcDepkqqou8KzyliR/Bpw8/YTmPS8AQKBgQDKvTrbfe+cpMzkkR7m"
    "DVOU1tnD/GA+La2UnK6q+Vau51+PHvZ0WLt7LHnovvTbcHPa5dvhGRLwe3dBSy76k4QtfBGGb8HXmmGFd7uWtA0QF+DO0u9/"
    "Vr///hoMqgF3+A0gASwei55g7K62pM7VHxVNkgQWTuzwxTJzumN2Y3RoCQKBgQC+HiKfAnEKMTVWikUBtPDoSx0qwM/JQFqV"
    "4dhittva7rW5Tw1pSbvnm7F7HU8AW/I0ANeMarrq35HlPg3auLjko/OqQc0nqesQQmZTWQ8nQQFLx2mtvsJ57bf4a9dtckpe"
    "SzvgrrrIERN0W8ALMXF1xkTA40k16UcXdX59Oj5HyQKBgCmbkFq/i89wGwTFq7u2/HJNbb/FKdNY+IjJZyd7qIiYv4nV5uqV"
    "01RCGnrjxcjLWVuRVQDrbnGgRSdHUMroP3Y+QjJ++R9Qdbc4jW0uYofs/pwzuic+HIVjFuGGemquo7LvyqgyKzzlFi4xwKkI"
    "igyzbNdPN11qeyI5HHSNkLRRAoGAew9cj5pv+w3xHYwwsLMjgOkl/weBOB6MxBnFC9ibJPKA9GsEHlPY6kkwL6W//laFxz2I"
    "SF7JkMCYWk+5fgs1uuGZFmqzVeo5unOQcoDiOyFrqlZwxEMG9Q93lriPYEurca+3GW9gfaH3+shs3ZHqhDaLSGOWfuv51Wh7"
    "MKnjqGkCgYEAlJzJeoBIoyC4jZ1Vmm3kaJKQ/Q3L/KsnNnHH8ajEXHI6wdy5oD2CsF7VnodduHwVpNkVZMp15IXClr/KbYWL"
    "y+cpsyRBeiGoglreO2lxAuqP51FjQriaT5E/ox7nvy2jATAjX8i6BDLk69F0+6QL1cuHTHhz4Y6bkDCJrocSNfY=";

static const char *TEST_PUBLIC_KEY_B64 =
    "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAlpBPRtx4TXLEotc9UdDd89HqdbIZ5UKKD/epdPbGuU5yZMgY9tTO"
    "UQoDJqlVVlnmEyOn1IfNHeCJgma8oGkedr0lfZ3zD6JgcbFkSyJoGweh77nZX/E1pKTCHxeEgagve2qhvXl7H6xIlIzwo+sT"
    "yRtw+HAY7GRm5p5+u8Il3txFfnhw1zupXkPpRGljerxZuHXQiendX+kvVosst5wi/eccc5GEoklGE0779ip/qnBV/TwND+TB"
    "evP80yl8OFicvcQ5Su+YQa5L3XZ2F8Lt6iic4rFHpbFlIg8vMc75LKK9t0MZ1NTS9CnBaZLhTd2zGP83fPoD3y+uSp2xm24u"
    "EQIDAQAB";

// base64 of bytes 0x00..0x1f - a fixed 32 byte AES key
static const char *TEST_AES_KEY_B64 = "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8=";

static const char *TEST_SESSION_ID = "9b6350cd-3ac6-4d47-9d43-a1d5bbcbe553";
static const char *TEST_CHALLENGE = "dGhpcyBpcyBhIHRlc3QgY2hhbGxlbmdlLCA0NCBjaGFycw==";
static const char *TEST_SK_URI = "public:_apsk.primary.a.__e@test_daemon";

static int failures = 0;

static void check(bool ok, const char *what) {
  if (!ok) {
    printf("FAIL: %s\n", what);
    failures++;
  } else {
    printf("ok: %s\n", what);
  }
}

static unsigned char *b64_decode_alloc(const char *src, size_t *out_len) {
  size_t dstsize = strlen(src) + 1;
  unsigned char *dst = malloc(dstsize);
  if (dst == NULL) {
    return NULL;
  }
  if (atchops_base64_decode(src, strlen(src), dst, dstsize, out_len) != 0) {
    free(dst);
    return NULL;
  }
  return dst;
}

int main() {
  atchops_rsa_key_private_key private_key;
  atchops_rsa_key_private_key_init(&private_key);
  check(atchops_rsa_key_populate_private_key(&private_key, TEST_PRIVATE_KEY_B64, strlen(TEST_PRIVATE_KEY_B64)) == 0,
        "populate private key");

  atchops_rsa_key_public_key public_key;
  atchops_rsa_key_public_key_init(&public_key);
  check(atchops_rsa_key_populate_public_key(&public_key, TEST_PUBLIC_KEY_B64, strlen(TEST_PUBLIC_KEY_B64)) == 0,
        "populate public key");

  unsigned char iv[16];
  for (int i = 0; i < 16; i++) {
    iv[i] = (unsigned char)i;
  }

  char *line = NULL;
  check(srv_escr_build_response(TEST_SESSION_ID, TEST_CHALLENGE, TEST_AES_KEY_B64, TEST_SK_URI, &private_key, false, iv,
                                &line) == 0 &&
            line != NULL,
        "build response");
  if (line == NULL) {
    return 1;
  }

  // Determinism: same inputs and iv produce the same line
  char *line2 = NULL;
  check(srv_escr_build_response(TEST_SESSION_ID, TEST_CHALLENGE, TEST_AES_KEY_B64, TEST_SK_URI, &private_key, false, iv,
                                &line2) == 0 &&
            line2 != NULL && strcmp(line, line2) == 0,
        "deterministic for fixed iv");
  free(line2);

  // A challenge needing JSON escaping must be refused, not mis-encoded
  char *bad_line = NULL;
  check(srv_escr_build_response(TEST_SESSION_ID, "chal\"lenge", TEST_AES_KEY_B64, TEST_SK_URI, &private_key, false, iv,
                                &bad_line) != 0 &&
            bad_line == NULL,
        "reject challenge containing a quote");

  // ---- Take the line apart the way the relay does ----
  char *colon = strchr(line, ':');
  check(colon != NULL && strchr(colon + 1, ':') == NULL, "line has exactly one colon");
  check(colon != NULL && strncmp(line, TEST_SESSION_ID, colon - line) == 0, "session id prefix");

  size_t outer_len = 0;
  unsigned char *outer_bytes = b64_decode_alloc(colon + 1, &outer_len);
  check(outer_bytes != NULL, "decode outer payload");
  outer_bytes[outer_len] = '\0';

  cJSON *outer = cJSON_Parse((char *)outer_bytes);
  check(outer != NULL, "parse outer json");
  char *iv_b64 = cJSON_GetStringValue(cJSON_GetObjectItem(outer, "iv"));
  char *e_b64 = cJSON_GetStringValue(cJSON_GetObjectItem(outer, "e"));
  check(iv_b64 != NULL && e_b64 != NULL, "outer json has iv and e");

  size_t iv_len = 0;
  unsigned char *iv_bytes = b64_decode_alloc(iv_b64, &iv_len);
  check(iv_bytes != NULL && iv_len == 16 && memcmp(iv_bytes, iv, 16) == 0, "iv round trips");

  size_t cipher_len = 0;
  unsigned char *cipher = b64_decode_alloc(e_b64, &cipher_len);
  check(cipher != NULL && cipher_len > 0 && cipher_len % 16 == 0, "ciphertext is block aligned");

  // Decrypt (CTR decrypt == CTR encrypt)
  unsigned char *plain = malloc(cipher_len + 1);
  {
    size_t aes_key_len = 0;
    unsigned char aes_key[32];
    atchops_base64_decode(TEST_AES_KEY_B64, strlen(TEST_AES_KEY_B64), aes_key, sizeof(aes_key), &aes_key_len);
    mbedtls_aes_context aes_ctx;
    mbedtls_aes_init(&aes_ctx);
    mbedtls_aes_setkey_enc(&aes_ctx, aes_key, 256);
    size_t nc_off = 0;
    unsigned char stream_block[16] = {0};
    unsigned char nonce_counter[16];
    memcpy(nonce_counter, iv, 16);
    check(mbedtls_aes_crypt_ctr(&aes_ctx, cipher_len, &nc_off, nonce_counter, stream_block, cipher, plain) == 0,
          "decrypt");
    mbedtls_aes_free(&aes_ctx);
  }

  // PKCS#7 unpad
  unsigned char pad = plain[cipher_len - 1];
  check(pad >= 1 && pad <= 16, "padding byte in range");
  bool pad_ok = true;
  for (size_t i = cipher_len - pad; i < cipher_len; i++) {
    if (plain[i] != pad) {
      pad_ok = false;
    }
  }
  check(pad_ok, "PKCS#7 padding is consistent");
  size_t env64_len = cipher_len - pad;
  plain[env64_len] = '\0';

  size_t env_len = 0;
  unsigned char *env_bytes = b64_decode_alloc((char *)plain, &env_len);
  check(env_bytes != NULL, "decode envelope");
  env_bytes[env_len] = '\0';

  cJSON *envelope = cJSON_Parse((char *)env_bytes);
  check(envelope != NULL, "parse envelope json");
  cJSON *p = cJSON_GetObjectItem(envelope, "p");
  check(cJSON_IsObject(p), "envelope has payload object");
  check(strcmp(cJSON_GetStringValue(cJSON_GetObjectItem(envelope, "ha")), "sha256") == 0, "ha is sha256");
  check(strcmp(cJSON_GetStringValue(cJSON_GetObjectItem(envelope, "sa")), "rsa2048") == 0, "sa is rsa2048");
  check(strcmp(cJSON_GetStringValue(cJSON_GetObjectItem(envelope, "sk")), TEST_SK_URI) == 0, "sk uri matches");
  check(strcmp(cJSON_GetStringValue(cJSON_GetObjectItem(p, "sid")), TEST_SESSION_ID) == 0, "sid matches");
  check(strcmp(cJSON_GetStringValue(cJSON_GetObjectItem(p, "c")), TEST_CHALLENGE) == 0, "challenge matches");
  check(strcmp(cJSON_GetStringValue(cJSON_GetObjectItem(p, "side")), "b") == 0, "side is b");

  // The relay verifies the signature over the compact re-serialization of p;
  // it must also be byte-identical to what the builder signed
  char *p_compact = cJSON_PrintUnformatted(p);
  char expected_p[512];
  snprintf(expected_p, sizeof(expected_p), "{\"sid\":\"%s\",\"c\":\"%s\",\"side\":\"b\"}", TEST_SESSION_ID,
           TEST_CHALLENGE);
  check(p_compact != NULL && strcmp(p_compact, expected_p) == 0, "payload serialization is compact and ordered");

  size_t sig_len = 0;
  unsigned char *sig = b64_decode_alloc(cJSON_GetStringValue(cJSON_GetObjectItem(envelope, "s")), &sig_len);
  check(sig != NULL && sig_len == 256, "signature is 256 bytes");
  check(atchops_rsa_verify(&public_key, ATCHOPS_MD_SHA256, (unsigned char *)p_compact, strlen(p_compact), sig) == 0,
        "signature verifies over compact payload");

  free(sig);
  cJSON_free(p_compact);
  cJSON_Delete(envelope);
  free(env_bytes);
  free(plain);
  free(cipher);
  free(iv_bytes);
  cJSON_Delete(outer);
  free(outer_bytes);
  free(line);
  atchops_rsa_key_private_key_free(&private_key);
  atchops_rsa_key_public_key_free(&public_key);

  if (failures > 0) {
    printf("%d failures\n", failures);
    return 1;
  }
  printf("all passed\n");
  return 0;
}
