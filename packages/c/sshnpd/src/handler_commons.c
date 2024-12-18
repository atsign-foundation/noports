#include "atchops/aes.h"
#include "atchops/base64.h"
#include "atchops/iv.h"
#include "atchops/rsa.h"
#include "atclient/notify.h"
#include "atclient/notify_params.h"
#include "sshnpd/params.h"
#include "sshnpd/sshnpd.h"
#include <atchops/constants.h>
#include <atchops/rsa_key.h>
#include <atclient/cjson.h>
#include <atlogger/atlogger.h>
#include <sshnpd/handler_commons.h>
#include <stdlib.h>
#include <string.h>

#define LOGGER_TAG "HANDLER_COMMONS"

int verify_envelope_signature_from(cJSON *envelope, char *requesting_atsign, atclient *atclient,
                                   pthread_mutex_t *atclient_lock) {
  cJSON *signature = cJSON_GetObjectItem(envelope, "signature");
  cJSON *hashing_algo = cJSON_GetObjectItem(envelope, "hashingAlgo");
  cJSON *signing_algo = cJSON_GetObjectItem(envelope, "signingAlgo");
  cJSON *payload = cJSON_GetObjectItem(envelope, "payload");

  int res = 0;
  atclient_atkey atkey;
  atclient_atkey_init(&atkey);

  if ((res = atclient_atkey_create_public_key(&atkey, "publickey", requesting_atsign, NULL)) != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to create public key\n");
    return 1;
  }

  res = pthread_mutex_lock(atclient_lock);
  if (res != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to get a lock on atclient for sending a notification\n");
    atclient_atkey_free(&atkey);
    return 1;
  } else {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Locked the atclient\n");
  }
  // TODO lock wrap
  char *buffer = NULL;
  res = atclient_get_public_key(atclient, &atkey, &buffer, NULL);
  atclient_atkey_free(&atkey);
  if (res != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to get public key\n");
    return 1;
  }

  res = pthread_mutex_unlock(atclient_lock);
  if (res != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to release atclient lock\n");
    exit(1);
  } else {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Released the atclient lock\n");
  }

  atchops_rsa_key_public_key requesting_atsign_publickey;
  atchops_rsa_key_public_key_init(&requesting_atsign_publickey);

  res = atchops_rsa_key_populate_public_key(&requesting_atsign_publickey, buffer, strlen(buffer));
  if (res != 0) {
    printf("atchops_rsakey_populate_publickey (failed): %d\n", res);
    return 1;
  }

  char *signature_str = cJSON_GetStringValue(signature);
  char *hashing_algo_str = cJSON_GetStringValue(hashing_algo);
  char *signing_algo_str = cJSON_GetStringValue(signing_algo);

  size_t valueolen = 0;
  res = atchops_base64_decode((unsigned char *)signature_str, strlen(signature_str), (unsigned char *)buffer,
                              strlen(buffer), &valueolen);

  if (res != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "atchops_base64_decode: %d\n", res);
    free(buffer);
    return 1;
  }

  char *payloadstr = cJSON_PrintUnformatted(payload);
  res = verify_envelope_signature(&requesting_atsign_publickey, (const unsigned char *)payloadstr,
                                  (unsigned char *)buffer, hashing_algo_str, signing_algo_str);

  free(buffer);
  atchops_rsa_key_public_key_free(&requesting_atsign_publickey);
  cJSON_free(payloadstr);

  if (res != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to verify envelope signature\n");
  }

  return res;
}

int verify_envelope_signature(atchops_rsa_key_public_key *publickey, const unsigned char *payload,
                              unsigned char *signature, const char *hashing_algo, const char *signing_algo) {
  int ret = 0;

  atchops_md_type mdtype;

  if (strcmp(hashing_algo, "sha256") == 0) {
    mdtype = ATCHOPS_MD_SHA256;
  } else {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Unsupported hash type for envelope verify\n");
    return -1;
  }
  if (strcmp(signing_algo, "rsa2048") == 0) {
    ret = atchops_rsa_verify(publickey, mdtype, payload, strlen((char *)payload), signature);
    if (ret != 0) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "verify_envelope_signature (failed)\n");
      return -1;
    }
  } else {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Unsupported signing algo for envelope verify");
    return -1;
  }

  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "verify_envelope_signature (success)\n");

  return ret;
}

