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

void run_srv(char *dir, sshnpd_params *params, cJSON *host, cJSON *port, bool authenticate_to_rvd,
             char *rvd_auth_string, bool encrypt_rvd_traffic, unsigned char *session_aes_key_encrypted,
             unsigned char *session_iv_encrypted, FILE *authkeys_file, char *authkeys_filename) {
  int res = 0;
  char *path;
  if (dir[0] == '/') {
    // absolute path - so just use it
    size_t srv_path_len = strlen(dir) + 5; // "<dir>/srv"
    path = malloc(sizeof(char) * srv_path_len);
    if (path == NULL) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "srv fork failed to allocate some memory\n");
      exit(1);
    }
    snprintf(path, srv_path_len, "%s/srv", dir);
  } else {
    char *cwd;
    cwd = getcwd(NULL, 0); // free this
    if (cwd == NULL) {
      res = errno;
      if (res == 0) {
        res = 1;
      }
      printf("Failed to get the current working directory: %s\n", strerror(errno));
      exit(res);
    }
    size_t srv_path_len = (strlen(cwd) + strlen(dir) + 6); // + 1 for a '/' inbetween + 4 for "/srv" + 1 for '\0'
    path = malloc(sizeof(char) * srv_path_len);
    if (path == NULL) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "srv fork failed to allocate some memory\n");
      exit(1);
    }
    snprintf(path, srv_path_len, "%s/%s/srv", cwd, dir);
    free(cwd);
  }

  char *streaming_host = cJSON_GetStringValue(host);
  char *streaming_port = cJSON_Print(port);
  long local_port_len = long_strlen(params->local_sshd_port);

  size_t argc = 9 + authenticate_to_rvd + encrypt_rvd_traffic;
  char **argv = malloc(sizeof(char *) * (argc + 1));
  if (argv == NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "srv fork failed to allocate some memory\n");
    exit(1);
  }
  argv[0] = path;
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

  size_t envc = authenticate_to_rvd + 2 * encrypt_rvd_traffic;
  char **envp = malloc(sizeof(char *) * (envc + 1));
  if (envp == NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "srv fork failed to allocate some memory\n");
    exit(1);
  }
  envp[envc] = NULL;
  off = 0;
  if (authenticate_to_rvd) {
    size = strlen(rvd_auth_string) + 9; // "RV_AUTH="+ \0
    envp[off] = malloc(sizeof(char) * size);
    if (envp[off] == NULL) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "srv fork failed to allocate some memory\n");
      exit(1);
    }
    snprintf(envp[off++], size, "RV_AUTH=%s", rvd_auth_string);
  }

  if (encrypt_rvd_traffic) {
    envp[off] = malloc(sizeof(char) * size);
    if (envp[off] == NULL) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "srv fork failed to allocate some memory\n");
      exit(1);
    }
    snprintf(envp[off++], size, "RV_AES=%s", session_aes_key_encrypted);

    size = strlen((char *)session_iv_encrypted) + 7; // "RV_IV="+ \0
    envp[off] = malloc(sizeof(char) * size);
    if (envp[off] == NULL) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "srv fork failed to allocate some memory\n");
      exit(1);
    }
    snprintf(envp[off++], size, "RV_IV=%s", session_iv_encrypted);
  }

  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Starting srv with command:");
  for (int i = 0; i < argc; i++) {
    printf(" %s", argv[i]);
  }
  printf("\n");
  fflush(stdout);
  res = execve(path, argv, envp);
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "srv exited (with code %d): %s\n", res, strerror(errno));
  fflush(stdout);
  exit(res);
}
