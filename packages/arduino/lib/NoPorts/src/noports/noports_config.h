/**
 * @file noports_config.h
 * @brief Configuration structures and constants for the NoPorts daemon
 *
 * Mirrors sshnpd_params from the C sshnpd implementation, adapted for
 * Arduino/ESP32 constraints (no argparse, no filesystem paths by default).
 */

#ifndef NOPORTS_CONFIG_H
#define NOPORTS_CONFIG_H

#include <Arduino.h>

// ---------------------------------------------------------------------------
// Version & protocol constants (from sshnpd/version.h and sshnpd/sshnpd.h)
// ---------------------------------------------------------------------------
#define NOPORTS_VERSION          "1.5.0"
#define NOPORTS_CORE_PKG_VERSION "c1.5.0-arduino"

#define NOPORTS_DEFAULT_ROOT_HOST "root.atsign.org"
#define NOPORTS_DEFAULT_ROOT_PORT 64

#define NOPORTS_NS       "sshnp"   // atProtocol namespace (must match client)
#define NOPORTS_NS_LEN   5

// Monitor read timeout in milliseconds — keep short so the Arduino loop()
// remains responsive to touch input (the UI runs on the same core).
#define NOPORTS_MONITOR_READ_TIMEOUT_MS  100
// Noop timeout – after this many ms without data we send a noop/reconnect
#define NOPORTS_MONITOR_NOOP_TIMEOUT_MS  40000

// Maximum consecutive monitor reconnect failures before forced ESP.restart().
// With 30s max backoff, 10 failures = ~5 minutes of retrying before reboot.
// This handles memory fragmentation where mbedTLS can't allocate contiguous
// blocks for TLS even with sufficient total free heap.
#define NOPORTS_MAX_RECONNECT_FAILURES 10

// Minimum TOTAL free heap before attempting a TLS reconnect.
// mbedTLS makes many small-to-medium allocations rather than one huge
// contiguous block, so total free is the right wait metric.
// Observed on CYD (ESP32, no PSRAM):
//   TLS SUCCEEDS: total=46 KB, largest_contiguous=11 KB (fragmented post-relay)
//   TLS FAILS:    total=9 KB  (heap genuinely exhausted mid-relay)
// 30 KB is a comfortable margin above the ~20-25 KB mbedTLS peak usage.
//
// Also used as the OOM guard in daemon.loop(): if heap < this threshold we
// skip calling atclient_monitor_read() to avoid 'Failed to allocate read
// buffer' spam.  The SDK allocates READ_BUF_SIZE=4096 bytes on every read.
// With 4 active SSH sessions the relay task transiently allocates ~10-14 KB
// of pbufs between our check and the SDK malloc, so we need >4+14=18 KB of
// margin.  40 KB gives ~22 KB of headroom, preventing the race.
#define NOPORTS_TLS_MIN_FREE_HEAP        40000   // min total free heap for TLS reconnect

// Largest-contiguous block required before attempting TLS while relay subs
// are active (pcbs > 1).  With active subs, pbufs fragment DRAM even when
// total free is >60 KB, so this condition gates the wait loop.
// Observed on CYD (ESP32):
//   TLS SUCCEEDS: largest=22516 (3 active subs, total=39 KB)
//   TLS SUCCEEDS: largest=11252 (0 subs, post-drain)
//   TLS FAILS:    largest=1396  (total=9 KB — genuine heap exhaustion)
// 20 KB gives ~2.5 KB margin below the observed minimum success value.
#define NOPORTS_TLS_MIN_CONTIGUOUS_HEAP  20000

// Default worker keep-alive interval (ms).  The worker TLS connection is
// periodically exercised with a heartbeat so that intermediate NAT/firewall
// tables don't silently expire the TCP session between tunnel uses.
// 4 minutes is below most residential NAT timeouts (typically 5-30 min).
// Set to 0 to disable.  Overridden at runtime via setWorkerKeepaliveMs().
#define NOPORTS_WORKER_KEEPALIVE_MS  240000UL

// Maximum number of permitopen entries
#define NOPORTS_MAX_PERMITOPEN 255

