// Checking the enrollment key each client signs its session request with:
// verifying it when a request arrives, and ending a session once its
// client's enrollment is withdrawn.

#include "noports/noports_daemon.h"
#include "noports/noports_enrollment_signature.h"
#include "noports/noports_log.h"
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <esp_system.h>

extern "C" {
  #include "atclient/atclient.h"
  #include "atclient/atkey.h"
  #include "atclient/cacerts.h"
  #include "atdirectory.h"
}

static const char *TAG = "noports_keys";

// How long a lookup may take when a request arrives, as the Dart daemon
// allows, and all the lookups of one key check from loop(), which they hold
// up
#define NOPORTS_LOOKUP_TIMEOUT_MS   10000
#define NOPORTS_KEY_CHECK_BUDGET_MS 5000

// A key whose check can't tell is skipped for twice as many rounds each time,
// up to this many, so a slow atServer can hold loop() up only now and then
#define NOPORTS_KEY_CHECK_MAX_SKIP 30

// The most a record's value may be, which no `_apsk` advertisement or public
// key comes near
#define NOPORTS_LOOKUP_MAX_VALUE_BYTES (64 * 1024)

// NOTE: an atServer answers a TLS connection over HTTP only when ALPN selects
// http/1.1
static const char *_alpn_http11[] = {"http/1.1", NULL};

#ifdef CONFIG_MBEDTLS_CERTIFICATE_BUNDLE
extern const uint8_t x509_crt_bundle_start[] asm("_binary_x509_crt_bundle_start");
#if ESP_ARDUINO_VERSION >= ESP_ARDUINO_VERSION_VAL(3, 0, 0)
extern const uint8_t x509_crt_bundle_end[] asm("_binary_x509_crt_bundle_end");
#endif
#else
static const char _lookup_ca_pem[] = LETS_ENCRYPT_ROOT GOOGLE_GLOBAL_SIGN GLOBALSIGN_ROOT_CA GOOGLE_GTS_ROOT_R1
    GOOGLE_GTS_ROOT_R2 GOOGLE_GTS_ROOT_R3 GOOGLE_GTS_ROOT_R4 ZEROSSL_INTERMEDIATE;
#endif

// Trusts what the at_client trusts for atServer connections, since the GET
// goes to the same atServer, on the same port
static void _trust_atservers(WiFiClientSecure &client) {
#ifdef CONFIG_MBEDTLS_CERTIFICATE_BUNDLE
#if ESP_ARDUINO_VERSION >= ESP_ARDUINO_VERSION_VAL(3, 0, 0)
  client.setCACertBundle(x509_crt_bundle_start, x509_crt_bundle_end - x509_crt_bundle_start);
#else
  client.setCACertBundle(x509_crt_bundle_start);
#endif
#else
  client.setCACert(_lookup_ca_pem);
#endif
}

// Appends segment to url percent-encoded as a URI path segment, keeping the
// characters RFC 3986 allows there unencoded, as Dart's Uri does
static void _append_path_segment(String &url, const char *segment, size_t len) {
  static const char keep[] = "-._~!$&'()*+,;=:@";
  char escaped[4];
  for (size_t i = 0; i < len; i++) {
    unsigned char c = (unsigned char)segment[i];
    if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= '0' && c <= '9') || strchr(keep, c)) {
      url += (char)c;
    } else {
      snprintf(escaped, sizeof(escaped), "%%%02X", c);
      url += escaped;
    }
  }
}

// A Stream that keeps what is written to it, refusing past the value cap
class _CappedBody : public Stream {
public:
  String data;
  bool too_big = false;
  size_t write(uint8_t c) override {
    if (data.length() >= NOPORTS_LOOKUP_MAX_VALUE_BYTES || c == 0) {
      too_big = true;
      return 0;
    }
    data += (char)c;
    return 1;
  }
  size_t write(const uint8_t *buf, size_t size) override {
    for (size_t i = 0; i < size; i++) {
      if (write(buf[i]) != 1) return i;
    }
    return size;
  }
  int available() override { return 0; }
  int read() override { return -1; }
  int peek() override { return -1; }
  void flush() override {}
};

