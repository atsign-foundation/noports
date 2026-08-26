#include "sshnpd/ephemeral_key.h"
#include "sshnpd/file_utils.h"
#include <atlogger/atlogger.h>
#include <errno.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#define LOGGER_TAG "EPHEMERAL KEY"

// How long after the session response the ephemeral key stays authorized -
// long enough for the client to bring up the tunnel ssh session (the Dart
// daemon uses the same 15 second window)
#define EPHEMERAL_DEAUTH_DELAY_SECONDS 15

#define EPHEMERAL_DEAUTH_SLOTS 16

#define EPHEMERAL_MARKER_PREFIX "sshnp_ephemeral_"

// The session id ends up in a file name, in ssh-keygen argv and in an
// authorized_keys line, so restrict it to the characters a uuid can contain
static bool session_id_is_safe(const char *session_id) {
  size_t len = strlen(session_id);
  if (len == 0 || len > 40) {
    return false;
  }
  for (size_t i = 0; i < len; i++) {
    char c = session_id[i];
    if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '-')) {
      return false;
    }
  }
  return true;
}

static char *read_file_alloc(const char *path) {
  FILE *f = fopen(path, "r");
  if (f == NULL) {
    return NULL;
  }
  if (fseek(f, 0, SEEK_END) != 0) {
    fclose(f);
    return NULL;
  }
  long size = ftell(f);
  if (size < 0 || fseek(f, 0, SEEK_SET) != 0) {
    fclose(f);
    return NULL;
  }
  char *buf = malloc(size + 1);
  if (buf == NULL) {
    fclose(f);
    return NULL;
  }
  size_t nread = fread(buf, 1, size, f);
  fclose(f);
  buf[nread] = '\0';
  return buf;
}

int generate_ephemeral_ssh_keypair(const char *directory, bool use_rsa, const char *session_id,
                                   char **private_key_pem, char **public_key) {
  *private_key_pem = NULL;
  *public_key = NULL;

  if (!session_id_is_safe(session_id)) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Refusing to generate a key for an unsafe session id\n");
    return 1;
  }

  if (mkdir(directory, 0700) != 0 && errno != EEXIST) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to create %s: %s\n", directory, strerror(errno));
    return 1;
  }

  char key_path[512];
  int written = snprintf(key_path, sizeof(key_path), "%s/ephemeral_%s", directory, session_id);
  if (written < 0 || (size_t)written >= sizeof(key_path)) {
    return 1;
  }
  char pub_path[520];
  snprintf(pub_path, sizeof(pub_path), "%s.pub", key_path);

  // Make sure a stale file from a crashed run can't make ssh-keygen prompt
  unlink(key_path);
  unlink(pub_path);

  // Same ssh-keygen invocations as the Dart daemon's LocalSshKeyUtil
  char *const argv_ed25519[] = {"ssh-keygen", "-t", "ed25519", "-a", "100", "-f", key_path, "-q", "-N", "", NULL};
  char *const argv_rsa[] = {"ssh-keygen", "-t", "rsa", "-b", "4096", "-f", key_path, "-q", "-N", "", NULL};
  char *const *keygen_argv = use_rsa ? argv_rsa : argv_ed25519;

  pid_t pid = fork();
  if (pid < 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to fork for ssh-keygen: %s\n", strerror(errno));
    return 1;
  }
  if (pid == 0) {
    execvp("ssh-keygen", keygen_argv);
    _exit(127); // exec failed (e.g. ssh-keygen not installed)
  }

  int status = 0;
  if (waitpid(pid, &status, 0) < 0 || !WIFEXITED(status) || WEXITSTATUS(status) != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "ssh-keygen failed (status %d)\n",
                 WIFEXITED(status) ? WEXITSTATUS(status) : -1);
    unlink(key_path);
    unlink(pub_path);
    return 1;
  }

  *private_key_pem = read_file_alloc(key_path);
  *public_key = read_file_alloc(pub_path);

  // The transient files are removed regardless; the private key only ever
  // leaves this process inside the encrypted session response
  unlink(key_path);
  unlink(pub_path);

  if (*private_key_pem == NULL || *public_key == NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to read the generated key files\n");
    free(*private_key_pem);
    free(*public_key);
    *private_key_pem = NULL;
    *public_key = NULL;
    return 1;
  }
  return 0;
}

int authorize_ephemeral_public_key(FILE *authkeys_file, char *authkeys_filename, const char *public_key,
                                   uint16_t local_sshd_port, const char *session_id, const char *extra_permissions) {
  if (!session_id_is_safe(session_id)) {
    return 1;
  }

  if (extra_permissions == NULL) {
    extra_permissions = "";
  }
  // Extra options join the comma separated option list (mirrors the Dart
  // daemon's handling of --ephemeral-permissions)
  const char *extra_sep = "";
  if (extra_permissions[0] != '\0' && extra_permissions[0] != ',') {
    extra_sep = ",";
  }

  char permissions[512];
  int written = snprintf(permissions, sizeof(permissions),
                         "command=\"echo \\\"ssh session complete\\\";sleep 20\",PermitOpen=\"localhost:%d\"%s%s",
                         local_sshd_port, extra_sep, extra_permissions);
  if (written < 0 || (size_t)written >= sizeof(permissions)) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "authorized_keys options line too long\n");
    return 1;
  }

  // '<public key> sshnp_ephemeral_<session id>' - the marker makes the entry
  // findable for removal
  size_t key_size = strlen(public_key) + strlen(EPHEMERAL_MARKER_PREFIX) + strlen(session_id) + 3;
  char *key = malloc(key_size);
  if (key == NULL) {
    return 1;
  }
  size_t pub_len = strlen(public_key);
  while (pub_len > 0 && (public_key[pub_len - 1] == '\n' || public_key[pub_len - 1] == '\r' ||
                         public_key[pub_len - 1] == ' ')) {
    pub_len--;
  }
  snprintf(key, key_size, "%.*s %s%s\n", (int)pub_len, public_key, EPHEMERAL_MARKER_PREFIX, session_id);

  authkeys_params akp;
  akp.authkeys_file = authkeys_file;
  akp.authkeys_filename = authkeys_filename;
  akp.permissions = permissions;
  akp.key = key;

  int ret = authorize_ssh_public_key(&akp);
  free(key);
  return ret;
}

