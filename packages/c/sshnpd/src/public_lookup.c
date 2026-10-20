#include <atclient/atclient_utils.h>
#include <atclient/cacerts.h>
#include <atlogger/atlogger.h>
#include <curl/curl.h>
#include <errno.h>
#include <fcntl.h>
#include <mbedtls/ssl.h>
#include <poll.h>
#include <signal.h>
#include <sshnpd/public_lookup.h>
#include <sshnpd/run_srv_process.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

#define LOGGER_TAG "PUBLIC_LOOKUP"

// The CA certificates at_c trusts for atServer connections, since the GET
// goes to the same atServer, on the same port
static const char ca_pem[] = LETS_ENCRYPT_ROOT GOOGLE_GLOBAL_SIGN GOOGLE_GTS_ROOT_R1 GOOGLE_GTS_ROOT_R2
    GOOGLE_GTS_ROOT_R3 GOOGLE_GTS_ROOT_R4 ZEROSSL_INTERMEDIATE;

// NOTE: an atServer answers a TLS connection over HTTP only when ALPN selects
// http/1.1, and curl offers ALPN over mbedtls only when built for HTTP/2
static const char *alpn_protocols[] = {"http/1.1", NULL};

static CURLcode offer_http11(CURL *curl, void *ssl_config, void *userptr) {
  (void)curl;
  (void)userptr;
  return mbedtls_ssl_conf_alpn_protocols(ssl_config, alpn_protocols) == 0 ? CURLE_OK : CURLE_SSL_CONNECT_ERROR;
}

enum public_lookup_result public_lookup_find_atserver(const public_lookup_directory *directory, const char *atsign,
                                                      char **host, uint16_t *port) {
  *host = NULL;
  if (directory->via_proxy) {
    *host = strdup(directory->host);
    *port = directory->port;
    return *host == NULL ? PUBLIC_LOOKUP_FAILED : PUBLIC_LOOKUP_FOUND;
  }
  if (atclient_utils_find_atserver_address(directory->host, directory->port, atsign, host, port) != 0 ||
      *host == NULL) {
    free(*host);
    *host = NULL;
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_WARN, "The atDirectory has no address for %s\n", atsign);
    return PUBLIC_LOOKUP_NOT_SERVED;
  }
  return PUBLIC_LOOKUP_FOUND;
}

// Appends segment to url percent-encoded as a URI path segment, keeping the
// characters RFC 3986 allows there unencoded, as Dart's Uri does
static void append_path_segment(char *url, size_t url_size, const char *segment) {
  static const char keep[] = "-._~!$&'()*+,;=:@";
  size_t n = strlen(url);
  for (const unsigned char *c = (const unsigned char *)segment; *c != '\0' && n + 4 < url_size; c++) {
    if ((*c >= 'A' && *c <= 'Z') || (*c >= 'a' && *c <= 'z') || (*c >= '0' && *c <= '9') || strchr(keep, *c)) {
      url[n++] = (char)*c;
    } else {
      n += (size_t)snprintf(url + n, url_size - n, "%%%02X", *c);
    }
  }
  url[n] = '\0';
}

typedef struct {
  char *data;
  size_t len;
  bool too_big;
} body;

static size_t on_body(char *data, size_t size, size_t nmemb, void *userdata) {
  body *b = userdata;
  size_t n = size * nmemb;
  // NOTE: curl stops a transfer outgrowing CURLOPT_MAXFILESIZE only from 8.4;
  // an older system libcurl checks just a declared length
  if (b->len + n > PUBLIC_LOOKUP_MAX_VALUE_BYTES) {
    b->too_big = true;
    return 0;
  }
  char *grown = realloc(b->data, b->len + n + 1);
  if (grown == NULL) {
    return 0;
  }
  memcpy(grown + b->len, data, n);
  b->data = grown;
  b->len += n;
  b->data[b->len] = '\0';
  return n;
}