// Looks up the public record uri (public:<key>@<atSign>) with a GET of
// /<atSign>/<key> on the atServer at host:port, within timeout_ms, without
// following redirects. On NOPORTS_LOOKUP_FOUND, *value is the malloc'd value.
static noports_lookup_result _lookup_at(const char *host, uint16_t port, const char *uri, uint32_t timeout_ms,
                                        char **value) {
  *value = NULL;
  const char *at = strrchr(uri, '@');
  if (strncmp(uri, "public:", 7) != 0 || at == NULL || at < uri + 7) {
    return NOPORTS_LOOKUP_FAILED;
  }
  if (esp_get_free_heap_size() < NOPORTS_TLS_MIN_FREE_HEAP) {
    NOPORTS_LOGW(TAG, "Not enough free heap to look %s up", uri);
    return NOPORTS_LOOKUP_FAILED;
  }
  String url = "https://";
  url += host;
  url += ':';
  url += port;
  url += '/';
  _append_path_segment(url, at, strlen(at));
  url += '/';
  _append_path_segment(url, uri + 7, (size_t)(at - uri) - 7);

  WiFiClientSecure client;
  _trust_atservers(client);
  client.setAlpnProtocols(_alpn_http11);
  client.setHandshakeTimeout((timeout_ms + 999) / 1000);
  HTTPClient http;
  http.setConnectTimeout((int32_t)(timeout_ms / 2));
  http.setTimeout((uint16_t)timeout_ms);
  http.setFollowRedirects(HTTPC_DISABLE_FOLLOW_REDIRECTS);
  http.setReuse(false);
  if (!http.begin(client, url)) {
    return NOPORTS_LOOKUP_NOT_SERVED;
  }
  int code = http.GET();
  noports_lookup_result result;
  if (code == HTTP_CODE_OK) {
    _CappedBody body;
    int size = http.getSize();
    int written = size > NOPORTS_LOOKUP_MAX_VALUE_BYTES ? -1 : http.writeToStream(&body);
    if (written < 0 || body.too_big) {
      NOPORTS_LOGW(TAG, "%s answered with more than %d bytes, or with something other than text",
                   url.c_str(), NOPORTS_LOOKUP_MAX_VALUE_BYTES);
      result = NOPORTS_LOOKUP_FAILED;
    } else {
      *value = strdup(body.data.c_str());
      result = *value == NULL ? NOPORTS_LOOKUP_FAILED : NOPORTS_LOOKUP_FOUND;
    }
  } else if (code == HTTP_CODE_NOT_FOUND) {
    result = NOPORTS_LOOKUP_NOT_FOUND;
  } else if (code > 0) {
    NOPORTS_LOGW(TAG, "%s answered %d", url.c_str(), code);
    result = NOPORTS_LOOKUP_NOT_SERVED;
  } else if (code == HTTPC_ERROR_READ_TIMEOUT) {
    NOPORTS_LOGW(TAG, "%s did not answer within %lu ms", url.c_str(), (unsigned long)timeout_ms);
    result = NOPORTS_LOOKUP_FAILED;
  } else {
    NOPORTS_LOGW(TAG, "%s did not answer over https: %s", url.c_str(), HTTPClient::errorToString(code).c_str());
    result = NOPORTS_LOOKUP_NOT_SERVED;
  }
  http.end();
  return result;
}

// Where the `_apsk` record uri has been withdrawn to on the atServer at
// host:port: *location is "r.__e" (revoked or superseded), "d.__e" (deleted
// or expired) or NULL (neither holds it). Returns false when that can't be
// told.
static bool _withdrawn_to(const char *host, uint16_t port, const char *uri, uint32_t timeout_ms,
                          const char **location) {
  static const char *const locations[] = {"r.__e", "d.__e"};
  *location = NULL;
  const char *suffix = strstr(uri, ".a.__e@");
  if (strncmp(uri, "public:_apsk.", 13) != 0 || suffix == NULL) {
    return true;
  }
  bool error = false;
  for (int i = 0; i < 2; i++) {
    size_t size = strlen(uri) + 1;
    char *withdrawn = (char *)malloc(size);
    if (withdrawn == NULL) return false;
    snprintf(withdrawn, size, "%.*s.%s%s", (int)(suffix - uri), uri, locations[i], suffix + 6);
    char *value = NULL;
    noports_lookup_result result = _lookup_at(host, port, withdrawn, timeout_ms, &value);
    free(withdrawn);
    free(value);
    if (result == NOPORTS_LOOKUP_FOUND) {
      *location = locations[i];
      return true;
    }
    if (result != NOPORTS_LOOKUP_NOT_FOUND) error = true;
  }
  return !error;
}

bool NoPortsDaemon::_findAtServer(const char *atsign, char *host, size_t host_size, uint16_t *port) {
  if (_via_proxy) {
    snprintf(host, host_size, "%s", _root_host);
    *port = _root_port;
    return true;
  }
  char *found = NULL;
  uint16_t found_port = 0;
  if (atdirectory_lookup_once(_root_host, _root_port, atsign, &found, &found_port) != 0 || found == NULL ||
      found_port == 0) {
    free(found);
    NOPORTS_LOGW(TAG, "The atDirectory has no address for %s", atsign);
    return false;
  }
  snprintf(host, host_size, "%s", found);
  *port = found_port;
  free(found);
  return true;
}

