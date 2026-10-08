#include "srv/params.h"
#include "srv/srv.h"
#include <atclient/json.h>
#include <atclient/string_utils.h>
#include <atlogger/atlogger.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <sshnpd/run_srv_process.h>
#include <signal.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <poll.h>
#include <time.h>
#include <unistd.h>
#ifdef __APPLE__
#include <mach-o/dyld.h>
#endif

#define LOGGER_TAG "RUN SRV"

// The relay is run by self-exec'ing this daemon in a hidden worker mode (see
// SRV_WORKER_FLAG handling in main.c) rather than in-process, so it starts with
// a fresh address space that holds none of the daemon's atSign private keys or
// its authenticated atServer connections. We deliberately re-exec our own
// already-trusted binary (which links srv-lib) instead of launching a separate
// srv executable, so there is no external file to plant or replace. Secrets
// travel via the environment and non-secrets via argv - the same contract the
// standalone srv binary and the Dart daemon use.
#define SRV_WORKER_FLAG "--__srv-worker"

// Resolve the absolute path of the currently running executable into buf.
int sshnpd_own_exe_path(char *buf, size_t bufsize) {
#ifdef __APPLE__
  uint32_t size = (uint32_t)bufsize;
  if (_NSGetExecutablePath(buf, &size) != 0) {
    return -1;
  }
  return 0;
#else
  ssize_t n = readlink("/proc/self/exe", buf, bufsize - 1);
  if (n < 0) {
    return -1;
  }
  buf[n] = '\0';
  return 0;
#endif
}

// Close every descriptor above stderr so the exec'd srv cannot inherit the
// daemon's open atServer TLS sockets (or any other fd). srv opens its own
// sockets and only needs stdin/stdout/stderr.
void sshnpd_close_inherited_fds(int from_fd) {
  long max_fd = sysconf(_SC_OPEN_MAX);
  if (max_fd < 0 || max_fd > 65536) {
    max_fd = 65536;
  }
  for (int fd = from_fd; fd < (int)max_fd; fd++) {
    close(fd);
  }
}

int run_srv_process(const char *srvd_host, uint16_t srvd_port, const char *requested_host, uint16_t requested_port,
                    bool authenticate_to_rvd, char *rvd_auth_string, const sshnpd_escr_context *escr,
                    bool encrypt_rvd_traffic, bool multi, int timeout_seconds, unsigned char *session_aes_key_c2d,
                    unsigned char *session_iv_c2d, unsigned char *session_aes_key_d2c, unsigned char *session_iv_d2c,
                    int ready_fd) {

  const char *local_host = requested_host != NULL ? requested_host : "localhost";
  uint16_t local_port = requested_port != 0 ? requested_port : 22;
  int timeout = timeout_seconds > 0 ? timeout_seconds : SRV_DEFAULT_TIMEOUT_SECONDS;

  char srvd_port_str[6], local_port_str[6], timeout_str[16];
  snprintf(srvd_port_str, sizeof(srvd_port_str), "%u", srvd_port);
  snprintf(local_port_str, sizeof(local_port_str), "%u", local_port);
  snprintf(timeout_str, sizeof(timeout_str), "%d", timeout);

  // Secrets go through the environment, never argv (argv is world-visible via
  // ps). These names are the contract parse_srv_params() reads.
  if (escr != NULL) {
    setenv("REMOTE_AUTH_ESCR_SESSION_ID", escr->session_id, 1);
    setenv("REMOTE_AUTH_ESCR_AES_KEY", escr->aes_key_base64, 1);
    setenv("REMOTE_AUTH_ESCR_PUB_KEY_URI", escr->signing_key_uri, 1);
    setenv("REMOTE_AUTH_ESCR_SIGNING_PRIVKEY", escr->signing_key_base64, 1);
    setenv("REMOTE_AUTH_ESCR_IS_SIDE_A", "false", 1);
  } else if (authenticate_to_rvd && rvd_auth_string != NULL) {
    setenv("RV_AUTH", rvd_auth_string, 1);
  }
  if (encrypt_rvd_traffic) {
    setenv("RV_AES_C2D", (char *)session_aes_key_c2d, 1);
    setenv("RV_IV_C2D", (char *)session_iv_c2d, 1);
    if (session_aes_key_d2c != NULL && session_iv_d2c != NULL) {
      setenv("RV_AES_D2C", (char *)session_aes_key_d2c, 1);
      setenv("RV_IV_D2C", (char *)session_iv_d2c, 1);
    }
  }

  // Build the srv argument list (non-secret). Index 0 is filled in per exec
  // target below (srv binary name, or the daemon path + worker flag).
  const char *srv_args[24];
  int n = 0;
  srv_args[n++] = "-h";
  srv_args[n++] = srvd_host;
  srv_args[n++] = "-p";
  srv_args[n++] = srvd_port_str;
  srv_args[n++] = "--local-port";
  srv_args[n++] = local_port_str;
  srv_args[n++] = "--local-host";
  srv_args[n++] = local_host;
  srv_args[n++] = "--timeout";
  srv_args[n++] = timeout_str;
  if (multi) {
    srv_args[n++] = "--multi";
  }
  if (encrypt_rvd_traffic) {
    srv_args[n++] = "--rv-e2ee";
  }
  // --rv-auth (legacy) and --relay-auth-mode escr are mutually exclusive in
  // srv; pick exactly one, matching the auth env vars set above.
  if (escr != NULL) {
    srv_args[n++] = "--relay-auth-mode";
    srv_args[n++] = "escr";
  } else if (authenticate_to_rvd) {
    srv_args[n++] = "--rv-auth";
  }

  char exe_path[PATH_MAX];
  if (sshnpd_own_exe_path(exe_path, sizeof(exe_path)) != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to resolve daemon executable path: %s\n",
                 strerror(errno));
    return -1;
  }

  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "Starting srv\n");
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "relay: %s:%s\n", srvd_host, srvd_port_str);
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_DEBUG, "requested: %s:%s\n", local_host, local_port_str);
  fflush(stdout);

  if (ready_fd >= 0 && dup2(ready_fd, 3) == 3) {
    setenv("SRV_READY_FD", "3", 1);
    sshnpd_close_inherited_fds(4);
  } else {
    sshnpd_close_inherited_fds(3);
  }

  // Self-exec only: re-run this exact (already-trusted) binary in srv worker
  // mode. There is deliberately no path to an external srv binary - that would
  // add a plant/replace target in the install directory - and the daemon links
  // srv-lib, so the worker path runs the same relay code in a fresh image with
  // no inherited daemon keys or atServer sockets.
  const char *argv[27];
  int i = 0;
  argv[i++] = exe_path;
  argv[i++] = SRV_WORKER_FLAG;
  for (int j = 0; j < n; j++) {
    argv[i++] = srv_args[j];
  }
  argv[i] = NULL;
  execv(exe_path, (char *const *)argv);

  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Failed to self-exec srv worker (%s): %s\n", exe_path,
               strerror(errno));
  return -1;
}

