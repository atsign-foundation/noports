#include "sshnpd/params.h"
#include "sshnpd/sshnpd.h"
#include <atchops/aes.h>
#include <atchops/base64.h>
#include <atchops/iv.h>
#include <atchops/rsa_key.h>
#include <atclient/monitor.h>
#include <atclient/notify.h>
#include <atclient/string_utils.h>
#include <atlogger/atlogger.h>
#include <cJSON.h>
#include <pthread.h>
#include <sshnpd/handle_ssh_request.h>
#include <sshnpd/run_srv_process.h>
#include <stdlib.h>
#include <string.h>
#include <sys/errno.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

#define LOGGER_TAG "SSH_REQUEST"

#define BYTES(x) (sizeof(unsigned char) * x)

void handle_ssh_request(atclient *atclient, pthread_mutex_t *atclient_lock, sshnpd_params *params,
                        bool *is_child_process, atclient_monitor_response *message, char *home_dir, FILE *authkeys_file,
                        char *authkeys_filename, atchops_rsa_key_private_key signing_key) {
  int res = 0;
  if(!atclient_atnotification_is_from_initialized(&message->notification) && message->notification.from != NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to initialize the from field of the notification\n");
    return;
  }
  char *requesting_atsign = message->notification.from;

  if(!atclient_atnotification_is_decrypted_value_initialized(&message->notification) && message->notification.decrypted_value != NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to initialize the decrypted value of the notification\n");
    return;
  }
  char *decrypted_json = malloc(sizeof(char) * (strlen(message->notification.decrypted_value) + 1));
  if (decrypted_json == NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to allocate memory to decrypt the envelope\n");
    return;
  }

  memcpy(decrypted_json, message->notification.decrypted_value, strlen(message->notification.decrypted_value));
  *(decrypted_json + strlen(message->notification.decrypted_value)) = '\0';

  // log the decrypted json
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Decrypted json: %s\n", decrypted_json);

  cJSON *envelope = cJSON_Parse(decrypted_json);

  // log envelope
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Received envelope: %s\n", cJSON_Print(envelope));
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
    cJSON_Delete(envelope);
    return;
  }

  cJSON *direct = cJSON_GetObjectItem(payload, "direct");
  has_valid_values = cJSON_IsBool(direct);

  if (!has_valid_values) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Couldn't determine if payload is direct\n");
    cJSON_Delete(envelope);
    return;
  }

  if (!cJSON_IsTrue(direct)) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Only direct mode is supported by this device\n");
    cJSON_Delete(envelope);
    return;
  }

  cJSON *session_id = cJSON_GetObjectItem(payload, "sessionId");
  has_valid_values = cJSON_IsString(session_id);

  cJSON *host = cJSON_GetObjectItem(payload, "host");
  has_valid_values = has_valid_values && cJSON_IsString(host);

  cJSON *port = cJSON_GetObjectItem(payload, "port");
  has_valid_values = has_valid_values && cJSON_IsNumber(port) && cJSON_GetNumberValue(port) > 0;

  if (!has_valid_values) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Received invalid payload format\n");
    cJSON_Delete(envelope);
    return;
  }

  // These values do not need to be asserted for v4 compatibility, only for v5

  cJSON *auth_to_rvd = cJSON_GetObjectItem(payload, "authenticateToRvd");
  cJSON *encrypt_traffic = cJSON_GetObjectItem(payload, "encryptRvdTraffic");
  cJSON *client_nonce = cJSON_GetObjectItem(payload, "clientNonce");
  cJSON *rvd_nonce = cJSON_GetObjectItem(payload, "rvdNonce");
  cJSON *client_ephemeral_pk = cJSON_GetObjectItem(payload, "clientEphemeralPK");
  cJSON *client_ephemeral_pk_type = cJSON_GetObjectItem(payload, "clientEphemeralPKType");

  // verify signature of payload

  // - get public key of requesting atsign

  atclient_atkey atkey;
  atclient_atkey_init(&atkey);

  if ((res = atclient_atkey_create_public_key(&atkey, "publickey", requesting_atsign, NULL)) != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to create public key\n");
    cJSON_Delete(envelope);
    return;
  }

  char *value = NULL;

  res = atclient_get_public_key(atclient, &atkey, &value, NULL);
  if (res != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to get public key\n");
    atclient_atkey_free(&atkey);
    cJSON_Delete(envelope);
    return;
  }

  atclient_atkey_free(&atkey);

  atchops_rsa_key_public_key requesting_atsign_publickey;
  atchops_rsa_key_public_key_init(&requesting_atsign_publickey);

  res = atchops_rsa_key_populate_public_key(&requesting_atsign_publickey, value, strlen(value));
  if (res != 0) {
    printf("atchops_rsakey_populate_publickey (failed): %d\n", res);
    cJSON_Delete(envelope);
    free(value);
    return;
  }

  // - get hashing and signing algos from envelope
  // - verify signature from envelop against payload as cJSON_PrintUnformatted

  char *payloadstr = cJSON_PrintUnformatted(payload);
  char *signature_str = cJSON_GetStringValue(signature);
  char *hashing_algo_str = cJSON_GetStringValue(hashing_algo);
  char *signing_algo_str = cJSON_GetStringValue(signing_algo);

  size_t valueolen = 0;
  res = atchops_base64_decode((unsigned char *)signature_str, strlen(signature_str), (unsigned char *)value, strlen(value),
                              &valueolen);
  if (res != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "atchops_base64_decode: %d\n", res);
    cJSON_Delete(envelope);
    cJSON_free(payloadstr);
    free(value);
    return;
  }

  res = verify_envelope_signature(requesting_atsign_publickey, (const unsigned char *)payloadstr,
                                  (unsigned char *)value, hashing_algo_str, signing_algo_str);
  if (res != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to verify envelope signature\n");
    cJSON_Delete(envelope);
    atchops_rsa_key_public_key_free(&requesting_atsign_publickey);
    cJSON_free(payloadstr);
    free(value);
    return;
  }

  atchops_rsa_key_public_key_free(&requesting_atsign_publickey);

  bool authenticate_to_rvd = cJSON_IsTrue(auth_to_rvd);
  bool encrypt_rvd_traffic = cJSON_IsTrue(encrypt_traffic);

  if (!encrypt_rvd_traffic) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Encrypt rvd traffic flag is false, this feature must be enabled\n");
    cJSON_Delete(envelope);
    cJSON_free(payloadstr);
    free(value);
    return;
  }

  char *rvd_auth_string;
  if (authenticate_to_rvd) {
    has_valid_values = cJSON_IsString(client_nonce) && cJSON_IsString(rvd_nonce);

    if (!has_valid_values) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                   "Missing nonce values, cannot create auth string for rvd\n");
      cJSON_Delete(envelope);
      cJSON_free(payloadstr);
      free(value);
      return;
    }

    cJSON *rvd_auth_payload = cJSON_CreateObject();
    // FIXME: leaks : these 3 calls
    cJSON_AddItemReferenceToObject(rvd_auth_payload, "sessionId", session_id);
    cJSON_AddItemReferenceToObject(rvd_auth_payload, "clientNonce", client_nonce);
    cJSON_AddItemReferenceToObject(rvd_auth_payload, "rvdNonce", rvd_nonce);

    cJSON *res_envelope = cJSON_CreateObject();
    cJSON_AddItemReferenceToObject(res_envelope, "payload", rvd_auth_payload);

    char *signing_input = cJSON_PrintUnformatted(rvd_auth_payload);

    unsigned char signature[256];
    memset(signature, 0, BYTES(256));
    res = atchops_rsa_sign(&signing_key, ATCHOPS_MD_SHA256, (unsigned char *)signing_input,
                           strlen((char *)signing_input), signature);
    if (res != 0) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to sign the auth string payload\n");
      cJSON_free(signing_input);
      cJSON_Delete(res_envelope);
      cJSON_Delete(rvd_auth_payload);
      cJSON_Delete(envelope);
      cJSON_free(payloadstr);
      free(value);
      return;
    }

    unsigned char base64signature[384];
    memset(base64signature, 0, BYTES(384));

    size_t sig_len;
    res = atchops_base64_encode(signature, 256, base64signature, 384, &sig_len);
    if (res != 0) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to base64 encode the auth string payload\n");
      cJSON_free(signing_input);
      cJSON_Delete(res_envelope);
      cJSON_Delete(rvd_auth_payload);
      cJSON_Delete(envelope);
      cJSON_free(payloadstr);
      free(value);
      return;
    }

    cJSON_AddItemToObject(res_envelope, "signature", cJSON_CreateString((char *)base64signature));
    cJSON_AddItemToObject(res_envelope, "hashingAlgo", cJSON_CreateString("sha256"));
    cJSON_AddItemToObject(res_envelope, "signingAlgo", cJSON_CreateString("rsa2048"));
    rvd_auth_string = cJSON_PrintUnformatted(res_envelope);
    cJSON_free(signing_input);
    cJSON_Delete(res_envelope);
    cJSON_Delete(rvd_auth_payload);
    cJSON_free(payloadstr);
    free(value);
  }

  unsigned char key[32];
  unsigned char session_aes_key[49], *session_aes_key_encrypted, *session_aes_key_base64;
  unsigned char iv[16];
  unsigned char session_iv[25], *session_iv_encrypted, *session_iv_base64;
  bool free_session_base64 = false;
  size_t session_aes_key_len, session_iv_len, session_aes_key_encrypted_len, session_iv_encrypted_len;
  if (!encrypt_rvd_traffic) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "encryptRvdTraffic=false is not supported by this daemon\n");
    if (authenticate_to_rvd) {
      free(rvd_auth_string);
    }
    cJSON_Delete(envelope);
    return;
  }

  has_valid_values = cJSON_IsString(client_ephemeral_pk) && cJSON_IsString(client_ephemeral_pk_type);
  if (!has_valid_values) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "encryptRvdTraffic was requested, but no client ephemeral public key / key type was provided\n");

    if (authenticate_to_rvd) {
      free(rvd_auth_string);
    }
    cJSON_Delete(envelope);
    return;
  }

  memset(key, 0, BYTES(32));
  if ((res = atchops_aes_generate_key(key, ATCHOPS_AES_256)) != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to generate session aes key\n");
    if (authenticate_to_rvd) {
      free(rvd_auth_string);
    }
    cJSON_Delete(envelope);
    return;
  }

  memset(session_aes_key, 0, BYTES(49));
  res = atchops_base64_encode(key, 32, session_aes_key, 49, &session_aes_key_len);
  if (res != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to generate session aes key\n");
    if (authenticate_to_rvd) {
      free(rvd_auth_string);
    }
    cJSON_Delete(envelope);
    return;
  }

  memset(iv, 0, BYTES(16));
  if ((res = atchops_iv_generate(iv)) != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to generate session iv\n");
    if (authenticate_to_rvd) {
      free(rvd_auth_string);
    }
    cJSON_Delete(envelope);
    return;
  }

  memset(session_iv, 0, BYTES(25));
  res = atchops_base64_encode(iv, 16, session_iv, 25, &session_iv_len);
  if (res != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to generate session iv\n");
    if (authenticate_to_rvd) {
      free(rvd_auth_string);
    }
    cJSON_Delete(envelope);
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
      atchops_rsa_key_public_key ac;
      atchops_rsa_key_public_key_init(&ac);

      res = atchops_rsa_key_populate_public_key(&ac, pk, strlen(pk));
      if (res != 0) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to populate client ephemeral pk\n");
        atchops_rsa_key_public_key_free(&ac);
        if (authenticate_to_rvd) {
          free(rvd_auth_string);
        }
        cJSON_Delete(envelope);
        return;
      }

      session_aes_key_encrypted = malloc(BYTES(256));
      if (session_aes_key_encrypted == NULL) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                     "Failed to allocate memory to encrypt the session aes key\n");
        atchops_rsa_key_public_key_free(&ac);
        if (authenticate_to_rvd) {
          free(rvd_auth_string);
        }
        cJSON_Delete(envelope);
        return;
      }

      res = atchops_rsa_encrypt(&ac, session_aes_key, session_aes_key_len, session_aes_key_encrypted);
      if (res != 0) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to encrypt the session aes key\n");
        atchops_rsa_key_public_key_free(&ac);
        if (authenticate_to_rvd) {
          free(rvd_auth_string);
        }
        free(session_aes_key_encrypted);
        cJSON_Delete(envelope);
        return;
      }

      session_aes_key_encrypted_len = 256;

      session_aes_key_len = session_aes_key_encrypted_len * 3 / 2; // reusing this since we can

      session_aes_key_base64 = malloc(BYTES(session_aes_key_len));
      if (session_aes_key_base64 == NULL) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                     "Failed to allocate memory to base64 encode the session aes key\n");
        atchops_rsa_key_public_key_free(&ac);
        if (authenticate_to_rvd) {
          free(rvd_auth_string);
        }
        free(session_aes_key_encrypted);
        cJSON_Delete(envelope);
        return;
      }
      memset(session_aes_key_base64, 0, session_aes_key_len);

      size_t session_aes_key_base64_len;
      res = atchops_base64_encode(session_aes_key_encrypted, session_aes_key_encrypted_len, session_aes_key_base64,
                                  session_aes_key_len, &session_aes_key_base64_len);
      if (res != 0) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to base64 encode the session aes key\n");
        atchops_rsa_key_public_key_free(&ac);
        if (authenticate_to_rvd) {
          free(rvd_auth_string);
        }
        free(session_aes_key_base64);
        free(session_aes_key_encrypted);
        cJSON_Delete(envelope);
        return;
      }

      // No longer need this
      free(session_aes_key_encrypted);

      session_iv_encrypted = malloc(BYTES(256));
      if (session_iv_encrypted == NULL) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to allocate memory to encrypt the session iv\n");
        atchops_rsa_key_public_key_free(&ac);
        if (authenticate_to_rvd) {
          free(rvd_auth_string);
        }
        free(session_aes_key_base64);
        cJSON_Delete(envelope);
        return;
      }
      memset(session_iv_encrypted, 0, BYTES(256));

      res = atchops_rsa_encrypt(&ac, session_iv, session_iv_len, session_iv_encrypted);
      atchops_rsa_key_public_key_free(&ac);
      if (res != 0) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to encrypt the session iv\n");
        if (authenticate_to_rvd) {
          free(rvd_auth_string);
        }
        free(session_iv_encrypted);
        free(session_aes_key_base64);
        cJSON_Delete(envelope);
        return;
      }

      session_iv_encrypted_len = 256;
      session_iv_len = session_iv_encrypted_len * 3 / 2; // reusing this since we can
      session_iv_base64 = malloc(BYTES(session_iv_len));
      if (session_iv_base64 == NULL) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                     "Failed to allocate memory to base64 encode the session iv\n");
        if (authenticate_to_rvd) {
          free(rvd_auth_string);
        }
        free(session_iv_encrypted);
        free(session_aes_key_base64);
        cJSON_Delete(envelope);
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
        cJSON_Delete(envelope);
        return;
      }
      // No longer need this
      free(session_iv_encrypted);
      free_session_base64 = true;
    } // rsa2048 - allocates (session_iv_base64, session_aes_key_base64)
  } // case 7
  } // switch

  if (!is_valid) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "%s is not an accepted key type for encrypting the aes key\n", pk_type);
    if (authenticate_to_rvd) {
      free(rvd_auth_string);
    }
    cJSON_Delete(envelope);
    return;
  }

  // At this point, allocated memory:
  // - envelope (always)
  // - rvd_auth_string (if authenticate_to_rvd == true)
  // - session_aes_key_base64 (if free_session_base64 == true)
  // - session_iv_base64 (if free_session_base64 == true)

  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Running fork()...\n");

  pid_t pid = fork();
  int status;
  bool free_envelope = true;

  if (pid == 0) {
    // child process

    // free this immediately, we don't need it on the child fork
    if (free_session_base64) {
      free(session_aes_key_base64);
      free(session_iv_base64);
    }

    int res = run_srv_process(params, host, port, authenticate_to_rvd, rvd_auth_string, encrypt_rvd_traffic, false,
                              session_aes_key, session_iv, authkeys_file, authkeys_filename);
    *is_child_process = true;

    if (authenticate_to_rvd) {
      free(rvd_auth_string);
    }
    cJSON_Delete(envelope);
    exit(res);
    // end of child process
  } else if (pid > 0) {
    // parent process

    // since we use WNOHANG,
    // waitpid will return -1, if an error occurred
    // waitpid will return 0, if the child process has not exited
    // waitpid will return the pid of the child process if it has exited
    int waitpid_return = waitpid(pid, &status, WNOHANG); // Don't wait for srv - we want it to be running in the bg
    if(waitpid_return > 0) {
      // child process has already exited
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "srv process has already exited\n");
      if(WIFEXITED(status)) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "srv process exited with status %d\n", status);
      } else {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "srv process exited abnormally\n");
      }
      goto cancel;
    } else if(waitpid_return == -1) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to wait for srv process: %s\n", strerror(errno));
      goto cancel;
    }

    char *identifier = cJSON_GetStringValue(session_id);
    cJSON *final_res_payload = cJSON_CreateObject();
    cJSON_AddStringToObject(final_res_payload, "status", "connected");
    cJSON_AddItemReferenceToObject(final_res_payload, "sessionId", session_id);
    cJSON_AddNullToObject(final_res_payload, "ephemeralPrivateKey");
    cJSON_AddStringToObject(final_res_payload, "sessionAESKey", (char *)session_aes_key_base64);
    cJSON_AddStringToObject(final_res_payload, "sessionIV", (char *)session_iv_base64);

    cJSON *final_res_envelope = cJSON_CreateObject();
    cJSON_AddItemToObject(final_res_envelope, "payload", final_res_payload);

    unsigned char *signing_input2 = (unsigned char *)cJSON_PrintUnformatted(final_res_payload);

    unsigned char signature[256];
    memset(signature, 0, 256);
    res = atchops_rsa_sign(&signing_key, ATCHOPS_MD_SHA256, signing_input2, strlen((char *)signing_input2), signature);
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
    if((res = atclient_notify_params_set_atkey(&notify_params, &final_res_atkey)) != 0) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to set atkey in notify params\n");
      goto clean_res;
    }
    if((res = atclient_notify_params_set_value(&notify_params, final_res_value)) != 0) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to set value in notify params\n");
      goto clean_res;
    }
    if((res = atclient_notify_params_set_operation(&notify_params, ATCLIENT_NOTIFY_OPERATION_UPDATE)) != 0) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to set operation in notify params\n");
      goto clean_res;
    }

    char *final_keystr = NULL;
    atclient_atkey_to_string(&final_res_atkey, &final_keystr);

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
    ret = pthread_mutex_unlock(atclient_lock);
    if (ret != 0) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to release atclient lock\n");
    } else {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Released the atclient lock\n");
    }

  clean_res: {
    free(final_keystr);
    free(keyname);
  }
  clean_final_res_value: {
    atclient_atkey_free(&final_res_atkey);
    free(final_res_value);
  }
  clean_json: {
    cJSON_Delete(final_res_envelope); 
    cJSON_free(signing_input2);
  }

    // end of parent process
  } else {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to fork the srv process: %s\n", strerror(errno));
  }
cancel:
  if (authenticate_to_rvd) {
    free(rvd_auth_string);
  }
  if (free_session_base64) {
    free(session_iv_base64);
    free(session_aes_key_base64);
  }
  cJSON_Delete(envelope);
  return;
}

int verify_envelope_signature(atchops_rsa_key_public_key publickey, const unsigned char *payload,
                              unsigned char *signature, const char *hashing_algo, const char *signing_algo) {
  int ret = 0;

  atchops_md_type mdtype;

  if (strcmp(hashing_algo, "sha256") == 0) {
    mdtype = ATCHOPS_MD_SHA256;
  } else {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Unsupported hash type for rsa verify\n");
    return -1;
  }

  ret = atchops_rsa_verify(&publickey, ATCHOPS_MD_SHA256, payload, strlen((char *)payload), signature);
  if (ret != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "verify_envelope_signature (failed)\n");
    return -1;
  }

  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "verify_envelope_signature (success)\n");

  return ret;
}