// Whether s's first len bytes are UTF-8 holding no NUL, which a value must
// be to be read as text
static bool is_utf8_text(const unsigned char *s, size_t len) {
  size_t i = 0;
  while (i < len) {
    unsigned char c = s[i];
    size_t extra;
    if (c == 0) {
      return false;
    } else if (c < 0x80) {
      extra = 0;
    } else if ((c & 0xE0) == 0xC0) {
      extra = 1;
    } else if ((c & 0xF0) == 0xE0) {
      extra = 2;
    } else if ((c & 0xF8) == 0xF0) {
      extra = 3;
    } else {
      return false;
    }
    if (extra > len - i - 1) {
      return false;
    }
    for (size_t k = 1; k <= extra; k++) {
      if ((s[i + k] & 0xC0) != 0x80) {
        return false;
      }
    }
    i += extra + 1;
  }
  return true;
}

enum public_lookup_result public_lookup_at(const char *scheme, const char *host, uint16_t port, const char *uri,
                                           long timeout_ms, char **value) {
  *value = NULL;
  const char *at = strrchr(uri, '@');
  if (strncmp(uri, "public:", strlen("public:")) != 0 || at == NULL || at < uri + strlen("public:")) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "%s is not public:<key>@<atSign>\n", uri);
    return PUBLIC_LOOKUP_FAILED;
  }
  size_t key_len = (size_t)(at - uri) - strlen("public:");
  char *key = strndup(uri + strlen("public:"), key_len);
  size_t url_size = strlen(scheme) + strlen(host) + 3 * strlen(uri) + 32;
  char *url = malloc(url_size);
  CURL *curl = curl_easy_init();
  if (key == NULL || url == NULL || curl == NULL) {
    free(key);
    free(url);
    curl_easy_cleanup(curl);
    return PUBLIC_LOOKUP_FAILED;
  }
  snprintf(url, url_size, "%s://%s:%u/", scheme, host, (unsigned int)port);
  append_path_segment(url, url_size, at);
  strncat(url, "/", url_size - strlen(url) - 1);
  append_path_segment(url, url_size, key);
  free(key);

  body b = {NULL, 0, false};
  struct curl_blob ca = {(void *)ca_pem, sizeof(ca_pem), CURL_BLOB_NOCOPY};
  curl_easy_setopt(curl, CURLOPT_URL, url);
  curl_easy_setopt(curl, CURLOPT_PROTOCOLS_STR, scheme);
  curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, 0L);
  curl_easy_setopt(curl, CURLOPT_NOSIGNAL, 1L);
  curl_easy_setopt(curl, CURLOPT_TIMEOUT_MS, timeout_ms);
  curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT_MS, timeout_ms / 2);
  curl_easy_setopt(curl, CURLOPT_MAXFILESIZE_LARGE, (curl_off_t)PUBLIC_LOOKUP_MAX_VALUE_BYTES);
  curl_easy_setopt(curl, CURLOPT_CAINFO_BLOB, &ca);
  curl_easy_setopt(curl, CURLOPT_SSL_CTX_FUNCTION, offer_http11);
  curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, on_body);
  curl_easy_setopt(curl, CURLOPT_WRITEDATA, &b);

  CURLcode res = curl_easy_perform(curl);
  long status = 0;
  curl_off_t connected_at = 0;
  curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &status);
  curl_easy_getinfo(curl, strcmp(scheme, "https") == 0 ? CURLINFO_APPCONNECT_TIME_T : CURLINFO_CONNECT_TIME_T,
                    &connected_at);
  curl_easy_cleanup(curl);

  enum public_lookup_result result;
  if (res == CURLE_OK && status == 200) {
    if (is_utf8_text((const unsigned char *)(b.data == NULL ? "" : b.data), b.len)) {
      *value = b.data == NULL ? strdup("") : b.data;
      b.data = NULL;
      result = *value == NULL ? PUBLIC_LOOKUP_FAILED : PUBLIC_LOOKUP_FOUND;
    } else {
      atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_WARN, "%s answered with a value that is not text\n", url);
      result = PUBLIC_LOOKUP_FAILED;
    }
  } else if (res == CURLE_OK && status == 404) {
    result = PUBLIC_LOOKUP_NOT_FOUND;
  } else if (res == CURLE_OK) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_WARN, "%s answered %ld\n", url, status);
    result = PUBLIC_LOOKUP_NOT_SERVED;
  } else if (b.too_big || res == CURLE_FILESIZE_EXCEEDED) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_WARN, "%s answered more than %d bytes\n", url,
                 PUBLIC_LOOKUP_MAX_VALUE_BYTES);
    result = PUBLIC_LOOKUP_FAILED;
  } else if (res == CURLE_OPERATION_TIMEDOUT && connected_at > 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_WARN, "%s did not answer within %ld ms\n", url, timeout_ms);
    result = PUBLIC_LOOKUP_FAILED;
  } else {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_WARN, "%s did not answer over %s: %s\n", url, scheme,
                 curl_easy_strerror(res));
    result = PUBLIC_LOOKUP_NOT_SERVED;
  }
  free(b.data);
  free(url);
  return result;
}

