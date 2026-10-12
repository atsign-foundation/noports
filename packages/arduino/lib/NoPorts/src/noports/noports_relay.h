/**
 * @file noports_relay.h
 * @brief TCP socket relay (srv equivalent) for ESP32
 *
 * Replaces the srv (socket relay valve) component from the C sshnpd.
 * The original srv uses pthreads + mbedtls_net for socket-to-socket relaying.
 * This ESP32 version uses FreeRTOS tasks + WiFiClient for TCP connections.
 *
 * The relay creates a bidirectional bridge between:
 *   - The RVD (rendezvous daemon) at rvd_host:rvd_port
 *   - A local service at local_host:local_port
 *
 * Optionally supports:
 *   - RVD authentication (signing session with RSA key)
 *   - End-to-end AES-CTR encryption of traffic
 */

#ifndef NOPORTS_RELAY_H
#define NOPORTS_RELAY_H

#include <Arduino.h>
#include <WiFiClient.h>

// Forward declaration
struct NoPortsRelayConfig;

// Relay states
enum NoPortsRelayState {
  RELAY_IDLE,
  RELAY_CONNECTING,
  RELAY_AUTHENTICATING,
  RELAY_RUNNING,
  RELAY_ERROR,
  RELAY_STOPPED,
};

/**
 * @brief Configuration for a single relay instance
 */
struct NoPortsRelayConfig {
  // RVD (rendezvous) side
  const char *rvd_host;
  uint16_t    rvd_port;

  // Local service side
  const char *local_host;   // typically "127.0.0.1" or "localhost"
  uint16_t    local_port;

  // Authentication — legacy payload mode
  bool        rv_auth;           // authenticate to RVD? (legacy)
  char       *rvd_auth_string;   // JSON auth envelope (legacy)

  // ESCR authentication (Encrypted Signed Challenge-Response)
  bool        escr_auth;             // use ESCR instead of legacy payload auth
  char       *relay_auth_aes_key;    // AES-256 key string from NPT payload
  char       *escr_signing_key_uri;  // signing key URI (sk field in ESCR envelope)
  void       *escr_signing_key;      // atchops_rsa_key_private_key* (NOT owned by relay)

  // End-to-end encryption
  bool           rv_e2ee;             // encrypt traffic?
  unsigned char *session_aes_key;     // base64 AES-256 key (C2D)
  unsigned char *session_iv;          // base64 IV (C2D)
  unsigned char *session_aes_key_d2c; // base64 AES-256 key (D2C), NULL for single-key
  unsigned char *session_iv_d2c;      // base64 IV (D2C), NULL for single-key

  // Multi-mode (for NPT requests)
  bool multi;

  // Idle timeout in milliseconds (0 = use default 60s)
  uint32_t idle_timeout_ms;

  // Session ID for tracking
  char session_id[64];

  // Max sub-connections per relay session (0 = use MAX_RELAY_SUBS default)
  uint8_t max_subs;
};

/**
 * @brief A running relay instance
 *
 * Managed internally by the daemon. Each NPT request spawns one relay
 * as a FreeRTOS task instead of fork()+pthread as in the Linux version.
 */
struct NoPortsRelay {
  NoPortsRelayConfig config;
  NoPortsRelayState  state;
  TaskHandle_t       task_handle;
  WiFiClient         rvd_client;    // connection to RVD
  WiFiClient         local_client;  // connection to local service
  volatile bool      should_run;

  // Live byte counters (updated from relay task, read from main loop)
  volatile uint32_t  bytes_in;      // RVD → local
  volatile uint32_t  bytes_out;     // local → RVD
  volatile uint32_t  start_ms;      // millis() when relay entered RUNNING

  // Active sub-connection count (multi mode: 0..MAX_RELAY_SUBS)
  volatile uint8_t   active_sessions;

  // AES-CTR state for encryption (if enabled)
  // Uses mbedtls_aes_context from ESP-IDF's built-in mbedTLS
  void *encrypter; // opaque, cast to internal aes_ctr_state*
  void *decrypter;
};

/**
 * @brief Initialize a relay config with defaults
 */
void noports_relay_config_init(NoPortsRelayConfig *cfg);

/**
 * @brief Start a relay as a FreeRTOS task
 *
 * This replaces the fork() + run_srv_process() from the C sshnpd.
 * Returns immediately; the relay runs in the background.
 *
 * @param relay  Pointer to relay struct (caller must keep alive)
 * @param config Relay configuration (copied internally)
 * @return 0 on success, non-zero on failure
 */
int noports_relay_start(NoPortsRelay *relay, const NoPortsRelayConfig *config);

/**
 * @brief Stop a running relay
 */
void noports_relay_stop(NoPortsRelay *relay);

/**
 * @brief Check if a relay is still running
 */
bool noports_relay_is_running(const NoPortsRelay *relay);

/**
 * @brief Get current number of relay TCP sockets in use
 */
int noports_relay_get_pcb_count();

/**
 * @brief Get the maximum number of relay TCP sockets allowed (platform-dependent)
 */
int noports_relay_get_pcb_max();

/**
 * @brief Get relay task CPU busyness (0-100%).
 *        Measured as the ratio of data-moving iterations to total iterations
 *        over a 1-second rolling window inside the relay FreeRTOS task.
 *        Returns 0 when no relay session is active.
 */
uint8_t noports_relay_get_cpu_pct();

/**
 * @brief Return the maximum number of sub-connections each relay session
 *        should be allowed, given @p n_clients simultaneous relay sessions.
 *
 * Derived from the total relay PCB budget so that
 *   n_clients × (1 ctrl + n_subs×2 data) ≤ MAX_RELAY_PCBS
 * Clamped to [1, MAX_RELAY_SUBS].
 * n_clients is the number of concurrent TCP clients being relayed.
 */
uint8_t noports_relay_subs_for_clients(uint8_t n_clients);

#endif // NOPORTS_RELAY_H
