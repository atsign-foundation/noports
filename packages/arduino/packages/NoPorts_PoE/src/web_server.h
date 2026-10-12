/**
 * @file web_server.h
 * @brief HTTP server for NoPorts PoE setup and monitoring UI
 *
 * Serves a dark-themed web app on port 80.  Routes:
 *   GET  /login         → PIN sign-in form (only unauthenticated page)
 *   POST /api/login     → exchange PIN for a session cookie → 200 JSON
 *   POST /api/logout    → invalidate session → 200 JSON
 *   GET  /change-pin    → set/change admin PIN form
 *   POST /api/change-pin→ change admin PIN → 200 JSON
 *   GET  /              → dashboard (auto-refreshes via /api/status)
 *   GET  /setup         → first-run setup form
 *   POST /api/setup     → save initial config → 200 JSON
 *   GET  /enroll        → OTP enrollment form
 *   POST /api/enroll    → start enrollment task → 200 JSON
 *   GET  /api/enroll-status → poll enrollment progress → 200 JSON
 *   GET  /settings      → managers/permitopen rules form
 *   POST /api/settings  → save rules → 200 JSON
 *   GET  /config        → keepalive/relay-count form
 *   POST /api/config    → save config → 200 JSON
 *   POST /api/reset     → factory reset → 200 JSON
 *   GET  /api/status    → live daemon stats → 200 JSON
 *
 * Access control: every route except /login and /api/login requires a valid
 * session cookie, obtained by posting the device admin PIN to /api/login. The
 * PIN is auto-generated on first boot and printed to serial; the operator is
 * forced to set their own PIN at first login (/change-pin), after which the
 * initial PIN is no longer printed. The session cookie is HttpOnly +
 * SameSite=Strict; requests are additionally Host- and Origin-checked to defend
 * against DNS-rebinding and CSRF.
 */

#ifndef WEB_SERVER_H
#define WEB_SERVER_H

#include <Arduino.h>
#include <WebServer.h>
#include <NoPorts.h>

// ─── Enroll task state (written by FreeRTOS task, read by main loop) ──────
enum EnrollPhase { ENROLL_IDLE, ENROLL_RUNNING, ENROLL_OK, ENROLL_FAIL };

struct EnrollStatus {
  volatile EnrollPhase phase;
  char message[128];
  uint32_t started_ms;
};

// ─── Live stats (updated by daemon callbacks and main loop) ───────────────
struct DaemonStats {
  uint32_t total_tunnels;
  uint32_t total_pings;
  uint32_t bytes_in;
  uint32_t bytes_out;
  uint8_t  relay_cpu;
  int      pcb_count;
  int      pcb_max;
  uint8_t  active_relays;
  NoPortsDaemonState state;
};

// ─── Public API ───────────────────────────────────────────────────────────

/**
 * Register all routes and start listening on port 80.
 * Call once after network is up.  Provide pointers to the shared daemon
 * and running-flag so route handlers can read live state.
 *
 * @param daemon        pointer to the NoPortsDaemon instance
 * @param running       pointer to the daemon_running flag in main.cpp
 * @param stats         pointer to the shared stats struct (updated by callbacks)
 * @param enroll        pointer to shared enrollment status
 * @param restart_cb    callback: called when daemon should restart after settings change
 */
void web_server_begin(NoPortsDaemon *daemon,
                      bool          *running,
                      DaemonStats   *stats,
                      EnrollStatus  *enroll,
                      void        (*restart_cb)());

/** Call in loop() — processes pending HTTP requests. */
void web_server_handle();

/**
 * True if a daemon restart was requested (e.g. after settings save).
 * Call in loop() AFTER web_server_handle(); reset with web_server_clear_restart().
 */
bool web_server_restart_pending();
void web_server_clear_restart();

/** Return IP address string for display. */
String web_server_ip();

/** True when the web server is bound to 127.0.0.1 only (NoPorts-access mode). */
bool web_server_is_local();

#endif // WEB_SERVER_H
