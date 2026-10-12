#include "sshnpd/run_srv_process.h"
#include <signal.h>
#include <srv/srv.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

// Starts a stand-in srv that writes report (when not NULL) to a pipe, then
// closes the pipe when close_pipe is set, and stays up until killed
static pid_t stand_in(const char *report, bool close_pipe, int *ready_fd) {
  int fds[2];
  if (pipe(fds) != 0) {
    return -1;
  }
  pid_t pid = fork();
  if (pid == 0) {
    close(fds[0]);
    if (report != NULL) {
      ssize_t ignored = write(fds[1], report, strlen(report));
      (void)ignored;
    }
    if (close_pipe) {
      close(fds[1]);
    }
    sleep(10);
    _exit(0);
  }
  close(fds[1]);
  *ready_fd = fds[0];
  usleep(100 * 1000);
  return pid;
}

// Ends pid, returning the signal that ended it, or 0 when it was still up
// and had to be stopped here
static int end(pid_t pid) {
  int status = 0;
  if (waitpid(pid, &status, WNOHANG) == 0) {
    kill(pid, SIGKILL);
    waitpid(pid, &status, 0);
    return 0;
  }
  return WIFSIGNALED(status) ? WTERMSIG(status) : -1;
}

static int failures = 0;

static void expect(bool ok, const char *what) {
  if (!ok) {
    printf("FAILED: %s\n", what);
    failures++;
  }
}

int main() {
  int fd;
  pid_t silent = stand_in(NULL, false, &fd);
  srv_starts_watch(silent, fd, 1000);
  srv_starts_poll(1000 + SRV_START_TIMEOUT_MS - 1);
  expect(srv_starts_count() == 1, "keeps watching an srv until its time is up");
  srv_starts_poll(1000 + SRV_START_TIMEOUT_MS);
  usleep(100 * 1000);
  expect(srv_starts_count() == 0 && end(silent) == SIGTERM,
         "stops an srv that hasn't reached the relay within SRV_START_TIMEOUT_MS");

  pid_t reported = stand_in(SRV_COMPLETION_STRING "\n", false, &fd);
  srv_starts_watch(reported, fd, 2000);
  srv_starts_poll(2001);
  srv_starts_poll(2000 + SRV_START_TIMEOUT_MS);
  usleep(100 * 1000);
  expect(srv_starts_count() == 0 && end(reported) == 0, "leaves an srv that reported starting running");

  pid_t closed = stand_in(NULL, true, &fd);
  srv_starts_watch(closed, fd, 3000);
  srv_starts_poll(3001);
  srv_starts_poll(3000 + SRV_START_TIMEOUT_MS);
  usleep(100 * 1000);
  expect(srv_starts_count() == 0 && end(closed) == 0, "forgets an srv whose pipe has closed");

  pid_t reaped = stand_in(NULL, false, &fd);
  srv_starts_watch(reaped, fd, 4000);
  kill(reaped, SIGKILL);
  waitpid(reaped, NULL, 0);
  srv_starts_reaped(reaped);
  expect(srv_starts_count() == 0, "forgets an srv once it has been reaped, so its pid is never signalled");

  printf("Tests failed: %d\n", failures);
  return failures;
}
