#include "sshnpd/file_utils.h"
#include "sshnpd/params.h"
#include <atclient/monitor.h>
#include <atlogger/atlogger.h>
#include <stdbool.h>
#include <string.h>

#define LOGGER_TAG "SSHPUBLICKEY RESPONSE"
static const char *supported_key_prefix_map[] = {
    [SKP_NONE] = "",       [SKP_ESN] = "ecdsa-sha2-nistp", [SKP_RS2] = "rsa-sha2-",
    [SKP_RSA] = "ssh-rsa", [SKP_ED9] = "ssh-ed25519",
};

bool is_valid_ssh_public_key(const char *ssh_key) {
  if (ssh_key == NULL || ssh_key[0] == '\0') {
    return false;
  }

  const size_t ssh_key_len = strlen(ssh_key);

  bool has_valid_prefix = false;
  for (int i = 1; i < SUPPORTED_KEY_PREFIX_LEN; i++) {
    const char *prefix = supported_key_prefix_map[i];
    const size_t prefix_len = strlen(prefix);

    if (ssh_key_len < prefix_len) {
      continue;
    }

    if (strncmp(ssh_key, prefix, prefix_len) == 0) {
      has_valid_prefix = true;
      break;
    }
  }

  if (!has_valid_prefix) {
    return false;
  }

  if (strchr(ssh_key, '\n') != NULL || strchr(ssh_key, '\r') != NULL) {
    return false;
  }

  return true;
}

void handle_sshpublickey(sshnpd_params *params, atclient_monitor_message *message, FILE *authkeys_file,
                         char *authkeys_filename) {
  if (!params->sshpublickey) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Ignoring sshpublickey from %s\n",
                 message->notification->from);
    return;
  }

  char *ssh_key = (char *)message->notification->decrypted_value;

  if (!is_valid_ssh_public_key(ssh_key)) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_WARN, "Ssh public key does not look like a public key\n");
    return;
  }

  authkeys_params authkeys_params = {};
  authkeys_params.authkeys_file = authkeys_file;
  authkeys_params.authkeys_filename = authkeys_filename;
  authkeys_params.permissions = "";
  authkeys_params.key = ssh_key;

  // authorize public key
  int ret = authorize_ssh_public_key(&authkeys_params);
  if (ret != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to authorize ssh public key\n");
    return;
  }

  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Authorized public key\n");
}
