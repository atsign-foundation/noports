/**
 * @file noports_daemon.h
 * @brief Main NoPorts daemon class for Arduino/ESP32
 *
 * This is the primary interface. It mirrors the flow of main.c and daemon.c
 * from the C sshnpd, adapted for Arduino's setup()/loop() paradigm.
 *
 * Usage:
 *   1. Create a NoPortsDaemon instance
 *   2. Configure it with a NoPortsConfig
 *   3. Call begin() in setup() – this authenticates and starts monitoring
 *   4. Call loop() in loop() – this processes incoming notifications
 *   5. Optionally call stop() to shut down
 */

#ifndef NOPORTS_DAEMON_H
#define NOPORTS_DAEMON_H

#include <Arduino.h>
#include "noports_config.h"
#include "noports_relay.h"

// Maximum concurrent relays (limited by memory/sockets)
// S3 has more SRAM/PSRAM and a larger lwIP PCB pool (see sdkconfig.defaults.s3)
#ifdef ESP32S3_2432S028R
#define NOPORTS_MAX_RELAYS 6
#else
#define NOPORTS_MAX_RELAYS 5
#endif

// ---------------------------------------------------------------------------
// Policy-service RPC pending state
// ---------------------------------------------------------------------------

// Per-sender policy-check throttle (DoS mitigation).
//   NOPORTS_POLICY_COOLDOWN_SLOTS — size of the LRU table of recent senders.
//   NOPORTS_POLICY_COOLDOWN_MS    — minimum interval between accepted policy
//     checks for the same atSign.  A single sender can therefore spend at most
//     one policy-check slot per this interval; bursts in between are dropped.
//     Kept modest so a manager opening a second tunnel is not noticeably
//     delayed, while a flooding atSign cannot monopolise the single slot.
#define NOPORTS_POLICY_COOLDOWN_SLOTS 8
#define NOPORTS_POLICY_COOLDOWN_MS    2000UL

/** Type of request pending policy authorization */
enum NoPortsPolicyPendingType {
  NOPORTS_POLICY_NONE = 0,
  NOPORTS_POLICY_PING,   ///< awaiting auth for a ping response
  NOPORTS_POLICY_NPT,    ///< awaiting auth for an NPT tunnel request
};

/**
 * @brief Holds the state of a single in-flight policy authorisation check.
 *
 * Only one check can be outstanding at a time on the ESP32.
 * The request is sent via the worker; the response arrives on the monitor
 * (key pattern: @device:<type>.<reqId>.auth_checks.__rpcs.sshnp@policy_atsign).
 */
struct NoPortsPolicyPending {
  bool                     in_use;
  NoPortsPolicyPendingType type;
  uint32_t                 req_id;
  uint32_t                 sent_at_ms;  ///< millis() when the RPC was sent
  char                     requesting_atsign[64];
  void                    *envelope;   ///< cJSON* for NPT, nullptr for ping
};

/**
 * @brief NoPorts daemon states
 */
enum NoPortsDaemonState {
  DAEMON_UNINITIALIZED,
  DAEMON_INITIALIZING,
  DAEMON_AUTHENTICATING,
  DAEMON_MONITORING,
  DAEMON_ERROR,
  DAEMON_STOPPED,
};

/**
 * @brief The main daemon class
 *
 * Encapsulates all the global state from the C sshnpd (atclient, monitor,
 * signing keys, etc.) into a single class suitable for Arduino.
 */
class NoPortsDaemon {
public:
  NoPortsDaemon();
  ~NoPortsDaemon();

  /**
   * @brief Initialize and start the daemon
   *
   * Performs the equivalent of sshnpd main():
   *   1. Validates config
   *   2. Loads/populates atKeys
   *   3. PKAM authenticates the monitor connection
   *   4. PKAM authenticates the worker connection
   *   5. Publishes device info (unless hide=true)
   *   6. Starts monitoring for notifications
   *
   * @param config Configuration (copied internally)
   * @return true on success, false on failure
   */
  bool begin(const NoPortsConfig &config);

  /**
   * @brief Process one iteration of the monitor loop
   *
   * Call this from Arduino's loop(). It checks for incoming notifications
   * and dispatches handlers (ping, npt_request, etc.)
   *
   * This is non-blocking with a configurable timeout. It is the equivalent
   * of one iteration of main_loop() from daemon.c.
   */
  void loop();

