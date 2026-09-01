#ifndef RUN_SRV_H
#define RUN_SRV_H

#include <atchops/rsa_key.h>
#include <atclient/json.h>
#include <stdbool.h>
#include <stdint.h>

// Everything the srv needs to run ESCR (encrypted signed challenge response)
// relay authentication for one session. All pointers are borrowed.
//
// signing_key_base64 is the daemon's PKAM private key in base64 (atkeys
// pkam_private_key_base64). The srv is exec'd as a separate process and reads
// it from REMOTE_AUTH_ESCR_SIGNING_PRIVKEY, matching the Dart daemon's
// contract, so the parsed RSA struct is no longer passed across the boundary.
typedef struct {
  const char *session_id;
  const char *aes_key_base64;      // the session's relayAuthAesKey
  const char *signing_key_uri;     // public:_apsk.<enrollmentId>.a.__e<atsign>
  const char *signing_key_base64;  // the daemon's PKAM private key, base64
} sshnpd_escr_context;

// The d2c key and iv may be NULL, in which case the session uses a single key
// (the c2d key) for both directions of traffic.
// timeout_seconds: how long the srv stays alive with no active connections
// before exiting (multi mode only); pass SRV_DEFAULT_TIMEOUT_SECONDS when the
// request doesn't specify one.
// escr: non-NULL to authenticate to the relay with ESCR instead of the legacy
// rvd_auth_string.
int run_srv_process(const char *srvd_host, uint16_t srvd_port, const char *requested_host, uint16_t requested_port,
                    bool authenticate_to_rvd, char *rvd_auth_string, const sshnpd_escr_context *escr,
                    bool encrypt_rvd_traffic, bool multi, int timeout_seconds, unsigned char *session_aes_key_c2d,
                    unsigned char *session_iv_c2d, unsigned char *session_aes_key_d2c, unsigned char *session_iv_d2c);
#endif
