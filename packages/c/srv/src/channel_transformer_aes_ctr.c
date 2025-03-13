#include "channel_transformer_aes_ctr.h"
#include "channel_transformer.h"
#include <atlogger/atlogger.h>
#include <mbedtls/aes.h>
#include <mbedtls/base64.h>
#include <stdlib.h>

#define TAG "channel_transformer_aes_ctr"

struct aes_ctr_transformer_params {
  unsigned char decrypt_key[32];
  unsigned char decrypt_iv[16];
  unsigned char encrypt_key[32];
  unsigned char encrypt_iv[16];
  unsigned int decrypt_keybits;
  unsigned int encrypt_keybits;
};

#define aes_ctr_transformer_params_initializer                                 \
  (struct aes_ctr_transformer_params) {                                        \
    .decrypt_key = {0}, .decrypt_iv = {0}, .encrypt_key = {0},                 \
    .encrypt_iv = {0}, .decrypt_keybits = 0, .encrypt_keybits = 0,             \
  }

struct channel_transform_ctx_aes_ctr {
  struct channel_transformer interface;
  mbedtls_aes_context ctx;
  unsigned char nonce_counter[16];
  unsigned char stream_block[16];
  size_t nc_off;
};

static int get_hints_from_env(struct aes_ctr_transformer_params *hints);
static int aes_ctr_transform(struct channel_transformer *ctx,
                             const unsigned char *buffer, size_t len,
                             unsigned char *output, size_t *olen);
void free_aes_ctr_transformer(struct channel_transformer *ctx);

int create_local_to_remote_channel_transformer_aes_ctr(
    struct channel_transformer **transformer) {

  struct aes_ctr_transformer_params hints;
  int ret = get_hints_from_env(&hints);
  if (ret != 0)
    return 1;

  *transformer = malloc(sizeof(struct channel_transform_ctx_aes_ctr));

  if (*transformer == NULL)
    return 1;

  struct channel_transform_ctx_aes_ctr *state =
      (struct channel_transform_ctx_aes_ctr *)*transformer;

  mbedtls_aes_init(&state->ctx);
  ret = mbedtls_aes_setkey_enc(&state->ctx, hints.encrypt_key,
                               hints.encrypt_keybits);
  if (ret != 0) {
    free(*transformer);
    return ret;
  }

  for (int i = 0; i < 16; i++) {
    state->nonce_counter[i] = hints.encrypt_iv[i];
    state->stream_block[i] = 0;
  }
  state->nc_off = 0;

  state->interface.transform =
      (channel_transformer_transform *)&aes_ctr_transform;
  state->interface.free = &free_aes_ctr_transformer;

  return 0;
}

int create_remote_to_local_channel_transformer_aes_ctr(
    struct channel_transformer **transformer) {
  struct aes_ctr_transformer_params hints;
  int ret = get_hints_from_env(&hints);
  if (ret != 0)
    return 1;

  *transformer = malloc(sizeof(struct channel_transform_ctx_aes_ctr));

  if (*transformer == NULL)
    return 1;

  struct channel_transform_ctx_aes_ctr *state =
      (struct channel_transform_ctx_aes_ctr *)*transformer;

  mbedtls_aes_init(&state->ctx);
  ret = mbedtls_aes_setkey_dec(&state->ctx, hints.decrypt_key,
                               hints.decrypt_keybits);
  if (ret != 0) {
    free(*transformer);
    return ret;
  }

  for (int i = 0; i < 16; i++) {
    state->nonce_counter[i] = hints.decrypt_iv[i];
    state->stream_block[i] = 0;
  }
  state->nc_off = 0;

  state->interface.transform =
      (channel_transformer_transform *)&aes_ctr_transform;
  state->interface.free = &free_aes_ctr_transformer;

  return 0;
}