  /**
   * @brief Gracefully stop the daemon
   */
  void stop();

  /**
   * @brief Check if the daemon is running
   */
  bool isRunning() const;

  /**
   * @brief Get current daemon state
   */
  NoPortsDaemonState getState() const;

  /**
   * @brief Get number of active relays
   */
  uint8_t getActiveRelayCount() const;

  /**
   * @brief Get aggregate throughput across all active relays
   * @param bytes_in  Total bytes RVD->local (downloaded)
   * @param bytes_out Total bytes local->RVD (uploaded)
   */
  void getThroughput(uint32_t &bytes_in, uint32_t &bytes_out) const;

  /**
   * @brief Get the last error message
   */
  const char* getLastError() const;

  /**
   * @brief Get consecutive monitor reconnect failure count
   * Resets to 0 on successful reconnect. Triggers ESP.restart()
   * when it reaches NOPORTS_MAX_RECONNECT_FAILURES.
   */
  uint8_t getReconnectFailures() const;

  /**
   * @brief Get current number of relay TCP sockets in use
   */
  int getRelayPcbCount() const;

  /**
   * @brief Get the maximum number of relay TCP sockets allowed (platform-dependent)
   */
  int getRelayPcbMax() const;

  /**
   * @brief Get relay task CPU busyness percentage (0-100).
   *        Time-weighted: measures fraction of wall-clock time where data was
   *        actually forwarded, over a 1-second rolling window.
   *        Returns 0 when no relay session is active.
   */
  uint8_t getRelayCpuPct() const;

  /**
   * @brief Set worker TLS keep-alive interval.
   *        A heartbeat is sent on the worker connection every @p ms
   *        milliseconds to prevent intermediate NAT/firewall tables
   *        from expiring the session.  Set to 0 to disable.
   */
  void setWorkerKeepaliveMs(uint32_t ms);

  /**
   * @brief Set maximum concurrent relay sub-connections (1–5, default 2).
   *        Takes effect on the next NPT request; does not affect running sessions.
   */
  // Max TCP session slots per relay task (1–4, default 2).
  // Each slot = one rvd socket + one local socket.
  // The relay PCB budget check enforces the hardware limit independently.
  void setMaxRelays(uint8_t max) { _max_relays = (max >= 1 && max <= NOPORTS_MAX_RELAYS) ? max : NOPORTS_MAX_RELAYS; }
  uint8_t getMaxRelays() const { return _max_relays; }

private:
  // Daemon state
  NoPortsDaemonState _state;
  NoPortsConfig      _config;
  volatile bool      _should_run;
  char               _last_error[128];

  // atProtocol handles — stored as opaque pointers so the header
  // doesn't pull in the full atSDK type definitions.
  // The .cpp file casts these to the proper types.
  void *_monitor_ctx;       // atclient (monitor)
  void *_worker_ctx;        // atclient (worker)
  void *_atkeys;            // atclient_atkeys
  void *_signing_key;       // atchops_rsa_key_private_key (encrypt key, for notification signing)
  void *_pkam_signing_key;  // atchops_rsa_key_private_key (APKAM key, for ESCR auth)
  void *_monitor_options;   // atclient_authenticate_options
  void *_worker_options;    // atclient_authenticate_options

  // Ping response (pre-built JSON string)
  char *_ping_response;

  // Monitor regex
  char *_monitor_regex;

  // Root server (atDirectory), or the reverse proxy when _via_proxy is set
  char     _root_host[254];
  uint16_t _root_port;
  // 'proxy:' root spec — _root_host:_root_port IS the atServer address
  // (via a protocol-aware reverse proxy); no atDirectory lookups at all
  bool     _via_proxy;

  // Resolved atServer address — populated once at startup via atdirectory_lookup_once().
  // Subsequent pkam_authenticate calls use this directly, avoiding a root TLS
  // connection on every monitor/worker reconnect.  Empty string = not yet resolved.
  char     _atserver_host[254];
  uint16_t _atserver_port;

  // Active relays
  NoPortsRelay _relays[NOPORTS_MAX_RELAYS];
  uint8_t      _relay_count;

  // Timeout tracking
  uint32_t _timeout_counter;
  uint8_t  _reconnect_failures;    // consecutive TLS connection failures (monitor + worker)
  uint8_t  _monitor_fail_streak;   // consecutive monitor-read failures; used to detect dead monitor socket

