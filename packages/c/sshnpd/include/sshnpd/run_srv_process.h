#ifndef RUN_SRV_H
#define RUN_SRV_H

#include <atclient/cjson.h>
#include <stdbool.h>
#include <stdint.h>

int run_srv_process(const char *srvd_host, uint16_t srvd_port, const char *requested_host, uint16_t requested_port,
                    bool authenticate_to_rvd, char *rvd_auth_string, bool encrypt_rvd_traffic, bool multi,
                    unsigned char *session_aes_key_encrypted, unsigned char *session_iv_encrypted);
#endif
