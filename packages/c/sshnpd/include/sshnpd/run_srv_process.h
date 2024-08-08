#ifndef RUN_SRV_H
#define RUN_SRV_H

#include "sshnpd/params.h"
#include <cJSON.h>
#include <stdio.h>

int run_srv_process(sshnpd_params *params, cJSON *host, cJSON *port, bool authenticate_to_rvd, char *rvd_auth_string,
                    bool encrypt_rvd_traffic, bool multi, unsigned char *session_aes_key_encrypted,
                    unsigned char *session_iv_encrypted, FILE *authkeys_file, char *authkeys_filename);
#endif