// Interface functions
static int aes_ctr_transform(struct channel_transformer *transformer,
                             const unsigned char *buffer, size_t len,
                             unsigned char *output, size_t *olen) {

  struct channel_transform_ctx_aes_ctr *state =
      (struct channel_transform_ctx_aes_ctr *)transformer;

  int res = mbedtls_aes_crypt_ctr(&state->ctx, len, &state->nc_off,
                                  state->nonce_counter, state->stream_block,
                                  buffer, output);
  if (res != 0) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to (en/de)crypt a chunk\n");
    return res;
  }

  *olen = len;
  return 0;
}

void free_aes_ctr_transformer(struct channel_transformer *transformer) {
  struct channel_transform_ctx_aes_ctr *state =
      (struct channel_transform_ctx_aes_ctr *)transformer;
  mbedtls_aes_free(&state->ctx);
  free(transformer);
}

// ENV setup

static char *decrypt_key_env[] = {
    "INBOUND_AES_KEY",
    "RV_AES",
};
#define decrypt_key_env_len                                                    \
  (sizeof(decrypt_key_env) / sizeof(decrypt_key_env[0]))

static char *encrypt_key_env[] = {
    "OUTBOUND_AES_KEY",
    "RV_AES",
};
#define encrypt_key_env_len                                                    \
  (sizeof(encrypt_key_env) / sizeof(encrypt_key_env[0]))

static char *decrypt_iv_env[] = {
    "INBOUND_AES_IV",
    "RV_IV",
};
#define decrypt_iv_env_len (sizeof(decrypt_iv_env) / sizeof(decrypt_iv_env[0]))

static char *encrypt_iv_env[] = {
    "OUTBOUND_AES_IV",
    "RV_IV",
};
#define encrypt_iv_env_len (sizeof(encrypt_iv_env) / sizeof(encrypt_iv_env[0]))

static int get_hints_from_env(struct aes_ctr_transformer_params *hints) {
  // decrypt key
  char *decrypt_key;
  for (size_t i = 0; i < decrypt_key_env_len; i++) {
    decrypt_key = getenv(decrypt_key_env[i]);
    if (decrypt_key != NULL)
      break;
  }
  if (decrypt_key == NULL) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Decryption key not found in environment, see help\n");
    return 1;
  }
  // decrypt iv
  char *decrypt_iv;
  for (size_t i = 0; i < decrypt_iv_env_len; i++) {
    decrypt_iv = getenv(decrypt_iv_env[i]);
    if (decrypt_iv != NULL)
      break;
  }
  if (decrypt_iv == NULL) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Decryption iv not found in environment, see help\n");
    return 1;
  }
  // encrypt key
  char *encrypt_key;
  for (size_t i = 0; i < encrypt_key_env_len; i++) {
    encrypt_key = getenv(decrypt_key_env[i]);
    if (encrypt_key != NULL)
      break;
  }
  if (encrypt_key == NULL) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Encryption key not found in environment, see help\n");
    return 1;
  }
  // encrypt iv
  char *encrypt_iv;
  for (size_t i = 0; i < encrypt_iv_env_len; i++) {
    encrypt_iv = getenv(decrypt_iv_env[i]);
    if (encrypt_iv != NULL)
      break;
  }
  if (encrypt_iv == NULL) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Encryption iv not found in environment, see help\n");
    return 1;
  }

#define base64_decode(dst, dstsize, src, olen, pretty_name)                    \
  {                                                                            \
    int ret;                                                                   \
    ret = mbedtls_base64_decode((unsigned char *)dst, dstsize, (size_t *)olen, \
                                (unsigned char *)src, strlen(src));            \
    if (ret != 0) {                                                            \
      atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,                          \
                   "Failed to base64 decode %s from environment\n",            \
                   pretty_name);                                               \
      return ret;                                                              \
    }                                                                          \
  }

  base64_decode(hints->decrypt_key, 32, decrypt_key, &hints->decrypt_keybits,
                "decrypt key");
  base64_decode(hints->encrypt_key, 32, encrypt_key, &hints->encrypt_keybits,
                "encrypt key");

  size_t temp;
  base64_decode(hints->decrypt_iv, 16, decrypt_iv, &temp, "decrypt iv");
  base64_decode(hints->encrypt_iv, 16, encrypt_iv, &temp, "encrypt iv");

  return 0;
}
