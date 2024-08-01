#ifndef HANDLE_SSH_REQUEST_H
#define HANDLE_SSH_REQUEST_H
#include "sshnpd/params.h"
#include "sshnpd/sshnpd.h"
#include <atclient/monitor.h>
#include <pthread.h>

void handle_ssh_request(atclient *atclient, pthread_mutex_t *atclient_lock, sshnpd_params *params,
                        bool *is_child_process, atclient_monitor_message *message, char *home_dir, FILE *authkeys_file,
                        char *authkeys_filename, atchops_rsakey_privatekey signing_key,
                        struct sshnpd_process_node *process_head);

int verify_envelope_signature(atchops_rsakey_publickey publickey, const unsigned char *payload,
                              unsigned char *signature, const char *hashing_algo, const char *signing_algo);

#endif
