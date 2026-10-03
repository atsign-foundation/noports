/**
 * @file noports_daemon.cpp
 * @brief Main NoPorts daemon implementation for ESP32
 *
 * This is the Arduino/ESP32 adaptation of:
 *   - packages/c/sshnpd/src/main.c     (initialization flow)
 *   - packages/c/sshnpd/src/daemon.c   (main_loop / notification dispatch)
 *   - packages/c/sshnpd/src/handle_ping.c
 *   - packages/c/sshnpd/src/handle_npt_request.c
 *   - packages/c/sshnpd/src/handler_commons.c
 *
 * Key adaptations from the C sshnpd:
 *   - No fork(): relay processes use FreeRTOS tasks (see noports_relay.cpp)
 *   - No pthreads: FreeRTOS tasks
 *   - No POSIX signals: volatile bool flag
 *   - No filesystem for authorized_keys: not applicable to Arduino
 *   - No SSH support: only NPT (network port tunneling)
 *   - No argparse: configuration via NoPortsConfig struct
 *   - No environment variables: all config is explicit
 */

#include "noports/noports_daemon.h"
#include "noports/noports_log.h"
#include <stdarg.h>
#include <sys/time.h>     // gettimeofday() for the policy reqId seed
#include <mbedtls/platform_util.h> // mbedtls_platform_zeroize
#include <esp_system.h>   // esp_restart(), esp_random()
#include <esp_heap_caps.h> // heap_caps_get_largest_free_block()

// === Embedded atSDK includes ===
// These are bundled directly in this library (no external atsdk dependency)
extern "C" {
  #include "atclient/atclient.h"
  #include "atclient/atclient_utils.h"
  #include "atclient/rpc.h"
  #include "atdirectory.h"
  #include "atclient/atkey.h"
  #include "atclient/atkeys.h"
  #include "atclient/monitor.h"
  #include "atclient/notify.h"
  #include "atclient/string_utils.h"
  #include "atclient/json.h"
  #include "atchops/aes.h"
  #include "atchops/iv.h"
  #include "atchops/rsa.h"
  #include "atchops/rsa_key.h"
  #include "atchops/sha.h"
  #include "atchops/base64.h"
  #include "atlogger/atlogger.h"
}

#define TAG "noports"

// Policy-service RPC settings (used in loop(), _startMonitor(), and helpers)
#define NOPORTS_POLICY_DOMAIN_NS   "auth_checks"
// ATCLIENT_RPC_NS_RPCS ("__rpcs") is defined in atclient/rpc.h
// Milliseconds to wait for a policy-service response before aborting and
// releasing the single pending slot.  The timer is reset when the server ACKs
// (see _handlePolicyResponse), so this bounds the wait after the last sign of
// progress.  Kept short so a slow/unreachable policy server — or a bogus
// request that the server never answers — cannot hold the slot for long and
// stall legitimate checks.  Must stay comfortably above the real policy-server
// round-trip time under load.
#define NOPORTS_POLICY_TIMEOUT_MS  10000

// Monotonically increasing counter shared across all policy RPC requests.
// Each ping AND npt check must use a unique reqId so the Dart AtRpc server's
// per-request mutex (keyed on reqId, TTL=30 s) does not block the next check.
static uint32_t s_policy_req_counter = 0;

// Next policy reqId, never 0. The counter is seeded randomly at begin() and
// increments per request; on the 2^32 wrap `++` yields 0, which we skip so a
// reqId can never collide with the "uninitialised id" value on either side.
static uint32_t _next_policy_req_id() {
  uint32_t id = ++s_policy_req_counter;
  if (id == 0) id = ++s_policy_req_counter;
  return id;
}

// Notification key string mapping (from daemon.c)
static const struct {
  const char *str;
  NoPortsNotificationKey key;
} _notification_key_map[] = {
  { "",                  NK_NONE },
  { "sshpublickey",      NK_SSHPUBLICKEY },
  { "ping",              NK_PING },
  { "ssh_request",       NK_SSH_REQUEST },
  { "npt_request",       NK_NPT_REQUEST },
  { "graceful_shutdown", NK_GRACEFUL_SHUTDOWN },
};

// ============================================================================
// Constructor / Destructor
// ============================================================================

NoPortsDaemon::NoPortsDaemon()
  : _state(DAEMON_UNINITIALIZED)
  , _should_run(false)
  , _monitor_ctx(nullptr)
  , _worker_ctx(nullptr)
  , _atkeys(nullptr)
  , _signing_key(nullptr)
  , _pkam_signing_key(nullptr)
  , _monitor_options(nullptr)
  , _worker_options(nullptr)
  , _ping_response(nullptr)
  , _monitor_regex(nullptr)
  , _root_port(0)
  , _via_proxy(false)
  , _relay_count(0)
  , _timeout_counter(0)
  , _reconnect_failures(0)
  , _monitor_fail_streak(0)
  , _worker_keepalive_ms(NOPORTS_WORKER_KEEPALIVE_MS)
  , _worker_last_used_ms(0)
  , _max_relays(2)
  , _atserver_port(0) {
  memset(_last_error, 0, sizeof(_last_error));
  memset(_root_host, 0, sizeof(_root_host));
  memset(_atserver_host, 0, sizeof(_atserver_host));
  // Don't memset _relays — it contains WiFiClient C++ objects whose
  // constructors have already run.  Zero only the POD fields.
  for (int i = 0; i < NOPORTS_MAX_RELAYS; i++) {
    memset(&_relays[i].config, 0, sizeof(NoPortsRelayConfig));
    _relays[i].state = RELAY_IDLE;
    _relays[i].task_handle = NULL;
    _relays[i].should_run = false;
    _relays[i].bytes_in = 0;
    _relays[i].bytes_out = 0;
    _relays[i].start_ms = 0;
    _relays[i].encrypter = NULL;
    _relays[i].decrypter = NULL;
  }
  memset(&_policy_pending, 0, sizeof(_policy_pending));
  memset(_policy_cooldown, 0, sizeof(_policy_cooldown));
}

void NoPortsDaemon::_freeResources() {
  if (_monitor_ctx) {
    atclient_monitor_free((atclient *)_monitor_ctx);
    free(_monitor_ctx);
    _monitor_ctx = nullptr;
  }
  if (_worker_ctx) {
    atclient_free((atclient *)_worker_ctx);
    free(_worker_ctx);
    _worker_ctx = nullptr;
  }
  if (_atkeys) {
    atclient_atkeys_free((atclient_atkeys *)_atkeys);
    free(_atkeys);
    _atkeys = nullptr;
  }
  if (_signing_key) {
    atchops_rsa_key_private_key_free((atchops_rsa_key_private_key *)_signing_key);
    free(_signing_key);
    _signing_key = nullptr;
  }
  if (_pkam_signing_key) {
    atchops_rsa_key_private_key_free((atchops_rsa_key_private_key *)_pkam_signing_key);
    free(_pkam_signing_key);
    _pkam_signing_key = nullptr;
  }
  if (_monitor_options) {
    atclient_authenticate_options_free((atclient_authenticate_options *)_monitor_options);
    free(_monitor_options);
    _monitor_options = nullptr;
  }
  if (_worker_options) {
    atclient_authenticate_options_free((atclient_authenticate_options *)_worker_options);
    free(_worker_options);
    _worker_options = nullptr;
  }
  if (_ping_response) {
    free(_ping_response);
    _ping_response = nullptr;
  }
  if (_monitor_regex) {
    free(_monitor_regex);
    _monitor_regex = nullptr;
  }
  // enrollment_id is strdup'd in begin() — free our copy
  if (_config.enrollment_id) {
    free((void *)_config.enrollment_id);
    _config.enrollment_id = nullptr;
  }
}

NoPortsDaemon::~NoPortsDaemon() {
  stop();
  _freeResources();
}

// atchops_rsa_sign writes modulus-size bytes into the caller's buffer, and
// every sign site in the daemon and relay uses a fixed 256-byte buffer - so a
// signing key with a larger modulus (e.g. RSA-4096 atKeys) would smash the
// stack/heap at first use. Checking once here, right after the keys are
// cloned, covers all of them. The DER INTEGER encoding pads the modulus with
// a leading 0x00 whenever its MSB is set (always, for a real modulus), so a
// valid RSA-2048 key normally arrives with n.len == 257 - compare significant
// bytes, not raw length.
static bool _is_rsa2048_private_key(const atchops_rsa_key_private_key *key) {
  const unsigned char *n_bytes = key->n.value;
  size_t n_sig = key->n.len;
  while (n_sig > 0 && n_bytes[0] == 0x00) { n_bytes++; n_sig--; }
  return n_sig == 256;
}

// Wipe a NUL-terminated key/IV string before freeing it: on a single-address-
// space MCU freed heap holding live session keys can surface in later
// allocations or crash dumps. mbedtls_platform_zeroize is never optimized away.
static void _zero_free_key(void *p) {
  if (p) {
    mbedtls_platform_zeroize(p, strlen((char *)p));
    free(p);
  }
}

// ============================================================================
// Public API
// ============================================================================

bool NoPortsDaemon::begin(const NoPortsConfig &config) {
  // Free any resources from a previous begin() call to avoid memory leaks
  // when restarting the daemon (e.g. after settings change).
  _freeResources();

  _state = DAEMON_INITIALIZING;
  memcpy(&_config, &config, sizeof(NoPortsConfig));

  // Seed the policy-RPC reqId counter so a restart never reuses reqIds the Dart
  // AtRpc server still holds in its 30 s dedup window (a plain reset to 0 makes
  // the first requests 1,2,3… again — the normal flash-and-retest cycle — which
  // the policy server drops as duplicates, timing out the first several checks).
  //
  // Prefer the wall clock, like the C sshnpd (which uses gettimeofday micros):
  // the base then always advances across reboots. at_c's reqId is uint32_t so we
  // can't carry full epoch-micros; the low 32 bits advance ~1 MHz and wrap only
  // every ~71 min, far longer than the 30 s window, so a reboot always lands
  // clear of the previous run's recent reqIds. Fall back to the hardware RNG if
  // the clock is not NTP-synced yet (e.g. no network at startup).
  {
    struct timeval tv;
    if (gettimeofday(&tv, nullptr) == 0 &&
        (unsigned long)tv.tv_sec > 1735689600UL /* 2025-01-01: clock is set */) {
      uint64_t epoch_us = (uint64_t)tv.tv_sec * 1000000ULL + (uint64_t)tv.tv_usec;
      s_policy_req_counter = (uint32_t)epoch_us;
    } else {
      s_policy_req_counter = esp_random();
    }
  }

  // enrollment_id is a heap string freed by noports_keys_free() after begin() returns.
  // Deep-copy it so the daemon owns a persistent copy for the lifetime of the session.
  if (_config.enrollment_id)
    _config.enrollment_id = strdup(_config.enrollment_id);

  // ---- Validate config ----
  if (!_config.atsign || strlen(_config.atsign) == 0) {
    _setError("atSign is required");
    _state = DAEMON_ERROR;
    return false;
  }
  if (!_config.device_name || strlen(_config.device_name) == 0) {
    _setError("device_name is required");
    _state = DAEMON_ERROR;
    return false;
  }
  if (_config.manager_count == 0 &&
      (!_config.policy_atsign || _config.policy_atsign[0] == '\0')) {
    _setError("At least one manager atSign is required (or set a policy atSign)");
    _state = DAEMON_ERROR;
    return false;
  }
  if (!_config.pkam_private_key_base64 ||
      !_config.encrypt_private_key_base64 ||
      !_config.encrypt_public_key_base64) {
    _setError("atKeys (PKAM and encryption keys) are required");
    _state = DAEMON_ERROR;
    return false;
  }

  // ---- Setup logging ----
  if (_config.verbose) {
    NOPORTS_LOGI(TAG, "Verbose mode enabled");
  }

  // ---- Setup root host/port ----
  // Spec follows the Dart AtRootDomain / at_lookup convention:
  //   host             -> ask the atDirectory at host:64
  //   host:port        -> ask the atDirectory at host:port
  //   proxy:host       -> no atDirectory: the atServer address is host:64
  //   proxy:host:port  -> no atDirectory: the atServer address is host:port
  // The 'proxy:' forms support 443-only networks via a protocol-aware
  // reverse proxy, e.g. "proxy:proxy0001.atsign.org:443".
  _via_proxy = false;
  if (_config.root_domain) {
    const char *spec = _config.root_domain;
    if (strncmp(spec, "proxy:", 6) == 0) {
      _via_proxy = true;
      spec += 6;
      if (spec[0] == '\0') {
        _setError("No host given after 'proxy:' in root domain spec");
        _state = DAEMON_ERROR;
        return false;
      }
    }
    // Parse host:port if colon present
    const char *colon = strchr(spec, ':');
    if (colon) {
      size_t host_len = colon - spec;
      if (host_len == 0 || host_len >= sizeof(_root_host)) {
        _setError("Invalid host in root domain spec");
        _state = DAEMON_ERROR;
        return false;
      }
      snprintf(_root_host, sizeof(_root_host), "%.*s", (int)host_len, spec);
      // atoi silently wraps out-of-range ports (70000 -> 4464) and accepts
      // trailing garbage (443x) — reject malformed specs instead
      char *port_end = nullptr;
      long port_val = strtol(colon + 1, &port_end, 10);
      if (port_end == colon + 1 || *port_end != '\0' || port_val < 1 || port_val > UINT16_MAX) {
        _setError("Invalid port in root domain spec");
        _state = DAEMON_ERROR;
        return false;
      }
      _root_port = (uint16_t)port_val;
    } else {
      snprintf(_root_host, sizeof(_root_host), "%s", spec);
      _root_port = NOPORTS_DEFAULT_ROOT_PORT;
    }
  } else {
    snprintf(_root_host, sizeof(_root_host), "%s", NOPORTS_DEFAULT_ROOT_HOST);
    _root_port = NOPORTS_DEFAULT_ROOT_PORT;
  }

  if (_config.root_port != 0) {
    _root_port = _config.root_port;
  }

  NOPORTS_LOGI(TAG, "Root server: %s%s:%d", _via_proxy ? "proxy:" : "",
               _root_host, _root_port);

  // ---- Resolve atServer address (once, cached for all reconnects) ----
  // We do a single root-directory TLS lookup here and cache the result.
  // All subsequent pkam_authenticate calls (monitor, worker, reconnects)
  // use set_atserver_host/port directly — no further root TLS connections
  // are needed, saving a transient PCB and ~36 KB of TLS handshake heap
  // on every reconnect.
  if (_via_proxy) {
    // No atDirectory: every atServer connection goes to the reverse proxy
    snprintf(_atserver_host, sizeof(_atserver_host), "%s", _root_host);
    _atserver_port = _root_port;
    NOPORTS_LOGI(TAG, "atServer via reverse proxy %s:%d (no atDirectory lookup)",
                 _atserver_host, _atserver_port);
  } else {
    char *resolved_host = nullptr;
    uint16_t resolved_port = 0;
    int lookup_res = atdirectory_lookup_once(_root_host, _root_port,
                                             _config.atsign,
                                             &resolved_host, &resolved_port);
    if (lookup_res == 0 && resolved_host && resolved_port > 0) {
      snprintf(_atserver_host, sizeof(_atserver_host), "%s", resolved_host);
      _atserver_port = resolved_port;
      free(resolved_host);
      NOPORTS_LOGI(TAG, "atServer resolved: %s:%d (cached for reconnects)",
                   _atserver_host, _atserver_port);
    } else {
      // Lookup failed — leave _atserver_host empty; auth will fall back to
      // setting atdirectory_host/port and do the lookup itself.
      if (resolved_host) free(resolved_host);
      NOPORTS_LOGW(TAG, "atServer lookup failed (%d) — auth will retry via root",
                   lookup_res);
    }
  }

  // ---- Load atKeys ----
  _atkeys = calloc(1, sizeof(atclient_atkeys));
  if (!_atkeys) {
    _setError("Failed to allocate atkeys");
    _state = DAEMON_ERROR;
    return false;
  }
  atclient_atkeys_init((atclient_atkeys *)_atkeys);

  atclient_atkeys *keys = (atclient_atkeys *)_atkeys;

  // Populate keys from the base64 strings
  int res = 0;

  if (_config.pkam_public_key_base64) {
    res = atchops_rsa_key_populate_public_key(&keys->pkam_public_key,
                                              _config.pkam_public_key_base64,
                                              strlen(_config.pkam_public_key_base64));
    if (res != 0) {
      _setError("Failed to populate PKAM public key: %d", res);
      _state = DAEMON_ERROR;
      return false;
    }
  }

  res = atchops_rsa_key_populate_private_key(&keys->pkam_private_key,
                                             _config.pkam_private_key_base64,
                                             strlen(_config.pkam_private_key_base64));
  if (res != 0) {
    _setError("Failed to populate PKAM private key: %d", res);
    _state = DAEMON_ERROR;
    return false;
  }

  if (_config.encrypt_public_key_base64) {
    res = atchops_rsa_key_populate_public_key(&keys->encrypt_public_key,
                                              _config.encrypt_public_key_base64,
                                              strlen(_config.encrypt_public_key_base64));
    if (res != 0) {
      _setError("Failed to populate encrypt public key: %d", res);
      _state = DAEMON_ERROR;
      return false;
    }
  }

  res = atchops_rsa_key_populate_private_key(&keys->encrypt_private_key,
                                             _config.encrypt_private_key_base64,
                                             strlen(_config.encrypt_private_key_base64));
  if (res != 0) {
    _setError("Failed to populate encrypt private key: %d", res);
    _state = DAEMON_ERROR;
    return false;
  }

  if (_config.self_encryption_key_base64) {
    res = atclient_atkeys_set_self_encryption_key_base64(keys,
                                  _config.self_encryption_key_base64,
                                  strlen(_config.self_encryption_key_base64));
    if (res != 0) {
      NOPORTS_LOGW(TAG, "Failed to set self encryption key: %d (non-fatal)", res);
    }
  }

  // Set enrollment ID (required for APKAM-enrolled keys)
  if (_config.enrollment_id) {
    res = atclient_atkeys_set_enrollment_id(keys,
                                  _config.enrollment_id,
                                  strlen(_config.enrollment_id));
    if (res != 0) {
      NOPORTS_LOGW(TAG, "Failed to set enrollment_id: %d (non-fatal)", res);
    } else {
      NOPORTS_LOGI(TAG, "Enrollment ID set: %s", _config.enrollment_id);
    }
  }

  // ---- Create signing key copy (from encrypt private key, same as C sshnpd) ----
  _signing_key = calloc(1, sizeof(atchops_rsa_key_private_key));
  if (!_signing_key) {
    _setError("Failed to allocate signing key");
    _state = DAEMON_ERROR;
    return false;
  }
  atchops_rsa_key_private_key_init((atchops_rsa_key_private_key *)_signing_key);
  res = atchops_rsa_key_private_key_clone(&keys->encrypt_private_key,
                                          (atchops_rsa_key_private_key *)_signing_key);
  if (res != 0) {
    _setError("Failed to clone signing key: %d", res);
    _state = DAEMON_ERROR;
    return false;
  }
  if (!_is_rsa2048_private_key((atchops_rsa_key_private_key *)_signing_key)) {
    _setError("Encrypt private key is not RSA-2048; refusing to sign with it");
    _state = DAEMON_ERROR;
    return false;
  }

  // ---- Create APKAM signing key copy (from pkam private key, for ESCR auth) ----
  _pkam_signing_key = calloc(1, sizeof(atchops_rsa_key_private_key));
  if (!_pkam_signing_key) {
    _setError("Failed to allocate PKAM signing key");
    _state = DAEMON_ERROR;
    return false;
  }
  atchops_rsa_key_private_key_init((atchops_rsa_key_private_key *)_pkam_signing_key);
  res = atchops_rsa_key_private_key_clone(&keys->pkam_private_key,
                                          (atchops_rsa_key_private_key *)_pkam_signing_key);
  if (res != 0) {
    _setError("Failed to clone PKAM signing key: %d", res);
    _state = DAEMON_ERROR;
    return false;
  }
  if (!_is_rsa2048_private_key((atchops_rsa_key_private_key *)_pkam_signing_key)) {
    _setError("PKAM private key is not RSA-2048; refusing to sign with it");
    _state = DAEMON_ERROR;
    return false;
  }
  NOPORTS_LOGI(TAG, "PKAM signing key ready for ESCR auth");

  // ---- Authenticate ----
  _state = DAEMON_AUTHENTICATING;
  if (!_authenticate()) {
    _state = DAEMON_ERROR;
    return false;
  }

  // ---- Build ping response ----
  _buildPingResponse();

  // ---- Publish ESCR public signing key ----
  // The Dart sshnpd calls ApkamSigning.publishPublicSigningKey() at startup.
  // Without this, the SRVD cannot look up our public key to verify ESCR signatures.
  _publishPublicSigningKey();

  // ---- Publish device info ----
  if (!_config.hide) {
    _publishDeviceInfo();
  }

  // ---- Start monitor ----
  if (!_startMonitor()) {
    _state = DAEMON_ERROR;
    return false;
  }

  _should_run = true;
  _state = DAEMON_MONITORING;
  _worker_last_used_ms = millis();  // start keepalive timer from now
  NOPORTS_LOGI(TAG, "NoPorts daemon started for %s (device: %s)",
               _config.atsign, _config.device_name);

  return true;
}

