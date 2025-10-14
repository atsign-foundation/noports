#ifndef HANDLE_SSH_REQUEST_H
#define HANDLE_SSH_REQUEST_H
#include "sshnpd/params.h"
#include <atclient/monitor.h>

void handle_ssh_request(atclient *atclient, sshnpd_params *params, bool *is_child_process,
                        atclient_monitor_message *message, atchops_rsa_key_private_key signing_key);

#endif
