#include "sshnpd/file_utils.h"
#include <atlogger/atlogger.h>
#include <pthread.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/errno.h>
#include <unistd.h>

int authorize_ssh_public_key(authkeys_params *params) {
  const char *tag = "AUTH SSH KEY";
  int ret = 0;

  flockfile(params->authkeys_file); // should be safe to call freopen inside a lock, since the FILE stream is preserved
                                    // in most implementations
  params->authkeys_file = freopen(params->authkeys_filename, "a+", params->authkeys_file); // reopen file in append mode
  if (params->authkeys_file == NULL) {
    atlogger_log(tag, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to freopen authkeys file: %s\n", strerror(errno));
    if (errno != 0) {
      ret = errno;
    } else {
      ret = 1;
    }
    goto exit;
  }

  ret = fseek(params->authkeys_file, 0, SEEK_SET);
  if (ret != 0) {
    atlogger_log(tag, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to seek to the beginning of authkeys file: %s\n",
                 strerror(errno));
    goto exit;
  }

  size_t bufsize = 256;
  char *buf = malloc(bufsize * sizeof(char));
  if (buf == NULL) {
    atlogger_log(tag, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to allocate memory for buf\n", strerror(errno));
    ret = 1;
    goto exit;
  }

  while (getline(&buf, &bufsize, params->authkeys_file) >= 0) {
    if (strstr(buf, params->key) != NULL) {
      // already exists in the file, moving on
      atlogger_log(tag, ATLOGGER_LOGGING_LEVEL_DEBUG, "Already found key in the file, did not add a second entry\n");
      ret = 0;
      goto cleanup;
    }
  }

  ret = fseek(params->authkeys_file, 0, SEEK_END); // on some platforms a+ opens to the end so seek to beginning first
  if (ret != 0) {
    atlogger_log(tag, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to seek to the end of authkeys file: %s\n",
                 strerror(errno));
    goto cleanup;
  }

  char *postfix = "";
  if (params->key[strlen(params->key) - 1] != '\n') {
    postfix = "\n";
  }

  if (strlen(params->permissions) > 0) {
    ret = fprintf(params->authkeys_file, "%s %s%s", params->permissions, params->key, postfix);
  } else {
    ret = fprintf(params->authkeys_file, "%s%s", params->key, postfix);
  }

  if (ret < 0) {
    printf("%d\n", ret);
    atlogger_log(tag, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to append key to authkeys file s: %s\n", strerror(errno));
    goto cleanup;
  }

  ret = fflush(params->authkeys_file);
  if (ret != 0) {
    atlogger_log(tag, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to flush authkeys file: %s\n", strerror(errno));
    goto cleanup;
  }

  atlogger_log(tag, ATLOGGER_LOGGING_LEVEL_DEBUG, "Successfully authorized the new public key\n");
cleanup: { free(buf); }
exit: {
  funlockfile(params->authkeys_file);

  return ret;
}
}
