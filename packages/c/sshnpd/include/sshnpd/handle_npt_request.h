#ifndef HANDLE_NPT_REQUEST_H
#define HANDLE_NPT_REQUEST_H
#include "sshnpd/params.h"
#include <atclient/monitor.h>
#include <pthread.h>

void handle_npt_request(atclient *atclient, pthread_mutex_t *atclient_lock, sshnpd_params *params,
                        bool *is_child_process, atclient_monitor_response *message, char *home_dir, FILE *authkeys_file,
                        char *authkeys_filename, atchops_rsa_key_private_key signing_key);
#endif
