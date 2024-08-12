#ifndef HANDLE_SSHPUBLICKEY_H
#define HANDLE_SSHPUBLICKEY_H
#include "sshnpd/params.h"
#include <atclient/monitor.h>
void handle_sshpublickey(sshnpd_params *params, atclient_monitor_response *message, FILE *authkeys_file,
                         char *authkeys_filename);
#endif
