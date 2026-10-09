#ifndef NOPORTS_ENROLLMENT_SIGNATURE_H
#define NOPORTS_ENROLLMENT_SIGNATURE_H

#include "atclient/json.h"
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// The request envelope field holding the payload's signature by the sender's
// enrollment key, beside the atSign-wide `signature`
#define NOPORTS_ENROLLMENT_SIGNATURE_FIELD "enrollmentSignature"

enum noports_lookup_result {
  // The atServer answered with the record's value
  NOPORTS_LOOKUP_FOUND = 0,
  // The atServer answered that it holds no such record
  NOPORTS_LOOKUP_NOT_FOUND = 1,
  // The atServer couldn't be found, connected to or trusted, or didn't answer
  // over HTTP, so asking it some other way might still work
  NOPORTS_LOOKUP_NOT_SERVED = 2,
  // The atServer was connected to but didn't answer in time, or answered with
  // something unusable
  NOPORTS_LOOKUP_FAILED = 3,
};

enum noports_enrollment_signature {
  // The envelope carries no enrollment signature
  NOPORTS_ENROLLMENT_SIGNATURE_ABSENT,
  // It verifies against the `_apsk` record it names
  NOPORTS_ENROLLMENT_SIGNATURE_VERIFIED,
  // It is malformed, names a record that isn't the requester's, is made with
  // an algorithm this daemon can't verify, or doesn't verify
  NOPORTS_ENROLLMENT_SIGNATURE_REFUSED,
  // The record it names couldn't be looked up
  NOPORTS_ENROLLMENT_SIGNATURE_UNCHECKED,
};

// Looks up the public record uri, setting *value (malloc'd) when found
typedef enum noports_lookup_result (*noports_enrollment_signature_lookup_fn)(const char *uri, char **value,
                                                                             void *ctx);

// Verifies the NOPORTS_ENROLLMENT_SIGNATURE_FIELD of envelope, a request from
// requester, against the `_apsk` record it names, looked up with lookup. On
// NOPORTS_ENROLLMENT_SIGNATURE_VERIFIED, *signing_key is that record's
// canonical uri (malloc'd); on _REFUSED and _UNCHECKED, why says why. ML-DSA
// signatures are refused, since atchops can't verify them.
enum noports_enrollment_signature noports_verify_enrollment_signature(const cJSON *envelope, const char *requester,
                                                                      noports_enrollment_signature_lookup_fn lookup,
                                                                      void *ctx, char **signing_key, char *why,
                                                                      size_t why_size);

#ifdef __cplusplus
}
#endif

#endif
