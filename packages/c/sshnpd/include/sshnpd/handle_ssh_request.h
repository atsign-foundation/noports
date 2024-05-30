#ifndef HANDLE_SSH_REQUEST_H
#define HANDLE_SSH_REQUEST_H
#include "sshnpd/params.h"
#include <atclient/monitor.h>
#include <pthread.h>

void handle_ssh_request(atclient *atclient, pthread_mutex_t *atclient_lock, sshnpd_params *params,
                        atclient_monitor_message *message, char *home_dir, FILE *authkeys_file, char *authkeys_filename,
                        atchops_rsakey_privatekey signing_key);
#endif