int public_lookup_withdrawn_to_at(const char *scheme, const char *host, uint16_t port, const char *uri,
                                  long timeout_ms, const char **location) {
  static const char prefix[] = "public:_apsk.";
  static const char approved[] = ".a.__e@";
  static const char *const locations[] = {"r.__e", "d.__e"};
  *location = NULL;
  if (strncmp(uri, prefix, strlen(prefix)) != 0) {
    return 0;
  }
  const char *id = uri + strlen(prefix);
  size_t id_len = strspn(id, "abcdefghijklmnopqrstuvwxyz0123456789_-");
  const char *suffix = id + id_len;
  const char *atsign = suffix + strlen(approved) - 1;
  if (id_len == 0 || strncmp(suffix, approved, strlen(approved)) != 0 || atsign[1] == '\0' ||
      strpbrk(atsign + 1, "@: \t\r\n\f\v") != NULL) {
    return 0;
  }
  bool error = false;
  for (size_t i = 0; i < 2; i++) {
    size_t size = strlen(uri) + 1;
    char *withdrawn = malloc(size);
    if (withdrawn == NULL) {
      return 1;
    }
    snprintf(withdrawn, size, "%.*s.%s%s", (int)(suffix - uri), uri, locations[i], atsign);
    char *value = NULL;
    enum public_lookup_result result = public_lookup_at(scheme, host, port, withdrawn, timeout_ms, &value);
    free(withdrawn);
    free(value);
    if (result == PUBLIC_LOOKUP_FOUND) {
      *location = locations[i];
      return 0;
    }
    if (result != PUBLIC_LOOKUP_NOT_FOUND) {
      error = true;
    }
  }
  return error ? 1 : 0;
}

static public_lookup_directory worker_directory;
static char worker_port[8];

void public_lookup_worker_init(const public_lookup_directory *directory) {
  worker_directory = *directory;
  snprintf(worker_port, sizeof(worker_port), "%u", (unsigned int)directory->port);
}

// The atSign a public record uri belongs to: everything from its last '@'
static const char *uri_atsign(const char *uri) { return strrchr(uri, '@'); }

static long monotonic_ms(void) {
  struct timespec now;
  clock_gettime(CLOCK_MONOTONIC, &now);
  return (long)now.tv_sec * 1000 + now.tv_nsec / 1000000;
}

// When the worker must be done, by monotonic_ms
static long worker_done_by_ms;

// How long the worker's next GET may take: what is left of its budget, and
// no more than one lookup's timeout; 0 when nothing is left, since curl reads
// a timeout of 0 as none
static long next_timeout_ms(void) {
  long left = worker_done_by_ms - monotonic_ms();
  if (left <= 0) {
    return 0;
  }
  return left < PUBLIC_LOOKUP_TIMEOUT_MS ? left : PUBLIC_LOOKUP_TIMEOUT_MS;
}

static int run_lookup(const public_lookup_directory *directory, const char *uri) {
  char *host = NULL;
  uint16_t port = 0;
  enum public_lookup_result result = public_lookup_find_atserver(directory, uri_atsign(uri), &host, &port);
  if (result != PUBLIC_LOOKUP_FOUND) {
    return result;
  }
  char *value = NULL;
  long timeout_ms = next_timeout_ms();
  result = timeout_ms == 0 ? PUBLIC_LOOKUP_FAILED
                           : public_lookup_at(directory->scheme, host, port, uri, timeout_ms, &value);
  free(host);
  if (result == PUBLIC_LOOKUP_FOUND) {
    fputs(value, stdout);
    fflush(stdout);
  }
  free(value);
  return result;
}

