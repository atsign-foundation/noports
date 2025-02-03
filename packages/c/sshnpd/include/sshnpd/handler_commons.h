#ifndef HANDLER_COMMONS_H
#define HANDLER_COMMONS_H
#include "sshnpd/params.h"
#include <atclient/json.h>
#include <atclient/monitor.h>
#include <pthread.h>

#define BYTES(x) (sizeof(unsigned char) * x)

int verify_envelope_signature_from(cJSON *envelope, char *requesting_atsign, atclient *atclient,
                                   pthread_mutex_t *atclient_lock);
int verify_envelope_signature(atchops_rsa_key_public_key *publickey, const unsigned char *payload,
                              unsigned char *signature, const char *hashing_algo, const char *signing_algo);

enum payload_type { payload_type_ssh, payload_type_npt };

cJSON *extract_envelope_from_notification(atclient_monitor_response *message);

int verify_envelope_contents(cJSON *envelope, enum payload_type type);

int verify_payload_contents(cJSON *payload, enum payload_type type);

int create_rvd_auth_string(cJSON *payload, atchops_rsa_key_private_key *signing_key, char **rvd_auth_string);

int setup_rvd_session_encryption(cJSON *payload, unsigned char **session_aes_key, char **session_aes_key_base64,
                                 unsigned char **session_iv, char **session_iv_base64);

int send_success_payload(cJSON *payload, atclient *atclient, pthread_mutex_t *atclient_lock, sshnpd_params *params,
                         char *session_aes_key_base64, char *session_iv_base64,
                         atchops_rsa_key_private_key *signing_key, char *requesting_atsign);
#endif