cJSON *extract_envelope_from_notification(atclient_monitor_response *message) {
  // Sanity check the notification
  if (!atclient_atnotification_is_from_initialized(&message->notification) && message->notification.from != NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to initialize the from field of the notification\n");
    return NULL;
  }

  if (!atclient_atnotification_is_decrypted_value_initialized(&message->notification) &&
      message->notification.decrypted_value != NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to initialize the decrypted value of the notification\n");
    return NULL;
  }

  // Get the decrypted envelope
  char *decrypted_json = malloc(sizeof(char) * (strlen(message->notification.decrypted_value) + 1));
  if (decrypted_json == NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to allocate memory to decrypt the envelope\n");
    return NULL;
  }

  memcpy(decrypted_json, message->notification.decrypted_value, strlen(message->notification.decrypted_value));
  *(decrypted_json + strlen(message->notification.decrypted_value)) = '\0';

  // log the decrypted json
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Decrypted json: %s\n", decrypted_json);

  // Parse it to cJSON*
  cJSON *envelope = cJSON_Parse(decrypted_json);
  free(decrypted_json);
  if (envelope == NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to parse the decrypted notification\n");
  }
  return envelope;
}

int verify_envelope_contents(cJSON *envelope, enum payload_type type) {
  bool has_valid_values = cJSON_IsObject(envelope);

  if (!has_valid_values) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to parse the envelope\n");
    return 1;
  }

  // These 4 values are always required for a signed envelope
  cJSON *payload = cJSON_GetObjectItem(envelope, "payload");
  has_valid_values = has_valid_values && cJSON_IsObject(payload) &&
                     cJSON_IsString(cJSON_GetObjectItem(envelope, "signature")) &&
                     cJSON_IsString(cJSON_GetObjectItem(envelope, "hashingAlgo")) &&
                     cJSON_IsString(cJSON_GetObjectItem(envelope, "signingAlgo"));

  if (!has_valid_values) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Received invalid envelope format\n");
    return 1;
  }

  return verify_payload_contents(payload, type);
}

int verify_payload_contents(cJSON *payload, enum payload_type type) {
  bool has_valid_values = cJSON_IsObject(payload);

  has_valid_values = cJSON_IsString(cJSON_GetObjectItem(payload, "sessionId"));

  switch (type) {
  case payload_type_ssh: {
    cJSON *direct = cJSON_GetObjectItem(payload, "direct");
    has_valid_values = cJSON_IsBool(direct);

    if (!has_valid_values) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Couldn't determine if payload is direct\n");
      return 1;
    }

    if (!cJSON_IsTrue(direct)) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Only direct mode is supported by this device\n");
      return 1;
    }

    has_valid_values = has_valid_values && cJSON_IsString(cJSON_GetObjectItem(payload, "host")) &&
                       cJSON_IsNumber(cJSON_GetObjectItem(payload, "port"));
    break;
  }
  case payload_type_npt: {
    has_valid_values = has_valid_values && cJSON_IsString(cJSON_GetObjectItem(payload, "rvdHost")) &&
                       cJSON_IsNumber(cJSON_GetObjectItem(payload, "rvdPort")) &&
                       cJSON_IsString(cJSON_GetObjectItem(payload, "requestedHost"));

    cJSON *requested_port = cJSON_GetObjectItem(payload, "requestedPort");
    has_valid_values = has_valid_values && cJSON_IsNumber(requested_port) && cJSON_GetNumberValue(requested_port) > 0;
    break;
  }
  }

  if (!has_valid_values) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Received invalid payload format\n");
    return 1;
  }
  return 0;
}

