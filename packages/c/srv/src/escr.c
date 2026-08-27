#include "srv/escr.h"
#include "srv/srv.h"
#include <atchops/base64.h>
#include <atchops/iv.h>
#include <atchops/rsa.h>
#include <atlogger/atlogger.h>
#include <mbedtls/aes.h>
#include <mbedtls/net_sockets.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define TAG "srv - escr"

// The relay writes the challenge immediately on accept and answers the
// response promptly; anything slower than this is a dead connection
#define ESCR_IO_TIMEOUT_MS 10000

// RSA-2048 signature size; the PKAM signing key is always RSA-2048
#define ESCR_RSA_SIG_BYTES 256

// The relay rejects auth lines longer than 4096 bytes, and its own challenge
// is a 44 char base64 string; be generous on the read side regardless
#define ESCR_MAX_LINE 4096

// The JSON in the auth exchange is built with snprintf rather than a JSON
// library, which is only byte-compatible with Dart's jsonEncode when none of
// the embedded strings need escaping. Everything we embed is base64, a uuid,
// or an atProtocol key uri, so restricting to printable ASCII minus the two
// JSON specials is both safe and byte-exact.
static bool json_safe(const char *s) {
  for (const unsigned char *p = (const unsigned char *)s; *p != '\0'; p++) {
    if (*p < 32 || *p > 126 || *p == '"' || *p == '\\') {
      return false;
    }
  }
  return true;
}

static char *base64_encode_alloc(const unsigned char *src, size_t len) {
  size_t dstsize = (len / 3 + 2) * 4 + 4;
  char *dst = malloc(dstsize);
  if (dst == NULL) {
    return NULL;
  }
  size_t dstlen = 0;
  if (atchops_base64_encode(src, len, dst, dstsize, &dstlen) != 0) {
    free(dst);
    return NULL;
  }
  dst[dstlen] = '\0';
  return dst;
}

int srv_escr_build_response(const char *session_id, const char *challenge, const char *aes_key_base64,
                            const char *signing_key_uri, const atchops_rsa_key_private_key *signing_key, bool is_side_a,
                            const unsigned char iv[16], char **out_line) {
  int ret = 1;

  char *p_json = NULL;
  char *sig_b64 = NULL;
  char *env_json = NULL;
  char *env64 = NULL;
  unsigned char *padded = NULL;
  unsigned char *encrypted = NULL;
  char *enc_b64 = NULL;
  char *outer_json = NULL;
  char *auth_payload64 = NULL;

  *out_line = NULL;

  if (!json_safe(session_id) || !json_safe(challenge) || !json_safe(signing_key_uri)) {
    atlogger_log(TAG, ERROR, "Refusing to build escr response: input contains characters that need JSON escaping\n");
    return 1;
  }

  // Inner signed payload. The relay re-serializes this map with Dart's
  // jsonEncode and verifies the signature against that, so the bytes must be
  // compact JSON in exactly this key order.
  size_t p_size = strlen(session_id) + strlen(challenge) + 32;
  p_json = malloc(p_size);
  if (p_json == NULL) {
    goto exit;
  }
  snprintf(p_json, p_size, "{\"sid\":\"%s\",\"c\":\"%s\",\"side\":\"%s\"}", session_id, challenge,
           is_side_a ? "a" : "b");

  // Sign the payload bytes: RSASSA-PKCS1-v1_5 over SHA-256
  unsigned char sig[ESCR_RSA_SIG_BYTES];
  if (atchops_rsa_sign(signing_key, ATCHOPS_MD_SHA256, (unsigned char *)p_json, strlen(p_json), sig) != 0) {
    atlogger_log(TAG, ERROR, "Failed to sign escr challenge payload\n");
    goto exit;
  }
  sig_b64 = base64_encode_alloc(sig, ESCR_RSA_SIG_BYTES);
  if (sig_b64 == NULL) {
    goto exit;
  }

  // Envelope: payload, signature, algorithm names and the signing key uri
  size_t env_size = strlen(p_json) + strlen(sig_b64) + strlen(signing_key_uri) + 64;
  env_json = malloc(env_size);
  if (env_json == NULL) {
    goto exit;
  }
  snprintf(env_json, env_size, "{\"p\":%s,\"s\":\"%s\",\"ha\":\"sha256\",\"sa\":\"rsa2048\",\"sk\":\"%s\"}", p_json,
           sig_b64, signing_key_uri);

  env64 = base64_encode_alloc((unsigned char *)env_json, strlen(env_json));
  if (env64 == NULL) {
    goto exit;
  }

  // Decode the relay auth AES key
  unsigned char aes_key[32];
  size_t aes_key_len = 0;
  if (atchops_base64_decode(aes_key_base64, strlen(aes_key_base64), aes_key, sizeof(aes_key), &aes_key_len) != 0 ||
      aes_key_len != 32) {
    atlogger_log(TAG, ERROR, "relay auth AES key is not a base64 encoded 32 byte key\n");
    goto exit;
  }

  // PKCS#7 pad the base64 envelope, then AES-256-CTR encrypt it. The padding
  // is redundant for a stream mode, but the relay's decrypt path removes and
  // validates it, so it is part of the wire format.
  size_t env64_len = strlen(env64);
  size_t pad = 16 - (env64_len % 16); // always 1..16
  size_t padded_len = env64_len + pad;
  padded = malloc(padded_len);
  encrypted = malloc(padded_len);
  if (padded == NULL || encrypted == NULL) {
    goto exit;
  }
  memcpy(padded, env64, env64_len);
  memset(padded + env64_len, (unsigned char)pad, pad);

  {
    mbedtls_aes_context aes_ctx;
    mbedtls_aes_init(&aes_ctx);
    int res = mbedtls_aes_setkey_enc(&aes_ctx, aes_key, 256);
    if (res == 0) {
      size_t nc_off = 0;
      unsigned char stream_block[16] = {0};
      unsigned char nonce_counter[16];
      memcpy(nonce_counter, iv, 16);
      res = mbedtls_aes_crypt_ctr(&aes_ctx, padded_len, &nc_off, nonce_counter, stream_block, padded, encrypted);
    }
    mbedtls_aes_free(&aes_ctx);
    if (res != 0) {
      atlogger_log(TAG, ERROR, "Failed to encrypt escr envelope: %d\n", res);
      goto exit;
    }
  }

  char iv_b64[32];
  size_t iv_b64_len = 0;
  if (atchops_base64_encode(iv, 16, iv_b64, sizeof(iv_b64), &iv_b64_len) != 0) {
    goto exit;
  }
  iv_b64[iv_b64_len] = '\0';

  enc_b64 = base64_encode_alloc(encrypted, padded_len);
  if (enc_b64 == NULL) {
    goto exit;
  }

  size_t outer_size = strlen(iv_b64) + strlen(enc_b64) + 24;
  outer_json = malloc(outer_size);
  if (outer_json == NULL) {
    goto exit;
  }
  snprintf(outer_json, outer_size, "{\"iv\":\"%s\",\"e\":\"%s\"}", iv_b64, enc_b64);

  auth_payload64 = base64_encode_alloc((unsigned char *)outer_json, strlen(outer_json));
  if (auth_payload64 == NULL) {
    goto exit;
  }

  size_t line_size = strlen(session_id) + strlen(auth_payload64) + 2;
  *out_line = malloc(line_size);
  if (*out_line == NULL) {
    goto exit;
  }
  snprintf(*out_line, line_size, "%s:%s", session_id, auth_payload64);

  if (strlen(*out_line) > ESCR_MAX_LINE - 1) {
    atlogger_log(TAG, ERROR, "escr response line exceeds the relay's %d byte limit\n", ESCR_MAX_LINE);
    free(*out_line);
    *out_line = NULL;
    goto exit;
  }

  ret = 0;

exit:
  free(p_json);
  free(sig_b64);
  free(env_json);
  free(env64);
  free(padded);
  free(encrypted);
  free(enc_b64);
  free(outer_json);
  free(auth_payload64);
  return ret;
}