// Maximum number of manager atSigns
#define NOPORTS_MAX_MANAGERS   16

// ---------------------------------------------------------------------------
// Notification key types (from sshnpd/sshnpd.h)
// ---------------------------------------------------------------------------
enum NoPortsNotificationKey {
  NK_NONE = 0,
  NK_SSHPUBLICKEY,          // not usable on Arduino
  NK_PING,
  NK_SSH_REQUEST,           // not usable on Arduino (no SSH server)
  NK_NPT_REQUEST,           // primary use-case on Arduino
  NK_GRACEFUL_SHUTDOWN,
};

// Must match the number of NK_* entries minus NK_NONE
#define NOPORTS_NOTIFICATION_KEYS_LEN 5

// ---------------------------------------------------------------------------
// PermitOpen entry
// ---------------------------------------------------------------------------
struct NoPortsPermitOpen {
  const char *host;  // e.g. "localhost"
  uint16_t    port;  // 0 means wildcard '*'
};

// ---------------------------------------------------------------------------
// NoPortsConfig – equivalent of sshnpd_params
// ---------------------------------------------------------------------------
struct NoPortsConfig {
  // Required
  const char *atsign;          // e.g. "@mydevice"
  const char *device_name;     // e.g. "esp32_sensor"
  const char *manager_list[NOPORTS_MAX_MANAGERS]; // allowed manager atSigns
  uint8_t     manager_count;

  // Optional
  // Root server spec (Dart AtRootDomain / at_lookup convention):
  //   host / host:port         → atDirectory lookup (default port 64)
  //   proxy:host[:port]        → no atDirectory: the atServer address is the
  //                              reverse proxy itself, for 443-only networks
  //                              e.g. "proxy:proxy0001.atsign.org:443"
  const char *root_domain;     // NULL → NOPORTS_DEFAULT_ROOT_HOST
  uint16_t    root_port;       // 0   → NOPORTS_DEFAULT_ROOT_PORT

  uint16_t    local_sshd_port; // default 22 (used for ssh_request, not useful on Arduino)
  bool        verbose;
  bool        hide;            // if true, don't publish device info

  // Policy service – if non-NULL, authorisation is delegated via RPC to this
  // atSign instead of checking manager_list.  Set either manager_count > 0 OR
  // policy_atsign, not both.
  const char *policy_atsign;   // e.g. "@mypolicyservice"

  // PermitOpen – which host:port combinations the device is willing to relay
  NoPortsPermitOpen permitopen[NOPORTS_MAX_PERMITOPEN];
  uint8_t           permitopen_count;

  // Keys – raw base64-encoded atKeys (loaded from SPIFFS/LittleFS or hardcoded)
  // See noports_keys.h for helpers to load from filesystem
  const char *pkam_private_key_base64;
  const char *pkam_public_key_base64;
  const char *encrypt_private_key_base64;
  const char *encrypt_public_key_base64;
  const char *self_encryption_key_base64;
  const char *enrollment_id;              // APKAM enrollment ID (required for APKAM auth)

  // Callbacks (optional)
  // Called when a tunnel is established – host:port that is being relayed
  void (*on_tunnel_open)(const char *host, uint16_t port, const char *session_id);
  // Called when a tunnel closes
  void (*on_tunnel_close)(const char *session_id);
  // Called on ping
  void (*on_ping)(const char *from_atsign);
};

/**
 * @brief Apply sensible defaults to a NoPortsConfig
 */
inline void noports_config_init(NoPortsConfig *cfg) {
  memset(cfg, 0, sizeof(NoPortsConfig));
  cfg->root_domain     = NULL; // will use NOPORTS_DEFAULT_ROOT_HOST
  cfg->root_port       = 0;   // will use NOPORTS_DEFAULT_ROOT_PORT
  cfg->local_sshd_port = 22;
  cfg->verbose         = false;
  cfg->hide            = false;
  cfg->manager_count   = 0;
  cfg->policy_atsign   = NULL;
  cfg->permitopen_count = 0;
  cfg->on_tunnel_open  = NULL;
  cfg->on_tunnel_close = NULL;
  cfg->on_ping         = NULL;
}

#endif // NOPORTS_CONFIG_H
