#include "srv/params.h"
#include "srv/srv.h"
#include <atclient/json.h>
#include <sshnpd/run_srv_process.h>
#include <atclient/string_utils.h>
#include <atlogger/atlogger.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>

#define LOGGER_TAG "RUN SRV"

int run_srv_process(const char *srvd_host, uint16_t srvd_port, const char *requested_host, uint16_t requested_port,
                    bool authenticate_to_rvd, char *rvd_auth_string, const sshnpd_escr_context *escr,
                    bool encrypt_rvd_traffic, bool multi, int timeout_seconds, unsigned char *session_aes_key_c2d,
                    unsigned char *session_iv_c2d, unsigned char *session_aes_key_d2c, unsigned char *session_iv_d2c) {

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

  if (escr != NULL) {
    // ESCR replaces the legacy auth string entirely; the daemon side is
    // always side b of the session
    srv_params.escr_auth = true;
    srv_params.escr_is_side_a = false;
    srv_params.escr_session_id = (char *)escr->session_id;
    srv_params.escr_aes_key_base64 = (char *)escr->aes_key_base64;
    srv_params.escr_signing_key_uri = (char *)escr->signing_key_uri;
    srv_params.escr_signing_key = escr->signing_key;
  } else {
    srv_params.rv_auth = authenticate_to_rvd;
    srv_params.rvd_auth_string = rvd_auth_string;
  }

  srv_params.rv_e2ee = encrypt_rvd_traffic;
  srv_params.session_aes_key_c2d_string = (char *)session_aes_key_c2d;
  srv_params.session_aes_iv_c2d_string = (char *)session_iv_c2d;
  srv_params.session_aes_key_d2c_string = (char *)session_aes_key_d2c;
  srv_params.session_aes_iv_d2c_string = (char *)session_iv_d2c;
  srv_params.multi = multi;
  srv_params.timeout = timeout_seconds > 0 ? timeout_seconds : SRV_DEFAULT_TIMEOUT_SECONDS;

  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Starting srv\n");
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "relay: %s:%d\n", srvd_host, srvd_port);
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "requested: %s:%d\n", requested_host, requested_port);
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "rv_auth: %d\n", authenticate_to_rvd);
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "rv_e2ee: %d\n", encrypt_rvd_traffic);
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "multi: %d\n", multi);
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "timeout: %d\n", srv_params.timeout);
  fflush(stdout);

  atlogger_set_logging_level(ATLOGGER_LOGGING_LEVEL_INFO);
  res = run_srv(&srv_params);

  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "srv exited (with code %d): %s\n", res, strerror(errno));
  fflush(stdout);

  return res;
}
