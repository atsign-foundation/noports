// Goal: no private key material (a relay-auth key, a socket key or IV) reaches a log line. Non-goal: keeping other
// request content out of the log.
#include <arpa/inet.h>
#include <atlogger/atlogger.h>
#include <netinet/in.h>
#include <pthread.h>
#include <srv/params.h>
#include <srv/srv.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>

#define SCENARIO                                                                                                       \
  "Given srv logging at every level, when handling a control message fails, then the log names the message's type "    \
  "and gives the error, and no log line contains a socket key or IV."
#define SOCKET_KEY "c29ja2V0LWtleS1mb3ItY29udHJvbC1sb2ctY2hlY2s="
#define SOCKET_IV "c29ja2V0LWl2LWNoZWNrIQ=="

static int failures = 0;

static void check(bool ok, const char *what) {
  if (!ok) {
    printf("FAIL: %s\n", what);
    failures++;
  } else {
    printf("ok: %s\n", what);
  }
}

static void *run_daemon_side(void *params) {
  run_srv_daemon_side_multi((srv_params_t *)params);
  return NULL;
}

// Plays the relay to a daemon-side srv, sending message on its control
// channel, and returns what srv logged; the caller frees it
static char *log_of_control_message(const char *message) {
  FILE *capture = tmpfile();
  atlogger_set_logging_stream(capture);

  int relay = socket(AF_INET, SOCK_STREAM, 0);
  struct sockaddr_in address;
  memset(&address, 0, sizeof(address));
  address.sin_family = AF_INET;
  address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  socklen_t address_len = sizeof(address);
  if (relay < 0 || bind(relay, (struct sockaddr *)&address, sizeof(address)) != 0 || listen(relay, 1) != 0 ||
      getsockname(relay, (struct sockaddr *)&address, &address_len) != 0) {
    printf("could not play the relay\n");
    exit(1);
  }

  srv_params_t params;
  memset(&params, 0, sizeof(params));
  params.host = "127.0.0.1";
  params.port = ntohs(address.sin_port);
  params.multi = true;
  params.timeout = 5;
  params.ready_fd = -1;
  pthread_t daemon_side;
  pthread_create(&daemon_side, NULL, run_daemon_side, &params);

  int control = accept(relay, NULL, NULL);
  if (control < 0 || send(control, message, strlen(message), 0) != (ssize_t)strlen(message)) {
    printf("could not send the control message\n");
    exit(1);
  }
  usleep(300 * 1000);
  close(control);
  pthread_join(daemon_side, NULL);
  close(relay);

  fflush(capture);
  long len = ftell(capture);
  char *logged = calloc(len + 1, 1);
  rewind(capture);
  if (fread(logged, 1, len, capture) != (size_t)len) {
    logged[0] = '\0';
  }
  fclose(capture);
  atlogger_set_logging_stream(stderr);
  return logged;
}

// Whether logged holds either half of the socket key or the IV, printing the
// line it found
static bool holds_key_or_iv(const char *logged) {
  const char *key = SOCKET_KEY;
  const char *parts[] = {key, key + strlen(key) / 2, SOCKET_IV};
  for (size_t i = 0; i < sizeof(parts) / sizeof(parts[0]); i++) {
    char part[64] = {0};
    memcpy(part, parts[i], strlen(parts[i]) < 16 ? strlen(parts[i]) : 16);
    const char *at = strstr(logged, part);
    if (at != NULL) {
      const char *line = at;
      while (line > logged && line[-1] != '\n') {
        line--;
      }
      const char *end = strchr(at, '\n');
      printf("holds a key or IV: %.*s\n", (int)(end == NULL ? strlen(line) : (size_t)(end - line)), line);
      return true;
    }
  }
  return false;
}

int main(void) {
  atlogger_set_logging_level(ATLOGGER_LOGGING_LEVEL_DEBUG);
  printf("%s\n", SCENARIO);

  char *logged = log_of_control_message("conect:" SOCKET_KEY ":" SOCKET_IV "\n");
  check(!holds_key_or_iv(logged), "case: a control message of a type srv does not know, carrying a key and IV");
  const char *at = strstr(logged, "| Unknown conect request to control channel\n");
  if (at != NULL) {
    const char *line = at;
    while (line > logged && line[-1] != '\n') {
      line--;
    }
    const char *end = strchr(at, '\n');
    printf("matched: %.*s\n", (int)(end == NULL ? strlen(line) : (size_t)(end - line)), line);
  }
  check(at != NULL, "reach: the log names the unknown message's type");
  free(logged);

  if (failures > 0) {
    printf("%d check(s) failed\n", failures);
    return 1;
  }
  return 0;
}