// Read one newline-terminated line, a byte at a time (the handshake is tiny,
// and byte-wise reads mean no bytes past the newline are consumed - anything
// after the relay's "ok" already belongs to the session)
static int escr_read_line(mbedtls_net_context *socket, char *buf, size_t buflen) {
  size_t pos = 0;
  while (pos < buflen - 1) {
    unsigned char b;
    int res = mbedtls_net_recv_timeout(socket, &b, 1, ESCR_IO_TIMEOUT_MS);
    if (res == MBEDTLS_ERR_SSL_TIMEOUT) {
      atlogger_log(TAG, ERROR, "Timed out waiting for relay during escr auth\n");
      return 1;
    }
    if (res <= 0) {
      atlogger_log(TAG, ERROR, "Connection error during escr auth: %d\n", res);
      return 1;
    }
    if (b == '\n') {
      buf[pos] = '\0';
      return 0;
    }
    buf[pos++] = (char)b;
  }
  atlogger_log(TAG, ERROR, "Line from relay exceeded %zu bytes during escr auth\n", buflen);
  return 1;
}

static int escr_send_all(mbedtls_net_context *socket, const unsigned char *buf, size_t len) {
  size_t sent = 0;
  while (sent < len) {
    int res = mbedtls_net_send(socket, buf + sent, len - sent);
    if (res < 0) {
      atlogger_log(TAG, ERROR, "Failed to send escr response: %d\n", res);
      return 1;
    }
    sent += res;
  }
  return 0;
}

int srv_escr_authenticate(mbedtls_net_context *socket, const srv_params_t *params) {
  if (params->escr_session_id == NULL || params->escr_aes_key_base64 == NULL || params->escr_signing_key_uri == NULL ||
      params->escr_signing_key == NULL) {
    atlogger_log(TAG, ERROR, "escr auth requested but escr parameters are incomplete\n");
    return 1;
  }

  char challenge[ESCR_MAX_LINE];
  if (escr_read_line(socket, challenge, sizeof(challenge)) != 0) {
    return 1;
  }

  unsigned char iv[16];
  if (atchops_iv_generate(iv) != 0) {
    atlogger_log(TAG, ERROR, "Failed to generate iv for escr auth\n");
    return 1;
  }

  char *line = NULL;
  int res = srv_escr_build_response(params->escr_session_id, challenge, params->escr_aes_key_base64,
                                    params->escr_signing_key_uri, params->escr_signing_key, params->escr_is_side_a, iv,
                                    &line);
  if (res != 0) {
    return res;
  }

  res = escr_send_all(socket, (unsigned char *)line, strlen(line));
  free(line);
  if (res == 0) {
    res = escr_send_all(socket, (const unsigned char *)"\n", 1);
  }
  if (res != 0) {
    return res;
  }

  char reply[64];
  if (escr_read_line(socket, reply, sizeof(reply)) != 0) {
    return 1;
  }
  if (strcmp(reply, "ok") != 0) {
    atlogger_log(TAG, ERROR, "Relay rejected escr auth: %s\n", reply);
    return 1;
  }

  atlogger_log(TAG, DEBUG, "escr auth succeeded\n");
  return 0;
}