int create_rvd_auth_string(cJSON *payload, atchops_rsa_key_private_key *signing_key, char **rvd_auth_string) {

  (void)(rvd_auth_string); // Tell the compiler to be quiet about output parameters

  cJSON *client_nonce = cJSON_GetObjectItem(payload, "clientNonce");
  cJSON *rvd_nonce = cJSON_GetObjectItem(payload, "rvdNonce");
  bool has_valid_values = cJSON_IsString(client_nonce) && cJSON_IsString(rvd_nonce);

  if (!has_valid_values) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Missing nonce values, cannot create auth string for rvd\n");
    return 1;
  }

  cJSON *rvd_auth_payload = cJSON_CreateObject();
  cJSON *session_id = cJSON_GetObjectItem(payload, "sessionId");
  cJSON_AddItemReferenceToObject(rvd_auth_payload, "sessionId", session_id);
  cJSON_AddItemReferenceToObject(rvd_auth_payload, "clientNonce", client_nonce);
  cJSON_AddItemReferenceToObject(rvd_auth_payload, "rvdNonce", rvd_nonce);

  cJSON *res_envelope = cJSON_CreateObject();
  cJSON_AddItemReferenceToObject(res_envelope, "payload", rvd_auth_payload);

  char *signing_input = cJSON_PrintUnformatted(rvd_auth_payload);
  unsigned char signature[256];
  memset(signature, 0, BYTES(256));
  int res = atchops_rsa_sign(signing_key, ATCHOPS_MD_SHA256, (unsigned char *)signing_input,
                             strlen((char *)signing_input), signature);
  cJSON_free(signing_input);
  if (res != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to sign the auth string payload\n");
    cJSON_Delete(rvd_auth_payload);
    cJSON_Delete(res_envelope);
    return res;
  }

  unsigned char base64signature[384];
  memset(base64signature, 0, BYTES(384));

  size_t sig_len;
  res = atchops_base64_encode(signature, 256, base64signature, 384, &sig_len);
  if (res != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to base64 encode the auth string payload\n");
    cJSON_Delete(rvd_auth_payload);
    cJSON_Delete(res_envelope);
    return res;
  }

  cJSON_AddItemToObject(res_envelope, "signature", cJSON_CreateString((char *)base64signature));
  cJSON_AddItemToObject(res_envelope, "hashingAlgo", cJSON_CreateString("sha256"));
  cJSON_AddItemToObject(res_envelope, "signingAlgo", cJSON_CreateString("rsa2048"));

  *rvd_auth_string = cJSON_PrintUnformatted(res_envelope);
  cJSON_Delete(rvd_auth_payload);
  cJSON_Delete(res_envelope);

  if (*rvd_auth_string == NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to write auth string from rvd auth envelope\n");
    return 1;
  }
  return 0;
}

