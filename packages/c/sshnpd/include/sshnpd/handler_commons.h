#ifndef HANDLER_COMMONS_H
#define HANDLER_COMMONS_H
#include "sshnpd/params.h"
#include <atclient/atkeys.h>
#include <atclient/json.h>
#include <atclient/monitor.h>

#define BYTES(x) (sizeof(unsigned char) * x)

int verify_envelope_signature_from(cJSON *envelope, char *requesting_atsign, atclient *atclient);
int verify_envelope_signature(atchops_rsa_key_public_key *publickey, const unsigned char *payload,
                              unsigned char *signature, const char *hashing_algo, const char *signing_algo);

enum payload_type { payload_type_ssh, payload_type_npt };

cJSON *extract_envelope_from_notification(atclient_monitor_message *message);

int verify_envelope_contents(cJSON *envelope, enum payload_type type);

int verify_payload_contents(cJSON *payload, enum payload_type type);

int create_rvd_auth_string(cJSON *payload, atchops_rsa_key_private_key *signing_key, char **rvd_auth_string);

// Notify the requesting client that its session request was denied and why.
// The value is a plain string, deliberately not json: the client treats a
// payload starting with '{' as a signed envelope carrying session keys.
int send_session_error(atclient *atclient, sshnpd_params *params, char *requesting_atsign, const char *session_id,
                       const char *message);

// Format the daemon's permit-open list the way Dart prints a List:
// '[localhost:22, localhost:3389]' (a port of 0 prints as '*')
void format_permitopen_list(char **hosts, const uint16_t *ports, size_t len, char *buf, size_t bufsize);

// Format a list of strings the way Dart prints a List: '[a, b]'
void format_string_list(char **items, size_t len, char *buf, size_t bufsize);

// Returns the malloc'd atProtocol uri of the daemon's public signing key,
// 'public:_apsk.<enrollmentId>.a.__e<atsign>', used for escr relay auth. The
// enrollment id falls back to 'primary' when the atkeys carry none.
char *public_signing_key_uri(const atclient_atkeys *atkeys, const char *atsign);

// Generates a fresh session AES key and iv, returning the base64 encoded
// plaintext values (session_aes_key / session_iv) alongside copies encrypted
// with the client's ephemeral public key (the *_base64 out params). Call once
// for the C2D key and, when the client requested twinned keys, a second time
// for the D2C key.
int setup_rvd_session_encryption(cJSON *payload, unsigned char **session_aes_key, char **session_aes_key_base64,
                                 unsigned char **session_iv, char **session_iv_base64);

// The d2c key and iv may be NULL. When they are provided the response payload
// uses the twinned key field names (aesKeyC2D/ivC2D/aesKeyD2C/ivD2C), matching
// the Dart sshnpd; otherwise the legacy names (sessionAESKey/sessionIV).
int send_success_payload(cJSON *payload, atclient *atclient, sshnpd_params *params, char *session_aes_key_c2d_base64,
                         char *session_iv_c2d_base64, char *session_aes_key_d2c_base64, char *session_iv_d2c_base64,
                         atchops_rsa_key_private_key *signing_key, char *requesting_atsign);

bool is_manager_atsign(const sshnpd_params *params, const char *atsign);
#endif
