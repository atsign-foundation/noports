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

void handle_sshpublickey(sshnpd_params *params, atclient_monitor_response *message, FILE *authkeys_file,
                         char *authkeys_filename) {
  if (!params->sshpublickey) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Ignoring sshpublickey from %s\n",
                 message->notification.from);
    return;
  }

  char *ssh_key = (char *)message->notification.decrypted_value;
  size_t ssh_key_len = strlen(ssh_key);

  bool is_valid_prefix = false;
  for (int i = 1; i < SUPPORTED_KEY_PREFIX_LEN; i++) {
    char *prefix = supported_key_prefix_map[i];
    size_t prefix_len = strlen(message->notification.decrypted_value);

    if (prefix_len < strlen(ssh_key)) {
      continue;
    }

    if (strncmp(ssh_key, prefix, prefix_len)) {
      is_valid_prefix = true;
      break;
    }
  }

  if (!is_valid_prefix) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Ssh public key does not look like a public key\n");
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