int setup_rvd_session_encryption(cJSON *payload, unsigned char **session_aes_key,
                                 unsigned char **session_aes_key_base64, unsigned char **session_iv,
                                 unsigned char **session_iv_base64) {
  cJSON *client_ephemeral_pk = cJSON_GetObjectItem(payload, "clientEphemeralPK");
  cJSON *client_ephemeral_pk_type = cJSON_GetObjectItem(payload, "clientEphemeralPKType");
  unsigned char key[32], iv[16];
  unsigned char *session_aes_key_encrypted, *session_iv_encrypted;
  size_t session_aes_key_len, session_iv_len, session_aes_key_encrypted_len, session_iv_encrypted_len;

  bool is_valid = false;
  bool has_valid_values = cJSON_IsString(client_ephemeral_pk) && cJSON_IsString(client_ephemeral_pk_type);
  if (!has_valid_values) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "encryptRvdTraffic was requested, but no client ephemeral public key / key type was provided\n");
    return 1;
  }
  int res = 0;

  memset(key, 0, BYTES(32));
  if ((res = atchops_aes_generate_key(key, ATCHOPS_AES_256)) != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to generate session aes key\n");
    return res;
  }

  *session_aes_key = malloc(sizeof(unsigned char) * 49);
  if (*session_aes_key == NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "unable to allocate memory for: session_aes_key");
    free(*session_aes_key);
    return 1;
  }

  memset(*session_aes_key, 0, BYTES(49));
  res = atchops_base64_encode(key, 32, *session_aes_key, 49, &session_aes_key_len);
  if (res != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to generate session aes key\n");
    free(*session_aes_key);
    return res;
  }

  memset(iv, 0, BYTES(16));
  if ((res = atchops_iv_generate(iv)) != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to generate session iv\n");
    free(*session_aes_key);
    return res;
  }

  *session_iv = malloc(sizeof(unsigned char) * 25);
  if (*session_iv == NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "unable to allocate memory for: session_iv");
    free(*session_aes_key);
    return 1;
  }

  memset(*session_iv, 0, BYTES(25));
  res = atchops_base64_encode(iv, 16, *session_iv, 25, &session_iv_len);
  if (res != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to generate session iv\n");
    free(*session_aes_key);
    free(*session_iv);
    return res;
  }

  char *pk_type = cJSON_GetStringValue(client_ephemeral_pk_type);
  char *pk = cJSON_GetStringValue(client_ephemeral_pk);

  switch (strlen(pk_type)) {
  case 7: { // rsa2048 is the only valid type right now
    if (strncmp(pk_type, "rsa2048", 7) == 0) {
      is_valid = true;
      atchops_rsa_key_public_key ac;
      atchops_rsa_key_public_key_init(&ac);

      res = atchops_rsa_key_populate_public_key(&ac, pk, strlen(pk));
      if (res != 0) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to populate client ephemeral pk\n");
        atchops_rsa_key_public_key_free(&ac);
        free(*session_aes_key);
        free(*session_iv);
        return res;
      }

      session_aes_key_encrypted = malloc(BYTES(256));
      if (session_aes_key_encrypted == NULL) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                     "Failed to allocate memory to encrypt the session aes key\n");
        atchops_rsa_key_public_key_free(&ac);
        free(*session_aes_key);
        free(*session_iv);
        return 1;
      }

      res = atchops_rsa_encrypt(&ac, *session_aes_key, session_aes_key_len, session_aes_key_encrypted);
      if (res != 0) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to encrypt the session aes key\n");
        atchops_rsa_key_public_key_free(&ac);
        free(*session_aes_key);
        free(*session_iv);
        free(session_aes_key_encrypted);
        return res;
      }

      session_aes_key_encrypted_len = 256;
      session_aes_key_len = session_aes_key_encrypted_len * 3 / 2; // reusing this since we can

      *session_aes_key_base64 = malloc(BYTES(session_aes_key_len));
      if (*session_aes_key_base64 == NULL) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                     "Failed to allocate memory to base64 encode the session aes key\n");
        atchops_rsa_key_public_key_free(&ac);
        free(*session_aes_key);
        free(*session_iv);
        free(session_aes_key_encrypted);
        return 1;
      }
      memset(*session_aes_key_base64, 0, session_aes_key_len);

      size_t session_aes_key_base64_len;
      res = atchops_base64_encode(session_aes_key_encrypted, session_aes_key_encrypted_len, *session_aes_key_base64,
                                  session_aes_key_len, &session_aes_key_base64_len);
      // No longer need this
      free(session_aes_key_encrypted);
      if (res != 0) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to base64 encode the session aes key\n");
        atchops_rsa_key_public_key_free(&ac);
        free(*session_aes_key);
        free(*session_iv);
        free(*session_aes_key_base64);
        return res;
      }

      session_iv_encrypted = malloc(BYTES(256));
      if (session_iv_encrypted == NULL) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to allocate memory to encrypt the session iv\n");
        atchops_rsa_key_public_key_free(&ac);
        free(*session_aes_key);
        free(*session_iv);
        free(*session_aes_key_base64);
        return 1;
      }
      memset(session_iv_encrypted, 0, BYTES(256));

      res = atchops_rsa_encrypt(&ac, *session_iv, session_iv_len, session_iv_encrypted);
      atchops_rsa_key_public_key_free(&ac);
      if (res != 0) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to encrypt the session iv\n");
        free(session_iv_encrypted);
        free(*session_aes_key);
        free(*session_iv);
        free(*session_aes_key_base64);
        return res;
      }

      session_iv_encrypted_len = 256;
      session_iv_len = session_iv_encrypted_len * 3 / 2; // reusing this since we can
      *session_iv_base64 = malloc(BYTES(session_iv_len));
      if (*session_iv_base64 == NULL) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                     "Failed to allocate memory to base64 encode the session iv\n");
        free(session_iv_encrypted);
        free(*session_aes_key);
        free(*session_iv);
        free(*session_aes_key_base64);
        return 1;
      }
      memset(*session_iv_base64, 0, session_iv_len);

      size_t session_iv_base64_len;
      res = atchops_base64_encode(session_iv_encrypted, session_iv_encrypted_len, *session_iv_base64, session_iv_len,
                                  &session_iv_base64_len);
      // No longer need this
      free(session_iv_encrypted);
      if (res != 0) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to base64 encode the session iv\n");
        free(*session_aes_key);
        free(*session_iv);
        free(*session_iv_base64);
        free(*session_aes_key_base64);
        return res;
      }
    } // rsa2048 - allocates (session_iv_base64, session_aes_key_base64)
  } // case 7
  } // switch

  if (!is_valid) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "%s is not an accepted key type for encrypting the aes key\n", pk_type);
    return 1;
  }
  return res;
}

