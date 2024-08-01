#ifndef HANDLER_COMMONS_H
#define HANDLER_COMMONS_H
#include "sshnpd/params.h"
#include "sshnpd/sshnpd.h"
#include <atclient/monitor.h>
#include <pthread.h>

#define BYTES(x) (sizeof(unsigned char) * x)

int verify_envelope_signature(atchops_rsakey_publickey publickey, const unsigned char *payload,
                              unsigned char *signature, const char *hashing_algo, const char *signing_algo);

#endif

