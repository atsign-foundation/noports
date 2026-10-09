#include <atlogger/atlogger.h>
#include <errno.h>
#include <signal.h>
#include <sshnpd/client_sessions.h>
#include <sshnpd/public_lookup.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>

#define LOGGER_TAG "CLIENT_SESSIONS"

// A key check running longer than this is killed, which the worker's own
// deadline should make unnecessary
#define KEY_CHECK_OVERRUN_SECS 120

typedef struct {
  char *session_id;
  char *signing_key;
  pid_t srv_pid;
  bool ending;
  bool due;
} client_session;

typedef struct {
  char *signing_key;
  pid_t pid;
  time_t started;
} key_check;

static client_session *sessions;
static size_t session_count;
static size_t session_capacity;
static key_check checks[CLIENT_SESSIONS_MAX_KEY_CHECKS];
static size_t check_count;
static unsigned int interval_secs;
static time_t next_due;
static client_sessions_ops session_ops;

void client_sessions_init(unsigned int check_interval_secs, const client_sessions_ops *ops) {
  interval_secs = check_interval_secs;
  next_due = 0;
  session_ops = *ops;
}

static client_session *find_session(const char *session_id) {
  for (size_t i = 0; i < session_count; i++) {
    if (strcmp(sessions[i].session_id, session_id) == 0) {
      return &sessions[i];
    }
  }
  return NULL;
}

bool client_sessions_is_watched(const char *session_id) { return find_session(session_id) != NULL; }

static void end_session(client_session *session, const char *why) {
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_WARN, "Ending session %s: %s\n", session->session_id, why);
  if (session_ops.signal_process(session->srv_pid, SIGTERM, session_ops.ctx) != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_WARN, "Could not end session %s: %s\n", session->session_id,
                 strerror(errno));
  }
}

int client_sessions_track(const char *session_id, const char *signing_key, pid_t srv_pid) {
  if (find_session(session_id) != NULL) {
    client_session duplicate = {(char *)session_id, (char *)signing_key, srv_pid, true, false};
    end_session(&duplicate, "a session with that id is already being watched");
    return 1;
  }
  if (session_count == session_capacity) {
    size_t capacity = session_capacity == 0 ? 8 : session_capacity * 2;
    client_session *grown = realloc(sessions, capacity * sizeof(client_session));
    if (grown == NULL) {
      return 1;
    }
    sessions = grown;
    session_capacity = capacity;
  }
  client_session *session = &sessions[session_count];
  session->session_id = strdup(session_id);
  session->signing_key = strdup(signing_key);
  if (session->session_id == NULL || session->signing_key == NULL) {
    free(session->session_id);
    free(session->signing_key);
    return 1;
  }
  session->srv_pid = srv_pid;
  session->ending = false;
  session->due = false;
  session_count++;
  return 0;
}

static bool is_being_checked(const char *signing_key) {
  for (size_t i = 0; i < check_count; i++) {
    if (strcmp(checks[i].signing_key, signing_key) == 0) {
      return true;
    }
  }
  return false;
}

static size_t checks_of_atsign(const char *signing_key) {
  const char *atsign = strrchr(signing_key, '@');
  size_t n = 0;
  for (size_t i = 0; i < check_count; i++) {
    if (strcmp(strrchr(checks[i].signing_key, '@'), atsign) == 0) {
      n++;
    }
  }
  return n;
}

static void clear_due(const char *signing_key) {
  for (size_t i = 0; i < session_count; i++) {
    if (strcmp(sessions[i].signing_key, signing_key) == 0) {
      sessions[i].due = false;
    }
  }
}

void client_sessions_tick(time_t now) {
  if (interval_secs == 0) {
    return;
  }
  for (size_t i = 0; i < check_count; i++) {
    if (now - checks[i].started > KEY_CHECK_OVERRUN_SECS) {
      session_ops.signal_process(checks[i].pid, SIGKILL, session_ops.ctx);
    }
  }
  if (next_due == 0) {
    next_due = now + interval_secs;
  }
  if (now >= next_due) {
    next_due = now + interval_secs;
    for (size_t i = 0; i < session_count; i++) {
      sessions[i].due = true;
    }
  }
  for (size_t i = 0; i < session_count && check_count < CLIENT_SESSIONS_MAX_KEY_CHECKS; i++) {
    client_session *session = &sessions[i];
    if (!session->due || session->ending) {
      continue;
    }
    // A key whose last check hasn't finished sits this one out, so a slow
    // atServer delays only the checks of its own keys
    if (is_being_checked(session->signing_key)) {
      clear_due(session->signing_key);
      continue;
    }
    if (checks_of_atsign(session->signing_key) >= CLIENT_SESSIONS_MAX_KEY_CHECKS_PER_ATSIGN) {
      continue;
    }
    char *key = strdup(session->signing_key);
    if (key == NULL) {
      return;
    }
    clear_due(key);
    pid_t pid = session_ops.start_key_check(key, session_ops.ctx);
    if (pid <= 0) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_WARN,
                   "Could not re-check client signing key %s, so the sessions it signed carry on\n", key);
      free(key);
      continue;
    }
    checks[check_count++] = (key_check){key, pid, now};
  }
}

static void remove_session(size_t i) {
  free(sessions[i].session_id);
  free(sessions[i].signing_key);
  sessions[i] = sessions[--session_count];
}

static void key_check_finished(const char *signing_key, int status) {
  int outcome = WIFEXITED(status) ? WEXITSTATUS(status) : PUBLIC_LOOKUP_KEY_CHECK_UNKNOWN;
  if (outcome == PUBLIC_LOOKUP_KEY_CHECK_PUBLISHED) {
    return;
  }
  if (outcome == PUBLIC_LOOKUP_KEY_CHECK_MISSING) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_WARN,
                 "Client signing key %s is missing but has not been withdrawn, so the sessions it signed carry on\n",
                 signing_key);
    return;
  }
  if (outcome != PUBLIC_LOOKUP_KEY_CHECK_REVOKED && outcome != PUBLIC_LOOKUP_KEY_CHECK_DELETED) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_WARN,
                 "Could not re-check client signing key %s, so the sessions it signed carry on\n", signing_key);
    return;
  }
  char why[512];
  snprintf(why, sizeof(why), "its client's signing key %s has been withdrawn to %s", signing_key,
           outcome == PUBLIC_LOOKUP_KEY_CHECK_REVOKED ? "r.__e" : "d.__e");
  for (size_t i = 0; i < session_count; i++) {
    if (!sessions[i].ending && strcmp(sessions[i].signing_key, signing_key) == 0) {
      sessions[i].ending = true;
      end_session(&sessions[i], why);
    }
  }
}

bool client_sessions_reaped(pid_t pid, int status) {
  for (size_t i = 0; i < session_count; i++) {
    if (sessions[i].srv_pid == pid) {
      remove_session(i);
      return true;
    }
  }
  for (size_t i = 0; i < check_count; i++) {
    if (checks[i].pid == pid) {
      char *key = checks[i].signing_key;
      checks[i] = checks[--check_count];
      key_check_finished(key, status);
      free(key);
      return true;
    }
  }
  return false;
}

size_t client_sessions_count(void) { return session_count; }

void client_sessions_free(void) {
  while (session_count > 0) {
    remove_session(session_count - 1);
  }
  free(sessions);
  sessions = NULL;
  session_capacity = 0;
  for (size_t i = 0; i < check_count; i++) {
    free(checks[i].signing_key);
  }
  check_count = 0;
  next_due = 0;
}