int send_success_payload(cJSON *payload, atclient *atclient, pthread_mutex_t *atclient_lock, sshnpd_params *params,
                         unsigned char *session_aes_key_base64, unsigned char *session_iv_base64,
                         atchops_rsa_key_private_key *signing_key, char *requesting_atsign) {
  int res = 0;
  cJSON *session_id = cJSON_GetObjectItem(payload, "sessionId");
  char *identifier = cJSON_GetStringValue(session_id);
  cJSON *final_res_payload = cJSON_CreateObject();
  cJSON_AddStringToObject(final_res_payload, "status", "connected");
  cJSON_AddItemReferenceToObject(final_res_payload, "sessionId", session_id);
  cJSON_AddStringToObject(final_res_payload, "sessionAESKey", (char *)session_aes_key_base64);
  cJSON_AddStringToObject(final_res_payload, "sessionIV", (char *)session_iv_base64);

  cJSON *final_res_envelope = cJSON_CreateObject();
  cJSON_AddItemToObject(final_res_envelope, "payload", final_res_payload);

  unsigned char *signing_input = (unsigned char *)cJSON_PrintUnformatted(final_res_payload);

  unsigned char signature[256];
  memset(signature, 0, 256);
  res = atchops_rsa_sign(signing_key, ATCHOPS_MD_SHA256, signing_input, strlen((char *)signing_input), signature);
  if (res != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to sign the final res payload\n");
    goto clean_json;
  }

  unsigned char base64signature[384];
  memset(base64signature, 0, sizeof(unsigned char) * 384);

  size_t sig_len;
  res = atchops_base64_encode(signature, 256, base64signature, 384, &sig_len);
  if (res != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to base64 encode the final res payload's signature\n");
    goto clean_json;
  }

  cJSON_AddItemToObject(final_res_envelope, "signature", cJSON_CreateString((char *)base64signature));
  cJSON_AddItemToObject(final_res_envelope, "hashingAlgo", cJSON_CreateString("sha256"));
  cJSON_AddItemToObject(final_res_envelope, "signingAlgo", cJSON_CreateString("rsa2048"));
  char *final_res_value = cJSON_PrintUnformatted(final_res_envelope);

  atclient_atkey final_res_atkey;
  atclient_atkey_init(&final_res_atkey);

  size_t keynamelen = strlen(identifier) + strlen(params->device) + 2; // + 1 for '.' +1 for '\0'
  char *keyname = malloc(sizeof(char) * keynamelen);
  if (keyname == NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to allocate memory for keyname");
    goto clean_final_res_value;
  }

  snprintf(keyname, keynamelen, "%s.%s", identifier, params->device);
  atclient_atkey_create_shared_key(&final_res_atkey, keyname, params->atsign, requesting_atsign, SSHNP_NS);

  // print final_res_atkey
  char *final_res_atkey_str = NULL;
  atclient_atkey_to_string(&final_res_atkey, &final_res_atkey_str);
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Final response atkey: %s\n", final_res_atkey_str);
  free(final_res_atkey_str);

  atclient_atkey_metadata *metadata = &final_res_atkey.metadata;
  atclient_atkey_metadata_set_is_public(metadata, false);
  atclient_atkey_metadata_set_is_encrypted(metadata, true);
  atclient_atkey_metadata_set_ttl(metadata, 10000);

  atclient_notify_params notify_params;
  atclient_notify_params_init(&notify_params);
  if ((res = atclient_notify_params_set_atkey(&notify_params, &final_res_atkey)) != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to set atkey in notify params\n");
    goto clean_res;
  }
  if ((res = atclient_notify_params_set_value(&notify_params, final_res_value)) != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to set value in notify params\n");
    goto clean_res;
  }
  if ((res = atclient_notify_params_set_operation(&notify_params, ATCLIENT_NOTIFY_OPERATION_UPDATE)) != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to set operation in notify params\n");
    goto clean_res;
  }

  char *final_keystr = NULL;
  atclient_atkey_to_string(&final_res_atkey, &final_keystr);
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Final response atkey: %s\n", final_res_atkey_str);
  free(final_keystr);

  int ret = pthread_mutex_lock(atclient_lock);
  if (ret != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to get a lock on atclient for sending a notification\n");
    goto clean_res;
  }

  ret = atclient_notify(atclient, &notify_params, NULL);
  if (ret != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to send final response to %s\n", requesting_atsign);
  }
  ret = pthread_mutex_unlock(atclient_lock);
  if (ret != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to release atclient lock\n");
    exit(1);
  } else {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Released the atclient lock\n");
  }

clean_res: { free(keyname); }
clean_final_res_value: {
  atclient_atkey_free(&final_res_atkey);
  cJSON_free(final_res_value);
}
clean_json: {
  cJSON_Delete(final_res_envelope);
  cJSON_free(signing_input);
}
  return res;
}
