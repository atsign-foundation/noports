#include "sshnpd/public_lookup.h"
#include <arpa/inet.h>
#include <netinet/in.h>
#include <signal.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/wait.h>
#include <unistd.h>

// What the test atServer sends for a request of path: a whole response,
// NULL to send nothing, with *len set when it holds NUL bytes
typedef const char *(*responder)(const char *path, size_t *len);

typedef struct {
  pid_t pid;
  uint16_t port;
  int paths_fd;
} server;

// Starts an HTTP server on 127.0.0.1 answering each request with respond,
// and writing each request's path, a line each, to paths_fd
static server serve(responder respond) {
  server s = {-1, 0, -1};
  int listener = socket(AF_INET, SOCK_STREAM, 0);
  struct sockaddr_in addr = {0};
  addr.sin_family = AF_INET;
  addr.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  socklen_t addr_len = sizeof(addr);
  int fds[2];
  if (listener < 0 || bind(listener, (struct sockaddr *)&addr, sizeof(addr)) != 0 || listen(listener, 8) != 0 ||
      getsockname(listener, (struct sockaddr *)&addr, &addr_len) != 0 || pipe(fds) != 0) {
    return s;
  }
  s.port = ntohs(addr.sin_port);
  s.pid = fork();
  if (s.pid == 0) {
    close(fds[0]);
    for (;;) {
      int c = accept(listener, NULL, NULL);
      if (c < 0) {
        _exit(0);
      }
      char request[4096];
      size_t n = 0;
      while (n < sizeof(request) - 1) {
        ssize_t r = read(c, request + n, sizeof(request) - 1 - n);
        if (r <= 0) {
          break;
        }
        n += (size_t)r;
        request[n] = '\0';
        if (strstr(request, "\r\n\r\n") != NULL) {
          break;
        }
      }
      request[n] = '\0';
      char path[1024] = "";
      sscanf(request, "GET %1023s", path);
      dprintf(fds[1], "%s\n", path);
      size_t len = 0;
      const char *response = respond(path, &len);
      if (response == NULL) {
        sleep(5);
      } else {
        size_t total = len == 0 ? strlen(response) : len;
        for (size_t sent = 0; sent < total;) {
          ssize_t w = write(c, response + sent, total - sent);
          if (w <= 0) {
            break;
          }
          sent += (size_t)w;
        }
      }
      close(c);
    }
  }
  close(fds[1]);
  close(listener);
  s.paths_fd = fds[0];
  return s;
}

// Stops s, returning the paths it was asked for, a line each
static char *stop(server *s) {
  kill(s->pid, SIGKILL);
  waitpid(s->pid, NULL, 0);
  char *paths = calloc(1, 4096);
  ssize_t n = read(s->paths_fd, paths, 4095);
  paths[n < 0 ? 0 : n] = '\0';
  close(s->paths_fd);
  return paths;
}

static const char *ok(const char *path, size_t *len) {
  (void)path;
  (void)len;
  return "HTTP/1.1 200 OK\r\nContent-Length: 12\r\nConnection: close\r\n\r\na public key";
}
static const char *not_found(const char *path, size_t *len) {
  (void)path;
  (void)len;
  return "HTTP/1.1 404 Not Found\r\nContent-Length: 13\r\nConnection: close\r\n\r\n404 Not Found";
}
static const char *redirect(const char *path, size_t *len) {
  (void)path;
  (void)len;
  return "HTTP/1.1 302 Found\r\nLocation: /elsewhere\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";
}
static const char *server_error(const char *path, size_t *len) {
  (void)path;
  (void)len;
  return "HTTP/1.1 500 Internal Server Error\r\nContent-Length: 0\r\nConnection: close\r\n\r\n";
}
static const char *at_protocol(const char *path, size_t *len) {
  (void)path;
  (void)len;
  return "@";
}
static const char *declared_too_big(const char *path, size_t *len) {
  (void)path;
  (void)len;
  return "HTTP/1.1 200 OK\r\nContent-Length: 70000\r\nConnection: close\r\n\r\n";
}
static char chunked_body[80000];
static const char *chunked_too_big(const char *path, size_t *len) {
  (void)path;
  (void)len;
  return chunked_body;
}
static const char *with_nul(const char *path, size_t *len) {
  (void)path;
  static const char response[] = "HTTP/1.1 200 OK\r\nContent-Length: 3\r\nConnection: close\r\n\r\na\0b";
  *len = sizeof(response) - 1;
  return response;
}
static const char *silent(const char *path, size_t *len) {
  (void)path;
  (void)len;
  return NULL;
}
static const char *revoked(const char *path, size_t *len) {
  return strstr(path, ".r.__e") != NULL ? ok(path, len) : not_found(path, len);
}
static const char *deleted(const char *path, size_t *len) {
  return strstr(path, ".d.__e") != NULL ? ok(path, len) : not_found(path, len);
}
static const char *deleted_unserved(const char *path, size_t *len) {
  return strstr(path, ".d.__e") != NULL ? server_error(path, len) : not_found(path, len);
}