  // Worker TLS keep-alive
  uint32_t _worker_keepalive_ms;  // 0 = disabled; heartbeat interval in ms
  uint32_t _worker_last_used_ms;  // millis() of last worker activity

  // Max relay sub-connections per session (default 2, range 1-NOPORTS_MAX_RELAYS)
  uint8_t _max_relays;

  // Policy-service RPC — single in-flight pending slot
  NoPortsPolicyPending _policy_pending;

  // Per-sender cooldown table (LRU) used to throttle requests.
  // Ping and NPT are tracked separately so the normal client sequence
  // (ping, then immediately an NPT request from the same atSign) is not
  // throttled — only rapid repeats of the SAME request type are.
  struct PolicyCooldownEntry {
    char     atsign[64];
    uint32_t last_ping_ms;  // millis() of last ACCEPTED ping check (0 = never)
    uint32_t last_npt_ms;   // millis() of last ACCEPTED NPT request (0 = never)
    bool     used;
  } _policy_cooldown[NOPORTS_POLICY_COOLDOWN_SLOTS];

  // Internal methods (mirror the C sshnpd functions)
  void _freeResources();  // free all allocated SDK objects
  bool _authenticate();
  bool _startMonitor();
  bool _publishDeviceInfo();
  void _buildPingResponse();
  void _publishPublicSigningKey();  // publish APKAM public key for ESCR auth

  // Notification handlers
  void _handleNotification(void *message); // atclient_monitor_message*
  void _handlePing(void *message);
  void _handleNptRequest(void *message);
  void _handleGracefulShutdown();
  // Returns true if atsign exactly matches an entry in config.manager_list.
  // Returns false on nullptr or when no managers are configured.
  bool _isManagerAtsign(const char *atsign);

  // Policy-service RPC helpers
  // Called when policy_atsign is configured: sends auth-check RPC via worker,
  // saves context in _policy_pending, and defers processing until the response
  // notification arrives on the monitor.
  void _sendPolicyRpcRequest(const char *client_atsign);
  void _handlePolicyResponse(void *message);
  void _cleanupPolicyPending();
  // DoS throttle: returns true if a request of the given |type| from |atsign|
  // should be dropped because one was already accepted within
  // NOPORTS_POLICY_COOLDOWN_MS.  On a non-throttled call it records the
  // acceptance timestamp for that type (LRU-evicting the oldest entry when the
  // table is full).  Ping and NPT are throttled independently.
  bool _policyRateLimited(const char *atsign, NoPortsPolicyPendingType type);
  // Extracts post-auth ping response logic (called directly in manager mode,
  // or from _handlePolicyResponse after a successful policy RPC).
  void _handlePingAuthorized(const char *from_atsign);
  // Contains all post-auth NPT processing (permit-open, key gen, relay launch).
  // Takes ownership of envelope (always calls cJSON_Delete before returning).
  // policy_po/policy_po_count are the permitOpen rules returned by the policy
  // service (nullptr + 0 in manager mode → falls back to config.permitopen).
  void _continueNptRequest(void *envelope, const char *requesting_atsign,
                            const char **policy_po, int policy_po_count);
  // Sends a signed error notification back to the requesting npt client.
  // Key: <session_id>.<device_name>.sshnp@daemon_atsign, shared with to_atsign.
  void _sendNptError(const char *to_atsign, const char *session_id, const char *error_msg);

  // Relay management
  int  _findFreeRelaySlot();
  void _cleanupFinishedRelays();

  // Reconnection
  bool _reconnectMonitor();
  bool _reconnectWorker();
  // Re-runs the root-directory lookup and refreshes _atserver_host/_atserver_port
  // and both options structs if the address has changed.  Returns true if a new
  // address was discovered and cached, false if unchanged or the lookup failed.
  bool _refreshAtServerCache();

  // Notify with automatic worker reconnect on failure
  int _notifyWithRetry(void *worker, void *notify_params, char **notification_id);

  // Envelope verification
  bool _verifyEnvelopeSignature(void *envelope, const char *from_atsign);
  bool _verifyEnvelopeContents(void *envelope, int payload_type);

  // Utility
  void _setError(const char *fmt, ...);
};

#endif // NOPORTS_DAEMON_H