// What the request-time lookup of a client's signing key found, and where
struct _RequestLookup {
  NoPortsDaemon *daemon;
  char host[254];
  uint16_t port;
};

noports_lookup_result NoPortsDaemon::_lookupSigningKey(const char *uri, char **value, void *ctx) {
  _RequestLookup *lookup = (_RequestLookup *)ctx;
  NoPortsDaemon *daemon = lookup->daemon;
  noports_lookup_result result = NOPORTS_LOOKUP_NOT_SERVED;
  if (daemon->_findAtServer(strrchr(uri, '@'), lookup->host, sizeof(lookup->host), &lookup->port)) {
    result = _lookup_at(lookup->host, lookup->port, uri, NOPORTS_LOOKUP_TIMEOUT_MS, value);
  }
  if (result != NOPORTS_LOOKUP_NOT_SERVED) {
    return result;
  }
  lookup->host[0] = '\0';
  NOPORTS_LOGI(TAG, "%s is not served over HTTP, so asking this daemon's own atServer for it", uri);
  const char *name = uri + 7;
  const char *namespace_start = strstr(name, ".a.__e@");
  if (namespace_start == NULL) return NOPORTS_LOOKUP_FAILED;
  char *key_name = strndup(name, (size_t)(namespace_start - name));
  if (key_name == NULL) return NOPORTS_LOOKUP_FAILED;
  atclient_atkey atkey;
  atclient_atkey_init(&atkey);
  int res = atclient_atkey_create_public_key(&atkey, key_name, strrchr(uri, '@'), "a.__e");
  free(key_name);
  if (res == 0) {
    res = atclient_get_public_key((atclient *)daemon->_worker_ctx, &atkey, value, NULL);
  }
  atclient_atkey_free(&atkey);
  if (res != 0) {
    free(*value);
    *value = NULL;
    return NOPORTS_LOOKUP_FAILED;
  }
  return NOPORTS_LOOKUP_FOUND;
}

bool NoPortsDaemon::_checkClientSigningKey(void *env, const char *requesting_atsign, const char *session_id,
                                           ClientSigningKey *key) {
  memset(key, 0, sizeof(*key));
  char message[1024];
  for (int i = 0; i < NOPORTS_MAX_RELAYS; i++) {
    if (_client_keys[i].signing_key != NULL && strcmp(_relays[i].config.session_id, session_id) == 0) {
      snprintf(message, sizeof(message), "A session with id %s is already live", session_id);
      _sendNptError(requesting_atsign, session_id, message);
      return false;
    }
  }
  _RequestLookup lookup;
  lookup.daemon = this;
  lookup.host[0] = '\0';
  lookup.port = 0;
  char why[768];
  char *signing_key = NULL;
  noports_enrollment_signature result = noports_verify_enrollment_signature(
      (cJSON *)env, requesting_atsign, _lookupSigningKey, &lookup, &signing_key, why, sizeof(why));
  switch (result) {
  case NOPORTS_ENROLLMENT_SIGNATURE_VERIFIED:
    key->signing_key = signing_key;
    snprintf(key->atserver_host, sizeof(key->atserver_host), "%s", lookup.host);
    key->atserver_port = lookup.port;
    return true;
  case NOPORTS_ENROLLMENT_SIGNATURE_REFUSED:
    snprintf(message, sizeof(message), "Enrollment signature not verified: %s", why);
    break;
  case NOPORTS_ENROLLMENT_SIGNATURE_UNCHECKED:
    if (!_config.require_enrollment_signature) {
      NOPORTS_LOGW(TAG, "Could not check the enrollment signature on session %s from %s, so it goes ahead"
                   " unwatched, as an unsigned request would: %s", session_id, requesting_atsign, why);
      return true;
    }
    snprintf(message, sizeof(message), "Could not check the enrollment signature: %s", why);
    break;
  case NOPORTS_ENROLLMENT_SIGNATURE_ABSENT:
    if (!_config.require_enrollment_signature) return true;
    snprintf(message, sizeof(message),
             "This daemon requires session requests signed with the client's enrollment key");
    break;
  }
  NOPORTS_LOGW(TAG, "Refusing session %s from %s: %s", session_id, requesting_atsign, message);
  _sendNptError(requesting_atsign, session_id, message);
  return false;
}

void NoPortsDaemon::_forgetClientSigningKey(int slot) {
  free(_client_keys[slot].signing_key);
  memset(&_client_keys[slot], 0, sizeof(_client_keys[slot]));
}

