#ifndef RUN_SRV_H
#define RUN_SRV_H

#include <atclient/json.h>
#include <stdbool.h>
#include <stdint.h>

// The d2c key and iv may be NULL, in which case the session uses a single key
// (the c2d key) for both directions of traffic.
int run_srv_process(const char *srvd_host, uint16_t srvd_port, const char *requested_host, uint16_t requested_port,
                    bool authenticate_to_rvd, char *rvd_auth_string, bool encrypt_rvd_traffic, bool multi,
                    unsigned char *session_aes_key_c2d, unsigned char *session_iv_c2d, unsigned char *session_aes_key_d2c,
                    unsigned char *session_iv_d2c);
#endif
