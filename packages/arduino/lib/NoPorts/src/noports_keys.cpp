/**
 * @file noports_keys.cpp
 * @brief Key loading implementation for ESP32
 *
 * Supports loading atKeys from SPIFFS/LittleFS JSON files.
 * The .atKeys format stores AES-encrypted keys which must be
 * decrypted using the selfEncryptionKey.
 */

#include "noports/noports_keys.h"
#include "noports/noports_log.h"
#include <FS.h>

// Try to use LittleFS first, fall back to SPIFFS
#if __has_include(<LittleFS.h>)
  #include <LittleFS.h>
  #define NOPORTS_FS LittleFS
#elif __has_include(<SPIFFS.h>)
  #include <SPIFFS.h>
  #define NOPORTS_FS SPIFFS
#else
  #error "No filesystem library available (need LittleFS or SPIFFS)"
#endif

// cJSON and atchops are bundled directly in this library
#include <mbedtls/aes.h>
#include <mbedtls/platform_util.h>  // mbedtls_platform_zeroize

extern "C" {
  #include "atclient/json.h"
  #include "atchops/aes.h"
  #include "atchops/aes_ctr.h"
  #include "atchops/base64.h"
  #include "atchops/iv.h"
}

#define TAG "noports_keys"

// Internal: AES-256-CTR decrypt a base64-encoded value using a base64-encoded key
// The atKeys format uses AES-CTR with a zero IV (legacy IV)
static int _decrypt_key(const char *encrypted_base64, const char *self_enc_key_base64,
                        char **out_decrypted_base64) {
  if (encrypted_base64 == NULL || self_enc_key_base64 == NULL || out_decrypted_base64 == NULL) {
    return -1;
  }

  // Decode the self-encryption key
  unsigned char aes_key[32];
  size_t aes_key_len = 0;
  int res = atchops_base64_decode(self_enc_key_base64, strlen(self_enc_key_base64),
                                  aes_key, sizeof(aes_key), &aes_key_len);
  if (res != 0 || aes_key_len != 32) {
    NOPORTS_LOGE(TAG, "Failed to decode self encryption key");
    return -1;
  }

  // Decode the encrypted value
  size_t enc_max_len = strlen(encrypted_base64);
  unsigned char *encrypted = (unsigned char *)malloc(enc_max_len);
  if (encrypted == NULL) return -1;

  size_t encrypted_len = 0;
  res = atchops_base64_decode(encrypted_base64, strlen(encrypted_base64),
                              encrypted, enc_max_len, &encrypted_len);
  if (res != 0) {
    NOPORTS_LOGE(TAG, "Failed to decode encrypted key");
    mbedtls_platform_zeroize(aes_key, sizeof(aes_key));
    free(encrypted);
    return -1;
  }

  // Decrypt using AES-256-CTR with zero IV (legacy atKeys format)
  unsigned char iv[ATCHOPS_IV_BUFFER_SIZE];
  memset(iv, 0, sizeof(iv));

  size_t plaintext_size = encrypted_len + 1;
  unsigned char *plaintext = (unsigned char *)malloc(plaintext_size);
  if (plaintext == NULL) {
    mbedtls_platform_zeroize(aes_key, sizeof(aes_key));
    free(encrypted);
    return -1;
  }

  size_t plaintext_len = 0;
  res = atchops_aes_ctr_decrypt(aes_key, ATCHOPS_AES_256, iv,
                                encrypted, encrypted_len,
                                plaintext, plaintext_size, &plaintext_len);
  // the decoded self-encryption key is no longer needed on the stack
  mbedtls_platform_zeroize(aes_key, sizeof(aes_key));
  free(encrypted);

  if (res != 0) {
    NOPORTS_LOGE(TAG, "AES-CTR decryption failed: %d", res);
    free(plaintext);
    return -1;
  }

  plaintext[plaintext_len] = '\0';

  // The decrypted value is the base64-encoded key itself
  *out_decrypted_base64 = (char *)plaintext;
  return 0;
}

