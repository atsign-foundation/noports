#ifndef SSHNPD_CLIENT_SESSIONS_H
#define SSHNPD_CLIENT_SESSIONS_H

#include <stdbool.h>
#include <stddef.h>
#include <sys/types.h>
#include <time.h>

// At most this many key checks run at once, and at most
// CLIENT_SESSIONS_MAX_KEY_CHECKS_PER_ATSIGN of them for any one atSign. Fewer
// at once than the Dart daemon's 16 lookups, since each is a process (about
// 1.7 MB resident) and clients choose how many keys there are to check.
#define CLIENT_SESSIONS_MAX_KEY_CHECKS 4
#define CLIENT_SESSIONS_MAX_KEY_CHECKS_PER_ATSIGN 2

// How a key check is started and a process ended, so tests can stand in
typedef struct {
  // Starts a check of the `_apsk` record signing_key, returning the pid
  // of the process doing it, or -1
  pid_t (*start_key_check)(const char *signing_key, void *ctx);
  // Sends sig to pid, returning non-zero on failure
  int (*signal_process)(pid_t pid, int sig, void *ctx);
  void *ctx;
} client_sessions_ops;

// Sets how often (seconds; 0 turns the checks off) the signing key of each
// tracked session is checked, and the ops to do it with
void client_sessions_init(unsigned int check_interval_secs, const client_sessions_ops *ops);

// Whether a session with session_id is being watched
bool client_sessions_is_watched(const char *session_id);

// Watches session_id, whose srv process is srv_pid, ending it once
// signing_key, the `_apsk` record its client signed the request with, is
// withdrawn. A session whose id is already watched is ended at once. Returns
// non-zero when it isn't tracked.
int client_sessions_track(const char *session_id, const char *signing_key, pid_t srv_pid);

// Starts the key checks due at now, within the limits, and kills any that
// have overrun
void client_sessions_tick(time_t now);

// Handles the exit of child pid with status, as waitpid reports it: a
// tracked session's srv ending, or a key check finishing, which ends every
// session whose key it found withdrawn. Returns whether pid was either.
bool client_sessions_reaped(pid_t pid, int status);

// How many sessions are being watched
size_t client_sessions_count(void);

// Forgets every session and key check
void client_sessions_free(void);

#endif
