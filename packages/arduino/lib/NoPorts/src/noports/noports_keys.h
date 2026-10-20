/**
 * @file noports_keys.h
 * @brief Helpers to load atKeys on ESP32 from SPIFFS/LittleFS or from C strings
 *
 * The original sshnpd reads keys from ~/.atsign/keys/@atsign_key.atKeys.
 * On Arduino/ESP32, we support:
 *   1. Hardcoded base64 strings in the sketch (simplest)
 *   2. Loading from SPIFFS/LittleFS file
 */

#ifndef NOPORTS_KEYS_H
#define NOPORTS_KEYS_H

#include <Arduino.h>
#include "noports_config.h"

/**
 * @brief Load atKeys from a JSON file stored on SPIFFS/LittleFS
 *
 * The file format is the standard .atKeys JSON:
 * {
 *   "aesPkamPublicKey": "...",
 *   "aesPkamPrivateKey": "...",
 *   "aesEncryptPublicKey": "...",
 *   "aesEncryptPrivateKey": "...",
 *   "selfEncryptionKey": "..."
 * }
 *
 * NOTE: The keys in .atKeys files are AES-encrypted with the selfEncryptionKey.
 * This function handles the decryption automatically.
 *
 * @param config Pointer to NoPortsConfig to populate with key data
 * @param filepath Path to the .atKeys file on SPIFFS (e.g. "/keys/atkeys.json")
 * @return 0 on success, non-zero on failure
 *
 * IMPORTANT: This function allocates memory for the key strings.
 *            Call noports_keys_free() when done.
 */
int noports_keys_load_from_file(NoPortsConfig *config, const char *filepath);

/**
 * @brief Set keys directly from pre-decrypted base64 strings
 *
 * Use this when you embed the keys directly in your sketch.
 * These should be the DECRYPTED PKAM and encryption keys (not the
 * AES-encrypted versions from the .atKeys file).
 *
 * To obtain decrypted keys:
 *   1. Use the at_activate tool to get your .atKeys file
 *   2. Use the selfEncryptionKey to decrypt each key
 *   3. Or use the at_c tools to export pre-decrypted keys
 *
 * @param config Pointer to NoPortsConfig
 * @param pkam_public  Base64 PKAM public key
 * @param pkam_private Base64 PKAM private key
 * @param enc_public   Base64 encryption public key
 * @param enc_private  Base64 encryption private key
 * @param self_enc_key Base64 self encryption key
 */
inline void noports_keys_set(NoPortsConfig *config,
                             const char *pkam_public,
                             const char *pkam_private,
                             const char *enc_public,
                             const char *enc_private,
                             const char *self_enc_key) {
  config->pkam_public_key_base64      = pkam_public;
  config->pkam_private_key_base64     = pkam_private;
  config->encrypt_public_key_base64   = enc_public;
  config->encrypt_private_key_base64  = enc_private;
  config->self_encryption_key_base64  = self_enc_key;
}

/**
 * @brief Free key memory allocated by noports_keys_load_from_file
 */
void noports_keys_free(NoPortsConfig *config);

#endif // NOPORTS_KEYS_H
