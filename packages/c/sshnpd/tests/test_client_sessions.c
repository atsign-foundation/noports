#include "sshnpd/client_sessions.h"
#include "sshnpd/public_lookup.h"
#include <signal.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

typedef struct {
  char started[64][128];
  pid_t started_pids[64];
  size_t starts;
  pid_t next_pid;
  pid_t signalled[64];
  int signals_sent[64];
  size_t signals;
} fake_ops;

static pid_t start(const char *signing_key, void *ctx) {
  fake_ops *f = ctx;
  snprintf(f->started[f->starts], sizeof(f->started[0]), "%s", signing_key);
  f->started_pids[f->starts] = f->next_pid;
  f->starts++;
  return f->next_pid++;
}

static int send_signal(pid_t pid, int sig, void *ctx) {
  fake_ops *f = ctx;
  f->signalled[f->signals] = pid;
  f->signals_sent[f->signals] = sig;
  f->signals++;
  return 0;
}

// The status waitpid reports for a child that exits with code, or, when
// code is negative, that is killed
static int child_status(int code) {
  pid_t pid = fork();
  if (pid == 0) {
    if (code < 0) {
      kill(getpid(), SIGKILL);
    }
    _exit(code);
  }
  int status = 0;
  waitpid(pid, &status, 0);
  return status;
}

static fake_ops *fresh(unsigned int interval) {
  static fake_ops f;
  client_sessions_free();
  memset(&f, 0, sizeof(f));
  f.next_pid = 5000;
  client_sessions_ops ops = {start, send_signal, &f};
  client_sessions_init(interval, &ops);
  return &f;
}

static pid_t pid_started_for(fake_ops *f, const char *key) {
  for (size_t i = f->starts; i > 0; i--) {
    if (strcmp(f->started[i - 1], key) == 0) {
      return f->started_pids[i - 1];
    }
  }
  return -1;
}

static bool was_signalled(fake_ops *f, pid_t pid, int sig) {
  for (size_t i = 0; i < f->signals; i++) {
    if (f->signalled[i] == pid && f->signals_sent[i] == sig) {
      return true;
    }
  }
  return false;
}

static int failures = 0;

static void expect(bool ok, const char *what) {
  if (!ok) {
    printf("FAILED: %s\n", what);
    failures++;
  }
}

static const char *A = "public:_apsk.a.a.__e@alice";
static const char *B = "public:_apsk.b.a.__e@bob";

int main() {
  fake_ops *f = fresh(10);
  client_sessions_track("s1", A, 100);
  client_sessions_track("s2", A, 101);
  client_sessions_track("s3", B, 102);
  expect(client_sessions_is_watched("s1") && !client_sessions_is_watched("s9"), "watches the sessions it tracks");

  client_sessions_tick(1000);
  client_sessions_tick(1009);
  expect(f->starts == 0, "checks no key before an interval has passed");
  client_sessions_tick(1010);
  expect(f->starts == 2 && pid_started_for(f, A) > 0 && pid_started_for(f, B) > 0,
         "checks each distinct key once an interval has passed");
  client_sessions_tick(1020);
  expect(f->starts == 2, "skips a key whose last check hasn't finished");

  expect(client_sessions_reaped(pid_started_for(f, A), child_status(PUBLIC_LOOKUP_KEY_CHECK_REVOKED)),
         "takes a finished key check as its own");
  expect(was_signalled(f, 100, SIGTERM) && was_signalled(f, 101, SIGTERM) && !was_signalled(f, 102, SIGTERM),
         "ends every session whose key was withdrawn, and no other");

  size_t signals_before = f->signals;
  client_sessions_reaped(pid_started_for(f, B), child_status(PUBLIC_LOOKUP_KEY_CHECK_MISSING));
  expect(f->signals == signals_before, "keeps the sessions of a key that is missing but not withdrawn");

  client_sessions_tick(1030);
  expect(f->starts == 3 && strcmp(f->started[2], B) == 0, "doesn't check the key of sessions being ended");
  client_sessions_reaped(pid_started_for(f, B), child_status(-1));
  expect(f->signals == signals_before, "keeps the sessions of a key whose check was killed");

  expect(client_sessions_reaped(102, child_status(0)) && !client_sessions_is_watched("s3") &&
             client_sessions_count() == 2,
         "forgets a session once its srv has exited");
  expect(!client_sessions_reaped(4242, child_status(0)), "takes no other child as its own");

  expect(client_sessions_track("s1", B, 200) != 0 && was_signalled(f, 200, SIGTERM),
         "ends a session started under an id already being watched");

  f = fresh(10);
  const char *carol[] = {"public:_apsk.c1.a.__e@carol", "public:_apsk.c2.a.__e@carol",
                         "public:_apsk.c3.a.__e@carol"};
  for (int i = 0; i < 3; i++) {
    char id[8];
    snprintf(id, sizeof(id), "c%d", i);
    client_sessions_track(id, carol[i], 300 + i);
  }
  client_sessions_tick(2000);
  client_sessions_tick(2010);
  expect(f->starts == 2, "checks at most two keys of one atSign at once");
  client_sessions_reaped(f->started_pids[0], child_status(PUBLIC_LOOKUP_KEY_CHECK_PUBLISHED));
  client_sessions_tick(2011);
  expect(f->starts == 3, "checks a waiting key of that atSign once one finishes");
  client_sessions_tick(2010 + 121);
  expect(was_signalled(f, f->started_pids[1], SIGKILL), "kills a key check that has run for over two minutes");

  f = fresh(10);
  for (int i = 0; i < CLIENT_SESSIONS_MAX_KEY_CHECKS + 1; i++) {
    char id[8], key[64];
    snprintf(id, sizeof(id), "d%d", i);
    snprintf(key, sizeof(key), "public:_apsk.d.a.__e@d%d", i);
    client_sessions_track(id, key, 400 + i);
  }
  client_sessions_tick(3000);
  client_sessions_tick(3010);
  expect(f->starts == CLIENT_SESSIONS_MAX_KEY_CHECKS, "runs at most CLIENT_SESSIONS_MAX_KEY_CHECKS key checks at once");

  f = fresh(0);
  client_sessions_track("e1", A, 500);
  client_sessions_tick(4000);
  client_sessions_tick(9999);
  expect(f->starts == 0 && client_sessions_is_watched("e1"), "with an interval of 0, watches but never checks");

  client_sessions_free();
  printf("Tests failed: %d\n", failures);
  return failures;
}