// What a key check found for one key
enum _KeyCheck { KEY_PUBLISHED, KEY_REVOKED, KEY_DELETED, KEY_MISSING, KEY_UNKNOWN };

// What is left of a key check's budget, started at started_ms; 0 when too
// little is left for a lookup to be worth starting
static uint32_t _budget_left(uint32_t started_ms) {
  uint32_t spent = millis() - started_ms;
  return spent + 500 >= NOPORTS_KEY_CHECK_BUDGET_MS ? 0 : NOPORTS_KEY_CHECK_BUDGET_MS - spent;
}

int NoPortsDaemon::_checkKey(ClientSigningKey *key) {
  uint32_t started_ms = millis();
  char *value = NULL;
  noports_lookup_result result = NOPORTS_LOOKUP_NOT_SERVED;
  if (key->atserver_host[0] != '\0') {
    result = _lookup_at(key->atserver_host, key->atserver_port, key->signing_key, _budget_left(started_ms),
                        &value);
  }
  if (result == NOPORTS_LOOKUP_NOT_SERVED &&
      _findAtServer(strrchr(key->signing_key, '@'), key->atserver_host, sizeof(key->atserver_host),
                    &key->atserver_port) &&
      _budget_left(started_ms) > 0) {
    result = _lookup_at(key->atserver_host, key->atserver_port, key->signing_key, _budget_left(started_ms),
                        &value);
  }
  free(value);
  if (result == NOPORTS_LOOKUP_FOUND) return KEY_PUBLISHED;
  if (result != NOPORTS_LOOKUP_NOT_FOUND) return KEY_UNKNOWN;
  // The two lookups of where it went share what is left of the budget
  uint32_t each_ms = _budget_left(started_ms) / 2;
  const char *location = NULL;
  if (each_ms == 0 ||
      !_withdrawn_to(key->atserver_host, key->atserver_port, key->signing_key, each_ms, &location)) {
    return KEY_UNKNOWN;
  }
  if (location == NULL) return KEY_MISSING;
  return strcmp(location, "r.__e") == 0 ? KEY_REVOKED : KEY_DELETED;
}

static uint8_t _next_backoff(uint8_t backoff) {
  if (backoff == 0) return 1;
  return backoff * 2 > NOPORTS_KEY_CHECK_MAX_SKIP ? NOPORTS_KEY_CHECK_MAX_SKIP : backoff * 2;
}

void NoPortsDaemon::_checkClientKeys() {
  if (_config.client_key_check_secs == 0) return;
  // The Dart daemon's ceiling, which also keeps the product inside 32 bits
  uint32_t interval_ms = _config.client_key_check_secs > 86400 ? 86400000UL : _config.client_key_check_secs * 1000UL;
  uint32_t now = millis();
  if (now - _last_key_check_ms >= interval_ms) {
    _last_key_check_ms = now;
    for (int i = 0; i < NOPORTS_MAX_RELAYS; i++) {
      ClientSigningKey *key = &_client_keys[i];
      key->due = key->signing_key != NULL && !key->ending && key->skip_rounds == 0;
      if (key->skip_rounds > 0) key->skip_rounds--;
    }
  }
  // NOTE: one key per pass, since each lookup holds up loop()
  for (int i = 0; i < NOPORTS_MAX_RELAYS; i++) {
    ClientSigningKey *key = &_client_keys[i];
    if (!key->due) continue;
    int found = _checkKey(key);
    for (int j = 0; j < NOPORTS_MAX_RELAYS; j++) {
      ClientSigningKey *other = &_client_keys[j];
      if (other->signing_key == NULL || strcmp(other->signing_key, key->signing_key) != 0) continue;
      other->due = false;
      other->backoff = found == KEY_UNKNOWN ? _next_backoff(other->backoff) : 0;
      other->skip_rounds = other->backoff;
      if ((found == KEY_REVOKED || found == KEY_DELETED) && !other->ending) {
        other->ending = true;
        NOPORTS_LOGW(TAG, "Ending session %s: its client's signing key %s has been withdrawn to %s",
                     _relays[j].config.session_id, other->signing_key, found == KEY_REVOKED ? "r.__e" : "d.__e");
        noports_relay_stop(&_relays[j]);
      }
    }
    if (found == KEY_MISSING) {
      NOPORTS_LOGW(TAG, "Client signing key %s is missing but has not been withdrawn, so the sessions it signed"
                   " carry on", key->signing_key);
    } else if (found == KEY_UNKNOWN) {
      NOPORTS_LOGW(TAG, "Could not re-check client signing key %s, so the sessions it signed carry on",
                   key->signing_key);
    }
    return;
  }
}