void NoPortsDaemon::loop() {
  if (_state != DAEMON_MONITORING || !_should_run) return;

  // Clean up finished relays
  _cleanupFinishedRelays();

  // Policy RPC timeout: if we sent an auth-check request and got no response
  // within the timeout window, clean up the pending slot so the next request
  // is not blocked indefinitely.
  if (_policy_pending.in_use &&
      (millis() - _policy_pending.sent_at_ms) > NOPORTS_POLICY_TIMEOUT_MS) {
    NOPORTS_LOGW(TAG, "Policy RPC: timeout waiting for response "
                      "(reqId=%lu, pending=%s) — clearing",
                 (unsigned long)_policy_pending.req_id,
                 _policy_pending.requesting_atsign);
    if (_policy_pending.type == NOPORTS_POLICY_NPT && _policy_pending.envelope) {
      cJSON *env_j  = (cJSON *)_policy_pending.envelope;
      cJSON *env_pl = cJSON_GetObjectItem(env_j, "payload");
      const char *sid = env_pl
          ? cJSON_GetStringValue(cJSON_GetObjectItem(env_pl, "sessionId"))
          : nullptr;
      _sendNptError(_policy_pending.requesting_atsign, sid,
                    "Policy server did not respond in time");
    }
    _cleanupPolicyPending();
  }

  // Worker TLS keep-alive: send a heartbeat if the worker connection has
  // been idle for longer than the configured interval.  This prevents NAT/
  // firewall tables from expiring the session between tunnel requests.
  atclient *worker = (atclient *)_worker_ctx;
  if (_worker_keepalive_ms > 0 &&
      (millis() - _worker_last_used_ms) >= _worker_keepalive_ms) {
    int hb = atclient_send_heartbeat(worker);
    if (hb != 0) {
      NOPORTS_LOGW(TAG, "Worker heartbeat failed (%d) — reconnecting worker", hb);
      _reconnectWorker();
    } else {
      NOPORTS_LOGD(TAG, "Worker heartbeat OK (ka=%lums)", _worker_keepalive_ms);
    }
    _worker_last_used_ms = millis();
  }

  // Read next monitor message
  atclient_monitor_message message;
  atclient_monitor_message_init(&message);

  atclient *monitor = (atclient *)_monitor_ctx;
  // (worker declared above for keepalive check)

  // Check if we need to reconnect
  if (_timeout_counter * NOPORTS_MONITOR_READ_TIMEOUT_MS > NOPORTS_MONITOR_NOOP_TIMEOUT_MS) {
    if (!_reconnectMonitor()) {
      _timeout_counter = NOPORTS_MONITOR_NOOP_TIMEOUT_MS / NOPORTS_MONITOR_READ_TIMEOUT_MS + 1;
      atclient_monitor_message_free(&message);
      return;
    }
    _timeout_counter = 0;
  }

  int ret = atclient_monitor_read(monitor, worker, &message, NULL);
  if (ret != 0) {
    // atclient_monitor_read sets message.type even on error — dispatch on it
    // so we don't needlessly kill a healthy worker TLS connection.
    if (message.type == ATCLIENT_MONITOR_ERROR_PARSE_NOTIFICATION ||
        message.type == 0) {
      // Malformed/partial server message (e.g. statsNotification without trailing \n)
      // or SDK parse error returning type=0.  The worker is uninvolved —
      // don't touch it.  Treating type=0 here prevents _reconnectWorker()
      // from being called, which blocked the daemon for up to 30s and caused
      // new SSH sessions to miss their connect: notifications.
      NOPORTS_LOGD(TAG, "Monitor: ignoring unparseable server message (type=%d)", message.type);
      _timeout_counter++;   // count the same as an empty/noop
      atclient_monitor_message_free(&message);
      return;
    }

    if (message.type == ATCLIENT_MONITOR_ERROR_DECRYPT_NOTIFICATION) {
      // Decrypt failed — the worker's shared-key cache may be stale.
      // Reconnect the worker (which refreshes the key cache) but leave the
      // monitor stream intact.
      NOPORTS_LOGW(TAG, "Monitor: decrypt failed, reconnecting worker");
      _reconnectWorker();
      // If a policy RPC is in-flight, the response notification was just
      // dropped.  Now that the worker has refreshed its key cache the next
      // exchange WILL decrypt, so re-send the request immediately.
      if (_policy_pending.in_use) {
        NOPORTS_LOGI(TAG, "Policy RPC: re-sending request after decrypt failure "
                         "(reqId=%lu, key cache refreshed)",
                    (unsigned long)_policy_pending.req_id);
        _policy_pending.sent_at_ms = millis();
        _sendPolicyRpcRequest(_policy_pending.requesting_atsign);
      }
      atclient_monitor_message_free(&message);
      return;
    }

    // ATCLIENT_MONITOR_ERROR_READ (or unknown): could be either:
    //   (a) OOM: atclient_tls_socket_read couldn't malloc its receive buffer
    //       because relay traffic exhausted the heap.  The TLS socket is fine.
    //       Reconnecting the worker would waste ~30 s and achieve nothing.
    //   (b) genuine TLS/network failure.  Worker reconnect is correct.
    //
    // Distinguish them by current heap: if total free is below the TLS
    // threshold, the malloc failure is the likely cause — wait briefly and
    // retry without touching the worker.  Only do the worker-reconnect dance
    // when heap is adequate (implies a true connection drop).
    if (esp_get_free_heap_size() < NOPORTS_TLS_MIN_FREE_HEAP) {
      // Heap is depleted by relay traffic — the TLS socket is fine, the SDK's
      // malloc for its read buffer just failed.  Log at DEBUG (not WARN) since
      // this is expected under load and not actionable.  Delay 500 ms so we
      // don't tight-loop and re-enter atclient_tls_socket_read hundreds of
      // times per second (which also spams "atsdk_socket | Failed to allocate
      // read buffer" from inside the SDK before we even get back here).
      NOPORTS_LOGD(TAG, "Monitor read OOM (heap=%u, relay_pcbs=%d) — backing off",
                   (unsigned)esp_get_free_heap_size(), noports_relay_get_pcb_count());
      atclient_monitor_message_free(&message);
      delay(500);
      return;
    }

    // Heap is adequate — this is a genuine read/TLS failure.
    _monitor_fail_streak++;
    NOPORTS_LOGW(TAG, "Monitor read error (ret: %d, type: %d, streak: %u, heap: %u)",
                 ret, (int)message.type, (unsigned)_monitor_fail_streak,
                 (unsigned)esp_get_free_heap_size());
    if (_reconnectWorker()) {
      if (_monitor_fail_streak >= 3) {
        // Worker keeps reconnecting fine but monitor keeps failing —
        // the monitor socket is dead (e.g. WiFi BEACON_TIMEOUT).
        NOPORTS_LOGW(TAG, "Monitor fail streak %u — forcing full monitor reconnect",
                     (unsigned)_monitor_fail_streak);
        _timeout_counter = NOPORTS_MONITOR_NOOP_TIMEOUT_MS / NOPORTS_MONITOR_READ_TIMEOUT_MS + 1;
        _monitor_fail_streak = 0;
      } else {
        NOPORTS_LOGI(TAG, "Worker reconnected, will retry monitor read");
      }
    } else {
      NOPORTS_LOGW(TAG, "Worker reconnect also failed (TLS failures: %d/%d), will reconnect monitor",
                   _reconnect_failures, NOPORTS_MAX_RECONNECT_FAILURES);
      _timeout_counter = NOPORTS_MONITOR_NOOP_TIMEOUT_MS / NOPORTS_MONITOR_READ_TIMEOUT_MS + 1;
    }
    atclient_monitor_message_free(&message);
    return;
  }

  // Monitor read succeeded — clear the fail streak
  _monitor_fail_streak = 0;

  switch (message.type) {
    case ATCLIENT_MONITOR_MESSAGE_TYPE_EMPTY:
      _timeout_counter++;
      break;

    case ATCLIENT_MONITOR_ERROR_READ:
      _timeout_counter = NOPORTS_MONITOR_NOOP_TIMEOUT_MS / NOPORTS_MONITOR_READ_TIMEOUT_MS + 1;
      break;

    case ATCLIENT_MONITOR_MESSAGE_TYPE_NOTIFICATION: {
      _timeout_counter = 0;
      _handleNotification(&message);
      break;
    }

    case ATCLIENT_MONITOR_MESSAGE_TYPE_DATA_RESPONSE:
      _timeout_counter = 0;
      NOPORTS_LOGD(TAG, "Data response: %s", message.data_response);
      break;

    case ATCLIENT_MONITOR_MESSAGE_TYPE_ERROR_RESPONSE:
      _timeout_counter = 0;
      NOPORTS_LOGE(TAG, "Error response: %s", message.error_response);
      break;

    case ATCLIENT_MONITOR_ERROR_PARSE_NOTIFICATION:
      _timeout_counter = NOPORTS_MONITOR_NOOP_TIMEOUT_MS / NOPORTS_MONITOR_READ_TIMEOUT_MS + 1;
      NOPORTS_LOGE(TAG, "Failed to parse notification");
      break;

    case ATCLIENT_MONITOR_ERROR_DECRYPT_NOTIFICATION:
      NOPORTS_LOGE(TAG, "Failed to decrypt notification, reconnecting worker");
      _reconnectWorker();
      // Don't force monitor reconnect — the monitor stream is fine,
      // only the worker (used for key lookup) was stale.
      // Same recovery as above: re-send a pending policy request.
      if (_policy_pending.in_use) {
        NOPORTS_LOGI(TAG, "Policy RPC: re-sending request after decrypt failure "
                         "(reqId=%lu, key cache refreshed)",
                    (unsigned long)_policy_pending.req_id);
        _policy_pending.sent_at_ms = millis();
        _sendPolicyRpcRequest(_policy_pending.requesting_atsign);
      }
      break;

    default:
      break;
  }

  atclient_monitor_message_free(&message);
}

