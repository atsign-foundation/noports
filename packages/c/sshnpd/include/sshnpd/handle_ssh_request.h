#ifndef HANDLE_SSH_REQUEST_H
#define HANDLE_SSH_REQUEST_H
#include "sshnpd/params.h"
#include <atclient/monitor.h>
#include <pthread.h>

void handle_ssh_request(atclient *atclient, pthread_mutex_t *atclient_lock, sshnpd_params *params,
                        bool *is_child_process, atclient_monitor_response *message, char *home_dir, FILE *authkeys_file,
                        char *authkeys_filename, atchops_rsa_key_private_key signing_key);

int verify_envelope_signature(atchops_rsa_key_public_key publickey, const unsigned char *payload,
                              unsigned char *signature, const char *hashing_algo, const char *signing_algo);

#endif
