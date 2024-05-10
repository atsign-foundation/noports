#include "sshnpd/ssh_key_util.h"
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

  pthread_mutex_lock(&authkeys_mutex);
  char *authkeys_file;
  sprintf(authkeys_file, "%s/.ssh/authorized_keys", homedir);

  FILE *fptr = fopen(authkeys_file, "a+"); // appending to the end is fine
  if (fptr) {
    // TODO  print error from errno
    ret = errno;
    goto exit;
  }

  size_t bufsize = 256;
  char *buf = malloc(bufsize * sizeof(char));
  while ((ret = getline(&buf, &bufsize, fptr)) >= 0) {
    if (strstr(buf, key) != NULL) {
      // already exists in the file, moving on
      ret = 0;
      goto cleanup;
    }
  }

  fprintf(fptr, "%s %s\n", permissions, key);
  fflush(fptr);
cleanup: {
  free(buf);
  fclose(fptr);
}
exit: {
  pthread_mutex_unlock(&authkeys_mutex);
  return ret;
}
}

// The more optimal solution is to scan through the whole file, find the line you want to remove
// then shift eveything after forward to overwrite it. But this is faster to implement and easier to understand
// Copy to a temporary file, skipping the line you want to remove, then copy temp file back
int deauthorize_ssh_public_key(const char *homedir, const char *key, const char *temp_file) {
  int ret = 0;

  pthread_mutex_lock(&authkeys_mutex);
  char *authkeys_file;
  sprintf(authkeys_file, "%s/.ssh/authorized_keys", homedir);

  FILE *fptr = fopen(authkeys_file, "w+"); // need to rewrite the file without the key
  if (fptr == NULL) {
    // TODO  print error from errno
    ret = errno;
    goto exit;
  }

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
exit: {
  pthread_mutex_unlock(&authkeys_mutex);
  return ret;
}
}
