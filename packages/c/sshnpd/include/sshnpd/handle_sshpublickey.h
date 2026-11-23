#ifndef HANDLE_SSHPUBLICKEY_H
#define HANDLE_SSHPUBLICKEY_H
#include "sshnpd/params.h"
#include <atclient/monitor.h>

/**
 * @brief Adds the ssh public key in message to the authorized_keys file at
 * authkeys_filename when params->sshpublickey is set, as one line allowing
 * logins only from the loopback address; logs a warning naming the sender
 * when the value is refused.
 */
void handle_sshpublickey(sshnpd_params *params, atclient_monitor_message *message, const char *authkeys_filename);

#endif
