// Regression test for issue #2891: socket_to_socket teardown segfault.
//
// pthread_join was called with the address of a 4-byte int as the thread
// result pointer; the 8-byte result write clobbered the adjacent `tid` local,
// so when side a (the local service socket) closed first, the teardown logic
// cancelled the thread it had just joined. On musl a joined thread's stack -
// including its pthread descriptor - is unmapped, so the stray pthread_cancel
// segfaulted the whole srv process.
//
// This test bridges two local sockets through socket_to_socket and tears the
// connection down repeatedly in both orders. The side-a-first ordering is the
// one which crashed; on musl x86-64 builds this test segfaults without the
// fix (the clobber is UB - on other arches/libcs the corruption is silent, so
// this test must run on musl x86-64 to be able to fail; see c_unit_tests.yaml).

#include <srv/params.h>
#include <srv/srv.h>

#include <arpa/inet.h>
#include <netinet/in.h>
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>

#define ITERATIONS_PER_ORDER 8

typedef struct {
  srv_params_t *params;
  int result;
} runner_args_t;

static void *run_socket_to_socket_thread(void *args) {
  runner_args_t *runner = (runner_args_t *)args;
  runner->result = socket_to_socket(runner->params, NULL, NULL, NULL, true);
  return NULL;
}

// Create a listener on 127.0.0.1 with an ephemeral port; returns the fd and
// writes the chosen port to *port_out
static int make_listener(uint16_t *port_out) {
  int fd = socket(AF_INET, SOCK_STREAM, 0);
  if (fd < 0) {
    return -1;
  }

  struct sockaddr_in addr;
  memset(&addr, 0, sizeof(addr));
  addr.sin_family = AF_INET;
  addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  addr.sin_port = 0;

  if (bind(fd, (struct sockaddr *)&addr, sizeof(addr)) != 0 || listen(fd, 1) != 0) {
    close(fd);
    return -1;
  }

  socklen_t addr_len = sizeof(addr);
  if (getsockname(fd, (struct sockaddr *)&addr, &addr_len) != 0) {
    close(fd);
    return -1;
  }
  *port_out = ntohs(addr.sin_port);

  return fd;
}

static int accept_with_recv_timeout(int listener) {
  int fd = accept(listener, NULL, NULL);
  if (fd < 0) {
    return -1;
  }
  // Bound every recv so a broken bridge fails the test instead of hanging it
  struct timeval tv = {.tv_sec = 3, .tv_usec = 0};
  setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));
  return fd;
}

// Send msg into `from` and expect it to come out of `to` via the bridge
static int expect_bridged(int from, int to, const char *msg) {
  size_t len = strlen(msg);
  char buffer[64];

  if (send(from, msg, len, 0) != (ssize_t)len) {
    printf("send failed\n");
    return 1;
  }

  size_t received = 0;
  while (received < len) {
    ssize_t n = recv(to, buffer + received, sizeof(buffer) - received, 0);
    if (n <= 0) {
      printf("recv failed or timed out (%zd)\n", n);
      return 1;
    }
    received += (size_t)n;
  }

  if (received != len || memcmp(buffer, msg, len) != 0) {
    printf("bridged data mismatch\n");
    return 1;
  }
  return 0;
}

// Run one bridge session and tear it down. close_service_first selects which
// side thread exits first: the service (side a) ordering is the one which
// crashed before the fix, the relay (side b) ordering is the control.
static int run_iteration(bool close_service_first) {
  uint16_t service_port = 0, relay_port = 0;
  int failures = 1; // cleared at the end when everything passed

  int service_listener = make_listener(&service_port);
  int relay_listener = make_listener(&relay_port);
  int service_conn = -1, relay_conn = -1;
  if (service_listener < 0 || relay_listener < 0) {
    printf("failed to create listeners\n");
    goto cleanup_listeners;
  }

  char local_host[] = "127.0.0.1";
  srv_params_t params;
  memset(&params, 0, sizeof(params));
  params.host = local_host;
  params.port = relay_port;
  params.local_host = local_host;
  params.local_port = service_port;

  runner_args_t runner = {.params = &params, .result = -1};
  pthread_t runner_thread;
  if (pthread_create(&runner_thread, NULL, run_socket_to_socket_thread, &runner) != 0) {
    printf("failed to start runner thread\n");
    goto cleanup_listeners;
  }

  // socket_to_socket connects side a (service) first, then side b (relay)
  service_conn = accept_with_recv_timeout(service_listener);
  relay_conn = accept_with_recv_timeout(relay_listener);
  if (service_conn < 0 || relay_conn < 0) {
    printf("accept failed\n");
    goto cleanup_session;
  }

  // Prove both side threads are up and bridging in both directions
  if (expect_bridged(relay_conn, service_conn, "ping") != 0 ||
      expect_bridged(service_conn, relay_conn, "pong") != 0) {
    goto cleanup_session;
  }

  // Tear down one side; socket_to_socket must join the exited thread, cancel
  // the OTHER one, and return cleanly
  if (close_service_first) {
    close(service_conn);
    service_conn = -1;
  } else {
    close(relay_conn);
    relay_conn = -1;
  }

  pthread_join(runner_thread, NULL);
  if (runner.result != 0) {
    printf("socket_to_socket returned %d\n", runner.result);
    goto cleanup_listeners;
  }

  failures = 0;
  goto cleanup_listeners;

cleanup_session:
  // Both conns must be closed before joining: while either is open its side
  // thread stays parked in mbedtls_net_recv and never writes its id to the
  // pipe, so socket_to_socket never returns and the join blocks forever.
  if (service_conn >= 0) {
    close(service_conn);
    service_conn = -1;
  }
  if (relay_conn >= 0) {
    close(relay_conn);
    relay_conn = -1;
  }
  pthread_join(runner_thread, NULL);

cleanup_listeners:
  if (service_conn >= 0) {
    close(service_conn);
  }
  if (relay_conn >= 0) {
    close(relay_conn);
  }
  if (service_listener >= 0) {
    close(service_listener);
  }
  if (relay_listener >= 0) {
    close(relay_listener);
  }
  return failures;
}

int main() {
  // The bridge sockets get torn down mid-session by design - don't let a
  // stray write to a closing socket kill the test
  signal(SIGPIPE, SIG_IGN);

  int failures = 0;

  for (int i = 0; i < ITERATIONS_PER_ORDER; i++) {
    failures += run_iteration(true);
  }
  printf("service-closes-first (issue #2891 ordering): %s\n", failures == 0 ? "OK" : "FAILED");

  int relay_failures = 0;
  for (int i = 0; i < ITERATIONS_PER_ORDER; i++) {
    relay_failures += run_iteration(false);
  }
  printf("relay-closes-first: %s\n", relay_failures == 0 ? "OK" : "FAILED");

  return failures + relay_failures;
}
