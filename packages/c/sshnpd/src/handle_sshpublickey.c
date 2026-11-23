#include "sshnpd/handle_sshpublickey.h"
#include "sshnpd/file_utils.h"
#include "sshnpd/params.h"
#include <atclient/monitor.h>
#include <atlogger/atlogger.h>
#include <stdbool.h>
#include <string.h>

#define LOGGER_TAG "SSHPUBLICKEY RESPONSE"

void handle_sshpublickey(sshnpd_params *params, atclient_monitor_message *message, const char *authkeys_filename) {
  const char *from = message->notification->from;
  if (!params->sshpublickey) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Ignoring sshpublickey from %s\n", from);
    return;
  }

  const char *value = message->notification->decrypted_value;
  sshnpd_authorized_key key;
  const char *reason = NULL;
  if (sshnpd_authorized_key_build(value, NULL, &key, &reason) != 0) {
    char shown[SSHNPD_SSHPUBLICKEY_LOG_MAX_LEN + 1];
    sshnpd_one_line_for_log(value, shown, sizeof(shown));
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_WARN, "Refusing the sshpublickey from %s, as %s: \"%s\"\n", from,
                 reason, shown);
    return;
  }

  bool added = false;
  if (authorize_ssh_public_key(authkeys_filename, &key, &added) != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to add the ssh public key from %s\n", from);
  } else if (!added) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_INFO, "The ssh public key from %s is already in authorized_keys\n",
                 from);
  } else if (key.comment_left_out) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_INFO,
                 "Added the ssh public key from %s without its comment, which was not printable ASCII or was over %d "
                 "characters\n",
                 from, SSHNPD_SSHPUBLICKEY_MAX_COMMENT_LEN);
  } else {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_INFO, "Added the ssh public key from %s\n", from);
  }
  sshnpd_authorized_key_free(&key);
}
