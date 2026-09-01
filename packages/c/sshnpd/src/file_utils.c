#include "sshnpd/file_utils.h"
#include <atlogger/atlogger.h>
#include <errno.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int authorize_ssh_public_key(authkeys_params *params) {
  const char *tag = "AUTH SSH KEY";
  int ret = 0;

  // Open a fresh handle per call instead of freopen'ing the shared persistent
  // FILE*. freopen closes the original stream on failure, which left the
  // daemon's global authkeys_file dangling (use-after-free on the next
  // sshpublickey request) and fell through to funlockfile(NULL). This handler
  // only runs on the single monitor thread, so no cross-call file lock is
  // needed. The shared read-only handle stays owned by main's cleanup list.
  FILE *file = fopen(params->authkeys_filename, "a+");
  if (file == NULL) {
    atlogger_log(tag, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to open authkeys file: %s\n", strerror(errno));
    return errno != 0 ? errno : 1;
  }

  ret = fseek(file, 0, SEEK_SET);
  if (ret != 0) {
    atlogger_log(tag, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to seek to the beginning of authkeys file: %s\n",
                 strerror(errno));
    goto exit;
  }

  size_t bufsize = 256;
  char *buf = malloc(bufsize * sizeof(char));
  if (buf == NULL) {
    atlogger_log(tag, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to allocate memory for buf: %s\n", strerror(errno));
    ret = 1;
    goto exit;
  }

  while (getline(&buf, &bufsize, file) >= 0) {
    if (strstr(buf, params->key) != NULL) {
      // already exists in the file, moving on
      atlogger_log(tag, ATLOGGER_LOGGING_LEVEL_DEBUG, "Already found key in the file, did not add a second entry\n");
      ret = 0;
      goto cleanup;
    }
  }

  ret = fseek(file, 0, SEEK_END); // on some platforms a+ opens to the end so seek to beginning first
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
    ret = fprintf(file, "%s %s%s", params->permissions, params->key, postfix);
  } else {
    ret = fprintf(file, "%s%s", params->key, postfix);
  }

  if (ret < 0) {
    atlogger_log(tag, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to append key to authkeys file: %s\n", strerror(errno));
    goto cleanup;
  }

  ret = fflush(file);
  if (ret != 0) {
    atlogger_log(tag, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to flush authkeys file: %s\n", strerror(errno));
    goto cleanup;
  }
  ret = 0;

  atlogger_log(tag, ATLOGGER_LOGGING_LEVEL_DEBUG, "Successfully authorized the new public key\n");
cleanup: { free(buf); }
exit: {
  fclose(file);

  return ret;
}
}