void NoPortsDaemon::stop() {
  _should_run = false;

  // Stop all active relays
  for (int i = 0; i < NOPORTS_MAX_RELAYS; i++) {
    if (noports_relay_is_running(&_relays[i])) {
      noports_relay_stop(&_relays[i]);
    }
  }

  _state = DAEMON_STOPPED;
  NOPORTS_LOGI(TAG, "NoPorts daemon stopped");
}

bool NoPortsDaemon::isRunning() const {
  return _state == DAEMON_MONITORING && _should_run;
}

NoPortsDaemonState NoPortsDaemon::getState() const {
  return _state;
}

uint8_t NoPortsDaemon::getActiveRelayCount() const {
  uint8_t count = 0;
  for (int i = 0; i < NOPORTS_MAX_RELAYS; i++) {
    if (noports_relay_is_running(&_relays[i])) {
      if (_relays[i].config.multi) {
        // Multi relay: count only active data sub-connections
        count += _relays[i].active_sessions;
      } else {
        count++;  // single-mode relay
      }
    }
  }
  return count;
}

const char* NoPortsDaemon::getLastError() const {
  return _last_error;
}

uint8_t NoPortsDaemon::getReconnectFailures() const {
  return _reconnect_failures;
}

int NoPortsDaemon::getRelayPcbCount() const {
  return noports_relay_get_pcb_count();
}

int NoPortsDaemon::getRelayPcbMax() const {
  return noports_relay_get_pcb_max();
}

uint8_t NoPortsDaemon::getRelayCpuPct() const {
  return noports_relay_get_cpu_pct();
}

void NoPortsDaemon::setWorkerKeepaliveMs(uint32_t ms) {
  _worker_keepalive_ms = ms;
  // Reset last-used so the new interval starts from now.
  _worker_last_used_ms = millis();
  NOPORTS_LOGI(TAG, "Worker keep-alive set to %lu ms", (unsigned long)ms);
}

void NoPortsDaemon::getThroughput(uint32_t &bytes_in, uint32_t &bytes_out) const {
  bytes_in = 0;
  bytes_out = 0;
  for (int i = 0; i < NOPORTS_MAX_RELAYS; i++) {
    bytes_in  += _relays[i].bytes_in;
    bytes_out += _relays[i].bytes_out;
  }
}

// ============================================================================
// Private: Authentication
// ============================================================================

bool NoPortsDaemon::_authenticate() {
  atclient_atkeys *keys = (atclient_atkeys *)_atkeys;
  int res;

  // ---- Monitor client ----
  _monitor_ctx = calloc(1, sizeof(atclient));
  if (!_monitor_ctx) {
    _setError("Failed to allocate monitor client");
    return false;
  }
  atclient_monitor_init((atclient *)_monitor_ctx);

  _monitor_options = calloc(1, sizeof(atclient_authenticate_options));
  if (!_monitor_options) {
    _setError("Failed to allocate monitor options");
    return false;
  }
  atclient_authenticate_options_init((atclient_authenticate_options *)_monitor_options);
  if (_atserver_host[0] != '\0') {
    // Use cached atServer address — no root directory TLS connection needed.
    atclient_authenticate_options_set_atserver_host(
      (atclient_authenticate_options *)_monitor_options, _atserver_host);
    atclient_authenticate_options_set_atserver_port(
      (atclient_authenticate_options *)_monitor_options, _atserver_port);
  } else {
    atclient_authenticate_options_set_atdirectory_host(
      (atclient_authenticate_options *)_monitor_options, _root_host);
    atclient_authenticate_options_set_atdirectory_port(
      (atclient_authenticate_options *)_monitor_options, _root_port);
  }

  NOPORTS_LOGI(TAG, "Authenticating monitor client for %s...", _config.atsign);
  res = atclient_monitor_pkam_authenticate(
    (atclient *)_monitor_ctx, _config.atsign, keys,
    (atclient_authenticate_options *)_monitor_options);

  if (res != 0) {
    _setError("Monitor PKAM auth failed: %d", res);
    return false;
  }
  NOPORTS_LOGI(TAG, "Monitor client authenticated");

  // Set the monitor read timeout AFTER authentication, because
  // atclient_tls_socket_configure (called during pkam_authenticate) 
  // resets the mbedTLS read timeout to ATCLIENT_CLIENT_READ_TIMEOUT_MS (3s).
  atclient_monitor_set_read_timeout((atclient *)_monitor_ctx, NOPORTS_MONITOR_READ_TIMEOUT_MS);

  // ---- Worker client ----
  _worker_ctx = calloc(1, sizeof(atclient));
  if (!_worker_ctx) {
    _setError("Failed to allocate worker client");
    return false;
  }
  atclient_init((atclient *)_worker_ctx);

  _worker_options = calloc(1, sizeof(atclient_authenticate_options));
  if (!_worker_options) {
    _setError("Failed to allocate worker options");
    return false;
  }
  atclient_authenticate_options_init((atclient_authenticate_options *)_worker_options);
  if (_atserver_host[0] != '\0') {
    atclient_authenticate_options_set_atserver_host(
      (atclient_authenticate_options *)_worker_options, _atserver_host);
    atclient_authenticate_options_set_atserver_port(
      (atclient_authenticate_options *)_worker_options, _atserver_port);
  } else {
    atclient_authenticate_options_set_atdirectory_host(
      (atclient_authenticate_options *)_worker_options, _root_host);
    atclient_authenticate_options_set_atdirectory_port(
      (atclient_authenticate_options *)_worker_options, _root_port);
  }

  NOPORTS_LOGI(TAG, "Authenticating worker client for %s...", _config.atsign);
  res = atclient_pkam_authenticate(
    (atclient *)_worker_ctx, _config.atsign, keys,
    (atclient_authenticate_options *)_worker_options, NULL);

  if (res != 0) {
    _setError("Worker PKAM auth failed: %d", res);
    return false;
  }
  NOPORTS_LOGI(TAG, "Worker client authenticated");

  return true;
}

// ============================================================================
// Private: Monitor setup
// ============================================================================

bool NoPortsDaemon::_startMonitor() {
  // Build monitor regex.
  //
  // The atProtocol monitor command does a substring match against notification
  // keys — it does NOT interpret '|' as regex alternation.
  //
  //   Manager-only mode:
  //     Inbound NoPorts requests:  "@device:npt_request.<id>.device.sshnp@client"
  //     → anchor: ".sshnp@"
  //
  //   Policy mode:
  //     Same inbound NoPorts requests plus policy-service RPC responses.
  //     The Dart AtRpc server sets namespaceAware=false on response keys, so
  //     the response key received has NO namespace suffix:
  //       "@device:success.<id>.auth_checks.__rpcs@policy"
  //     This does NOT contain ".sshnp@".
  //
  //     Solution: in policy mode send "monitor\r\n" (no filter) by using an
  //     empty regex string.  atclient_monitor_start("") → "monitor\r\n"
  //     which delivers ALL notifications addressed to this atsign.  Since
  //     the device is a dedicated IoT node the traffic is minimal, so the
  //     broader filter is safe.
  //
  const bool policy_mode = (_config.policy_atsign && _config.policy_atsign[0] != '\0');
  const char *regex = policy_mode ? "" : "." NOPORTS_NS "@";
  _monitor_regex = (char *)malloc(strlen(regex) + 1);
  if (!_monitor_regex) {
    _setError("Failed to allocate monitor regex");
    return false;
  }
  strcpy(_monitor_regex, regex);

  NOPORTS_LOGI(TAG, "Starting monitor with regex: '%s' (%s)",
               _monitor_regex,
               policy_mode ? "policy mode — no filter" : "manager mode");

  int res = atclient_monitor_start((atclient *)_monitor_ctx, _monitor_regex);
  if (res != 0) {
    _setError("Failed to start monitor: %d", res);
    return false;
  }

  NOPORTS_LOGI(TAG, "Monitor started successfully");
  return true;
}

// ============================================================================
// Private: Device info / Ping response
// ============================================================================

void NoPortsDaemon::_buildPingResponse() {
  cJSON *ping_json = cJSON_CreateObject();
  cJSON_AddStringToObject(ping_json, "devicename", _config.device_name);
  cJSON_AddStringToObject(ping_json, "version", NOPORTS_VERSION);
  cJSON_AddStringToObject(ping_json, "corePackageVersion", NOPORTS_CORE_PKG_VERSION);

  cJSON *features = cJSON_CreateObject();
  cJSON_AddBoolToObject(features, "srAuth", true);
  cJSON_AddBoolToObject(features, "srE2ee", true);
  cJSON_AddBoolToObject(features, "acceptsPublicKeys", false); // no SSH keys on Arduino
  cJSON_AddBoolToObject(features, "supportsPortChoice", true);
  cJSON_AddBoolToObject(features, "adjustableTimeout", true);
  cJSON_AddBoolToObject(features, "controlChannelHeartbeats", true);
  cJSON_AddBoolToObject(features, "supportsRamEscr", _pkam_signing_key != nullptr && _config.enrollment_id != nullptr);
  cJSON_AddBoolToObject(features, "twinKeys", true);
  cJSON_AddItemToObject(ping_json, "supportedFeatures", features);

  // Allowed services from permitopen config
  cJSON *allowed = cJSON_CreateArray();
  for (uint8_t i = 0; i < _config.permitopen_count; i++) {
    char buf[128];
    snprintf(buf, sizeof(buf), "%s:%u",
             _config.permitopen[i].host,
             (unsigned int)_config.permitopen[i].port);
    cJSON_AddItemToArray(allowed, cJSON_CreateString(buf));
  }
  cJSON_AddItemToObject(ping_json, "allowedServices", allowed);

  // ESCR: publish signing key URI so npt client can pre-fetch the public key.
  // Without this, the SRVD cannot look up our public key to verify the signature.
  if (_config.enrollment_id && _pkam_signing_key) {
    char pk_uri[320];
    snprintf(pk_uri, sizeof(pk_uri), "public:_apsk.%s.a.__e%s",
             _config.enrollment_id, _config.atsign);
    cJSON_AddStringToObject(ping_json, "publicSigningKeyUri", pk_uri);
  }

  _ping_response = cJSON_PrintUnformatted(ping_json);
  cJSON_Delete(ping_json);

  NOPORTS_LOGD(TAG, "Ping response: %s", _ping_response ? _ping_response : "NULL");
}

void NoPortsDaemon::_publishPublicSigningKey() {
  if (!_config.enrollment_id || !_config.pkam_public_key_base64) {
    NOPORTS_LOGD(TAG, "ESCR: no enrollment_id or pkam_public_key_base64 — skipping key publish");
    return;
  }

  // Build atkey: public:_apsk.{enrollmentId}.a.__e@{atSign}
  // keyname = "_apsk.{enrollmentId}", namespace = "a.__e"
  // (a.__e == EnrollmentConstants.perEnrollmentApproved in Dart at_commons)
  char keyname[256];
  snprintf(keyname, sizeof(keyname), "_apsk.%s", _config.enrollment_id);

  atclient_atkey sk_key;
  atclient_atkey_init(&sk_key);

  int res = atclient_atkey_create_public_key(&sk_key, keyname, _config.atsign, "a.__e");
  if (res != 0) {
    NOPORTS_LOGW(TAG, "ESCR: failed to create signing key atkey: %d", res);
    atclient_atkey_free(&sk_key);
    return;
  }

  res = atclient_put_public_key((atclient *)_worker_ctx, &sk_key,
                                _config.pkam_public_key_base64, NULL, NULL);
  atclient_atkey_free(&sk_key);

  if (res != 0) {
    NOPORTS_LOGW(TAG, "ESCR: failed to publish public signing key: %d", res);
  } else {
    NOPORTS_LOGI(TAG, "ESCR: published signing key at public:_apsk.%s.a.__e%s",
                 _config.enrollment_id, _config.atsign);
  }
}

bool NoPortsDaemon::_publishDeviceInfo() {
  // Publish username info key for each manager
  // This mirrors handle_username_keys from the C sshnpd
  atclient *worker = (atclient *)_worker_ctx;

  for (uint8_t i = 0; i < _config.manager_count; i++) {
    // Build the key: "username.device_name.sshnp"
    atclient_atkey info_key;
    atclient_atkey_init(&info_key);

    size_t keynamelen = strlen("username") + strlen(_config.device_name) + 2;
    char keyname[keynamelen];
    snprintf(keyname, keynamelen, "username.%s", _config.device_name);

    int res = atclient_atkey_create_shared_key(&info_key, keyname,
                                               _config.atsign,
                                               _config.manager_list[i],
                                               NOPORTS_NS);
    if (res != 0) {
      NOPORTS_LOGW(TAG, "Failed to create device info key for %s", _config.manager_list[i]);
      atclient_atkey_free(&info_key);
      continue;
    }

    atclient_atkey_metadata *metadata = &info_key.metadata;
    atclient_atkey_metadata_set_is_public(metadata, false);
    atclient_atkey_metadata_set_is_encrypted(metadata, true);

    atclient_notify_params notify_params;
    atclient_notify_params_init(&notify_params);
    atclient_notify_params_set_atkey(&notify_params, &info_key);
    atclient_notify_params_set_value(&notify_params, "esp32");
    atclient_notify_params_set_operation(&notify_params, ATCLIENT_NOTIFY_OPERATION_UPDATE);

    res = _notifyWithRetry(worker, &notify_params, NULL);
    if (res != 0) {
      NOPORTS_LOGW(TAG, "Failed to publish device info to %s: %d", _config.manager_list[i], res);
    } else {
      NOPORTS_LOGI(TAG, "Published device info to %s", _config.manager_list[i]);
    }

    atclient_notify_params_free(&notify_params);
    atclient_atkey_free(&info_key);
  }

  return true;
}

// ============================================================================
// Private: Notification handling (from daemon.c)
// ============================================================================

// Compare two atSigns for equality, tolerating an optional leading '@' on
// either operand.  Returns false if either is NULL.  Used to authenticate the
// sender of policy-service RPC responses.
static bool _atsign_equals(const char *a, const char *b) {
  if (a == nullptr || b == nullptr) return false;
  if (*a == '@') a++;
  if (*b == '@') b++;
  return strcmp(a, b) == 0;
}

// Strictly parse a TCP port from a NUL-terminated string. Returns the port in
// 1..65535, or -1 if the string is not a fully-numeric in-range port. atoi/atol
// and strtoul-without-end-pointer silently wrap out-of-range values (70000 ->
// 4464) and accept trailing garbage (22x -> 22), which for a permitOpen rule
// would *widen* access on a typo — so callers must fail closed on -1.
static int _parse_port_strict(const char *s) {
  if (s == nullptr || *s == '\0') return -1;
  char *end = nullptr;
  long v = strtol(s, &end, 10);
  if (end == s || *end != '\0' || v < 1 || v > UINT16_MAX) return -1;
  return (int)v;
}

