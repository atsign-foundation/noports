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

void run_srv_process(sshnpd_params *params, cJSON *host, cJSON *port, bool authenticate_to_rvd, char *rvd_auth_string,
                     bool encrypt_rvd_traffic, unsigned char *session_aes_key_encrypted,
                     unsigned char *session_iv_encrypted, FILE *authkeys_file, char *authkeys_filename) {
  int res = 0;

  char *streaming_host = cJSON_GetStringValue(host);
  char *streaming_port = cJSON_Print(port);
  long local_port_len = long_strlen(params->local_sshd_port);

  size_t argc = 9 + authenticate_to_rvd + encrypt_rvd_traffic;
  char **argv = malloc(sizeof(char *) * (argc + 1));
  if (argv == NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "srv fork failed to allocate some memory\n");
    exit(1);
  }
  argv[0] = "srv";
  argv[argc] = NULL; // the array must be terminated with a NULL pointer
  int off = 1;
  // -h
  argv[off++] = "-h";
  argv[off++] = streaming_host;
  // -p
  argv[off++] = "-p";
  argv[off++] = streaming_port;
  //--local-port
  argv[off++] = "--local-port";
  size_t size = local_port_len + 1;
  char *streaming_port_str = malloc(sizeof(char) * size);
  if (streaming_port_str == NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "srv fork failed to allocate some memory\n");
    exit(1);
  }
  snprintf(streaming_port_str, size, "%d", params->local_sshd_port);
  argv[off++] = streaming_port_str;
  // --local-host
  argv[off++] = "--local-host";
  argv[off++] = "localhost";

  if (authenticate_to_rvd) {
    argv[off++] = "--rv-auth";
  }

  if (encrypt_rvd_traffic) {
    argv[off++] = "--rv-e2ee";
  }

  srv_env_t environment = {
      rvd_auth_string,
      (char *)session_aes_key_encrypted,
      (char *)session_iv_encrypted,
  };

  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Starting srv with command:");
  for (int i = 0; i < argc; i++) {
    printf(" %s", argv[i]);
  }
  printf("\n");
  fflush(stdout);

  srv_params_t srv_params;
  apply_default_values_to_srv_params(&srv_params);
  if (parse_srv_params(&srv_params, argc, (const char **)argv, &environment) != 0) {
    exit(1);
  }

  res = run_srv(&srv_params);

  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "srv exited (with code %d): %s\n", res, strerror(errno));
  fflush(stdout);
  exit(res);
}
