#include "sshnpd/run_srv_process.h"
#include <signal.h>
#include <srv/srv.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

// Starts a child that, after delay_ms, writes report (when not NULL) to a
// pipe, then waits a second before exiting, returning the pipe's read end
static int child_reporting(const char *report, int delay_ms, bool exit_at_once, pid_t *pid) {
  int fds[2];
  if (pipe(fds) != 0) {
    return -1;
  }
  *pid = fork();
  if (*pid == 0) {
    close(fds[0]);
    usleep((useconds_t)delay_ms * 1000);
    if (report != NULL) {
      ssize_t ignored = write(fds[1], report, strlen(report));
      (void)ignored;
    }
    if (!exit_at_once) {
      sleep(1);
    }
    _exit(0);
  }
  close(fds[1]);
  return fds[0];
}

static int failures = 0;

static void check(const char *name, const char *report, int delay_ms, bool exit_at_once, int timeout_ms,
                  int expected, const char *why_part) {
  pid_t pid;
  int fd = child_reporting(report, delay_ms, exit_at_once, &pid);
  char why[160] = "";
  int result = wait_for_srv_start(fd, timeout_ms, why, sizeof(why));
  close(fd);
  kill(pid, SIGKILL);
  waitpid(pid, NULL, 0);
  if (result != expected || (why_part != NULL && strstr(why, why_part) == NULL)) {
    printf("FAILED %s: result %d, why \"%s\"\n", name, result, why);
    failures++;
  }
}

int main() {
  check("srv that reports starting", SRV_COMPLETION_STRING "\n", 50, false, 1000, 0, NULL);
  check("srv that reports in pieces", SRV_COMPLETION_STRING, 0, false, 1000, 0, NULL);
  check("srv that exits first", NULL, 0, true, 1000, 1, "exited before reporting");
  check("srv that stays silent", NULL, 0, false, 200, 1, "did not report starting");
  check("srv that reports something else", "rv failed\n", 0, true, 1000, 1, "exited before reporting");
  printf("Tests failed: %d\n", failures);
  return failures;
}