// RSA-encrypt a NUL-terminated base64 key/IV string with the client's
// ephemeral public key and return the result base64-encoded (malloc'd).
// Returns NULL on any failure so the caller can reject the whole request
// instead of sending the client a partial key set.
static char *_rsa_encrypt_b64(atchops_rsa_key_public_key *pk,
                              const unsigned char *plaintext) {
  unsigned char enc_buf[256];
  size_t enc_len = 0;
  if (atchops_rsa_encrypt(pk, plaintext,
                          strlen((const char *)plaintext), enc_buf,
                          sizeof(enc_buf), &enc_len) != 0) {
    return NULL;
  }
  char *out = (char *)malloc(384);
  if (!out) return NULL;
  memset(out, 0, 384);
  size_t b64_len;
  if (atchops_base64_encode(enc_buf, enc_len, out, 384, &b64_len) != 0) {
    free(out);
    return NULL;
  }
  return out;
}

void NoPortsDaemon::_handleNotification(void *msg) {
  atclient_monitor_message *message = (atclient_monitor_message *)msg;

  // -----------------------------------------------------------------------
  // Fast-path: policy-service RPC response
  // These notifications have keys like:
  //   @device:<type>.<reqId>.auth_checks.__rpcs.sshnp@policy_atsign
  // They do NOT match the "device.sshnp@" tail pattern used by the rest of
  // the dispatch, so we intercept them here before that logic runs.
  // -----------------------------------------------------------------------
  if (_config.policy_atsign && _config.policy_atsign[0] != '\0' &&
      message->notification->key &&
      atclient_rpc_is_response_key(message->notification->key,
                                     NOPORTS_NS, NOPORTS_POLICY_DOMAIN_NS)) {
    // SECURITY: only the configured policy atSign may answer auth-check RPCs.
    // atclient_rpc_is_response_key matches on the namespace pattern ONLY — it
    // does not bind the response to a sender.  The reqId is a predictable
    // per-boot counter, so without this check any atSign could forge a
    // "success" response (authorized=true, permitOpen=["*:*"]) that matches an
    // in-flight reqId and bypass the policy decision entirely.  The atServer
    // attests notification->from, so a spoofed sender cannot pass this gate.
    if (!_atsign_equals(message->notification->from, _config.policy_atsign)) {
      NOPORTS_LOGW(TAG, "Policy RPC: dropping response-shaped notification from "
                        "non-policy atSign '%s' (expected '%s')",
                   message->notification->from ? message->notification->from : "null",
                   _config.policy_atsign);
      return;
    }
    _handlePolicyResponse(msg);
    return;
  }

  bool is_init = atclient_atnotification_is_decrypted_value_initialized(message->notification);
  bool has_key = atclient_atnotification_is_key_initialized(message->notification);

  NOPORTS_LOGD(TAG, "Notification received: key_init=%d val_init=%d id=%s",
               has_key, is_init,
               message->notification->id ? message->notification->id : "null");
  if (has_key) {
    NOPORTS_LOGD(TAG, "  key=%s from=%s to=%s",
                 message->notification->key ? message->notification->key : "null",
                 message->notification->from ? message->notification->from : "null",
                 message->notification->to ? message->notification->to : "null");
  }

  if (!is_init) {
    NOPORTS_LOGD(TAG, "Skipping notification (no decrypted value)");
    return;
  }

  // Guard every field this handler dereferences: the notification comes off
  // the wire, and a missing id/from/to would otherwise be a strcmp/strlen on
  // NULL - an ESP32 panic and reboot loop any sender can trigger.
  bool has_id = atclient_atnotification_is_id_initialized(message->notification) &&
                message->notification->id != NULL;
  bool has_from = atclient_atnotification_is_from_initialized(message->notification) &&
                  message->notification->from != NULL;
  bool has_to = atclient_atnotification_is_to_initialized(message->notification) &&
                message->notification->to != NULL;

  if (!has_key || !has_id || strcmp(message->notification->id, "-1") == 0) {
    NOPORTS_LOGD(TAG, "Skipping notification (no key, no id, or id=-1)");
    return;
  }

  if (!has_from || !has_to) {
    NOPORTS_LOGD(TAG, "Skipping notification (missing from/to)");
    return;
  }

  char *key = message->notification->key;

  // Strip "$device.$namespace$from" from the back
  size_t tail_len = strlen(_config.device_name) + strlen(NOPORTS_NS) +
                    strlen(message->notification->from) + 3;
  char *tail = (char *)malloc(tail_len);
  if (!tail) return;

  sprintf(tail, ".%s.%s%s", _config.device_name, NOPORTS_NS, message->notification->from);
  char *tailstart = strstr(key, tail);
  free(tail);

  if (tailstart == NULL) {
    NOPORTS_LOGD(TAG, "Skipping: couldn't find tail in key");
    return;
  }
  *tailstart = '\0'; // reterminate

  // Strip notification.to from the front
  char *head = message->notification->to;
  size_t head_len = strlen(head);

  if (strlen(key) < head_len) {
    NOPORTS_LOGD(TAG, "Skipping: key too short for head strip");
    return;
  }

  if (strncmp(key, head, head_len) != 0) {
    NOPORTS_LOGD(TAG, "Skipping: head mismatch");
    return;
  }

  key += head_len + 1; // +1 for ":"

  NOPORTS_LOGD(TAG, "Parsed notification key: '%s'", key);

  // Identify notification type
  NoPortsNotificationKey nk = NK_NONE;
  for (int i = 1; i < NOPORTS_NOTIFICATION_KEYS_LEN; i++) {
    if (strcmp(key, _notification_key_map[i].str) == 0) {
      nk = _notification_key_map[i].key;
      break;
    }
  }

  // Dispatch
  switch (nk) {
    case NK_PING:
      NOPORTS_LOGI(TAG, "Handling ping from %s", message->notification->from);
      _handlePing(message);
      break;

    case NK_NPT_REQUEST:
      NOPORTS_LOGI(TAG, "Handling NPT request from %s", message->notification->from);
      _handleNptRequest(message);
      break;

    case NK_SSH_REQUEST:
      NOPORTS_LOGW(TAG, "SSH request not supported on Arduino/ESP32");
      break;

    case NK_SSHPUBLICKEY:
      NOPORTS_LOGW(TAG, "SSH public key not supported on Arduino/ESP32");
      break;

    case NK_GRACEFUL_SHUTDOWN:
      // Testing-only, mirroring the C sshnpd's
      // SSHNPD_ENABLE_TESTING_SHUTDOWN_NOTIFICATION guard.  Compiled out by
      // default so an arbitrary atSign cannot remotely stop the daemon.
#ifdef NOPORTS_ENABLE_TESTING_SHUTDOWN_NOTIFICATION
#warning BINARY COMPILED WITH SHUTDOWN NOTIFICATION ENABLED NOT FOR PRODUCTION USE
      if (_config.policy_atsign && _config.policy_atsign[0] != '\0') {
        // Policy mode auth would need an async RPC round-trip with no
        // continuation to resume into here — reject rather than fail open.
        NOPORTS_LOGW(TAG, "Shutdown: rejected — not supported in policy mode (from %s)",
                     message->notification->from);
      } else if (!_isManagerAtsign(message->notification->from)) {
        NOPORTS_LOGW(TAG, "Shutdown: rejected from unauthorized atSign: %s",
                     message->notification->from);
      } else {
        NOPORTS_LOGI(TAG, "Graceful shutdown requested by %s",
                     message->notification->from);
        _handleGracefulShutdown();
      }
#else
      NOPORTS_LOGW(TAG, "Graceful shutdown notification is disabled in this build "
                        "(define NOPORTS_ENABLE_TESTING_SHUTDOWN_NOTIFICATION to enable)");
#endif
      break;

    case NK_NONE:
    default:
      NOPORTS_LOGD(TAG, "Unknown notification key: %s", key);
      break;
  }
}

// ============================================================================
// Private: Manager-list authorization check
// ============================================================================

bool NoPortsDaemon::_isManagerAtsign(const char *atsign) {
  if (atsign == nullptr) {
    return false;
  }
  for (uint8_t i = 0; i < _config.manager_count; i++) {
    if (strcmp(atsign, _config.manager_list[i]) == 0) {
      return true;
    }
  }
  return false;
}

// ============================================================================
// Private: Ping handler (from handle_ping.c)
// ============================================================================

void NoPortsDaemon::_handlePing(void *msg) {
  atclient_monitor_message *message = (atclient_monitor_message *)msg;

  if (!_ping_response) {
    NOPORTS_LOGE(TAG, "Ping response not built");
    return;
  }

  const char *from = message->notification->from;

  // Authorise the pinging atSign.
  // Two modes: manager-list check (default) or policy-service RPC.
  if (_config.policy_atsign && _config.policy_atsign[0] != '\0') {
    // Policy mode — async RPC to the policy service.
    // Throttle first: a ping needs no signature, so it is the cheapest way to
    // spend the single policy slot.  Rate-limit per sender before doing so.
    if (_policyRateLimited(from, NOPORTS_POLICY_PING)) {
      NOPORTS_LOGW(TAG, "Ping: rate-limited (cooldown) — dropping ping from %s", from);
      return;
    }
    if (_policy_pending.in_use) {
      NOPORTS_LOGW(TAG, "Ping: policy check in flight, ignoring ping from %s", from);
      return;
    }
    _policy_pending.in_use          = true;
    _policy_pending.type            = NOPORTS_POLICY_PING;
    _policy_pending.req_id          = _next_policy_req_id();
    _policy_pending.sent_at_ms      = millis();
    _policy_pending.envelope        = nullptr;
    strncpy(_policy_pending.requesting_atsign, from,
            sizeof(_policy_pending.requesting_atsign) - 1);
    _policy_pending.requesting_atsign[sizeof(_policy_pending.requesting_atsign) - 1] = '\0';
    _sendPolicyRpcRequest(from);
    return;
  }

  if (!_isManagerAtsign(from)) {
    NOPORTS_LOGW(TAG, "Ping: rejected from unauthorized atSign: %s", from);
    return;
  }

  _handlePingAuthorized(from);
}

// ============================================================================
// Private: NPT Request handler (from handle_npt_request.c)
// ============================================================================

void NoPortsDaemon::_handleNptRequest(void *msg) {
  atclient_monitor_message *message = (atclient_monitor_message *)msg;
  atclient *worker = (atclient *)_worker_ctx;
  atchops_rsa_key_private_key *skey = (atchops_rsa_key_private_key *)_signing_key;
  int res = 0;

  // Per-sender throttle BEFORE any expensive work.  _verifyEnvelopeSignature
  // below fetches the sender's public key over the worker (a network round
  // trip), and any atSign can send an npt_request notification — so rejecting
  // a flooding sender here means a bogus request never costs a key lookup or a
  // policy slot.  Applies in both manager and policy modes; notification->from
  // is atServer-attested and cannot be spoofed.
  if (_policyRateLimited(message->notification->from, NOPORTS_POLICY_NPT)) {
    NOPORTS_LOGW(TAG, "NPT: rate-limited (cooldown) — ignoring request from %s",
                 message->notification->from ? message->notification->from : "null");
    return;
  }

  // Extract envelope from notification
  if (!atclient_atnotification_is_decrypted_value_initialized(message->notification) ||
      message->notification->decrypted_value == NULL) {
    NOPORTS_LOGE(TAG, "NPT: no decrypted value");
    return;
  }

  cJSON *envelope = cJSON_Parse(message->notification->decrypted_value);
  if (envelope == NULL) {
    NOPORTS_LOGE(TAG, "NPT: failed to parse envelope JSON");
    return;
  }

  // Verify envelope signature
  char *requesting_atsign = message->notification->from;
  if (!_verifyEnvelopeSignature(envelope, requesting_atsign)) {
    NOPORTS_LOGE(TAG, "NPT: envelope signature verification failed");
    cJSON_Delete(envelope);
    return;
  }

  // Authorise the requesting atSign.
  // Two modes: manager-list check (default) or policy-service RPC.
  if (_config.policy_atsign && _config.policy_atsign[0] != '\0') {
    // Policy mode: defer auth to the policy service via async RPC.
    // Continuation runs in _handlePolicyResponse → _continueNptRequest.
    // (Per-sender throttle already applied at the top of this function.)

    if (_policy_pending.in_use) {
      // NPT is the high-value path; do not let a pending PING check block it.
      // Preempt an in-flight ping (its late response will be dropped on reqId
      // mismatch), but never preempt another in-flight NPT.
      if (_policy_pending.type == NOPORTS_POLICY_PING) {
        NOPORTS_LOGI(TAG, "NPT: preempting in-flight ping check for %s",
                     requesting_atsign);
        _cleanupPolicyPending();
      } else {
        NOPORTS_LOGW(TAG, "NPT: policy check in flight — ignoring request from %s",
                     requesting_atsign);
        cJSON_Delete(envelope);
        return;
      }
    }
    _policy_pending.in_use          = true;
    _policy_pending.type            = NOPORTS_POLICY_NPT;
    _policy_pending.req_id          = _next_policy_req_id();
    _policy_pending.sent_at_ms      = millis();
    _policy_pending.envelope        = envelope;  // ownership transferred
    strncpy(_policy_pending.requesting_atsign, requesting_atsign,
            sizeof(_policy_pending.requesting_atsign) - 1);
    _policy_pending.requesting_atsign[sizeof(_policy_pending.requesting_atsign) - 1] = '\0';
    _sendPolicyRpcRequest(requesting_atsign);
    return;
  }

  if (!_isManagerAtsign(requesting_atsign)) {
    NOPORTS_LOGW(TAG, "NPT: rejected request from unauthorized atSign: %s",
                 requesting_atsign);
    cJSON_Delete(envelope);
    return;
  }

  // Continue NPT processing — envelope ownership transferred.
  _continueNptRequest(envelope, requesting_atsign, nullptr, 0);
}

// ============================================================================
// Private: Policy-service RPC helpers
// ============================================================================

// ---------------------------------------------------------------------------
// Send a signed error response notification to the npt client.
// Matches the Dart sshnpd error format so npt shows the correct error string.
// ---------------------------------------------------------------------------
void NoPortsDaemon::_sendNptError(const char *to_atsign,
                                   const char *session_id,
                                   const char *error_msg) {
  atclient *worker = (atclient *)_worker_ctx;

  if (!to_atsign || !session_id || !error_msg) {
    NOPORTS_LOGW(TAG, "NPT error: missing args for error response");
    return;
  }

  NOPORTS_LOGW(TAG, "NPT: sending error to %s: %s", to_atsign, error_msg);

  // SshnpdDefaultPayloadHandler.handleSshnpdPayload() checks whether the
  // notification value starts with '{'.  If it does, it parses it as a signed
  // JSON envelope and returns SshnpdAck.acknowledged — the npt client then
  // proceeds as if the tunnel is up.  If it does NOT start with '{', the
  // handler sets errorReceived = value and returns SshnpdAck.acknowledgedWithErrors,
  // which causes npt to throw SshnpError("Error response from device daemon: ...").
  // So we must send a plain string (no JSON wrapping), exactly as the Dart
  // sshnpd_impl.dart does for permit-open denials.

  // Key: <sessionId>.<deviceName>.sshnp@daemon  shared with to_atsign
  atclient_atkey err_atkey;
  atclient_atkey_init(&err_atkey);
  size_t klen = strlen(session_id) + strlen(_config.device_name) + 2;
  char *kname = (char *)malloc(klen);
  if (kname) {
    snprintf(kname, klen, "%s.%s", session_id, _config.device_name);
    atclient_atkey_create_shared_key(&err_atkey, kname,
                                      _config.atsign, to_atsign, NOPORTS_NS);
    atclient_atkey_metadata_set_is_public(&err_atkey.metadata,    false);
    atclient_atkey_metadata_set_is_encrypted(&err_atkey.metadata, true);
    atclient_atkey_metadata_set_ttl(&err_atkey.metadata,          10000);

    atclient_notify_params nparams;
    atclient_notify_params_init(&nparams);
    atclient_notify_params_set_atkey(&nparams, &err_atkey);
    atclient_notify_params_set_value(&nparams, error_msg);  // plain string, not JSON
    atclient_notify_params_set_operation(&nparams, ATCLIENT_NOTIFY_OPERATION_UPDATE);

    int nret = _notifyWithRetry(worker, &nparams, NULL);
    if (nret != 0) {
      NOPORTS_LOGE(TAG, "NPT: failed to send error response to %s (%d)", to_atsign, nret);
    }
    atclient_notify_params_free(&nparams);
    free(kname);
  }
  atclient_atkey_free(&err_atkey);
}

