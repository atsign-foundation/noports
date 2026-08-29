#include "sshnpd/file_utils.h"
#include "sshnpd/params.h"
#include <atclient/monitor.h>
#include <atlogger/atlogger.h>
#include <stdbool.h>
#include <string.h>

#define LOGGER_TAG "SSHPUBLICKEY RESPONSE"
static char *supported_key_prefix_map[] = {
    [SKP_NONE] = "",       [SKP_ESN] = "ecdsa-sha2-nistp", [SKP_RS2] = "rsa-sha2-",
    [SKP_RSA] = "ssh-rsa", [SKP_ED9] = "ssh-ed25519",
};

bool is_valid_ssh_public_key_prefix(const char *ssh_key) {
  if (ssh_key == NULL) {
    return false;
  }
  size_t ssh_key_len = strlen(ssh_key);

  // reject embedded newlines to prevent authorized_keys injection
  if (memchr(ssh_key, '\n', ssh_key_len) != NULL || memchr(ssh_key, '\r', ssh_key_len) != NULL) {
    return false;
  }

  // i = 1: skip SKP_NONE whose empty-string prefix would match any key
  for (int i = 1; i < SUPPORTED_KEY_PREFIX_LEN; i++) {
    char *prefix = supported_key_prefix_map[i];
    size_t prefix_len = strlen(prefix);

    if (prefix_len > ssh_key_len) {
      continue;
    }

    if (strncmp(ssh_key, prefix, prefix_len) == 0) {
      return true;
    }
  }
  return false;
}

void handle_sshpublickey(sshnpd_params *params, atclient_monitor_message *message, FILE *authkeys_file,
                         char *authkeys_filename) {
  if (!params->sshpublickey) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Ignoring sshpublickey from %s\n",
                 message->notification->from);
    return;
  }

  char *ssh_key = (char *)message->notification->decrypted_value;

  if (!is_valid_ssh_public_key_prefix(ssh_key)) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Ssh public key does not look like a public key\n");
    return;
  }

  authkeys_params authkeys_params = {};
  authkeys_params.authkeys_file = authkeys_file;
  authkeys_params.authkeys_filename = authkeys_filename;
  // Scope the pushed key to the local tunnel: an ssh session always reaches
  // sshd via srv connecting to localhost, so it arrives from 127.0.0.1/::1.
  // Without this the entry grants unrestricted login from anywhere and lingers
  // in authorized_keys after the client's authorization is revoked.
  authkeys_params.permissions = "from=\"127.0.0.1,::1\"";
  authkeys_params.key = ssh_key;

  // authorize public key
  int ret = authorize_ssh_public_key(&authkeys_params);
  if (ret != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to authorize ssh public key\n");
    return;
  }

  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Authorized public key\n");
}
