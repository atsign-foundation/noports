#ifndef SSHNPD_PUBLIC_LOOKUP_H
#define SSHNPD_PUBLIC_LOOKUP_H

#include <stdbool.h>
#include <stdint.h>
#include <sys/types.h>

// How long one lookup may take, as the Dart daemon allows
#define PUBLIC_LOOKUP_TIMEOUT_MS 10000

// The most a record's value may be, which no `_apsk` advertisement or public
// key comes near
#define PUBLIC_LOOKUP_MAX_VALUE_BYTES (64 * 1024)

// The first argument that makes the daemon a lookup worker
#define PUBLIC_LOOKUP_WORKER_FLAG "--__public-lookup"

enum public_lookup_result {
  // The atServer answered with the record's value
  PUBLIC_LOOKUP_FOUND = 0,
  // The atServer answered that it holds no such record
  PUBLIC_LOOKUP_NOT_FOUND = 1,
  // The atServer couldn't be found, connected to or trusted, or didn't answer
  // over HTTP, so asking it some other way might still work
  PUBLIC_LOOKUP_NOT_SERVED = 2,
  // The atServer was connected to but didn't answer in time, or answered with
  // something unusable
  PUBLIC_LOOKUP_FAILED = 3,
};

// What a key check of an `_apsk` record found, as a lookup worker's exit code
enum public_lookup_key_check {
  // The record is still published, so the sessions it signed carry on
  PUBLIC_LOOKUP_KEY_CHECK_PUBLISHED = 0,
  // The enrollment was revoked or superseded: the record is now in `r.__e`
  PUBLIC_LOOKUP_KEY_CHECK_REVOKED = 10,
  // The enrollment was deleted or expired: the record is now in `d.__e`
  PUBLIC_LOOKUP_KEY_CHECK_DELETED = 11,
  // The record is missing, but hasn't been withdrawn
  PUBLIC_LOOKUP_KEY_CHECK_MISSING = 12,
  // The record's atServer couldn't tell
  PUBLIC_LOOKUP_KEY_CHECK_UNKNOWN = 13,
};

// Where atServers are found: the atDirectory at host:port, or, with
// via_proxy, the reverse proxy at host:port that every atServer is reached
// through
typedef struct {
  const char *host;
  uint16_t port;
  bool via_proxy;
  // "https", or "http" for a test's atServer
  const char *scheme;
} public_lookup_directory;

// Finds the atServer for atsign. Returns PUBLIC_LOOKUP_FOUND with *host
// (malloc'd) and *port set, or PUBLIC_LOOKUP_NOT_SERVED when there is no
// address for it.
enum public_lookup_result public_lookup_find_atserver(const public_lookup_directory *directory, const char *atsign,
                                                      char **host, uint16_t *port);

// Looks up the public record uri (`public:<key>@<atSign>`) with a GET of
// `/<atSign>/<key>` on the atServer at host:port, within timeout_ms, without
// following redirects. On PUBLIC_LOOKUP_FOUND, *value is the malloc'd value.
enum public_lookup_result public_lookup_at(const char *scheme, const char *host, uint16_t port, const char *uri,
                                           long timeout_ms, char **value);

// Where the `_apsk` record uri, lower-cased
// `public:_apsk.<enrollmentId>.a.__e@<atSign>`, has been withdrawn to on the
// atServer at host:port: *location is "r.__e" when its enrollment was revoked
// or superseded, "d.__e" when it was deleted or expired, and NULL when
// neither holds it. Returns non-zero when that can't be told.
int public_lookup_withdrawn_to_at(const char *scheme, const char *host, uint16_t port, const char *uri,
                                  long timeout_ms, const char **location);

// Sets where the lookup workers this process starts find atServers
void public_lookup_worker_init(const public_lookup_directory *directory);

// Runs a lookup worker, the process public_lookup_worker_start starts, and
// returns its exit code: a public_lookup_result for "lookup", with the value
// on stdout, or a public_lookup_key_check for "key-check"
int public_lookup_worker_main(int argc, const char **argv);

// Starts a lookup worker in mode ("lookup" or "key-check") for uri, with its
// stdout on *stdout_fd when stdout_fd isn't NULL. Returns its pid, or -1.
pid_t public_lookup_worker_start(const char *mode, const char *uri, int *stdout_fd);

// Looks the public record uri up straight from its atServer, in a worker
// process that is killed if it outlives its deadline. On PUBLIC_LOOKUP_FOUND,
// *value is the malloc'd value.
enum public_lookup_result public_lookup_direct(const char *uri, char **value);

#endif