void NoPortsDaemon::_cleanupPolicyPending() {
  if (_policy_pending.envelope) {
    cJSON_Delete((cJSON *)_policy_pending.envelope);
    _policy_pending.envelope = nullptr;
  }
  memset(&_policy_pending, 0, sizeof(_policy_pending));
}

// Per-sender throttle for requests (DoS mitigation).  Returns true when a
// request of |type| from |atsign| should be dropped because one was already
// accepted within NOPORTS_POLICY_COOLDOWN_MS.  Otherwise records the acceptance
// and returns false.  Because the timestamp is only updated on acceptance, a
// legitimate sender's first request always passes; only rapid repeats of the
// SAME type are throttled, and the table can never permanently lock anyone out.
// Ping and NPT use independent timestamps so a ping does not throttle the NPT
// request that normally follows it.
bool NoPortsDaemon::_policyRateLimited(const char *atsign,
                                       NoPortsPolicyPendingType type) {
  if (!atsign) return false;
  uint32_t now = millis();

  int free_slot = -1;
  int oldest_slot = 0;
  uint32_t oldest_recency = 0xFFFFFFFFUL;  // smallest max(ts) → LRU victim

  for (int i = 0; i < NOPORTS_POLICY_COOLDOWN_SLOTS; i++) {
    if (_policy_cooldown[i].used) {
      if (strcmp(_policy_cooldown[i].atsign, atsign) == 0) {
        uint32_t *ts = (type == NOPORTS_POLICY_PING)
                         ? &_policy_cooldown[i].last_ping_ms
                         : &_policy_cooldown[i].last_npt_ms;
        // *ts == 0 means "never accepted for this type" → not throttled.
        if (*ts != 0 && (now - *ts) < NOPORTS_POLICY_COOLDOWN_MS) {
          return true;  // throttled — do NOT refresh the timestamp
        }
        *ts = now ? now : 1;  // accepted — start a new window (avoid 0 sentinel)
        return false;
      }
      // Track the least-recently-active entry for LRU eviction.
      uint32_t recency = _policy_cooldown[i].last_ping_ms > _policy_cooldown[i].last_npt_ms
                           ? _policy_cooldown[i].last_ping_ms
                           : _policy_cooldown[i].last_npt_ms;
      if (recency < oldest_recency) {
        oldest_recency = recency;
        oldest_slot = i;
      }
    } else if (free_slot < 0) {
      free_slot = i;
    }
  }

  // Not seen — record in a free slot, else evict the least-recently-active (LRU).
  int slot = (free_slot >= 0) ? free_slot : oldest_slot;
  memset(&_policy_cooldown[slot], 0, sizeof(_policy_cooldown[slot]));
  strncpy(_policy_cooldown[slot].atsign, atsign,
          sizeof(_policy_cooldown[slot].atsign) - 1);
  _policy_cooldown[slot].atsign[sizeof(_policy_cooldown[slot].atsign) - 1] = '\0';
  if (type == NOPORTS_POLICY_PING)
    _policy_cooldown[slot].last_ping_ms = now ? now : 1;
  else
    _policy_cooldown[slot].last_npt_ms = now ? now : 1;
  _policy_cooldown[slot].used = true;
  return false;
}

void NoPortsDaemon::_sendPolicyRpcRequest(const char *client_atsign) {
  atclient *worker = (atclient *)_worker_ctx;
  uint32_t req_id  = _policy_pending.req_id;

  // Build the NoPorts-specific NPAAuthCheckRequest payload JSON.
  // atclient_rpc_send_request wraps it in the AtRpcReq envelope:
  //   {"reqId":<n>,"payload":<payload_json>}
  cJSON *pl = cJSON_CreateObject();
  cJSON_AddStringToObject(pl, "daemonAtsign",          _config.atsign);
  cJSON_AddStringToObject(pl, "daemonDeviceName",      _config.device_name);
  cJSON_AddStringToObject(pl, "daemonDeviceGroupName", "");
  cJSON_AddStringToObject(pl, "clientAtsign",          client_atsign);
  char *payload_json = cJSON_PrintUnformatted(pl);
  cJSON_Delete(pl);

  if (!payload_json) {
    NOPORTS_LOGE(TAG, "Policy RPC: OOM building payload JSON");
    _cleanupPolicyPending();
    return;
  }

  NOPORTS_LOGI(TAG, "Policy RPC: requesting auth for %s from %s (reqId=%lu)",
               client_atsign, _config.policy_atsign, (unsigned long)req_id);

  int res = atclient_rpc_send_request(worker,
                                       _config.atsign,
                                       _config.policy_atsign,
                                       NOPORTS_NS,
                                       NOPORTS_POLICY_DOMAIN_NS,
                                       req_id,
                                       payload_json,
                                       30000);
  free(payload_json);

  if (res != 0) {
    NOPORTS_LOGE(TAG, "Policy RPC: send failed (%d) — cancelling check", res);
    _cleanupPolicyPending();
  }
}

void NoPortsDaemon::_handlePolicyResponse(void *msg) {
  atclient_monitor_message *message = (atclient_monitor_message *)msg;

  if (!message->notification->key) {
    NOPORTS_LOGW(TAG, "Policy RPC: response with no key");
    return;
  }

  // SECURITY (defense in depth): reject any response not sent by the configured
  // policy atSign.  The primary gate is in _handleNotification, but this keeps
  // the invariant local so the handler can never authorize on a forged sender.
  if (!_atsign_equals(message->notification->from, _config.policy_atsign)) {
    NOPORTS_LOGW(TAG, "Policy RPC: response from non-policy atSign '%s' — ignoring",
                 message->notification->from ? message->notification->from : "null");
    return;
  }

  // Use the library to parse resp_type and req_id from the key.
  atclient_rpc_resp rpc_resp;
  if (atclient_rpc_parse_response_key(message->notification, &rpc_resp) != 0) {
    NOPORTS_LOGW(TAG, "Policy RPC: failed to parse response key: %s",
                 message->notification->key);
    return;
  }

  NOPORTS_LOGI(TAG, "Policy RPC: type=%d reqId=%lu from=%s",
               (int)rpc_resp.resp_type, (unsigned long)rpc_resp.req_id,
               message->notification->from ? message->notification->from : "?");

  if (!_policy_pending.in_use) {
    NOPORTS_LOGW(TAG, "Policy RPC: no pending request (ignoring reqId=%lu)",
                 (unsigned long)rpc_resp.req_id);
    return;
  }
  if (_policy_pending.req_id != rpc_resp.req_id) {
    NOPORTS_LOGW(TAG, "Policy RPC: reqId mismatch (pending=%lu got=%lu) — ignoring",
                 (unsigned long)_policy_pending.req_id, (unsigned long)rpc_resp.req_id);
    return;
  }

  // ACK = server received the request; reset timeout and wait for the decision.
  if (rpc_resp.resp_type == ATCLIENT_RPC_RESP_ACK) {
    NOPORTS_LOGI(TAG, "Policy RPC: ack received — waiting for decision");
    _policy_pending.sent_at_ms = millis();
    return;
  }

  // Any other type (success / error / nack) finalises the check.
  bool authorized = false;
  char        po_buf[16][64];
  const char *po_ptrs[16];
  int         po_count = 0;

  if (rpc_resp.resp_type == ATCLIENT_RPC_RESP_SUCCESS) {
    if (!atclient_atnotification_is_decrypted_value_initialized(message->notification) ||
        !message->notification->decrypted_value) {
      NOPORTS_LOGE(TAG, "Policy RPC: success but no decrypted value");
    } else {
      cJSON *resp = cJSON_Parse(message->notification->decrypted_value);
      if (resp) {
        cJSON *pl = cJSON_GetObjectItem(resp, "payload");
        if (pl) {
          authorized = cJSON_IsTrue(cJSON_GetObjectItem(pl, "authorized"));
          const char *ms = cJSON_GetStringValue(cJSON_GetObjectItem(pl, "message"));
          NOPORTS_LOGI(TAG, "Policy RPC: authorized=%d msg='%s'",
                       authorized, ms ? ms : "");
          cJSON *po_arr = cJSON_GetObjectItem(pl, "permitOpen");
          NOPORTS_LOGI(TAG, "Policy RPC: permitOpen is %s, size=%d",
                       po_arr ? (cJSON_IsArray(po_arr) ? "array" : "non-array") : "NULL",
                       po_arr && cJSON_IsArray(po_arr) ? cJSON_GetArraySize(po_arr) : -1);
          if (cJSON_IsArray(po_arr)) {
            int n = cJSON_GetArraySize(po_arr);
            for (int i = 0; i < n && po_count < 16; i++) {
              cJSON *item = cJSON_GetArrayItem(po_arr, i);
              const char *s = cJSON_GetStringValue(item);
              NOPORTS_LOGI(TAG, "Policy RPC: permitOpen[%d] type=%d val='%s'",
                           i, item ? item->type : -1, s ? s : "(null)");
              // Reject entries that don't fit the buffer instead of
              // truncating: truncation can land mid-port and silently
              // rewrite the rule (e.g. a 58-char host + ":12345" becomes
              // "...:123", permitting port 123 instead of 12345).
              if (s && strlen(s) < sizeof(po_buf[0])) {
                strcpy(po_buf[po_count], s);
                po_ptrs[po_count]    = po_buf[po_count];
                po_count++;
              } else if (s) {
                NOPORTS_LOGW(TAG, "Policy RPC: permitOpen[%d] longer than %u chars - skipping rule",
                             i, (unsigned)(sizeof(po_buf[0]) - 1));
              }
            }
          }
        } else {
          NOPORTS_LOGE(TAG, "Policy RPC: success response has no 'payload' field");
          NOPORTS_LOGI(TAG, "Policy RPC: raw decrypted_value: %s",
                       message->notification->decrypted_value);
        }
        cJSON_Delete(resp);
      } else {
        NOPORTS_LOGE(TAG, "Policy RPC: failed to parse response JSON");
      }
    }
  } else {
    NOPORTS_LOGW(TAG, "Policy RPC: type=%d response — rejecting", (int)rpc_resp.resp_type);
  }

  if (!authorized) {
    NOPORTS_LOGW(TAG, "Policy RPC: access denied for %s",
                 _policy_pending.requesting_atsign);
    // For NPT requests, notify the client so npt shows the error immediately
    if (_policy_pending.type == NOPORTS_POLICY_NPT && _policy_pending.envelope) {
      cJSON *env_j  = (cJSON *)_policy_pending.envelope;
      cJSON *env_pl = cJSON_GetObjectItem(env_j, "payload");
      const char *sid = env_pl
          ? cJSON_GetStringValue(cJSON_GetObjectItem(env_pl, "sessionId"))
          : nullptr;
      _sendNptError(_policy_pending.requesting_atsign, sid,
                    "Access denied by policy server");
    }
    _cleanupPolicyPending();
    return;
  }

  if (_policy_pending.type == NOPORTS_POLICY_PING) {
    _handlePingAuthorized(_policy_pending.requesting_atsign);
    _cleanupPolicyPending();

  } else if (_policy_pending.type == NOPORTS_POLICY_NPT) {
    cJSON *env = (cJSON *)_policy_pending.envelope;
    _policy_pending.envelope = nullptr;  // transfer ownership before cleanup
    char req_at[64];
    strncpy(req_at, _policy_pending.requesting_atsign, sizeof(req_at) - 1);
    req_at[sizeof(req_at) - 1] = '\0';
    NOPORTS_LOGI(TAG, "Policy RPC: passing %d permitOpen entries to continueNptRequest",
                 po_count);
    _cleanupPolicyPending();  // free the slot before the long relay setup
    _continueNptRequest(env, req_at, po_count > 0 ? po_ptrs : nullptr, po_count);
  }
}

// ============================================================================
// Private: Ping authorized — send the heartbeat notification
// ============================================================================

void NoPortsDaemon::_handlePingAuthorized(const char *from_atsign) {
  atclient *worker = (atclient *)_worker_ctx;

  atclient_atkey pingkey;
  atclient_atkey_init(&pingkey);

  size_t keynamelen = strlen("heartbeat") + strlen(_config.device_name) + 2;
  char keyname[keynamelen];
  snprintf(keyname, keynamelen, "heartbeat.%s", _config.device_name);

  int res = atclient_atkey_create_shared_key(&pingkey, keyname,
                                             _config.atsign, from_atsign,
                                             NOPORTS_NS);
  if (res != 0) {
    NOPORTS_LOGE(TAG, "Ping: failed to create heartbeat key (%d)", res);
    atclient_atkey_free(&pingkey);
    return;
  }

  atclient_atkey_metadata_set_is_public(&pingkey.metadata, false);
  atclient_atkey_metadata_set_is_encrypted(&pingkey.metadata, true);
  atclient_atkey_metadata_set_ttl(&pingkey.metadata, 10000);

  atclient_notify_params notify_params;
  atclient_notify_params_init(&notify_params);
  atclient_notify_params_set_atkey(&notify_params, &pingkey);
  atclient_notify_params_set_operation(&notify_params, ATCLIENT_NOTIFY_OPERATION_UPDATE);
  atclient_notify_params_set_value(&notify_params, _ping_response);

  res = _notifyWithRetry(worker, &notify_params, NULL);
  if (res != 0) {
    NOPORTS_LOGE(TAG, "Ping: failed to send response to %s", from_atsign);
  } else {
    NOPORTS_LOGI(TAG, "Ping: sent response to %s", from_atsign);
  }

  if (_config.on_ping) {
    _config.on_ping(from_atsign);
  }
}

// ============================================================================
// Private: Continue NPT request after authorization
// ============================================================================
// Takes ownership of |env| — always calls cJSON_Delete before returning.
// policy_po / policy_po_count: the permitOpen list from the policy service.
//   nullptr + 0  → manager mode, checks config.permitopen.
//   non-null     → policy mode, checks the policy-provided list.
// ============================================================================

