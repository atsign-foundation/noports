#include "sshnpd/ssh_key_util.h"
#include <atlogger/atlogger.h>
#include <pthread.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/errno.h>
#include <unistd.h>

// authorize and deauthorize could be a single function
// but I've kept them separate for clarity, stability and maintainability

int authorize_ssh_public_key(const char *homedir, const char *permissions, const char *key) {
  int ret = 0;

  char *authkeys_file = malloc(sizeof(char) + (strlen(homedir) + 22));
  sprintf(authkeys_file, "%s/.ssh/authorized_keys", homedir);

  atlogger_log("AUTH SSH KEY", ATLOGGER_LOGGING_LEVEL_DEBUG, "Using authorized_keys file: %s\n", authkeys_file);
  FILE *fptr = fopen(authkeys_file, "a+"); // appending to the end is fine
  if (fptr == NULL) {
    atlogger_log("AUTH SSH KEY", ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to open file %s: %s\n", authkeys_file,
                 strerror(errno));
    if (errno != 0) {
      ret = errno;
    } else {
      ret = 1;
    }
    goto exit;
  }

  ret = fseek(fptr, 0, SEEK_SET);
  if (ret != 0) {
    atlogger_log("AUTH SSH KEY", ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to seek to the beginning of file %s: %s\n",
                 authkeys_file, strerror(errno));
    goto close;
  }

  size_t bufsize = 256;
  char *buf = malloc(bufsize * sizeof(char));
  while (getline(&buf, &bufsize, fptr) >= 0) {
    atlogger_log("AUTH SSH KEY", ATLOGGER_LOGGING_LEVEL_DEBUG, "Comparing line: '%s'\n       To line: '%s'\n", buf,
                 key);
    if (strstr(buf, key) != NULL) {
      // already exists in the file, moving on
      atlogger_log("AUTH SSH KEY", ATLOGGER_LOGGING_LEVEL_DEBUG,
                   "Already found key in the file, did not add a second entry\n");
      ret = 0;
      goto cleanup;
    }
  }

  ret = fseek(fptr, 0, SEEK_END); // on some platforms a+ opens to the end so seek to beginning first
  if (ret != 0) {
    atlogger_log("AUTH SSH KEY", ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to seek to the end of file %s: %s\n",
                 authkeys_file, strerror(errno));
    goto cleanup;
  }

  if (strlen(permissions) > 0) {
    ret = fprintf(fptr, "%s %s\n", permissions, key);
  } else {
    ret = fprintf(fptr, "%s\n", key);
  }
  if (ret < 0) {
    printf("%d\n", ret);
    atlogger_log("AUTH SSH KEY", ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to append key to file %s: %s\n", authkeys_file,
                 strerror(errno));
    goto cleanup;
  }

  ret = fflush(fptr);
  if (ret != 0) {
    atlogger_log("AUTH SSH KEY", ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to flush file %s: %s\n", authkeys_file,
                 strerror(errno));
    goto cleanup;
  }

  atlogger_log("AUTH SSH KEY", ATLOGGER_LOGGING_LEVEL_DEBUG, "Successfully authorized the new public key\n");
cleanup: { free(buf); }
close: { fclose(fptr); }
exit: {
  free(authkeys_file);
  return ret;
}
}

// The more optimal solution is to scan through the whole file, find the line you want to remove
// then shift eveything after forward to overwrite it. But this is faster to implement and easier to understand
// Copy to a temporary file, skipping the line you want to remove, then copy temp file back
int deauthorize_ssh_public_key(const char *homedir, const char *key, const char *temp_file) {
  int ret = 0;

  char *authkeys_file;
  sprintf(authkeys_file, "%s/.ssh/authorized_keys", homedir);

  FILE *fptr = fopen(authkeys_file, "w+"); // need to rewrite the file without the key
  if (fptr == NULL) {
    ret = errno;
    goto exit;
  }

  // FIXME: uptake the correct ret value expectataions for fprintf
  // TODO: handle errors better
  // TODO  use open to create a temp file descriptor (linux only) then access with fdopen
  FILE *temp = fopen(temp_file, "w+");
  if (temp == NULL) {
    fclose(fptr);
    ret = errno;
    goto exit;
  }

  size_t bufsize = 256;
  char *buf = malloc(bufsize * sizeof(char));
  while ((ret = getline(&buf, &bufsize, fptr)) >= 0) {
    if (strstr(buf, key) == NULL) {
      fprintf(temp, "%s", buf);
    }
  }

  // TODO  check if I need to seek back to beginning of either file
  fflush(temp);
  while ((ret = getline(&buf, &bufsize, temp)) >= 0) {
    fprintf(fptr, "%s", buf);
  }

  // TODO  consider deleting temp_file after
cleanup: {
  free(buf);
  fclose(temp);
  fclose(fptr);
}
exit: { return ret; }
}

void deauthorize_ssh_public_key_job(void *job_params) {
  deauthorize_ssh_public_key_params *params = (deauthorize_ssh_public_key_params *)job_params;
  sleep(DEAUTHORIZE_SSH_PUBLIC_KEY_DELAY);

  char *temp_file;
  sprintf(temp_file, "%s/.ssh/authorized_keys.sshnp.bak", params->homedir);

  int ret;
  do {
    ret = deauthorize_ssh_public_key(params->homedir, params->key, temp_file);
    if (ret != 0) {
      atlogger_log("DEAUTH SSH KEY JOB", ATLOGGER_LOGGING_LEVEL_ERROR,
                   "Failed to deauthorize ssh public key, trying again in 1 second...\n");
      sleep(1);
    }
  } while (ret != 0);
  free(job_params);
  pthread_exit(NULL);
}