static int failures = 0;

static void expect(bool ok, const char *what, const char *detail) {
  if (!ok) {
    printf("FAILED: %s (%s)\n", what, detail);
    failures++;
  }
}

static const char *KEY = "public:_apsk.alice-enrollment.a.__e@alice";

// Looks KEY (or uri) up on a server answering with respond, within
// timeout_ms, returning the result and the paths the server was asked for
static enum public_lookup_result lookup_on(responder respond, const char *uri, long timeout_ms, char **value,
                                           char **paths) {
  server s = serve(respond);
  enum public_lookup_result result = public_lookup_at("http", "127.0.0.1", s.port, uri, timeout_ms, value);
  *paths = stop(&s);
  return result;
}

int main() {
  int n = snprintf(chunked_body, sizeof(chunked_body),
                   "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n11170\r\n");
  memset(chunked_body + n, 'x', 70000);
  snprintf(chunked_body + n + 70000, sizeof(chunked_body) - (size_t)n - 70000, "\r\n0\r\n\r\n");

  char *value = NULL, *paths = NULL;
  enum public_lookup_result r = lookup_on(ok, KEY, 1000, &value, &paths);
  expect(r == PUBLIC_LOOKUP_FOUND && value != NULL && strcmp(value, "a public key") == 0,
         "returns the value the atServer serves", value == NULL ? "(none)" : value);
  expect(strcmp(paths, "/@alice/_apsk.alice-enrollment.a.__e\n") == 0, "asks for /<atSign>/<key>", paths);
  free(value);
  free(paths);

  r = lookup_on(ok, "public:_apsk.x.a.__e@a/b c", 1000, &value, &paths);
  expect(strcmp(paths, "/@a%2Fb%20c/_apsk.x.a.__e\n") == 0, "percent-encodes what a path segment can't hold",
         paths);
  free(value);
  free(paths);

  struct {
    const char *name;
    responder respond;
    long timeout_ms;
    enum public_lookup_result expected;
  } cases[] = {
      {"a 404 is not found", not_found, 1000, PUBLIC_LOOKUP_NOT_FOUND},
      {"a redirect isn't followed", redirect, 1000, PUBLIC_LOOKUP_NOT_SERVED},
      {"another status is not served", server_error, 1000, PUBLIC_LOOKUP_NOT_SERVED},
      {"an atProtocol answer is not served", at_protocol, 1000, PUBLIC_LOOKUP_NOT_SERVED},
      {"a declared value over the cap fails", declared_too_big, 1000, PUBLIC_LOOKUP_FAILED},
      {"a chunked value over the cap fails", chunked_too_big, 1000, PUBLIC_LOOKUP_FAILED},
      {"a value holding a NUL fails", with_nul, 1000, PUBLIC_LOOKUP_FAILED},
      {"a silent atServer fails at the deadline", silent, 300, PUBLIC_LOOKUP_FAILED},
  };
  for (size_t i = 0; i < sizeof(cases) / sizeof(cases[0]); i++) {
    r = lookup_on(cases[i].respond, KEY, cases[i].timeout_ms, &value, &paths);
    char detail[64];
    snprintf(detail, sizeof(detail), "result %d", r);
    expect(r == cases[i].expected && (r == PUBLIC_LOOKUP_FOUND || value == NULL), cases[i].name, detail);
    if (cases[i].respond == redirect) {
      expect(strcmp(paths, "/@alice/_apsk.alice-enrollment.a.__e\n") == 0, "follows no redirect", paths);
    }
    free(value);
    free(paths);
  }

  server closed = serve(ok);
  uint16_t closed_port = closed.port;
  free(stop(&closed));
  r = public_lookup_at("http", "127.0.0.1", closed_port, KEY, 1000, &value);
  expect(r == PUBLIC_LOOKUP_NOT_SERVED, "a refused connection is not served", "");

  struct {
    const char *name;
    responder respond;
    int expected_rc;
    const char *expected_location;
  } withdrawn[] = {
      {"finds a revoked enrollment", revoked, 0, "r.__e"},
      {"finds a deleted enrollment", deleted, 0, "d.__e"},
      {"finds neither when the enrollment is merely missing", not_found, 0, NULL},
      {"can't tell when an atServer doesn't answer", deleted_unserved, 1, NULL},
  };
  for (size_t i = 0; i < sizeof(withdrawn) / sizeof(withdrawn[0]); i++) {
    server s = serve(withdrawn[i].respond);
    const char *location = "unset";
    int rc = public_lookup_withdrawn_to_at("http", "127.0.0.1", s.port, KEY, 1000, &location);
    free(stop(&s));
    bool same = location == NULL || withdrawn[i].expected_location == NULL
                    ? location == withdrawn[i].expected_location
                    : strcmp(location, withdrawn[i].expected_location) == 0;
    expect(rc == withdrawn[i].expected_rc && (rc != 0 || same), withdrawn[i].name,
           location == NULL ? "(null)" : location);
  }

  printf("Tests failed: %d\n", failures);
  return failures;
}
