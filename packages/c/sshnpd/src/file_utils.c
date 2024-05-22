#include "sshnpd/file_utils.h"
#include <atlogger/atlogger.h>
#include <pthread.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/errno.h>
#include <unistd.h>

char *read_file_contents(char *filename) {
  const char *tag = "READ FILE CONTENTS";
  int ret = 0;
  FILE *file = fopen(filename, "r");
  if (file == NULL) {
    atlogger_log(tag, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to fopen the file: %s\n", strerror(errno));
    if (errno != 0) {
      ret = errno;
    } else {
      ret = 1;
    }
    goto exit;
  }

  // Go to end and get position to allocate correct buffer size
  ret = fseek(file, 0, SEEK_END);
  if (ret != 0) {
    atlogger_log(tag, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to seek to the end of the file: %s\n", strerror(errno));
    goto exit;
  }
  long fsize = ftell(file);
  if (fsize < 0) {
    atlogger_log(tag, ATLOGGER_LOGGING_LEVEL_ERROR,
                 "Failed to get the current position of the cursor in the file: %s\n", strerror(errno));
    goto exit;
  }

  // Go back to beginning, allocate buffer, and read
  ret = fseek(file, 0, SEEK_SET);
  if (ret != 0) {
    atlogger_log(tag, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to seek to the beginning of the file: %s\n",
                 strerror(errno));
    goto exit;
  }

  char *buffer = malloc(sizeof(char) * (fsize + 10));
  if (buffer == NULL) {
    atlogger_log(tag, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to allocate a buffer to read file into: %s\n",
                 strerror(errno));
    goto exit;
  }

  char ch;
  int i = 0;
  do {
    ch = fgetc(file);
    if (ch > 0) {
      buffer[i++] = ch;
    }
  } while (ch != EOF);
  buffer[i] = '\0';

  if (ferror(file)) {
    atlogger_log(tag, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to read the entire file: %s\n", strerror(errno));
    free(buffer);
    buffer = NULL;
    goto exit;
  }

  ret = fclose(file);
  if (ret != 0) {
    atlogger_log(tag, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to close the file: %s\n", strerror(errno));
    free(buffer);
    buffer = NULL;
    goto exit;
  }

exit: { return buffer; }
}

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

  if (strlen(params->permissions) > 0) {
    ret = fprintf(params->authkeys_file, "%s %s\n", params->permissions, params->key);
  } else {
    ret = fprintf(params->authkeys_file, "%s\n", params->key);
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

int deauthorize_ssh_public_key(authkeys_params *params) {
  const char *tag = "DEAUTH SSH KEY";
  int ret = 0;

  params->authkeys_file = freopen(NULL, "a+", params->authkeys_file); // need to rewrite the file without the key
  if (params->authkeys_file == NULL) {
    ret = errno;
    goto exit;
  }

  // FIXME: uptake the correct ret value expectataions for fprintf
  // TODO: handle errors better
  FILE *temp = tmpfile();
  if (temp == NULL) {
    fclose(params->authkeys_file);
    ret = errno;
    goto exit;
  }

  size_t bufsize = 256;
  char *buf = malloc(bufsize * sizeof(char));
  if (buf == NULL) {
    atlogger_log(tag, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to allocate memory for buf\n");
    ret = 1;
    goto exit;
  }
  while ((ret = getline(&buf, &bufsize, params->authkeys_file)) >= 0) {
    if (strstr(buf, params->key) == NULL) {
      fprintf(temp, "%s", buf);
    }
  }

  // TODO  check if I need to seek back to beginning of either file
  fflush(temp);
  while ((ret = getline(&buf, &bufsize, temp)) >= 0) {
    fprintf(params->authkeys_file, "%s", buf);
  }

  // TODO  consider deleting temp_file after
cleanup: {
  free(buf);
  fclose(temp);
}
exit: { return ret; }
}

void deauthorize_ssh_public_key_job(void *params) {
  const char *tag = "DEAUTH SSH KEY JOB";
  sleep(DEAUTHORIZE_SSH_PUBLIC_KEY_DELAY);
  int ret;
  do {
    ret = deauthorize_ssh_public_key((authkeys_params *)params);
    if (ret != 0) {
      atlogger_log(tag, ATLOGGER_LOGGING_LEVEL_ERROR,
                   "Failed to deauthorize ssh public key, trying again in 1 second...\n");
      sleep(1);
    }
  } while (ret != 0);
  free(params);
  pthread_exit(NULL);
}
