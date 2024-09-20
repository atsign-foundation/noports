#include "srv/params.h"
#include "srv/srv.h"
#include <atclient/cjson.h>
#include <atclient/string_utils.h>
#include <atlogger/atlogger.h>
#include <stdio.h>
#include <string.h>
#include <sys/errno.h>
#include <unistd.h>

#define LOGGER_TAG "RUN SRV"

int run_srv_process(const char *srvd_host, uint16_t srvd_port, const char *requested_host, uint16_t requested_port,
                    bool authenticate_to_rvd, char *rvd_auth_string, bool encrypt_rvd_traffic, bool multi,
                    unsigned char *session_aes_key_encrypted, unsigned char *session_iv_encrypted) {

  int res = 0;
  srv_params_t srv_params;
  apply_default_values_to_srv_params(&srv_params);

  srv_params.host = (char *)srvd_host;
  srv_params.port = srvd_port;

  if (requested_host != NULL) {
    srv_params.local_host = (char *)requested_host;
  }
  if (requested_port != 0) {
    srv_params.local_port = requested_port;
  }

  srv_params.rv_auth = authenticate_to_rvd;
  srv_params.rvd_auth_string = rvd_auth_string;

  srv_params.rv_e2ee = encrypt_rvd_traffic;
  srv_params.session_aes_key_string = (char *)session_aes_key_encrypted;
  srv_params.session_aes_iv_string = (char *)session_iv_encrypted;
  srv_params.multi = multi;

  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Starting srv\n");
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "relay: %s:%d\n", srvd_host, srvd_port);
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "requested: %s:%d\n", requested_host, requested_port);
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "rv_auth: %d\n", authenticate_to_rvd);
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "rv_e2ee: %d\n", encrypt_rvd_traffic);
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "multi: %d\n", multi);
  fflush(stdout);

  atlogger_set_logging_level(ATLOGGER_LOGGING_LEVEL_INFO);
  res = run_srv(&srv_params);

  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "srv exited (with code %d): %s\n", res, strerror(errno));
  fflush(stdout);

  return res;
}