void NoPortsDaemon::_continueNptRequest(void *env,
                                         const char *requesting_atsign,
                                         const char **policy_po,
                                         int policy_po_count) {
  cJSON *envelope = (cJSON *)env;
  atclient *worker = (atclient *)_worker_ctx;
  atchops_rsa_key_private_key *skey = (atchops_rsa_key_private_key *)_signing_key;
  int res = 0;

  // Verify contents
  if (!_verifyEnvelopeContents(envelope, 1 /* payload_type_npt */)) {
    NOPORTS_LOGE(TAG, "NPT: invalid envelope contents");
    cJSON_Delete(envelope);
    return;
  }

  cJSON *payload = cJSON_GetObjectItem(envelope, "payload");
  // Extract sessionId early so all error-response paths can key the notification
  const char *session_id_str =
      cJSON_GetStringValue(cJSON_GetObjectItem(payload, "sessionId"));

  // Check permitopen — requestedHost and requestedPort are mandatory
  cJSON *requested_host = cJSON_GetObjectItem(payload, "requestedHost");
  cJSON *requested_port = cJSON_GetObjectItem(payload, "requestedPort");

  if (!requested_host || !requested_port) {
    NOPORTS_LOGE(TAG, "NPT: missing requestedHost/requestedPort");
    cJSON_Delete(envelope);
    return;
  }

  {
    const char *rhost = cJSON_GetStringValue(requested_host);
    uint16_t rport = (uint16_t)cJSON_GetNumberValue(requested_port);

    bool permitted = false;
    const bool in_policy_mode = (_config.policy_atsign && _config.policy_atsign[0] != '\0');
    if (in_policy_mode) {
      // Policy mode: the policy server's permitOpen list is authoritative.
      // An empty list means the device is not configured in the policy server.
      if (policy_po_count == 0) {
        NOPORTS_LOGW(TAG, "NPT: policy returned empty permitOpen — device not configured in policy server, denying %s:%d",
                     rhost, rport);
        // permitted stays false → connection will be denied below
      } else {
        NOPORTS_LOGI(TAG, "NPT: checking policy permitOpen (%d entries) for %s:%u",
                     policy_po_count, rhost, (unsigned)rport);
        for (int i = 0; i < policy_po_count && !permitted; i++) {
          const char *entry = policy_po[i];
          NOPORTS_LOGI(TAG, "NPT: policy permitOpen[%d]='%s'", i, entry ? entry : "(null)");
          const char *colon = strrchr(entry, ':');
          if (!colon) continue;
          size_t hlen = (size_t)(colon - entry);
          char h[128];
          if (hlen >= sizeof(h)) continue;
          memcpy(h, entry, hlen); h[hlen] = '\0';
          const char *port_str = colon + 1;
          bool port_wildcard = (strcmp(port_str, "*") == 0);
          int p = port_wildcard ? 0 : _parse_port_strict(port_str);
          // Fail closed: only the explicit "*" is a wildcard. A malformed port
          // (empty, non-numeric, or out of range) yields p == -1 and must NOT
          // match — otherwise a typo like "10.0.0.5:2x2" would silently permit
          // every port on that host.
          if (!port_wildcard && p < 0) {
            NOPORTS_LOGW(TAG, "NPT: policy permitOpen[%d] has invalid port '%s' — skipping rule",
                         i, port_str);
            continue;
          }
          bool hm = (strcmp(h, "*") == 0) || (strcmp(h, rhost) == 0);
          bool pm = port_wildcard || ((uint16_t)p == rport);
          NOPORTS_LOGI(TAG, "NPT: compare h='%s' p=%d hm=%d pm=%d (rport=%u)",
                       h, p, (int)hm, (int)pm, (unsigned)rport);
          if (hm && pm) {
            NOPORTS_LOGW(TAG, "NPT: POLICY PERMIT — %s:%u matched rule '%s'", rhost, (unsigned)rport, entry);
            permitted = true;
          }
        }
      }
    } else {
      // Manager mode: check static device config.
      for (uint8_t i = 0; i < _config.permitopen_count; i++) {
        bool host_match = (strcmp(_config.permitopen[i].host, "*") == 0) ||
                          (strcmp(_config.permitopen[i].host, rhost) == 0);
        bool port_match = (_config.permitopen[i].port == 0) ||
                          (_config.permitopen[i].port == rport);
        if (host_match && port_match) {
          permitted = true;
          break;
        }
      }
    }

    if (!permitted) {
      // Build a human-readable permit-open list for the error message
      NOPORTS_LOGW(TAG, "NPT: POLICY DENY — %s:%u not in policy permitOpen list", rhost, (unsigned)rport);
      char po_list[128] = "(none)";
      if (in_policy_mode && policy_po_count > 0) {
        size_t off = 0;
        for (int i = 0; i < policy_po_count && off + 2 < sizeof(po_list); i++) {
          if (i > 0 && off + 1 < sizeof(po_list)) po_list[off++] = ',';
          size_t n = strlen(policy_po[i]);
          if (off + n >= sizeof(po_list)) n = sizeof(po_list) - off - 1;
          memcpy(po_list + off, policy_po[i], n);
          off += n;
        }
        po_list[off] = '\0';
      } else if (!in_policy_mode) {
        size_t off = 0;
        for (uint8_t i = 0; i < _config.permitopen_count && off + 2 < sizeof(po_list); i++) {
          if (i > 0 && off + 1 < sizeof(po_list)) po_list[off++] = ',';
          int n = snprintf(po_list + off, sizeof(po_list) - off,
                           "%s:%u", _config.permitopen[i].host,
                           (unsigned)_config.permitopen[i].port);
          if (n > 0) off += (size_t)n;
        }
      }
      char err_msg[256];
      snprintf(err_msg, sizeof(err_msg),
               "Connection to %s:%d denied based on %s --permit-open [%s]",
               rhost, rport,
               in_policy_mode ? "POLICY" : "MANAGER",
               po_list);
      NOPORTS_LOGW(TAG, "NPT: %s", err_msg);
      _sendNptError(requesting_atsign, session_id_str, err_msg);
      cJSON_Delete(envelope);
      return;
    }
  }

  // Extract RVD connection info
  cJSON *rvd_host = cJSON_GetObjectItem(payload, "rvdHost");
  cJSON *rvd_port = cJSON_GetObjectItem(payload, "rvdPort");
  cJSON *session_id = cJSON_GetObjectItem(payload, "sessionId");

  if (!rvd_host || !rvd_port || !session_id) {
    NOPORTS_LOGE(TAG, "NPT: missing rvdHost/rvdPort/sessionId");
    _sendNptError(requesting_atsign, session_id_str,
                  "Malformed session request: missing rvdHost, rvdPort or sessionId");
    cJSON_Delete(envelope);
    return;
  }

  // Check if we have a free relay slot
  int slot = _findFreeRelaySlot();
  if (slot < 0) {
    NOPORTS_LOGE(TAG, "NPT: no free relay slots (max %d)", NOPORTS_MAX_RELAYS);
    char err_msg[64];
    snprintf(err_msg, sizeof(err_msg), "No relay slots available (max %d active)",
             NOPORTS_MAX_RELAYS);
    _sendNptError(requesting_atsign, session_id_str, err_msg);
    cJSON_Delete(envelope);
    return;
  }

  // Setup relay config
  NoPortsRelayConfig relay_cfg;
  noports_relay_config_init(&relay_cfg);
  // max_subs is set directly from _max_relays — how many sub-connections
  // (TCP client sessions) this relay task will accept on its ctrl channel.
  // The per-session PCB check in _handle_connect_msg enforces the hardware
  // PCB budget independently; max_subs just sizes the slot array.
  relay_cfg.max_subs = _max_relays;  // direct: each unit = one TCP session slot

  relay_cfg.rvd_host = cJSON_GetStringValue(rvd_host);
  relay_cfg.rvd_port = (uint16_t)cJSON_GetNumberValue(rvd_port);
  relay_cfg.local_host = cJSON_GetStringValue(requested_host);
  relay_cfg.local_port = (uint16_t)cJSON_GetNumberValue(requested_port);
  relay_cfg.multi = true;

  // Parse idle timeout from NPT request (sent in milliseconds by client)
  cJSON *timeout_item = cJSON_GetObjectItem(payload, "timeout");
  if (cJSON_IsNumber(timeout_item)) {
    uint32_t timeout_ms = (uint32_t)cJSON_GetNumberValue(timeout_item);
    relay_cfg.idle_timeout_ms = timeout_ms;
    NOPORTS_LOGI(TAG, "NPT: client requested timeout %u ms", (unsigned)timeout_ms);
  } else {
    relay_cfg.idle_timeout_ms = 0; // use default
  }

  strncpy(relay_cfg.session_id, cJSON_GetStringValue(session_id),
          sizeof(relay_cfg.session_id) - 1);

  // Handle RVD authentication — supports ESCR (Encrypted Signed Challenge-Response)
  // and legacy payload modes.  ESCR requires APKAM enrollment (enrollment_id != NULL).
  bool authenticate_to_rvd = cJSON_IsTrue(cJSON_GetObjectItem(payload, "authenticateToRvd"));
  if (authenticate_to_rvd) {
    const char *auth_mode_str =
      cJSON_GetStringValue(cJSON_GetObjectItem(payload, "relayAuthMode"));
    bool use_escr = (auth_mode_str && strcmp(auth_mode_str, "escr") == 0);

    if (use_escr && _config.enrollment_id && _pkam_signing_key) {
      const char *raw_aes_key =
        cJSON_GetStringValue(cJSON_GetObjectItem(payload, "relayAuthAesKey"));
      if (raw_aes_key) {
        relay_cfg.escr_auth          = true;
        relay_cfg.relay_auth_aes_key = strdup(raw_aes_key);
        relay_cfg.escr_signing_key   = _pkam_signing_key;  // daemon owns this

        // Build signing key URI: public:_apsk.<enrollmentId>.a.__e@<atSign>
        // The "public:" prefix is required so the SRVD can look up the key.
        // atsign already has '@' prefix (e.g. "@mydevice").
        // "a.__e" == EnrollmentConstants.perEnrollmentApproved in Dart at_commons.
        size_t uri_len = strlen(_config.enrollment_id) + strlen(_config.atsign) + 25;
        char *uri = (char *)malloc(uri_len);
        if (uri) {
          snprintf(uri, uri_len, "public:_apsk.%s.a.__e%s",
                   _config.enrollment_id, _config.atsign);
          relay_cfg.escr_signing_key_uri = uri;
        }
        NOPORTS_LOGI(TAG, "NPT: ESCR auth enabled, sk=%s",
                     relay_cfg.escr_signing_key_uri ? relay_cfg.escr_signing_key_uri : "NULL");
      } else {
        NOPORTS_LOGW(TAG, "NPT: relayAuthMode=escr but relayAuthAesKey missing"
                          " — falling back to legacy auth");
        use_escr = false;
      }
    } else if (use_escr) {
      NOPORTS_LOGW(TAG, "NPT: relayAuthMode=escr but no APKAM enrollment_id"
                        " — falling back to legacy auth");
      use_escr = false;
    }

    if (!use_escr) {
      // Legacy payload auth: sign {sessionId, clientNonce, rvdNonce}
      relay_cfg.rv_auth = true;

      cJSON *client_nonce = cJSON_GetObjectItem(payload, "clientNonce");
      cJSON *rvd_nonce    = cJSON_GetObjectItem(payload, "rvdNonce");

      if (cJSON_IsString(client_nonce) && cJSON_IsString(rvd_nonce)) {
        cJSON *auth_payload  = cJSON_CreateObject();
        cJSON_AddItemReferenceToObject(auth_payload, "sessionId",   session_id);
        cJSON_AddItemReferenceToObject(auth_payload, "clientNonce", client_nonce);
        cJSON_AddItemReferenceToObject(auth_payload, "rvdNonce",    rvd_nonce);

        cJSON *auth_envelope = cJSON_CreateObject();
        cJSON_AddItemReferenceToObject(auth_envelope, "payload", auth_payload);

        char *signing_input = cJSON_PrintUnformatted(auth_payload);
        unsigned char signature[256];
        memset(signature, 0, 256);

        // cJSON_PrintUnformatted returns NULL on OOM (realistic mid-session
        // on an ESP32) - strlen(NULL) here would panic the daemon
        res = -1;
        if (signing_input) {
          res = atchops_rsa_sign(skey, ATCHOPS_MD_SHA256,
                                 (unsigned char *)signing_input,
                                 strlen(signing_input), signature);
          cJSON_free(signing_input);
        }

        if (res == 0) {
          char b64sig[384];
          memset(b64sig, 0, 384);
          size_t sig_len;
          res = atchops_base64_encode(signature, 256, b64sig, 384, &sig_len);
          if (res == 0) {
            cJSON_AddStringToObject(auth_envelope, "signature",    b64sig);
            cJSON_AddStringToObject(auth_envelope, "hashingAlgo",  "sha256");
            cJSON_AddStringToObject(auth_envelope, "signingAlgo",  "rsa2048");
            relay_cfg.rvd_auth_string = cJSON_PrintUnformatted(auth_envelope);
          }
        }

        cJSON_Delete(auth_payload);
        cJSON_Delete(auth_envelope);
      }
    }
  }

  // Handle E2EE (from handler_commons.c setup_rvd_session_encryption)
  // Daemon generates a C2D (Client→Daemon) AES key/IV pair whenever
  // encryptRvdTraffic is set, and a second D2C (Daemon→Client) pair only
  // when the client requested twin-key mode via the twinKeys flag — same
  // as the Dart daemon, so legacy clients get the single-key response
  // they expect.  Encrypted copies go in the success response; plaintext
  // copies drive control channel encryption.
  bool encrypt_rvd_traffic = cJSON_IsTrue(cJSON_GetObjectItem(payload, "encryptRvdTraffic"));
  bool twin_keys = encrypt_rvd_traffic &&
                   cJSON_IsTrue(cJSON_GetObjectItem(payload, "twinKeys"));
  char *session_aes_key_b64 = NULL;
  char *session_iv_b64 = NULL;
  char *session_aes_key_d2c_b64 = NULL;
  char *session_iv_d2c_b64 = NULL;

  if (encrypt_rvd_traffic) {
    relay_cfg.rv_e2ee = true;
    bool e2ee_ok = false;

    do {
      // Generate C2D session AES key and IV
      unsigned char aes_key[32], iv[16];
      memset(aes_key, 0, 32);
      memset(iv, 0, 16);
      if (atchops_aes_generate_key(aes_key, ATCHOPS_AES_256) != 0) break;
      if (atchops_iv_generate(iv) != 0) break;

      // Base64 encode plaintext keys for relay's control channel
      relay_cfg.session_aes_key = (unsigned char *)malloc(49);
      relay_cfg.session_iv = (unsigned char *)malloc(25);
      if (!relay_cfg.session_aes_key || !relay_cfg.session_iv) {
        mbedtls_platform_zeroize(aes_key, sizeof(aes_key));
        break;
      }
      memset(relay_cfg.session_aes_key, 0, 49);
      memset(relay_cfg.session_iv, 0, 25);
      size_t len;
      atchops_base64_encode(aes_key, 32, (char *)relay_cfg.session_aes_key, 49, &len);
      atchops_base64_encode(iv, 16, (char *)relay_cfg.session_iv, 25, &len);
      // the b64 copies in relay_cfg are the working set; wipe the raw key
      mbedtls_platform_zeroize(aes_key, sizeof(aes_key));

      if (twin_keys) {
        // Generate D2C session AES key and IV
        unsigned char aes_key_d2c[32], iv_d2c[16];
        memset(aes_key_d2c, 0, 32);
        memset(iv_d2c, 0, 16);
        if (atchops_aes_generate_key(aes_key_d2c, ATCHOPS_AES_256) != 0) break;
        if (atchops_iv_generate(iv_d2c) != 0) break;

        relay_cfg.session_aes_key_d2c = (unsigned char *)malloc(49);
        relay_cfg.session_iv_d2c = (unsigned char *)malloc(25);
        if (!relay_cfg.session_aes_key_d2c || !relay_cfg.session_iv_d2c) {
          mbedtls_platform_zeroize(aes_key_d2c, sizeof(aes_key_d2c));
          break;
        }
        memset(relay_cfg.session_aes_key_d2c, 0, 49);
        memset(relay_cfg.session_iv_d2c, 0, 25);
        atchops_base64_encode(aes_key_d2c, 32, (char *)relay_cfg.session_aes_key_d2c, 49, &len);
        atchops_base64_encode(iv_d2c, 16, (char *)relay_cfg.session_iv_d2c, 25, &len);
        mbedtls_platform_zeroize(aes_key_d2c, sizeof(aes_key_d2c));
      }

      NOPORTS_LOGI(TAG, "NPT: generated %s session keys",
                   twin_keys ? "twin (C2D + D2C)" : "single (legacy)");

      // Encrypt the session keys with client's ephemeral RSA public key
      cJSON *client_pk = cJSON_GetObjectItem(payload, "clientEphemeralPK");
      cJSON *client_pk_type = cJSON_GetObjectItem(payload, "clientEphemeralPKType");

      if (!cJSON_IsString(client_pk) || !cJSON_IsString(client_pk_type) ||
          strcmp(cJSON_GetStringValue(client_pk_type), "rsa2048") != 0) {
        NOPORTS_LOGE(TAG, "NPT: missing or unsupported clientEphemeralPK/PKType");
        break;
      }

      atchops_rsa_key_public_key ephem_pk;
      atchops_rsa_key_public_key_init(&ephem_pk);

      char *pk_str = cJSON_GetStringValue(client_pk);
      if (atchops_rsa_key_populate_public_key(&ephem_pk, pk_str, strlen(pk_str)) != 0) {
        NOPORTS_LOGE(TAG, "NPT: failed to populate client ephemeral PK");
        atchops_rsa_key_public_key_free(&ephem_pk);
        break;
      }

      // The "rsa2048" label above is client-supplied and only names the type;
      // it does not constrain the actual modulus. atchops_rsa_encrypt now
      // enforces its output-buffer bound itself (at_c#709), so an oversized
      // modulus can no longer overflow enc_buf in _rsa_encrypt_b64 - but
      // rejecting it here first gives a precise error before any key
      // generation work is done. Note: the DER INTEGER
      // encoding pads the modulus with a leading 0x00 whenever its MSB is set
      // (always, for a real modulus), so a valid RSA-2048 key normally arrives
      // here with n.len == 257 — compare significant bytes, not raw length.
      {
        const unsigned char *n_bytes = ephem_pk.n.value;
        size_t n_sig = ephem_pk.n.len;
        while (n_sig > 0 && n_bytes[0] == 0x00) { n_bytes++; n_sig--; }
        if (n_sig != 256) {
          NOPORTS_LOGE(TAG, "NPT: client ephemeral PK modulus is not RSA-2048 "
                            "(significant bytes=%u, raw n.len=%u)",
                       (unsigned)n_sig, (unsigned)ephem_pk.n.len);
          atchops_rsa_key_public_key_free(&ephem_pk);
          break;
        }
      }

      session_aes_key_b64 = _rsa_encrypt_b64(&ephem_pk, relay_cfg.session_aes_key);
      session_iv_b64 = _rsa_encrypt_b64(&ephem_pk, relay_cfg.session_iv);
      if (twin_keys) {
        session_aes_key_d2c_b64 = _rsa_encrypt_b64(&ephem_pk, relay_cfg.session_aes_key_d2c);
        session_iv_d2c_b64 = _rsa_encrypt_b64(&ephem_pk, relay_cfg.session_iv_d2c);
      }
      atchops_rsa_key_public_key_free(&ephem_pk);

      e2ee_ok = session_aes_key_b64 && session_iv_b64 &&
                (!twin_keys || (session_aes_key_d2c_b64 && session_iv_d2c_b64));
    } while (0);

    if (!e2ee_ok) {
      // A partial key set would give the client a session that fails
      // confusingly downstream — reject the whole request instead.
      NOPORTS_LOGE(TAG, "NPT: session key setup failed, rejecting request");
      _sendNptError(requesting_atsign, session_id_str,
                    "Failed to set up session encryption");
      _zero_free_key(relay_cfg.session_aes_key);
      _zero_free_key(relay_cfg.session_iv);
      _zero_free_key(relay_cfg.session_aes_key_d2c);
      _zero_free_key(relay_cfg.session_iv_d2c);
      _zero_free_key(relay_cfg.relay_auth_aes_key);
      if (relay_cfg.escr_signing_key_uri) free(relay_cfg.escr_signing_key_uri);
      if (relay_cfg.rvd_auth_string) cJSON_free(relay_cfg.rvd_auth_string);
      if (session_aes_key_b64) free(session_aes_key_b64);
      if (session_iv_b64) free(session_iv_b64);
      if (session_aes_key_d2c_b64) free(session_aes_key_d2c_b64);
      if (session_iv_d2c_b64) free(session_iv_d2c_b64);
      cJSON_Delete(envelope);
      return;
    }
  }

  // Send success response BEFORE starting relay.
  // The relay task allocates ~8KB (6KB stack + buffers), and the TLS send
  // also needs ~16KB for its buffers. On ESP32 with limited heap, doing
  // both concurrently causes malloc failures. Send first, then start relay.
  // The client connects to SRVD after receiving this, so the relay will
  // be ready in time.
  {
    char *identifier = cJSON_GetStringValue(session_id);
    cJSON *res_payload = cJSON_CreateObject();
    cJSON_AddStringToObject(res_payload, "status", "connected");
    cJSON_AddItemReferenceToObject(res_payload, "sessionId", session_id);
    // Twin mode uses the canonical twin field names; legacy clients get
    // the old single-key names — same convention as the Dart daemon.
    if (twin_keys) {
      cJSON_AddStringToObject(res_payload, "aesKeyC2D", session_aes_key_b64);
      cJSON_AddStringToObject(res_payload, "ivC2D", session_iv_b64);
      cJSON_AddStringToObject(res_payload, "aesKeyD2C", session_aes_key_d2c_b64);
      cJSON_AddStringToObject(res_payload, "ivD2C", session_iv_d2c_b64);
    } else if (encrypt_rvd_traffic) {
      cJSON_AddStringToObject(res_payload, "sessionAESKey", session_aes_key_b64);
      cJSON_AddStringToObject(res_payload, "sessionIV", session_iv_b64);
    }

    cJSON *res_envelope = cJSON_CreateObject();
    cJSON_AddItemToObject(res_envelope, "payload", res_payload);

    // Sign the response
    char *signing_input = cJSON_PrintUnformatted(res_payload);
    unsigned char signature[256];
    memset(signature, 0, 256);

    // cJSON_PrintUnformatted returns NULL on OOM (realistic mid-session on an
    // ESP32) - strlen(NULL) here would panic the daemon
    res = -1;
    if (signing_input) {
      res = atchops_rsa_sign(skey, ATCHOPS_MD_SHA256,
                             (unsigned char *)signing_input,
                             strlen(signing_input), signature);
      cJSON_free(signing_input);
    }

    if (res == 0) {
      char b64sig[384];
      memset(b64sig, 0, 384);
      size_t sig_len;
      atchops_base64_encode(signature, 256, b64sig, 384, &sig_len);

      cJSON_AddStringToObject(res_envelope, "signature", b64sig);
      cJSON_AddStringToObject(res_envelope, "hashingAlgo", "sha256");
      cJSON_AddStringToObject(res_envelope, "signingAlgo", "rsa2048");

      char *res_value = cJSON_PrintUnformatted(res_envelope);

      // Send notification
      atclient_atkey res_atkey;
      atclient_atkey_init(&res_atkey);

      size_t klen = strlen(identifier) + strlen(_config.device_name) + 2;
      char *kname = (char *)malloc(klen);
      if (kname && res_value) {
        snprintf(kname, klen, "%s.%s", identifier, _config.device_name);

        atclient_atkey_create_shared_key(&res_atkey, kname, _config.atsign,
                                         requesting_atsign, NOPORTS_NS);

        atclient_atkey_metadata *meta = &res_atkey.metadata;
        atclient_atkey_metadata_set_is_public(meta, false);
        atclient_atkey_metadata_set_is_encrypted(meta, true);
        atclient_atkey_metadata_set_ttl(meta, 10000);

        // _verifyEnvelopeSignature used the worker to fetch the requester's
        // public key.  A concurrent statsNotification push from the atServer
        // can arrive in-band during that round-trip and leave garbage in the
        // worker's read buffer, making the next atclient_notify fail with
        // "no ':' token".  Reconnect here to guarantee a clean connection.
        _reconnectWorker();

        atclient_notify_params nparams;
        atclient_notify_params_init(&nparams);
        atclient_notify_params_set_atkey(&nparams, &res_atkey);
        atclient_notify_params_set_value(&nparams, res_value);
        atclient_notify_params_set_operation(&nparams, ATCLIENT_NOTIFY_OPERATION_UPDATE);

        int nret = _notifyWithRetry(worker, &nparams, NULL);
        if (nret != 0) {
          NOPORTS_LOGE(TAG, "NPT: failed to send success response to %s", requesting_atsign);
        } else {
          NOPORTS_LOGI(TAG, "NPT: sent success response to %s", requesting_atsign);
        }

        atclient_notify_params_free(&nparams);
        free(kname);
      } else {
        NOPORTS_LOGE(TAG, "NPT: failed to build success response (OOM)");
        free(kname); // free(NULL) is a no-op
      }

      atclient_atkey_free(&res_atkey);
      if (res_value) cJSON_free(res_value);
    }

    cJSON_Delete(res_envelope);
  }

  // Start the relay AFTER sending the success response.
  // This ensures TLS buffers from the notification send are freed before
  // the relay allocates its task stack and buffers.
  res = noports_relay_start(&_relays[slot], &relay_cfg);
  if (res != 0) {
    NOPORTS_LOGE(TAG, "NPT: failed to start relay");
    cJSON_Delete(envelope);
    // Relay start failed, so the relay task will never run to free the config
    // it took ownership of (noports_relay_start frees its own strdup'd copies on
    // failure). Free every daemon-owned allocation here, mirroring the e2ee-setup
    // failure cleanup above, or a relay-start failure — most likely under memory
    // pressure — leaks the whole session key set and compounds the exhaustion.
    _zero_free_key(relay_cfg.session_aes_key);
    _zero_free_key(relay_cfg.session_iv);
    _zero_free_key(relay_cfg.session_aes_key_d2c);
    _zero_free_key(relay_cfg.session_iv_d2c);
    _zero_free_key(relay_cfg.relay_auth_aes_key);
    if (relay_cfg.escr_signing_key_uri) free(relay_cfg.escr_signing_key_uri);
    if (relay_cfg.rvd_auth_string) cJSON_free(relay_cfg.rvd_auth_string);
    if (session_aes_key_b64) free(session_aes_key_b64);
    if (session_iv_b64) free(session_iv_b64);
    if (session_aes_key_d2c_b64) free(session_aes_key_d2c_b64);
    if (session_iv_d2c_b64) free(session_iv_d2c_b64);
    return;
  }

  if (_config.on_tunnel_open) {
    _config.on_tunnel_open(
      cJSON_GetStringValue(requested_host),
      (uint16_t)cJSON_GetNumberValue(requested_port),
      relay_cfg.session_id);
  }

  // noports_relay_start deep-copies (strdup) relay_auth_aes_key and
  // escr_signing_key_uri into the relay's own config, and the relay task frees
  // those copies on teardown — so the daemon still owns these originals and must
  // free them here, or they leak on every ESCR tunnel. (session_aes_key/iv and
  // rvd_auth_string are NOT copied: the relay takes over the daemon's pointers
  // and frees them in its own cleanup, so they must not be freed here.)
  if (relay_cfg.relay_auth_aes_key) {
    free(relay_cfg.relay_auth_aes_key);
    relay_cfg.relay_auth_aes_key = NULL;
  }
  if (relay_cfg.escr_signing_key_uri) {
    free(relay_cfg.escr_signing_key_uri);
    relay_cfg.escr_signing_key_uri = NULL;
  }

  if (session_aes_key_b64) free(session_aes_key_b64);
  if (session_iv_b64) free(session_iv_b64);
  if (session_aes_key_d2c_b64) free(session_aes_key_d2c_b64);
  if (session_iv_d2c_b64) free(session_iv_d2c_b64);
  cJSON_Delete(envelope);
}

