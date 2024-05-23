#include "sshnpd/params.h"
#include <atlogger/atlogger.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/errno.h>
#include <unistd.h>

#define LOGGER_TAG "RUN ssh-keygen"
void run_sshkeygen(sshnpd_params *params, char *filename, char *comment) {
  int res = 0;

  size_t argc = 12;
  char **argv = malloc(sizeof(char *) * (argc + 1));
  if (argv == NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "ssh-keygen fork failed to allocate some memory\n");
    exit(1);
  }
  argv[argc] = NULL;

  size_t off = 0;
  argv[off++] = "ssh-keygen";

  switch (params->ssh_algorithm) {
  case RSA: {
    argv[off++] = "-t";
    argv[off++] = "rsa";
    argv[off++] = "-b";
    argv[off++] = "4096";
  }
  case ED25519: {
    argv[off++] = "-t";
    argv[off++] = "ed25519";
    argv[off++] = "-a";
    argv[off++] = "100";
  }
  }

  argv[off++] = "-f";
  argv[off++] = filename;
  argv[off++] = "-q";
  argv[off++] = "-C";
  argv[off++] = comment;
  argv[off++] = "-N";
  argv[off++] = "";

  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Starting ssh-keygen with command:");
  for (int i = 0; i < argc; i++) {
    printf(" %s", argv[i]);
  }
  printf("\n");
  fflush(stdout);
  res = execvp("ssh-keygen", argv);
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "ssh-keygen exited (with code %d): %s\n", res,
               strerror(errno));
  fflush(stdout);
  exit(res);
}
