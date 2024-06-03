#include "sshnpd/params.h"
#include "sshnpd/sshnpd.h"
#include <atchops/aes.h>
#include <atchops/base64.h>
#include <atchops/iv.h>
#include <atchops/rsakey.h>
#include <atclient/monitor.h>
#include <atclient/notify.h>
#include <atclient/stringutils.h>
#include <atlogger/atlogger.h>
#include <cJSON.h>
#include <pthread.h>
#include <sshnpd/run_srv_process.h>
#include <sshnpd/run_sshkeygen.h>
#include <stdlib.h>
#include <string.h>
#include <sys/errno.h>
#include <unistd.h>

#define LOGGER_TAG "SSH_REQUEST"

void handle_ssh_request(atclient *atclient, pthread_mutex_t *atclient_lock, sshnpd_params *params,
                        atclient_monitor_message *message, char *home_dir, FILE *authkeys_file, char *authkeys_filename,
                        atchops_rsakey_privatekey signing_key) {
  int res = 0;
  char *requesting_atsign = message->notification.from;

  char *decrypted_json = malloc(sizeof(char) * (message->notification.decryptedvaluelen + 1));
  if (decrypted_json == NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to allocate memory to decrypt the envelope\n");
    return;
  }

  memcpy(decrypted_json, message->notification.decryptedvalue, message->notification.decryptedvaluelen);
  *(decrypted_json + message->notification.decryptedvaluelen) = '\0';

  cJSON *envelope = cJSON_Parse(decrypted_json);
  free(decrypted_json);

  // First validate the types of everything we expect to be in the envelope
  bool has_valid_values = cJSON_IsObject(envelope);

  if (!has_valid_values) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to parse the envelope\n");
    return;
  }

  cJSON *signature = cJSON_GetObjectItem(envelope, "signature");
  has_valid_values = has_valid_values && cJSON_IsString(signature);

  cJSON *hashing_algo = cJSON_GetObjectItem(envelope, "hashingAlgo");
  has_valid_values = has_valid_values && cJSON_IsString(hashing_algo);

  cJSON *signing_algo = cJSON_GetObjectItem(envelope, "signingAlgo");
  has_valid_values = has_valid_values && cJSON_IsString(signing_algo);

  cJSON *payload = cJSON_GetObjectItem(envelope, "payload");
  has_valid_values = has_valid_values && cJSON_IsObject(payload);

  if (!has_valid_values) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Received invalid envelope format\n");
    free(envelope);
    return;
  }

  cJSON *direct = cJSON_GetObjectItem(payload, "direct");
  has_valid_values = cJSON_IsBool(direct);

  if (!has_valid_values) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Couldn't determine if payload is direct\n");
    free(envelope);
    return;
  }

  if (!cJSON_IsTrue(direct)) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Only direct mode is supported by this device\n");
    free(envelope);
    return;
  }

  cJSON *session_id = cJSON_GetObjectItem(payload, "sessionId");
  has_valid_values = cJSON_IsString(session_id);

  cJSON *host = cJSON_GetObjectItem(payload, "host");
  has_valid_values = has_valid_values && cJSON_IsString(host);

  cJSON *port = cJSON_GetObjectItem(payload, "port");
  has_valid_values = has_valid_values && cJSON_IsNumber(port);

  if (!has_valid_values) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Received invalid payload format\n");
    free(envelope);
    return;
  }

  // These values do not need to be asserted for v4 compatibility, only for v5

  cJSON *auth_to_rvd = cJSON_GetObjectItem(payload, "authenticateToRvd");
  cJSON *encrypt_traffic = cJSON_GetObjectItem(payload, "encryptRvdTraffic");
  cJSON *client_nonce = cJSON_GetObjectItem(payload, "clientNonce");
  cJSON *rvd_nonce = cJSON_GetObjectItem(payload, "rvdNonce");
  cJSON *client_ephemeral_pk = cJSON_GetObjectItem(payload, "clientEphemeralPK");
  cJSON *client_ephemeral_pk_type = cJSON_GetObjectItem(payload, "clientEphemeralPKType");

  // TODO: verify signature of payload
  // - get public key of requesting atsign
  // - get hashing and signing algos from envelope
  // - verify signature from envelop against payload as cJSON_PrintUnformatted

  bool authenticate_to_rvd = cJSON_IsTrue(auth_to_rvd);
  bool encrypt_rvd_traffic = cJSON_IsTrue(encrypt_traffic);

  char *rvd_auth_string;
  if (authenticate_to_rvd) {
    has_valid_values = cJSON_IsString(client_nonce) && cJSON_IsString(rvd_nonce);

    if (!has_valid_values) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                   "Missing nonce values, cannot create auth string for rvd\n");
      free(envelope);
      return;
    }

    cJSON *rvd_auth_payload = cJSON_CreateObject();
    cJSON_AddItemReferenceToObject(rvd_auth_payload, "sessionId", session_id);
    cJSON_AddItemReferenceToObject(rvd_auth_payload, "clientNonce", client_nonce);
    cJSON_AddItemReferenceToObject(rvd_auth_payload, "rvdNonce", rvd_nonce);

    cJSON *res_envelope = cJSON_CreateObject();
    cJSON_AddItemToObject(res_envelope, "payload", rvd_auth_payload);

    char *signing_input = cJSON_PrintUnformatted(rvd_auth_payload);

    unsigned char signature[256];
    memset(signature, 0, sizeof(unsigned char) * 256);
    res = atchops_rsa_sign(signing_key, ATCHOPS_MD_SHA256, (unsigned char *)signing_input,
                           strlen((char *)signing_input), signature);
    if (res != 0) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to sign the auth string payload\n");
      free(signing_input);
      cJSON_Delete(res_envelope);
      free(envelope);
      return;
    }

    unsigned char base64signature[384];
    memset(base64signature, 0, sizeof(unsigned char) * 384);

    size_t sig_len;
    res = atchops_base64_encode(signature, 256, base64signature, 384, &sig_len);
    if (res != 0) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to base64 encode the auth string payload\n");
      free(signing_input);
      cJSON_Delete(res_envelope);
      free(envelope);
      return;
    }

    cJSON_AddItemToObject(res_envelope, "signature", cJSON_CreateString((char *)base64signature));
    cJSON_AddItemToObject(res_envelope, "hashingAlgo", cJSON_CreateString("sha256"));
    cJSON_AddItemToObject(res_envelope, "signingAlgo", cJSON_CreateString("rsa2048"));
    rvd_auth_string = cJSON_PrintUnformatted(res_envelope);
    free(signing_input);
    cJSON_Delete(res_envelope);
  }

  unsigned char session_aes_key[48], *session_aes_key_encrypted, *session_aes_key_base64;
  unsigned char session_iv[25], *session_iv_encrypted, *session_iv_base64;
  size_t session_aes_key_len, session_iv_len, session_aes_key_encrypted_len, session_iv_encrypted_len;
  if (!encrypt_rvd_traffic) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "encryptRvdTraffic=false is not supported by this daemon\n");
    if (authenticate_to_rvd) {
      free(rvd_auth_string);
    }
    free(envelope);
    return;
  }

  has_valid_values = cJSON_IsString(client_ephemeral_pk) && cJSON_IsString(client_ephemeral_pk_type);
  if (!has_valid_values) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "encryptRvdTraffic was requested, but no client ephemeral public key / key type was provided\n");

    if (authenticate_to_rvd) {
      free(rvd_auth_string);
    }
    free(envelope);
    return;
  }

  memset(session_aes_key, 0, sizeof(unsigned char) * 48);
  res = atchops_aes_generate_keybase64(session_aes_key, 48, &session_aes_key_len, ATCHOPS_AES_256);
  if (res != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to generate session aes key\n");
    if (authenticate_to_rvd) {
      free(rvd_auth_string);
    }
    free(envelope);
    return;
  }

  memset(session_iv, 0, sizeof(unsigned char) * 25);

  res = atchops_iv_generate_base64(session_iv, 25, &session_iv_len);
  if (res != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to generate session iv\n");
    if (authenticate_to_rvd) {
      free(rvd_auth_string);
    }
    free(envelope);
    return;
  }

  // enum EncryptionKeyType { rsa2048, rsa4096, ecc, aes128, aes192, aes256 }
  char *pk_type = cJSON_GetStringValue(client_ephemeral_pk_type);
  char *pk = cJSON_GetStringValue(client_ephemeral_pk);

  bool is_valid = false;
  switch (strlen(pk_type)) {
  case 7: { // rsa2048 is the only valid type right now
    if (strncmp(pk_type, "rsa2048", 7) == 0) {
      is_valid = true;
      atchops_rsakey_publickey ac;
      atchops_rsakey_publickey_init(&ac);

      res = atchops_rsakey_populate_publickey(&ac, pk, strlen(pk));
      session_aes_key_encrypted = malloc(sizeof(unsigned char) * 32);
      if (session_aes_key_encrypted == NULL) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                     "Failed to allocate memory to encrypt the session aes key\n");
        if (authenticate_to_rvd) {
          free(rvd_auth_string);
        }
        free(envelope);
        return;
      }

      res = atchops_rsa_encrypt(ac, session_aes_key, session_aes_key_len, session_aes_key_encrypted, 256,
                                &session_aes_key_encrypted_len);
      if (res != 0) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to encrypt the session aes key\n");
        if (authenticate_to_rvd) {
          free(rvd_auth_string);
        }
        free(session_aes_key_encrypted);
        free(envelope);
        return;
      }

      session_aes_key_len = session_aes_key_encrypted_len * 3 / 2; // reusing this since we can

      session_aes_key_base64 = malloc(sizeof(unsigned char) * session_aes_key_len);
      if (session_aes_key_base64 == NULL) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                     "Failed to allocate memory to base64 encode the session aes key\n");
        if (authenticate_to_rvd) {
          free(rvd_auth_string);
        }
        free(session_aes_key_encrypted);
        free(envelope);
        return;
      }
      memset(session_aes_key_base64, 0, session_aes_key_len);

      size_t session_aes_key_base64_len;
      res = atchops_base64_encode(session_aes_key_encrypted, session_aes_key_encrypted_len, session_aes_key_base64,
                                  session_aes_key_len, &session_aes_key_base64_len);
      if (res != 0) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to base64 encode the session aes key\n");
        if (authenticate_to_rvd) {
          free(rvd_auth_string);
        }
        free(session_aes_key_base64);
        free(session_aes_key_encrypted);
        free(envelope);
        return;
      }

      // No longer need this
      free(session_aes_key_encrypted);

      session_iv_encrypted = malloc(sizeof(unsigned char) * 32);
      if (session_iv_encrypted == NULL) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to allocate memory to encrypt the session iv\n");
        if (authenticate_to_rvd) {
          free(rvd_auth_string);
        }
        free(session_aes_key_base64);
        free(envelope);
        return;
      }

      res = atchops_rsa_encrypt(ac, session_iv, session_iv_len, session_iv_encrypted, 256, &session_iv_encrypted_len);
      if (res != 0) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to encrypt the session iv\n");
        if (authenticate_to_rvd) {
          free(rvd_auth_string);
        }
        free(session_iv_encrypted);
        free(session_aes_key_base64);
        free(envelope);
        return;
      }

      session_iv_len = session_iv_encrypted_len * 3 / 2; // reusing this since we can
      session_iv_base64 = malloc(sizeof(unsigned char) * session_iv_len);
      if (session_iv_base64 == NULL) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                     "Failed to allocate memory to base64 encode the session iv\n");
        if (authenticate_to_rvd) {
          free(rvd_auth_string);
        }
        free(session_iv_encrypted);
        free(session_aes_key_base64);
        free(envelope);
        return;
      }
      memset(session_iv_base64, 0, session_iv_len);

      size_t session_iv_base64_len;
      res = atchops_base64_encode(session_iv_encrypted, session_iv_encrypted_len, session_iv_base64, session_iv_len,
                                  &session_iv_base64_len);
      if (res != 0) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to base64 encode the session iv\n");
        if (authenticate_to_rvd) {
          free(rvd_auth_string);
        }
        free(session_iv_base64);
        free(session_iv_encrypted);
        free(session_aes_key_base64);
        free(envelope);
        return;
      }
      // No longer need this
      free(session_iv_encrypted);
    } // rsa2048
  } // case 7
  } // switch

  if (!is_valid) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "%s is not an accepted key type for encrypting the aes key\n", pk_type);
    if (authenticate_to_rvd) {
      free(rvd_auth_string);
    }
    free(envelope);
    return;
  }

  pid_t pid, pid2;
  int status, status2;
  pid = fork();
  if (pid == 0) {
    // child process
    run_srv_process(params, host, port, authenticate_to_rvd, rvd_auth_string, encrypt_rvd_traffic, session_aes_key,
                    session_iv, authkeys_file, authkeys_filename);
  } else if (pid > 0) {

    // parent process
    waitpid(pid, &status, WNOHANG); // Don't wait for srv

    char *identifier = cJSON_GetStringValue(session_id);
    cJSON *final_res_payload = cJSON_CreateObject();
    cJSON_AddStringToObject(final_res_payload, "status", "connected");
    cJSON_AddItemReferenceToObject(final_res_payload, "sessionId", session_id);
    // cJSON_AddStringToObject(final_res_payload, "ephemeralPrivateKey", priv_key);
    cJSON_AddNullToObject(final_res_payload, "ephemeralPrivateKey");
    if (encrypt_rvd_traffic) {
      cJSON_AddStringToObject(final_res_payload, "sessionAESKey", (char *)session_aes_key_base64);
      cJSON_AddStringToObject(final_res_payload, "sessionIV", (char *)session_iv_base64);
    } else {
      cJSON_AddNullToObject(final_res_payload, "sessionAESKey");
      cJSON_AddNullToObject(final_res_payload, "sessionIV");
    }

    cJSON *final_res_envelope = cJSON_CreateObject();
    cJSON_AddItemToObject(final_res_envelope, "payload", final_res_payload);

    unsigned char *signing_input = (unsigned char *)cJSON_PrintUnformatted(final_res_payload);

    unsigned char signature[256];
    memset(signature, 0, sizeof(unsigned char) * 256);
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
    snprintf(keyname, keynamelen, "%s.%s", identifier, params->device);
    atclient_atkey_create_sharedkey(&final_res_atkey, keyname, keynamelen, params->atsign, strlen(params->atsign),
                                    requesting_atsign, strlen(requesting_atsign), SSHNP_NS, SSHNP_NS_LEN);

    atclient_atkey_metadata *metadata = &final_res_atkey.metadata;
    atclient_atkey_metadata_set_ispublic(metadata, false);
    atclient_atkey_metadata_set_isencrypted(metadata, true);
    atclient_atkey_metadata_set_ttl(metadata, 10000);

    atclient_notify_params notify_params;
    atclient_notify_params_init(&notify_params);
    notify_params.key = final_res_atkey;
    notify_params.value = final_res_value;
    notify_params.operation = ATCLIENT_NOTIFY_OPERATION_UPDATE;

    char final_keystr[500];
    size_t out;
    atclient_atkey_to_string(&final_res_atkey, final_keystr, 500, &out);

    int ret = pthread_mutex_lock(atclient_lock);
    if (ret != 0) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                   "Failed to get a lock on atclient for sending a notification\n");
      goto clean_res;
    }

    ret = atclient_notify(atclient, &notify_params, NULL);
    if (ret != 0) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to send final response to %s\n",
                   message->notification.from);
    }
    do {
      ret = pthread_mutex_unlock(atclient_lock);
      if (ret != 0) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                     "Failed to release atclient lock, trying again in 1 second\n");
        sleep(1);
      }
    } while (ret != 0);
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Released the atclient lock\n");

  clean_res: {
    free(keyname);
    free(final_res_value);
  }
  clean_json: {
    cJSON_Delete(final_res_envelope);
    free(signing_input);
  }
  cancel_parent: {} // Don't need to do anything here, we just want a way to essentially exit out of the parent's post
                    // fork success block
    free(identifier);
  } else {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to fork the srv process: %s\n", strerror(errno));
  }
cancel:
  if (authenticate_to_rvd) {
    free(rvd_auth_string);
  }
  if (encrypt_rvd_traffic) {
    free(session_iv_base64);
    free(session_aes_key_base64);
  }
  free(envelope);
  return;
}