// ============================================================================
// Private: Graceful shutdown
// ============================================================================

void NoPortsDaemon::_handleGracefulShutdown() {
  _should_run = false;
}

// ============================================================================
// Private: Envelope verification (from handler_commons.c)
// ============================================================================

bool NoPortsDaemon::_verifyEnvelopeSignature(void *env, const char *from_atsign) {
  cJSON *envelope = (cJSON *)env;
  atclient *worker = (atclient *)_worker_ctx;

  cJSON *signature = cJSON_GetObjectItem(envelope, "signature");
  cJSON *hashing_algo = cJSON_GetObjectItem(envelope, "hashingAlgo");
  cJSON *signing_algo = cJSON_GetObjectItem(envelope, "signingAlgo");
  cJSON *payload = cJSON_GetObjectItem(envelope, "payload");

  if (!cJSON_IsString(signature) || !cJSON_IsString(hashing_algo) ||
      !cJSON_IsString(signing_algo) || !cJSON_IsObject(payload)) {
    NOPORTS_LOGE(TAG, "Invalid envelope format for signature verification");
    return false;
  }

  // Get the requester's public key
  atclient_atkey pubkey;
  atclient_atkey_init(&pubkey);

  int res = atclient_atkey_create_public_key(&pubkey, "publickey",
                                             (char *)from_atsign, NULL);
  if (res != 0) {
    atclient_atkey_free(&pubkey);
    return false;
  }

  char *pk_buffer = NULL;
  res = atclient_get_public_key(worker, &pubkey, &pk_buffer, NULL);
  atclient_atkey_free(&pubkey);

  if (res != 0 || pk_buffer == NULL) {
    NOPORTS_LOGE(TAG, "Failed to get public key for %s", from_atsign);
    return false;
  }

  atchops_rsa_key_public_key requester_pk;
  atchops_rsa_key_public_key_init(&requester_pk);

  res = atchops_rsa_key_populate_public_key(&requester_pk, pk_buffer, strlen(pk_buffer));
  if (res != 0) {
    free(pk_buffer);
    return false;
  }

  // Decode the signature
  char *sig_str = cJSON_GetStringValue(signature);
  size_t sig_dec_len = 0;
  res = atchops_base64_decode(sig_str, strlen(sig_str),
                              (unsigned char *)pk_buffer, strlen(pk_buffer),
                              &sig_dec_len);
  if (res != 0) {
    NOPORTS_LOGE(TAG, "Failed to decode signature");
    free(pk_buffer);
    atchops_rsa_key_public_key_free(&requester_pk);
    return false;
  }

  // Verify
  char *payload_str = cJSON_PrintUnformatted(payload);
  char *hash_algo = cJSON_GetStringValue(hashing_algo);
  char *sign_algo = cJSON_GetStringValue(signing_algo);

  bool verified = false;

  if (strcmp(hash_algo, "sha256") == 0 && strcmp(sign_algo, "rsa2048") == 0) {
    res = atchops_rsa_verify(&requester_pk, ATCHOPS_MD_SHA256,
                             (unsigned char *)payload_str, strlen(payload_str),
                             (unsigned char *)pk_buffer);
    verified = (res == 0);
  }

  cJSON_free(payload_str);
  free(pk_buffer);
  atchops_rsa_key_public_key_free(&requester_pk);

  if (!verified) {
    NOPORTS_LOGE(TAG, "Envelope signature verification failed");
  }

  return verified;
}

