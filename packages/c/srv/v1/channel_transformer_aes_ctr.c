#include "channel_transformer_aes_ctr.h"
#include "channel_transformer.h"
#include <atlogger/atlogger.h>
#include <mbedtls/aes.h>
#include <mbedtls/base64.h>

#define TAG "channel_transformer_aes_ctr"

struct channel_transform_ctx_aes_ctr {
  struct channel_transform_ctx self;
};

// METHODS
static int create_aes_ctr_transform_ctx_from_environment(
    struct channel_transform_ctx *decrypt_ctx,
    struct channel_transform_ctx *encrypt_ctx);

static int
create_aes_ctr_transform_ctx(struct aes_ctr_transformer_params *hints,
                             struct channel_transform_ctx *decrypt_ctx,
                             struct channel_transform_ctx *encrypt_ctx);

static int aes_ctr_transform(struct channel_transform_ctx *ctx,
                             const unsigned char *buffer, uint16_t len,
                             unsigned char *output, uint16_t *olen);

static void free_aes_ctr_transform_ctx(struct channel_transform_ctx *ctx);

// END OF METHODS

static int get_hints_from_env(struct aes_ctr_transformer_params *hints);
int create_aes_ctr_transform_ctx_from_environment(
    struct channel_transform_ctx *decrypt_ctx,
    struct channel_transform_ctx *encrypt_ctx) {
  int ret;

  struct aes_ctr_transformer_params params =
      aes_ctr_transformer_params_initializer;
  ret = get_hints_from_env(&params);
  if (ret != 0) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to derive aes parameters from the environment\n");
    return ret;
  }

  return create_aes_ctr_transform_ctx(&params, decrypt_ctx, encrypt_ctx);
}

int create_aes_ctr_transform_ctx(struct aes_ctr_transformer_params *hints,
                                 struct channel_transform_ctx *decrypt_ctx,
                                 struct channel_transform_ctx *encrypt_ctx) {
  int res = 0;

  atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_DEBUG,
               "Configuring aes tranformer for srv\n");

  struct aes_ctr_transformer_state *enc = &encrypt_ctx->aes_ctr;
  mbedtls_aes_init(&enc->ctx);
  res = mbedtls_aes_setkey_enc(&enc->ctx, hints->encrypt_key,
                               hints->encrypt_keybits);
  if (res != 0) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to populate the encrypter key\n");
    mbedtls_aes_free(&enc->ctx);
    return res;
  }

  struct aes_ctr_transformer_state *dec = &decrypt_ctx->aes_ctr;
  mbedtls_aes_init(&dec->ctx);
  res = mbedtls_aes_setkey_dec(&dec->ctx, hints->decrypt_key,
                               hints->decrypt_keybits);
  if (res != 0) {
    atlogger_log(TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to populate the decrypter key\n");
    mbedtls_aes_free(&enc->ctx);
    mbedtls_aes_free(&dec->ctx);
    return res;
  }

  memcpy(encrypt_ctx->aes_ctr.nonce_counter, hints->encrypt_iv, 16);
  memset(enc->stream_block, 0, 16);
  enc->nc_off = 0;

  memcpy(decrypt_ctx->aes_ctr.nonce_counter, hints->decrypt_iv, 16);
  memset(dec->stream_block, 0, 16);
  dec->nc_off = 0;

  return 0;
}

int aes_ctr_transform(struct channel_transform_ctx *ctx,
                      const unsigned char *buffer, uint16_t len,
                      unsigned char *output, uint16_t *olen) {

  struct aes_ctr_transformer_state *state = &ctx->aes_ctr;

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

void free_aes_ctr_transform_ctx(struct channel_transform_ctx *ctx) {
  mbedtls_aes_free(&ctx->aes_ctr.ctx);
}

static char *decrypt_key_env[] = {
    "REMOTE_INBOUND_AES_KEY",
    "RV_AES",
};
#define decrypt_key_env_len                                                    \
  (sizeof(decrypt_key_env) / sizeof(decrypt_key_env[0]))

static char *encrypt_key_env[] = {
    "REMOTE_OUTBOUND_AES_KEY",
    "RV_AES",
};
#define encrypt_key_env_len                                                    \
  (sizeof(encrypt_key_env) / sizeof(encrypt_key_env[0]))

static char *decrypt_iv_env[] = {
    "REMOTE_INBOUND_AES_IV",
    "RV_IV",
};
#define decrypt_iv_env_len (sizeof(decrypt_iv_env) / sizeof(decrypt_iv_env[0]))

static char *encrypt_iv_env[] = {
    "REMOTE_OUTBOUND_AES_IV",
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