int deauthorize_ephemeral_public_key(FILE *authkeys_file, const char *authkeys_filename, const char *session_id) {
  if (!session_id_is_safe(session_id)) {
    return 1;
  }

  char marker[64];
  int written = snprintf(marker, sizeof(marker), "%s%s", EPHEMERAL_MARKER_PREFIX, session_id);
  if (written < 0 || (size_t)written >= sizeof(marker)) {
    return 1;
  }

  int ret = 0;
  flockfile(authkeys_file);

  // Read the whole file, then rewrite it without this session's entry. The
  // freopen pattern (also used by authorize_ssh_public_key) keeps the
  // daemon's long lived FILE stream valid.
  FILE *reopened = freopen(authkeys_filename, "r", authkeys_file);
  if (reopened == NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to reopen %s: %s\n", authkeys_filename,
                 strerror(errno));
    funlockfile(authkeys_file);
    return 1;
  }

  char **lines = NULL;
  size_t num_lines = 0;
  bool found = false;

  char *buf = NULL;
  size_t bufsize = 0;
  while (getline(&buf, &bufsize, authkeys_file) >= 0) {
    if (strstr(buf, marker) != NULL) {
      found = true;
      continue; // drop this line
    }
    char **grown = realloc(lines, (num_lines + 1) * sizeof(char *));
    if (grown == NULL) {
      ret = 1;
      goto exit;
    }
    lines = grown;
    lines[num_lines] = strdup(buf);
    if (lines[num_lines] == NULL) {
      ret = 1;
      goto exit;
    }
    num_lines++;
  }

  if (!found) {
    // Nothing to remove; leave the file untouched
    goto exit;
  }

  reopened = freopen(authkeys_filename, "w", authkeys_file);
  if (reopened == NULL) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to rewrite %s: %s\n", authkeys_filename,
                 strerror(errno));
    ret = 1;
    goto exit;
  }
  for (size_t i = 0; i < num_lines; i++) {
    if (fputs(lines[i], authkeys_file) < 0) {
      ret = 1;
      break;
    }
  }
  fflush(authkeys_file);
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Removed ephemeral key for session %s\n", session_id);

exit:
  free(buf);
  for (size_t i = 0; i < num_lines; i++) {
    free(lines[i]);
  }
  free(lines);
  funlockfile(authkeys_file);
  return ret;
}

// Queue of sessions whose ephemeral keys are due for removal. The daemon
// main loop is single threaded, so no locking is needed.
static struct {
  bool used;
  time_t due;
  char session_id[48];
} deauth_queue[EPHEMERAL_DEAUTH_SLOTS];

void ephemeral_key_schedule_deauthorize(FILE *authkeys_file, const char *authkeys_filename, const char *session_id) {
  if (!session_id_is_safe(session_id)) {
    return;
  }
  int slot = -1;
  int oldest = 0;
  for (int i = 0; i < EPHEMERAL_DEAUTH_SLOTS; i++) {
    if (!deauth_queue[i].used) {
      slot = i;
      break;
    }
    if (deauth_queue[i].due < deauth_queue[oldest].due) {
      oldest = i;
    }
  }
  if (slot < 0) {
    // Queue full (16 sessions inside one grace window) - revoke the oldest
    // key now, most of its grace period has already passed
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_WARN,
                 "Deauthorize queue is full - removing the ephemeral key for session %s early\n",
                 deauth_queue[oldest].session_id);
    deauthorize_ephemeral_public_key(authkeys_file, authkeys_filename, deauth_queue[oldest].session_id);
    slot = oldest;
  }
  deauth_queue[slot].used = true;
  deauth_queue[slot].due = time(NULL) + EPHEMERAL_DEAUTH_DELAY_SECONDS;
  snprintf(deauth_queue[slot].session_id, sizeof(deauth_queue[slot].session_id), "%s", session_id);
}

void ephemeral_key_sweep_deauthorizations(FILE *authkeys_file, const char *authkeys_filename) {
  time_t now = time(NULL);
  for (int i = 0; i < EPHEMERAL_DEAUTH_SLOTS; i++) {
    if (deauth_queue[i].used && now >= deauth_queue[i].due) {
      if (deauthorize_ephemeral_public_key(authkeys_file, authkeys_filename, deauth_queue[i].session_id) != 0) {
        atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_WARN, "Failed to remove ephemeral key for session %s\n",
                     deauth_queue[i].session_id);
      }
      deauth_queue[i].used = false;
    }
  }
}