bool NoPortsDaemon::_verifyEnvelopeContents(void *env, int payload_type) {
  cJSON *envelope = (cJSON *)env;

  cJSON *payload = cJSON_GetObjectItem(envelope, "payload");
  if (!cJSON_IsObject(payload)) return false;
  if (!cJSON_IsString(cJSON_GetObjectItem(envelope, "signature"))) return false;
  if (!cJSON_IsString(cJSON_GetObjectItem(envelope, "hashingAlgo"))) return false;
  if (!cJSON_IsString(cJSON_GetObjectItem(envelope, "signingAlgo"))) return false;
  if (!cJSON_IsString(cJSON_GetObjectItem(payload, "sessionId"))) return false;

  if (payload_type == 1) { // NPT
    if (!cJSON_IsString(cJSON_GetObjectItem(payload, "rvdHost"))) return false;
    if (!cJSON_IsString(cJSON_GetObjectItem(payload, "requestedHost"))) return false;

    // Ports are cast to uint16_t downstream, which silently wraps out-of-range
    // values (70000 -> 4464). Enforce 1..65535 here so a bad port is rejected
    // rather than dialed as some other, wrapped port.
    cJSON *rvp = cJSON_GetObjectItem(payload, "rvdPort");
    if (!cJSON_IsNumber(rvp)) return false;
    double rvpv = cJSON_GetNumberValue(rvp);
    if (rvpv < 1 || rvpv > UINT16_MAX) return false;

    cJSON *rp = cJSON_GetObjectItem(payload, "requestedPort");
    if (!cJSON_IsNumber(rp)) return false;
    double rpv = cJSON_GetNumberValue(rp);
    if (rpv < 1 || rpv > UINT16_MAX) return false;
  }

  return true;
}

// ============================================================================
// Private: Relay management
// ============================================================================

int NoPortsDaemon::_findFreeRelaySlot() {
  for (int i = 0; i < _max_relays; i++) {
    if (!noports_relay_is_running(&_relays[i]) &&
        _relays[i].state != RELAY_CONNECTING &&
        _relays[i].state != RELAY_AUTHENTICATING) {
      return i;
    }
  }
  return -1;
}

void NoPortsDaemon::_cleanupFinishedRelays() {
  for (int i = 0; i < NOPORTS_MAX_RELAYS; i++) {
    if (_relays[i].state == RELAY_STOPPED || _relays[i].state == RELAY_ERROR) {
      if (_relays[i].task_handle == NULL) {
        if (_config.on_tunnel_close) {
          _config.on_tunnel_close(_relays[i].config.session_id);
        }
        _relays[i].state = RELAY_IDLE;
        _relays[i].bytes_in = 0;
        _relays[i].bytes_out = 0;
        _relays[i].start_ms = 0;
        _relays[i].active_sessions = 0;
        memset(&_relays[i].config, 0, sizeof(NoPortsRelayConfig));
      }
    }
  }
}

// ============================================================================
// Private: Reconnection
// ============================================================================

// Re-run root-directory lookup and update cached atServer address.
// Returns true if a new host/port was discovered (both options structs updated).
bool NoPortsDaemon::_refreshAtServerCache() {
  if (_via_proxy) {
    // The atServer address IS the reverse proxy — there is no directory to
    // re-ask, and the address never changes.
    NOPORTS_LOGI(TAG, "atServer is a fixed reverse proxy (%s:%d) — no re-lookup",
                 _atserver_host, _atserver_port);
    return false;
  }

  char *resolved_host = nullptr;
  uint16_t resolved_port = 0;

  NOPORTS_LOGI(TAG, "Re-looking up atServer for %s via %s:%d ...",
               _config.atsign, _root_host, _root_port);

  int res = atdirectory_lookup_once(_root_host, _root_port,
                                    _config.atsign,
                                    &resolved_host, &resolved_port);
  if (res != 0 || !resolved_host || resolved_port == 0) {
    if (resolved_host) free(resolved_host);
    NOPORTS_LOGW(TAG, "atServer re-lookup failed (%d) — keeping cached address", res);
    return false;
  }

  bool changed = (strcmp(_atserver_host, resolved_host) != 0) ||
                 (_atserver_port != resolved_port);

  if (!changed) {
    free(resolved_host);
    NOPORTS_LOGI(TAG, "atServer address unchanged: %s:%d",
                 _atserver_host, _atserver_port);
    return false;
  }

  NOPORTS_LOGI(TAG, "atServer address changed: %s:%d -> %s:%d",
               _atserver_host, _atserver_port, resolved_host, resolved_port);

  snprintf(_atserver_host, sizeof(_atserver_host), "%s", resolved_host);
  _atserver_port = resolved_port;
  free(resolved_host);

  // Push new address into both options structs so the next auth uses it
  if (_monitor_options) {
    atclient_authenticate_options_set_atserver_host(
      (atclient_authenticate_options *)_monitor_options, _atserver_host);
    atclient_authenticate_options_set_atserver_port(
      (atclient_authenticate_options *)_monitor_options, _atserver_port);
  }
  if (_worker_options) {
    atclient_authenticate_options_set_atserver_host(
      (atclient_authenticate_options *)_worker_options, _atserver_host);
    atclient_authenticate_options_set_atserver_port(
      (atclient_authenticate_options *)_worker_options, _atserver_port);
  }
  return true;
}

bool NoPortsDaemon::_reconnectMonitor() {
  // Too many consecutive failures — likely memory fragmentation preventing
  // mbedTLS from allocating contiguous blocks for TLS handshake.
  // A reboot is the only reliable fix on ESP32.
  if (_reconnect_failures >= NOPORTS_MAX_RECONNECT_FAILURES) {
    NOPORTS_LOGE(TAG, "Monitor reconnect failed %d times — rebooting (heap: %u, largest free: %u)",
                 _reconnect_failures,
                 (unsigned)esp_get_free_heap_size(),
                 (unsigned)heap_caps_get_largest_free_block(MALLOC_CAP_8BIT));
    delay(1000);  // brief pause for serial flush
    esp_restart();
  }

  // Exponential backoff: 5s, 10s, 20s, 30s, 30s, ...
  if (_reconnect_failures > 0) {
    unsigned long backoff_ms = 5000UL << (_reconnect_failures - 1);
    if (backoff_ms > 30000) backoff_ms = 30000;
    NOPORTS_LOGI(TAG, "Reconnect backoff: %lu ms (attempt %d, free heap: %u)",
                 backoff_ms, _reconnect_failures + 1,
                 (unsigned)esp_get_free_heap_size());
    delay(backoff_ms);
  }

  NOPORTS_LOGI(TAG, "Reconnecting monitor...");

  // Wait for heap only when the relay has just stopped (pcbs <= 1).
  // When pcbs > 1 the relay is actively running and holds pbufs that fragment
  // the heap — those pbufs will NOT be released until sessions close, so
  // waiting here is pointless and blocks notification delivery for up to 30s,
  // which freezes all active SSH sessions.  Skip the wait; TLS will either
  // succeed (brief lull between relay bursts) or fail and be retried quickly.
  if (noports_relay_get_pcb_count() <= 1) {
    uint32_t ws = millis();
    while ((millis() - ws) < 30000) {
      uint32_t total   = esp_get_free_heap_size();
      uint32_t largest = heap_caps_get_largest_free_block(MALLOC_CAP_8BIT);
      int      pcbs    = noports_relay_get_pcb_count();
      bool heap_ok = (total >= NOPORTS_TLS_MIN_FREE_HEAP) &&
                     (largest >= NOPORTS_TLS_MIN_CONTIGUOUS_HEAP || pcbs <= 1);
      if (heap_ok) break;
      NOPORTS_LOGW(TAG, "Monitor reconnect: waiting for heap (total=%u, largest=%u, relay_pcbs=%d)",
                   total, largest, pcbs);
      delay(200);
    }
    {
      uint32_t total   = esp_get_free_heap_size();
      uint32_t largest = heap_caps_get_largest_free_block(MALLOC_CAP_8BIT);
      int      pcbs    = noports_relay_get_pcb_count();
      bool heap_ok = (total >= NOPORTS_TLS_MIN_FREE_HEAP) &&
                     (largest >= NOPORTS_TLS_MIN_CONTIGUOUS_HEAP || pcbs <= 1);
      if (!heap_ok) {
        NOPORTS_LOGW(TAG, "Monitor reconnect: heap not ready after 30s (total=%u, largest=%u, relay_pcbs=%d) — proceeding anyway",
                     total, largest, pcbs);
      }
    }
  } else {
    NOPORTS_LOGD(TAG, "Monitor reconnect: relay active (pcbs=%d), skipping heap wait",
                 noports_relay_get_pcb_count());
  }

  atclient *monitor = (atclient *)_monitor_ctx;
  atclient_atkeys *keys = (atclient_atkeys *)_atkeys;

  // Fully tear down the old monitor connection before re-auth
  atclient_monitor_free(monitor);
  atclient_monitor_init(monitor);

  int res = atclient_monitor_pkam_authenticate(
    monitor, _config.atsign, keys,
    (atclient_authenticate_options *)_monitor_options);

  if (res != 0) {
    NOPORTS_LOGE(TAG, "Monitor reconnect auth failed: %d", res);
    // Re-lookup the atServer address — it may have moved (e.g. infrastructure
    // change).  If a new address is found, retry auth once before giving up.
    if (_refreshAtServerCache()) {
      NOPORTS_LOGI(TAG, "Retrying monitor auth with refreshed atServer address");
      atclient_monitor_free(monitor);
      atclient_monitor_init(monitor);
      res = atclient_monitor_pkam_authenticate(
        monitor, _config.atsign, keys,
        (atclient_authenticate_options *)_monitor_options);
      if (res != 0) {
        NOPORTS_LOGE(TAG, "Monitor reconnect auth failed again with new address: %d", res);
      }
    }
    if (res != 0) {
      if (_reconnect_failures < 255) _reconnect_failures++;
      return false;
    }
    NOPORTS_LOGI(TAG, "Monitor reconnect succeeded after atServer address refresh");
  }

  res = atclient_monitor_start(monitor, _monitor_regex);
  if (res != 0) {
    NOPORTS_LOGE(TAG, "Monitor reconnect start failed: %d", res);
    if (_reconnect_failures < 255) _reconnect_failures++;
    return false;
  }

  // Re-apply monitor read timeout (pkam_authenticate resets it to 3s)
  atclient_monitor_set_read_timeout(monitor, NOPORTS_MONITOR_READ_TIMEOUT_MS);

  _reconnect_failures = 0;
  NOPORTS_LOGI(TAG, "Monitor reconnected (TLS failure counter reset)");
  return true;
}

bool NoPortsDaemon::_reconnectWorker() {
  NOPORTS_LOGI(TAG, "Reconnecting worker...");

  // Same logic as monitor reconnect: skip heap wait when relay is active.
  if (noports_relay_get_pcb_count() <= 1) {
    uint32_t ws = millis();
    while ((millis() - ws) < 30000) {
      uint32_t total   = esp_get_free_heap_size();
      uint32_t largest = heap_caps_get_largest_free_block(MALLOC_CAP_8BIT);
      int      pcbs    = noports_relay_get_pcb_count();
      bool heap_ok = (total >= NOPORTS_TLS_MIN_FREE_HEAP) &&
                     (largest >= NOPORTS_TLS_MIN_CONTIGUOUS_HEAP || pcbs <= 1);
      if (heap_ok) break;
      NOPORTS_LOGW(TAG, "Worker reconnect: waiting for heap (total=%u, largest=%u, relay_pcbs=%d)",
                   total, largest, pcbs);
      delay(200);
    }
    {
      uint32_t total   = esp_get_free_heap_size();
      uint32_t largest = heap_caps_get_largest_free_block(MALLOC_CAP_8BIT);
      int      pcbs    = noports_relay_get_pcb_count();
      bool heap_ok = (total >= NOPORTS_TLS_MIN_FREE_HEAP) &&
                     (largest >= NOPORTS_TLS_MIN_CONTIGUOUS_HEAP || pcbs <= 1);
      if (!heap_ok) {
        NOPORTS_LOGW(TAG, "Worker reconnect: heap not ready after 30s (total=%u, largest=%u, relay_pcbs=%d) — proceeding anyway",
                     total, largest, pcbs);
      }
    }
  } else {
    NOPORTS_LOGD(TAG, "Worker reconnect: relay active (pcbs=%d), skipping heap wait",
                 noports_relay_get_pcb_count());
  }

  atclient *worker = (atclient *)_worker_ctx;
  atclient_atkeys *keys = (atclient_atkeys *)_atkeys;

  // Fully tear down the old worker connection
  atclient_free(worker);
  atclient_init(worker);

  int res = atclient_pkam_authenticate(
    worker, _config.atsign, keys,
    (atclient_authenticate_options *)_worker_options, NULL);

  if (res != 0) {
    NOPORTS_LOGE(TAG, "Worker reconnect auth failed: %d (heap: %u)", res,
                 (unsigned)esp_get_free_heap_size());
    // Re-lookup the atServer address — it may have moved.
    // If a new address is found, retry auth once before giving up.
    if (_refreshAtServerCache()) {
      NOPORTS_LOGI(TAG, "Retrying worker auth with refreshed atServer address");
      atclient_free(worker);
      atclient_init(worker);
      res = atclient_pkam_authenticate(
        worker, _config.atsign, keys,
        (atclient_authenticate_options *)_worker_options, NULL);
      if (res != 0) {
        NOPORTS_LOGE(TAG, "Worker reconnect auth failed again with new address: %d", res);
      }
    }
    if (res != 0) {
      if (_reconnect_failures < 255) _reconnect_failures++;
      return false;
    }
    NOPORTS_LOGI(TAG, "Worker reconnect succeeded after atServer address refresh");
  }

  NOPORTS_LOGI(TAG, "Worker reconnected");
  _worker_last_used_ms = millis();
  return true;
}

int NoPortsDaemon::_notifyWithRetry(void *w, void *np, char **notification_id) {
  atclient *worker = (atclient *)w;
  atclient_notify_params *params = (atclient_notify_params *)np;

  int res = atclient_notify(worker, params, notification_id);
  if (res != 0) {
    NOPORTS_LOGW(TAG, "Notify failed (%d), reconnecting worker and retrying...", res);
    if (_reconnectWorker()) {
      // worker pointer is unchanged (same allocation, re-authenticated)
      res = atclient_notify(worker, params, notification_id);
    }
  }
  if (res == 0) _worker_last_used_ms = millis();
  return res;
}

// ============================================================================
// Private: Utility
// ============================================================================

void NoPortsDaemon::_setError(const char *fmt, ...) {
  va_list args;
  va_start(args, fmt);
  vsnprintf(_last_error, sizeof(_last_error), fmt, args);
  va_end(args);
  NOPORTS_LOGE(TAG, "%s", _last_error);
}