long sshnpd_monotonic_ms(void) {
  struct timespec now;
  clock_gettime(CLOCK_MONOTONIC, &now);
  return (long)now.tv_sec * 1000 + now.tv_nsec / 1000000;
}

typedef struct {
  pid_t pid;
  int ready_fd;
  long started_ms;
  char seen[2 * sizeof(SRV_COMPLETION_STRING)];
  size_t seen_len;
} srv_start;

static srv_start *starts;
static size_t start_count;
static size_t start_capacity;

static void forget_start(size_t i) {
  close(starts[i].ready_fd);
  starts[i] = starts[--start_count];
}

void srv_starts_watch(pid_t pid, int ready_fd, long now_ms) {
  if (start_count == start_capacity) {
    size_t capacity = start_capacity == 0 ? 8 : start_capacity * 2;
    srv_start *grown = realloc(starts, capacity * sizeof(srv_start));
    if (grown == NULL) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_WARN, "Can't watch srv %d start\n", (int)pid);
      close(ready_fd);
      return;
    }
    starts = grown;
    start_capacity = capacity;
  }
  starts[start_count++] = (srv_start){pid, ready_fd, now_ms, "", 0};
}

// Whether watched start i is over: srv reported, or its pipe closed
static bool start_settled(srv_start *start) {
  for (;;) {
    struct pollfd p = {start->ready_fd, POLLIN, 0};
    int ready = poll(&p, 1, 0);
    if (ready < 0 && errno == EINTR) {
      continue;
    }
    if (ready <= 0) {
      return false;
    }
    ssize_t n = read(start->ready_fd, start->seen + start->seen_len, sizeof(start->seen) - 1 - start->seen_len);
    if (n < 0 && errno == EINTR) {
      continue;
    }
    if (n <= 0) {
      return true;
    }
    start->seen_len += (size_t)n;
    start->seen[start->seen_len] = '\0';
    if (strstr(start->seen, SRV_COMPLETION_STRING) != NULL) {
      return true;
    }
    if (start->seen_len == sizeof(start->seen) - 1) {
      start->seen_len = 0;
    }
  }
}

void srv_starts_poll(long now_ms) {
  for (size_t i = 0; i < start_count;) {
    if (start_settled(&starts[i])) {
      forget_start(i);
    } else if (now_ms - starts[i].started_ms >= SRV_START_TIMEOUT_MS) {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_WARN,
                   "srv %d did not reach the relay within %d seconds - stopping it\n", (int)starts[i].pid,
                   SRV_START_TIMEOUT_MS / 1000);
      kill(starts[i].pid, SIGTERM);
      forget_start(i);
    } else {
      i++;
    }
  }
}

void srv_starts_reaped(pid_t pid) {
  for (size_t i = 0; i < start_count; i++) {
    if (starts[i].pid == pid) {
      forget_start(i);
      return;
    }
  }
}

size_t srv_starts_count(void) { return start_count; }