int noports_keys_load_from_file(NoPortsConfig *config, const char *filepath) {
  if (config == NULL || filepath == NULL) {
    return -1;
  }

  // Initialize filesystem if needed
  if (!NOPORTS_FS.begin(true)) {
    NOPORTS_LOGE(TAG, "Failed to mount filesystem");
    return -1;
  }

  File f = NOPORTS_FS.open(filepath, "r");
  if (!f) {
    NOPORTS_LOGE(TAG, "Failed to open keys file: %s", filepath);
    return -1;
  }

  size_t size = f.size();
  char *buf = (char *)malloc(size + 1);
  if (buf == NULL) {
    f.close();
    NOPORTS_LOGE(TAG, "Failed to allocate buffer for keys file");
    return -1;
  }

  f.readBytes(buf, size);
  buf[size] = '\0';
  f.close();

  // Parse JSON
  cJSON *root = cJSON_Parse(buf);
  free(buf);

  if (root == NULL) {
    NOPORTS_LOGE(TAG, "Failed to parse keys JSON");
    return -1;
  }

  // Extract the self encryption key first (it's not encrypted)
  cJSON *self_enc = cJSON_GetObjectItem(root, "selfEncryptionKey");
  if (self_enc == NULL || !cJSON_IsString(self_enc)) {
    NOPORTS_LOGE(TAG, "Missing selfEncryptionKey in keys file");
    cJSON_Delete(root);
    return -1;
  }

  const char *self_enc_key = cJSON_GetStringValue(self_enc);

  // Save a copy of the self encryption key
  config->self_encryption_key_base64 = strdup(self_enc_key);

  // Decrypt each key using the self encryption key
  int res = 0;

  cJSON *pkam_pub  = cJSON_GetObjectItem(root, "aesPkamPublicKey");
  cJSON *pkam_priv = cJSON_GetObjectItem(root, "aesPkamPrivateKey");
  cJSON *enc_pub   = cJSON_GetObjectItem(root, "aesEncryptPublicKey");
  cJSON *enc_priv  = cJSON_GetObjectItem(root, "aesEncryptPrivateKey");

  char *dec = NULL;

  if (pkam_pub && cJSON_IsString(pkam_pub)) {
    res = _decrypt_key(cJSON_GetStringValue(pkam_pub), self_enc_key, &dec);
    if (res == 0) { config->pkam_public_key_base64 = dec; dec = NULL; }
    else { NOPORTS_LOGE(TAG, "Failed to decrypt PKAM public key"); }
  }

  if (res == 0 && pkam_priv && cJSON_IsString(pkam_priv)) {
    res = _decrypt_key(cJSON_GetStringValue(pkam_priv), self_enc_key, &dec);
    if (res == 0) { config->pkam_private_key_base64 = dec; dec = NULL; }
    else { NOPORTS_LOGE(TAG, "Failed to decrypt PKAM private key"); }
  }

  if (res == 0 && enc_pub && cJSON_IsString(enc_pub)) {
    res = _decrypt_key(cJSON_GetStringValue(enc_pub), self_enc_key, &dec);
    if (res == 0) { config->encrypt_public_key_base64 = dec; dec = NULL; }
    else { NOPORTS_LOGE(TAG, "Failed to decrypt encryption public key"); }
  }

  if (res == 0 && enc_priv && cJSON_IsString(enc_priv)) {
    res = _decrypt_key(cJSON_GetStringValue(enc_priv), self_enc_key, &dec);
    if (res == 0) { config->encrypt_private_key_base64 = dec; dec = NULL; }
    else { NOPORTS_LOGE(TAG, "Failed to decrypt encryption private key"); }
  }

  // Extract enrollment ID (not encrypted, plain string)
  cJSON *enroll_id = cJSON_GetObjectItem(root, "enrollmentId");
  if (enroll_id && cJSON_IsString(enroll_id)) {
    config->enrollment_id = strdup(cJSON_GetStringValue(enroll_id));
  }

  cJSON_Delete(root);

  if (res != 0) {
    noports_keys_free(config);
  } else {
    NOPORTS_LOGI(TAG, "Successfully loaded atKeys from %s", filepath);
  }

  return res;
}

void noports_keys_free(NoPortsConfig *config) {
  if (config == NULL) return;

  // Free any allocated key strings
  // Note: only free if they were allocated by _decrypt_key (via malloc)
  if (config->pkam_public_key_base64) {
    free((void*)config->pkam_public_key_base64);
    config->pkam_public_key_base64 = NULL;
  }
  if (config->pkam_private_key_base64) {
    free((void*)config->pkam_private_key_base64);
    config->pkam_private_key_base64 = NULL;
  }
  if (config->encrypt_public_key_base64) {
    free((void*)config->encrypt_public_key_base64);
    config->encrypt_public_key_base64 = NULL;
  }
  if (config->encrypt_private_key_base64) {
    free((void*)config->encrypt_private_key_base64);
    config->encrypt_private_key_base64 = NULL;
  }
  if (config->self_encryption_key_base64) {
    free((void*)config->self_encryption_key_base64);
    config->self_encryption_key_base64 = NULL;
  }
  if (config->enrollment_id) {
    free((void*)config->enrollment_id);
    config->enrollment_id = NULL;
  }
}
