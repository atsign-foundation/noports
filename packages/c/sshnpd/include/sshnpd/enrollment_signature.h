#ifndef SSHNPD_ENROLLMENT_SIGNATURE_H
#define SSHNPD_ENROLLMENT_SIGNATURE_H

#include <atclient/json.h>
#include <sshnpd/public_lookup.h>
#include <stddef.h>

// The request envelope field holding the payload's signature by the sender's
// enrollment key, beside the atSign-wide `signature`
#define ENROLLMENT_SIGNATURE_FIELD "enrollmentSignature"

enum enrollment_signature_result {
  // The envelope carries no enrollment signature
  ENROLLMENT_SIGNATURE_ABSENT,
  // It verifies against the `_apsk` record it names
  ENROLLMENT_SIGNATURE_VERIFIED,
  // It is malformed, names a record that isn't the requester's, is made with
  // an algorithm this daemon can't verify, or doesn't verify
  ENROLLMENT_SIGNATURE_REFUSED,
  // The record it names couldn't be looked up
  ENROLLMENT_SIGNATURE_UNCHECKED,
};

// Looks up the public record uri, setting *value (malloc'd) when found
typedef enum public_lookup_result (*enrollment_signature_lookup_fn)(const char *uri, char **value, void *ctx);

// Verifies the ENROLLMENT_SIGNATURE_FIELD of envelope, a request from
// requester, against the `_apsk` record it names, looked up with lookup. On
// ENROLLMENT_SIGNATURE_VERIFIED, *signing_key is that record's canonical
// uri (malloc'd); on ENROLLMENT_SIGNATURE_REFUSED and _UNCHECKED, why says
// why. ML-DSA signatures are refused, since atchops can't verify them.
enum enrollment_signature_result verify_enrollment_signature(const cJSON *envelope, const char *requester,
                                                             enrollment_signature_lookup_fn lookup, void *ctx,
                                                             char **signing_key, char *why, size_t why_size);

#endif