static int run_key_check(const public_lookup_directory *directory, const char *uri) {
  char *host = NULL;
  uint16_t port = 0;
  if (public_lookup_find_atserver(directory, uri_atsign(uri), &host, &port) != PUBLIC_LOOKUP_FOUND) {
    return PUBLIC_LOOKUP_KEY_CHECK_UNKNOWN;
  }
  char *value = NULL;
  long timeout_ms = next_timeout_ms();
  enum public_lookup_result result =
      timeout_ms == 0 ? PUBLIC_LOOKUP_FAILED : public_lookup_at(directory->scheme, host, port, uri, timeout_ms, &value);
  free(value);
  int outcome;
  if (result == PUBLIC_LOOKUP_FOUND) {
    outcome = PUBLIC_LOOKUP_KEY_CHECK_PUBLISHED;
  } else if (result != PUBLIC_LOOKUP_NOT_FOUND) {
    outcome = PUBLIC_LOOKUP_KEY_CHECK_UNKNOWN;
  } else {
    // The two lookups of where it went share what is left of the budget
    const char *location = NULL;
    long each_ms = next_timeout_ms() / 2;
    if (each_ms == 0 ||
        public_lookup_withdrawn_to_at(directory->scheme, host, port, uri, each_ms, &location) != 0) {
      outcome = PUBLIC_LOOKUP_KEY_CHECK_UNKNOWN;
    } else if (location == NULL) {
      outcome = PUBLIC_LOOKUP_KEY_CHECK_MISSING;
    } else {
      outcome = strcmp(location, "r.__e") == 0 ? PUBLIC_LOOKUP_KEY_CHECK_REVOKED : PUBLIC_LOOKUP_KEY_CHECK_DELETED;
    }
  }
  free(host);
  return outcome;
}

// How long a worker may take in all, its atDirectory lookup included: one
// lookup's timeout for a lookup, which holds up the daemon's main loop, and
// two for a key check, as the Dart daemon's lookupDirect then withdrawnTo
// allow
static unsigned int worker_budget_secs(const char *mode) {
  return (strcmp(mode, "key-check") == 0 ? 2 : 1) * PUBLIC_LOOKUP_TIMEOUT_MS / 1000;
}

// argv: <exe> --__public-lookup <lookup|key-check> <scheme> <directory host> <port> <atdirectory|proxy> <uri>
int public_lookup_worker_main(int argc, const char **argv) {
  if (argc != 8) {
    return PUBLIC_LOOKUP_FAILED;
  }
  const char *mode = argv[2];
  bool key_check = strcmp(mode, "key-check") == 0;
  int unknown = key_check ? PUBLIC_LOOKUP_KEY_CHECK_UNKNOWN : PUBLIC_LOOKUP_FAILED;
  long port = strtol(argv[5], NULL, 10);
  if ((!key_check && strcmp(mode, "lookup") != 0) || port < 1 || port > 65535) {
    return unknown;
  }
  // NOTE: SIGALRM's default action ends the worker, which the daemon reads as
  // a lookup that couldn't be done, however the network stalls it
  signal(SIGALRM, SIG_DFL);
  alarm(worker_budget_secs(mode) + 1);
  worker_done_by_ms = monotonic_ms() + (long)worker_budget_secs(mode) * 1000;
  atlogger_set_logging_stream(stderr);
  atlogger_set_logging_level(ATLOGGER_LOGGING_LEVEL_WARN);
  if (curl_global_init(CURL_GLOBAL_DEFAULT) != CURLE_OK) {
    return unknown;
  }
  public_lookup_directory directory = {argv[4], (uint16_t)port, strcmp(argv[6], "proxy") == 0, argv[3]};
  int result = key_check ? run_key_check(&directory, argv[7]) : run_lookup(&directory, argv[7]);
  curl_global_cleanup();
  return result;
}

