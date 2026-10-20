#ifndef SSHNPD_CLIENT_SIGNING_KEY_H
#define SSHNPD_CLIENT_SIGNING_KEY_H

#include <atclient/atclient.h>
#include <atclient/json.h>
#include <sshnpd/params.h>

// Finds the canonical `_apsk` record requesting_atsign signed envelope with,
// verified, setting *signing_key (malloc'd), or NULL when the request wasn't
// signed with an enrollment key or its signature couldn't be checked.
// Refuses the request, telling the client why, when a session with its id
// is already being watched, when its signature doesn't verify, or, under
// --require-enrollment-signature, when it is unsigned or can't be checked.
// Returns non-zero when it refused.
int check_client_signing_key(atclient *atclient, sshnpd_params *params, char *requesting_atsign,
                             const cJSON *envelope, char **signing_key);

#endif
