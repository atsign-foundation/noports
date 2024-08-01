#include "srv/params.h"
#include "srv/srv.h"
#include "sshnpd/params.h"
#include <atclient/stringutils.h>
#include <atlogger/atlogger.h>
#include <cJSON.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/errno.h>
#include <unistd.h>

#define LOGGER_TAG "RUN SRV"

int run_srv_process(sshnpd_params *params, cJSON *host, cJSON *port, bool npt, cJSON *requested_host,
                    cJSON *requested_port, bool authenticate_to_rvd, char *rvd_auth_string, bool encrypt_rvd_traffic,
                    bool multi, unsigned char *session_aes_key_encrypted, unsigned char *session_iv_encrypted,
                    FILE *authkeys_file, char *authkeys_filename) {
  int res = 0;
  srv_params_t srv_params;
  apply_default_values_to_srv_params(&srv_params);

  srv_params.host = cJSON_GetStringValue(host);
  srv_params.port = (uint16_t)cJSON_GetNumberValue(port);

  if (npt) {
    srv_params.local_host = cJSON_GetStringValue(requested_host);
    srv_params.local_port = (uint16_t)cJSON_GetNumberValue(requested_port);
  } else {
    srv_params.local_port = params->local_sshd_port;
  }

  srv_params.rv_auth = authenticate_to_rvd;
  srv_params.rvd_auth_string = rvd_auth_string;

  srv_params.rv_e2ee = encrypt_rvd_traffic;
  srv_params.session_aes_key_string = (char *)session_aes_key_encrypted;
  srv_params.session_aes_iv_string = (char *)session_iv_encrypted;
  srv_params.multi = multi;

  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Starting srv\n");
  fflush(stdout);

  atlogger_set_logging_level(ATLOGGER_LOGGING_LEVEL_INFO);
  res = run_srv(&srv_params);

  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "srv exited (with code %d): %s\n", res, strerror(errno));
  fflush(stdout);

  return res;
}
