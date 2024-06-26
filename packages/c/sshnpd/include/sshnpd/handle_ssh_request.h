#ifndef HANDLE_SSH_REQUEST_H
#define HANDLE_SSH_REQUEST_H
#include "sshnpd/params.h"
#include <atclient/monitor.h>
#include <pthread.h>

void handle_ssh_request(atclient *atclient, pthread_mutex_t *atclient_lock, sshnpd_params *params,
                        bool *is_child_process, atclient_monitor_message *message, char *home_dir, FILE *authkeys_file,
                        char *authkeys_filename, atchops_rsakey_privatekey signing_key);

int verify_envelope_signature(atchops_rsakey_publickey publickey, const unsigned char *payload,
                              unsigned char *signature, const char *hashing_algo, const char *signing_algo);
                              
static int create_response_atkey(atclient_atkey *key, const char *atsign, const char *requesting_atsign,
                                 const char *session_id, const char *keyname, const size_t *keynamelen);

static int notify(atclient *atclient, pthread_mutex_t *atclient_lock, atclient_atkey *key, char *value);

#endif