pid_t public_lookup_worker_start(const char *mode, const char *uri, int *stdout_fd) {
  char exe_path[4096];
  if (worker_directory.host == NULL || sshnpd_own_exe_path(exe_path, sizeof(exe_path)) != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Can't start a lookup worker for %s\n", uri);
    return -1;
  }
  int fds[2] = {-1, -1};
  if (stdout_fd != NULL && pipe(fds) != 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Can't make a pipe for a lookup worker: %s\n",
                 strerror(errno));
    return -1;
  }
  pid_t pid = fork();
  if (pid == 0) {
    int devnull = open("/dev/null", O_RDONLY);
    if (devnull >= 0) {
      dup2(devnull, STDIN_FILENO);
    }
    if (stdout_fd != NULL) {
      dup2(fds[1], STDOUT_FILENO);
    }
    sshnpd_close_inherited_fds(3);
    const char *argv[] = {exe_path,
                          PUBLIC_LOOKUP_WORKER_FLAG,
                          mode,
                          worker_directory.scheme,
                          worker_directory.host,
                          worker_port,
                          worker_directory.via_proxy ? "proxy" : "atdirectory",
                          uri,
                          NULL};
    execv(exe_path, (char *const *)argv);
    _exit(strcmp(mode, "key-check") == 0 ? PUBLIC_LOOKUP_KEY_CHECK_UNKNOWN : PUBLIC_LOOKUP_FAILED);
  }
  if (stdout_fd != NULL) {
    close(fds[1]);
    if (pid > 0) {
      *stdout_fd = fds[0];
    } else {
      close(fds[0]);
    }
  }
  if (pid < 0) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_ERROR, "Can't fork a lookup worker: %s\n", strerror(errno));
  }
  return pid;
}

static long ms_since(const struct timespec *start) {
  struct timespec now;
  clock_gettime(CLOCK_MONOTONIC, &now);
  return (long)(now.tv_sec - start->tv_sec) * 1000 + (now.tv_nsec - start->tv_nsec) / 1000000;
}

enum public_lookup_result public_lookup_direct(const char *uri, char **value) {
  *value = NULL;
  int fd = -1;
  pid_t pid = public_lookup_worker_start("lookup", uri, &fd);
  if (pid < 0) {
    return PUBLIC_LOOKUP_FAILED;
  }
  long deadline_ms = (long)(worker_budget_secs("lookup") + 2) * 1000;
  struct timespec start;
  clock_gettime(CLOCK_MONOTONIC, &start);
  char *out = NULL;
  size_t len = 0;
  bool overflow = false;
  bool timed_out = false;
  for (;;) {
    long left = deadline_ms - ms_since(&start);
    if (left <= 0) {
      timed_out = true;
      break;
    }
    struct pollfd p = {fd, POLLIN, 0};
    int ready = poll(&p, 1, (int)left);
    if (ready < 0 && errno == EINTR) {
      continue;
    }
    if (ready <= 0) {
      timed_out = ready == 0;
      break;
    }
    char chunk[4096];
    ssize_t n = read(fd, chunk, sizeof(chunk));
    if (n < 0 && errno == EINTR) {
      continue;
    }
    if (n <= 0) {
      break;
    }
    if (len + (size_t)n > PUBLIC_LOOKUP_MAX_VALUE_BYTES) {
      overflow = true;
      break;
    }
    char *grown = realloc(out, len + (size_t)n + 1);
    if (grown == NULL) {
      overflow = true;
      break;
    }
    out = grown;
    memcpy(out + len, chunk, (size_t)n);
    len += (size_t)n;
    out[len] = '\0';
  }
  close(fd);
  if (timed_out || overflow) {
    kill(pid, SIGKILL);
  }
  int status = 0;
  while (waitpid(pid, &status, 0) < 0 && errno == EINTR) {
  }
  enum public_lookup_result result = PUBLIC_LOOKUP_FAILED;
  if (timed_out) {
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_WARN, "Looking %s up took more than %ld ms\n", uri, deadline_ms);
  } else if (!overflow && WIFEXITED(status) && WEXITSTATUS(status) <= PUBLIC_LOOKUP_FAILED) {
    result = (enum public_lookup_result)WEXITSTATUS(status);
  }
  if (result == PUBLIC_LOOKUP_FOUND) {
    *value = out == NULL ? strdup("") : out;
    out = NULL;
    if (*value == NULL) {
      result = PUBLIC_LOOKUP_FAILED;
    }
  }
  free(out);
  return result;
}
