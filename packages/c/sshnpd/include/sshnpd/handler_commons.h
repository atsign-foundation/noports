#ifndef HANDLER_COMMONS_H
#define HANDLER_COMMONS_H
#include <atclient/monitor.h>
#include <pthread.h>

#define BYTES(x) (sizeof(unsigned char) * x)

int verify_envelope_signature(atchops_rsa_key_public_key publickey, const unsigned char *payload,
                              unsigned char *signature, const char *hashing_algo, const char *signing_algo);

#endif
