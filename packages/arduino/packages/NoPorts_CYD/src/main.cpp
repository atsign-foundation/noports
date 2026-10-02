/**
 * @file main_tft.cpp
 * @brief NoPorts CYD main entry point - TFT_eSPI version (memory-efficient)
 *
 * Boot flow:
 *   1. Init TFT display + touch + LED
 *   2. If previously configured → auto-connect WiFi → load keys → daemon → dashboard
 *   3. If not configured → WiFi screen → enroll screen → dashboard
 *
 * loop():
 *   - Handle touch input
 *   - npDaemon.loop()      (drives NoPorts monitor/relay)
 *   - ui_dashboard_update() (refreshes stats from event queue)
 */

#include <Arduino.h>
#include <LittleFS.h>
#include <WiFi.h>
#include <esp_wifi.h>   // esp_wifi_set_ps / WIFI_PS_NONE
#include <esp_task_wdt.h>
#include "esp_idf_version.h"
#if ESP_IDF_VERSION_MAJOR >= 5
  #include <esp_sntp.h>        // IDF 5+: esp_sntp_stop()
#else
  #include <lwip/apps/sntp.h>  // IDF 4.x: sntp_stop() (no esp_ wrapper yet)
#endif
#include <NoPorts.h>
#include "esp_bt.h"

extern "C" {
  #include "atlogger/atlogger.h"
}

#include "ui_tft.h"
#include "ui_wifi_tft.h"
#include "ui_enroll_tft.h"
#include "ui_dashboard_tft.h"
#include "ui_settings_tft.h"
#include "ui_config_tft.h"

// ---------------------------------------------------------------------------
// Globals
// ---------------------------------------------------------------------------
static NoPortsDaemon npDaemon;
static bool daemon_running = false;

// Session tracking
static uint32_t _total_tunnels = 0;
static uint32_t _total_pings = 0;

enum AppScreen {
  SCREEN_NONE,
  SCREEN_SPLASH,
  SCREEN_WIFI,
  SCREEN_ENROLL,
  SCREEN_DASHBOARD,
  SCREEN_SETTINGS,
  SCREEN_CONFIG,
  SCREEN_AUTH
};

static AppScreen current_screen = SCREEN_NONE;

// WiFi watchdog
static uint32_t _last_wifi_check_ms = 0;
#define WIFI_CHECK_INTERVAL_MS 5000
#define WIFI_RECONNECT_TIMEOUT_MS 15000

// Daemon supervision.  The Linux sshnpd relies on systemd Restart=always to
// come back after any stop; on ESP32 this sketch is the supervisor.  If the
// daemon stops without the sketch asking, restart it in place; if it will
// not stay up, reboot to clear heap fragmentation and wedged TLS/lwIP state.
#define DAEMON_RESTART_DELAY_MS 10000UL   // wait between supervision restarts
#define DAEMON_RESTART_MAX      3         // in-place attempts before rebooting
#define DAEMON_STABLE_MS        600000UL  // up this long = healthy, reset attempts

// Reboot-reason breadcrumb.  RTC noinit memory survives a software reset
// (not a power cycle), so the next boot's log can say why the device
// rebooted itself instead of looking like a random power event.
#define REBOOT_REASON_MAGIC     0x52424F54UL  // "RBOT"
typedef struct { uint32_t magic; char reason[48]; } RebootReason;
static RTC_NOINIT_ATTR RebootReason g_reboot_reason;

static void reboot_with_reason(const char *reason) {
  Serial.printf("[main] REBOOT: %s\n", reason);
  g_reboot_reason.magic = REBOOT_REASON_MAGIC;
  strncpy(g_reboot_reason.reason, reason, sizeof(g_reboot_reason.reason) - 1);
  g_reboot_reason.reason[sizeof(g_reboot_reason.reason) - 1] = '\0';
  delay(200);  // let serial drain
  ESP.restart();
}


// CPU usage tracking
static uint32_t _cpu_loop_start_us = 0;
static int32_t  _cpu_work_us = 0;       // accumulated work time in current window
static uint32_t _cpu_window_start = 0;  // millis() when current 1s window began
static uint8_t  _cpu_pct = 0;           // computed CPU %

// Auth retry screen state
static int _auth_attempt = 0;
static uint32_t _auth_countdown_start = 0;  // millis() when countdown began
static bool _auth_attempting = false;
static char _auth_error[80] = "";
static int _auth_prev_fill_w = 0;
#define AUTH_COUNTDOWN_MS 5000
#define AUTH_BAR_X  30
#define AUTH_BAR_Y  100
#define AUTH_BAR_W  (TFT_WIDTH - 60)
#define AUTH_BAR_H  14
#define AUTH_BTN_X  (TFT_WIDTH / 2 - 60)
#define AUTH_BTN_Y  (TFT_HEIGHT - 45)
#define AUTH_BTN_W  120
#define AUTH_BTN_H  30

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

static const char *daemon_state_str(NoPortsDaemonState s) {
  switch (s) {
    case DAEMON_UNINITIALIZED:  return "uninit";
    case DAEMON_INITIALIZING:   return "init";
    case DAEMON_AUTHENTICATING: return "auth";
    case DAEMON_MONITORING:     return "running";
    case DAEMON_ERROR:          return "error";
    case DAEMON_STOPPED:        return "stopped";
    default:                    return "?";
  }
}

// ---------------------------------------------------------------------------
// NoPorts callbacks → event queue
// ---------------------------------------------------------------------------

static void on_tunnel_open(const char *host, uint16_t port, const char *session_id) {
  _total_tunnels++;
  char buf[EVENT_TEXT_LEN];
  snprintf(buf, sizeof(buf), "Tunnel %s:%u", host, port);
  ui_event_push(UI_EVT_TUNNEL_OPEN, buf);
}

static void on_tunnel_close(const char *session_id) {
  char buf[EVENT_TEXT_LEN];
  snprintf(buf, sizeof(buf), "Closed [%.8s]", session_id ? session_id : "?");
  ui_event_push(UI_EVT_TUNNEL_CLOSE, buf);
}

static void on_ping(const char *from_atsign) {
  _total_pings++;
  char buf[EVENT_TEXT_LEN];
  snprintf(buf, sizeof(buf), "Ping from %s", from_atsign ? from_atsign : "?");
  ui_event_push(UI_EVT_PING, buf);
}

// ---------------------------------------------------------------------------
// Start the NoPorts daemon
// ---------------------------------------------------------------------------

static void _do_reset();
static void _show_settings();
static void _show_wifi();
static void _show_config();
static void _on_settings_saved();
static void _on_config_saved();
static void _draw_page_header();

// Check if managers and permitopen rules are configured
static bool _rules_valid() {
  String rules_mode = ui_load_string(NVS_KEY_RULES_MODE);
  bool policy_mode  = (rules_mode == "1");

  if (policy_mode) {
    // Policy mode: only the policy atSign is required.
    // The policy server owns all permitOpen decisions; no local config needed.
    String policy_at = ui_load_string(NVS_KEY_POLICY_AT);
    if (policy_at.length() == 0) {
      Serial.println("[main] Rules invalid: policy mode but no policy atSign configured");
      return false;
    }
    return true;
  }

  // Manager mode: need at least one manager and a permitopen rule
  String managers = ui_load_string(NVS_KEY_MANAGERS);
  if (managers.length() == 0) {
    managers = ui_load_string(NVS_KEY_MANAGER);
  }
  String permitopen = ui_load_string(NVS_KEY_PERMITOPEN);

  if (managers.length() == 0) {
    Serial.println("[main] Rules invalid: no managers configured");
    return false;
  }
  if (permitopen.length() == 0) {
    Serial.println("[main] Rules invalid: no permitopen rules configured");
    return false;
  }
  return true;
}

// Parse a comma-separated string into an array of static String objects.
// Returns count of items parsed (up to max_items).
static int _parse_csv(const String &input, String *out, int max_items) {
  int count = 0;
  int start = 0;
  for (int i = 0; i <= (int)input.length() && count < max_items; i++) {
    if (i == (int)input.length() || input[i] == ',') {
      String item = input.substring(start, i);
      item.trim();
      if (item.length() > 0) {
        out[count++] = item;
      }
      start = i + 1;
    }
  }
  return count;
}

static bool start_daemon() {
  // These MUST be static — NoPortsDaemon::begin() stores pointers to them
  // via memcpy, so they must outlive the function call.
  // Re-assign on every call so NVS changes (settings save) take effect.
  static String atsign;
  static String device;
  static String managers_raw;
  static String manager_items[NOPORTS_MAX_MANAGERS];
  static String policy_at;
  static String permitopen_raw;
  static String po_items[NOPORTS_MAX_PERMITOPEN];
  static String root_spec;

  atsign  = ui_load_string(NVS_KEY_ATSIGN);
  device  = ui_load_string(NVS_KEY_DEVICE);

  // Determine authorisation mode
  String rules_mode_str = ui_load_string(NVS_KEY_RULES_MODE);
  bool policy_mode = (rules_mode_str == "1");

  if (policy_mode) {
    // Policy mode: a single policy-service atSign handles authorisation via RPC
    policy_at = ui_load_string(NVS_KEY_POLICY_AT);
    Serial.printf("[main] Policy mode: atSign=%s\n",
                  policy_at.length() ? policy_at.c_str() : "(none)");
  } else {
    // Managers mode: load the comma-separated manager list (with legacy fallback)
    managers_raw = ui_load_string(NVS_KEY_MANAGERS);
    if (managers_raw.length() == 0) {
      managers_raw = ui_load_string(NVS_KEY_MANAGER);
    }
  }
  int mgr_count = policy_mode ? 0
                               : _parse_csv(managers_raw, manager_items, NOPORTS_MAX_MANAGERS);

  // Load permitopen rules
  permitopen_raw = ui_load_string(NVS_KEY_PERMITOPEN);
  int po_count = _parse_csv(permitopen_raw, po_items, NOPORTS_MAX_PERMITOPEN);

  if (atsign.length() == 0 || device.length() == 0) {
    Serial.println("[main] Missing atSign/device in NVS");
    return false;
  }

  NoPortsConfig config;
  noports_config_init(&config);
  config.atsign      = atsign.c_str();
  config.device_name = device.c_str();

  // Root server spec: host[:port] or proxy:host[:port]; empty → root.atsign.org:64
  root_spec = ui_load_string(NVS_KEY_ROOT);
  if (root_spec.length() > 0) config.root_domain = root_spec.c_str();

  if (policy_mode) {
    // Delegate authorisation to the policy service
    config.policy_atsign = policy_at.length() ? policy_at.c_str() : nullptr;
  } else {
    // Populate manager list
    for (int i = 0; i < mgr_count; i++) {
      config.manager_list[i] = manager_items[i].c_str();
    }
    config.manager_count = mgr_count;
    Serial.printf("[main] %d manager(s) configured\n", mgr_count);
  }

  // Populate permitopen rules
  static String po_hosts[NOPORTS_MAX_PERMITOPEN]; // keep alive
  int po_valid = 0;
  for (int i = 0; i < po_count; i++) {
    int colon = po_items[i].indexOf(':');
    String host;
    uint16_t port;
    if (colon > 0) {
      host = po_items[i].substring(0, colon);
      String port_str = po_items[i].substring(colon + 1);
      if (port_str == "*") {
        port = 0;  // explicit port wildcard
      } else {
        // Strict parse, fail closed. String::toInt() stops at the first
        // non-digit ("2x2" -> 2) and the cast wraps out-of-range values
        // ("70000" -> 4464), and an empty port ("host:") -> 0 would become a
        // wildcard — any of which silently *widens* a rule on a typo. Reject
        // the whole rule instead of matching every port on the host.
        char *end = nullptr;
        long v = strtol(port_str.c_str(), &end, 10);
        if (end == port_str.c_str() || *end != '\0' || v < 1 || v > UINT16_MAX) {
          Serial.printf("[main] permitopen rule '%s' has invalid port — skipping\n",
                        po_items[i].c_str());
          continue;
        }
        port = (uint16_t)v;
      }
    } else if (po_items[i] == "*") {
      host = "*";
      port = 0;  // wildcard
    } else {
      host = po_items[i];
      port = 0;
    }
    po_hosts[po_valid] = host;
    config.permitopen[po_valid].host = po_hosts[po_valid].c_str();
    config.permitopen[po_valid].port = port;
    po_valid++;
  }
  config.permitopen_count = po_valid;
  Serial.printf("[main] %d permitopen rule(s) configured\n", po_valid);

  // Callbacks
  config.on_tunnel_open  = on_tunnel_open;
  config.on_tunnel_close = on_tunnel_close;
  config.on_ping         = on_ping;

  // Load keys from LittleFS
  if (!LittleFS.begin(true)) {
    Serial.println("[main] LittleFS mount failed");
    return false;
  }

  int res = noports_keys_load_from_file(&config, ATKEYS_PATH);
  if (res != 0) {
    Serial.printf("[main] Failed to load keys from %s (err=%d)\n", ATKEYS_PATH, res);
    return false;
  }
  Serial.println("[main] Keys loaded from LittleFS");

  if (!npDaemon.begin(config)) {
    Serial.printf("[main] Daemon begin failed: %s\n", npDaemon.getLastError());
    noports_keys_free(&config);
    return false;
  }

  noports_keys_free(&config);
  daemon_running = true;
  Serial.println("[main] NoPorts daemon running!");

  // Apply NVS-stored settings to the running daemon
  {
    String ms = ui_load_string(NVS_KEY_MAX_RELAYS);
    uint8_t max_r = (ms.length() > 0 && ms.toInt() >= 1)
                    ? (uint8_t)constrain(ms.toInt(), 1, NOPORTS_MAX_RELAYS) : NOPORTS_MAX_RELAYS;
    npDaemon.setMaxRelays(max_r);
    Serial.printf("[main] Max TCP clients configured: %d\n", (int)max_r);
  }
  
  // Set LED to cyan (running)
  ui_load_led_color();
  
  return true;
}

// ---------------------------------------------------------------------------
// Reset device: delete atKeys, clear NVS config, reboot
// ---------------------------------------------------------------------------

static void _do_reset() {
  Serial.println("[main] RESET requested — wiping credentials");
  
  // Stop daemon if running
  if (daemon_running) {
    npDaemon.stop();
    daemon_running = false;
  }
  
  // Delete atKeys from LittleFS
  if (LittleFS.begin(true)) {
    if (LittleFS.exists(ATKEYS_PATH)) {
      LittleFS.remove(ATKEYS_PATH);
      Serial.println("[main] Deleted atKeys file");
    }
  }
  
  // Clear enrollment + rules config from NVS — a wipe is a factory reset
  ui_save_string(NVS_KEY_ATSIGN, "");
  ui_save_string(NVS_KEY_DEVICE, "");
  ui_save_string(NVS_KEY_MANAGER, "");
  ui_save_string(NVS_KEY_MANAGERS, "");
  ui_save_string(NVS_KEY_PERMITOPEN, "");
  ui_save_string(NVS_KEY_POLICY_AT, "");
  ui_save_string(NVS_KEY_RULES_MODE, "");
  ui_save_string(NVS_KEY_ROOT, "");  // back to root.atsign.org
  ui_set_configured(false);
  
  Serial.println("[main] NVS cleared — rebooting...");
  
  // Show reset message
  TFT_eSPI &tft = ui_get_tft();
  tft.fillScreen(COLOR_BG_DARK);
  tft.setTextColor(COLOR_ERROR);
  tft.setTextDatum(MC_DATUM);
  tft.setTextSize(1);
  tft.drawString("Device Reset", TFT_WIDTH / 2, TFT_HEIGHT / 2 - 20, 4);
  tft.setTextColor(COLOR_TEXT_GREY);
  tft.drawString("Rebooting...", TFT_WIDTH / 2, TFT_HEIGHT / 2 + 20, 2);
  
  delay(2000);
  ESP.restart();
}

// ---------------------------------------------------------------------------
// Screen transitions
// ---------------------------------------------------------------------------

static time_t _ntp_last_good = 0;  // 0 = never synced THIS session (gates ±1h clamp)

// Convert a broken-down UTC date/time to Unix epoch without relying on timegm()
// or the process timezone (days_from_civil, Howard Hinnant — all signed math).
static time_t _utc_epoch(int year, int mon0, int mday, int hour, int min, int sec) {
  int m   = mon0 + 1;                              // 1..12
  int y   = year - (m <= 2 ? 1 : 0);
  int era = (y >= 0 ? y : y - 399) / 400;
  int yoe = y - era * 400;                         // 0..399
  int doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + mday - 1;  // 0..365
  int doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;             // 0..146096
  long long days = (long long)era * 146097 + doe - 719468;     // days since 1970-01-01
  return (time_t)(days * 86400LL + hour * 3600LL + min * 60LL + sec);
}

// Firmware build time, parsed from the compiler's __DATE__/__TIME__ (UTC).
// Used as an absolute lower bound for accepted NTP times: the clock can never
// be set earlier than when this firmware was built.
static time_t _build_epoch() {
  static const char *months = "JanFebMarAprMayJunJulAugSepOctNovDec";
  char mon[4] = { __DATE__[0], __DATE__[1], __DATE__[2], '\0' };
  const char *p = strstr(months, mon);
  int mon0 = p ? (int)((p - months) / 3) : 0;
  int mday = atoi(__DATE__ + 4);   // atoi skips the space-padding of single-digit days
  int year = atoi(__DATE__ + 7);
  int hour = atoi(__TIME__);
  int min  = atoi(__TIME__ + 3);
  int sec  = atoi(__TIME__ + 6);
  time_t t = _utc_epoch(year, mon0, mday, hour, min, sec);
  return t > 0 ? t : 0;
}

// Absolute lower bound for an acceptable NTP time: the later of the firmware
// build date (minus a skew margin) and the last known-good time persisted to
// NVS.  A real NTP reply is always at/after this; only a spoofed backward jump
// falls below it.
static time_t _ntp_time_floor() {
  time_t floor = _build_epoch();
  if (floor > 86400) floor -= 86400;  // 1-day margin for build-host clock skew
  String s = ui_load_string(NVS_KEY_NTP_GOOD);
  if (s.length()) {
    time_t persisted = (time_t)strtoll(s.c_str(), nullptr, 10);
    if (persisted > floor) floor = persisted;
  }
  return floor;
}

// Persist forward progress of the known-good clock so the floor survives reboot.
// The ~24h re-sync interval keeps this to about one NVS write per day.
static void _persist_ntp_good(time_t t) {
  String s = ui_load_string(NVS_KEY_NTP_GOOD);
  time_t stored = s.length() ? (time_t)strtoll(s.c_str(), nullptr, 10) : 0;
  if (t > stored) {
    char buf[24];
    snprintf(buf, sizeof(buf), "%lld", (long long)t);
    ui_save_string(NVS_KEY_NTP_GOOD, buf);
  }
}

static void sync_ntp_time() {
  Serial.println("[NTP] Syncing time...");
  time_t before = time(nullptr);
  configTime(0, 0, "pool.ntp.org", "time.nist.gov", "time.google.com");

  struct tm timeinfo;
  int retries = 0;
  while (!getLocalTime(&timeinfo, 1000) && retries < 10) {
    retries++;
    Serial.printf("[NTP] Waiting for time... (%d/10)\n", retries);
  }

  if (retries < 10) {
    time_t after = mktime(&timeinfo);
    time_t floor = _ntp_time_floor();
    // Absolute floor — applies on EVERY sync, including the first.  Rejects any
    // reply that would set the clock earlier than the firmware build date or the
    // last known-good time.  This blocks a spoofed SNTP reply from rolling the
    // clock backward at boot (e.g. to validate an expired TLS certificate).
    if (after < floor) {
      Serial.printf("[NTP] REJECT: %lld < floor %lld — backward/spoofed, keeping current time\n",
                    (long long)after, (long long)floor);
      timeval tv{before, 0};
      settimeofday(&tv, nullptr);
    // After a good sync THIS session, also reject >1h jumps from the current
    // (already-correct) clock — guards against skewing a good clock.
    } else if (_ntp_last_good > 0 && labs((long)(after - before)) > 3600) {
      Serial.printf("[NTP] WARN: suspicious jump %ld s — reverting\n",
                    (long)(after - before));
      timeval tv{before, 0};
      settimeofday(&tv, nullptr);
    } else {
      _ntp_last_good = after;
      _persist_ntp_good(after);
      char buf[64];
      strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S UTC", &timeinfo);
      Serial.printf("[NTP] Time set: %s\n", buf);
    }
  } else {
    Serial.println("[NTP] WARNING: Failed to get time");
  }
#if ESP_IDF_VERSION_MAJOR >= 5
  esp_sntp_stop();  // IDF 5+: wrapper in <esp_sntp.h>
#else
  sntp_stop();      // IDF 4.x: lwIP-level function
#endif
}

// ---------------------------------------------------------------------------
// Auth retry screen — keeps trying PKAM with progress bar and Reset button
// ---------------------------------------------------------------------------

static void _auth_update_status(const char *msg, uint16_t color) {
  TFT_eSPI &tft = ui_get_tft();
  tft.fillRect(0, 73, TFT_WIDTH, 18, COLOR_BG_DARK);
  tft.setTextColor(color);
  tft.setTextDatum(MC_DATUM);
  tft.drawString(msg, TFT_WIDTH / 2, 82, 2);
}

static void _auth_update_error() {
  TFT_eSPI &tft = ui_get_tft();
  // Error text area (two lines)
  tft.fillRect(0, 120, TFT_WIDTH, 50, COLOR_BG_DARK);
  if (_auth_error[0] != '\0') {
    // Error in RED
    tft.setTextColor(COLOR_ERROR);
    tft.setTextDatum(MC_DATUM);
    tft.drawString(_auth_error, TFT_WIDTH / 2, 130, 2);

    char count_buf[32];
    snprintf(count_buf, sizeof(count_buf), "Attempt %d failed", _auth_attempt);
    tft.setTextColor(COLOR_TEXT_GREY);
    tft.drawString(count_buf, TFT_WIDTH / 2, 150, 2);
  }
}

// Clean first-attempt screen: title + version + atSign + "Authenticating..."
static void _show_auth_screen() {
  TFT_eSPI &tft = ui_get_tft();
  tft.fillScreen(COLOR_BG_DARK);

  // Title + version
  _draw_page_header();

  // atSign
  String atsign = ui_load_string(NVS_KEY_ATSIGN);
  tft.setTextColor(COLOR_TEXT_WHITE);
  tft.setTextDatum(MC_DATUM);
  tft.drawString(atsign.c_str(), TFT_WIDTH / 2, 60, 2);

  // Status — friendly message for first attempt
  tft.setTextColor(COLOR_ACCENT);
  tft.drawString("Authenticating...", TFT_WIDTH / 2, 90, 2);
  tft.setTextColor(COLOR_TEXT_GREY);
  tft.drawString("This takes 5-10 seconds", TFT_WIDTH / 2, 115, 2);

  _auth_prev_fill_w = 0;
}

// Retry screen: adds progress bar + Reset button (shown after first failure)
static void _show_auth_retry_screen() {
  TFT_eSPI &tft = ui_get_tft();
  tft.fillScreen(COLOR_BG_DARK);

  // Title + version
  _draw_page_header();

  // atSign
  String atsign = ui_load_string(NVS_KEY_ATSIGN);
  tft.setTextColor(COLOR_TEXT_WHITE);
  tft.setTextDatum(MC_DATUM);
  tft.drawString(atsign.c_str(), TFT_WIDTH / 2, 60, 2);

  // Status placeholder
  tft.setTextColor(COLOR_ERROR);
  tft.drawString("PKAM Failed!", TFT_WIDTH / 2, 82, 2);

  // Progress bar outline
  tft.drawRect(AUTH_BAR_X, AUTH_BAR_Y, AUTH_BAR_W, AUTH_BAR_H, COLOR_TEXT_GREY);

  // Error info
  _auth_update_error();

  // Reset atSign button
  ui_draw_rounded_rect(AUTH_BTN_X, AUTH_BTN_Y, AUTH_BTN_W, AUTH_BTN_H, 6, COLOR_ERROR);
  tft.setTextColor(COLOR_TEXT_WHITE);
  tft.setTextDatum(MC_DATUM);
  tft.drawString("Reset atSign", AUTH_BTN_X + AUTH_BTN_W / 2, AUTH_BTN_Y + AUTH_BTN_H / 2, 2);

  _auth_prev_fill_w = 0;
}

static void _enter_auth_screen() {
  _auth_attempt = 0;
  _auth_countdown_start = millis() - AUTH_COUNTDOWN_MS;  // attempt immediately
  _auth_attempting = false;
  _auth_error[0] = '\0';
  _auth_prev_fill_w = 0;
  current_screen = SCREEN_AUTH;
  _show_auth_screen();
  Serial.println("[main] Entering auth retry screen");
}

static void _auth_update_progress_bar() {
  if (_auth_attempt < 1) return;  // No bar on first-attempt screen

  TFT_eSPI &tft = ui_get_tft();
  int inner_w = AUTH_BAR_W - 2;

  if (_auth_attempting) return;  // Bar stays fully orange during attempt

  // Countdown phase: fill bar incrementally over 5 seconds
  unsigned long elapsed = millis() - _auth_countdown_start;
  int fill = (int)((unsigned long)inner_w * elapsed / AUTH_COUNTDOWN_MS);
  if (fill < 0) fill = 0;
  if (fill > inner_w) fill = inner_w;

  if (fill > 0 && fill > _auth_prev_fill_w) {
    tft.fillRect(AUTH_BAR_X + 1 + _auth_prev_fill_w, AUTH_BAR_Y + 1,
                 fill - _auth_prev_fill_w, AUTH_BAR_H - 2, COLOR_ACCENT);
    _auth_prev_fill_w = fill;
  }
}

// Called from loop() when current_screen == SCREEN_AUTH
static void _auth_loop() {
  _auth_update_progress_bar();

  unsigned long elapsed = millis() - _auth_countdown_start;

  // Update countdown text (only during retries, not first attempt)
  if (!_auth_attempting && _auth_attempt >= 1 && elapsed < AUTH_COUNTDOWN_MS) {
    int secs_left = (int)((AUTH_COUNTDOWN_MS - elapsed + 999) / 1000);
    if (secs_left < 0) secs_left = 0;
    char msg[48];
    snprintf(msg, sizeof(msg), "Retrying in %ds...", secs_left);
    _auth_update_status(msg, COLOR_ACCENT);
  }

  // Countdown complete (or immediate on first attempt)? Start attempt
  if (!_auth_attempting && elapsed >= AUTH_COUNTDOWN_MS) {
    _auth_attempting = true;
    _auth_attempt++;

    // Check WiFi first
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("[auth] WiFi not connected - skipping attempt");
      strncpy(_auth_error, "WiFi not connected", sizeof(_auth_error));
      _auth_attempting = false;
      if (_auth_attempt == 1) {
        // Switch to retry screen
        _show_auth_retry_screen();
      } else {
        _auth_update_status("WiFi disconnected!", COLOR_ERROR);
        _auth_update_error();
        TFT_eSPI &tft = ui_get_tft();
        tft.fillRect(AUTH_BAR_X + 1, AUTH_BAR_Y + 1, AUTH_BAR_W - 2, AUTH_BAR_H - 2, COLOR_BG_DARK);
      }
      _auth_countdown_start = millis();
      _auth_prev_fill_w = 0;
      return;
    }

    Serial.printf("[auth] Daemon start attempt %d (heap: %u)\n", _auth_attempt, ESP.getFreeHeap());

    // Fill bar orange during attempt (only if retry screen is showing)
    if (_auth_attempt > 1) {
      char msg[40];
      snprintf(msg, sizeof(msg), "Attempt %d...", _auth_attempt);
      _auth_update_status(msg, COLOR_PRIMARY);
      TFT_eSPI &tft = ui_get_tft();
      tft.fillRect(AUTH_BAR_X + 1, AUTH_BAR_Y + 1, AUTH_BAR_W - 2, AUTH_BAR_H - 2, COLOR_PRIMARY);
    }

    if (start_daemon()) {
      Serial.printf("[auth] PKAM succeeded on attempt %d\n", _auth_attempt);
      current_screen = SCREEN_DASHBOARD;
      ui_dashboard_create(_do_reset, _show_settings, _show_wifi, _show_config);

      if (_auth_attempt > 1) {
        char evt_buf[EVENT_TEXT_LEN];
        snprintf(evt_buf, sizeof(evt_buf), "PKAM OK after %d attempts", _auth_attempt);
        ui_event_push(UI_EVT_ERROR, evt_buf);
      }
      return;
    }

    // Failed
    const char *err = npDaemon.getLastError();
    snprintf(_auth_error, sizeof(_auth_error), "%s", err ? err : "Unknown error");
    Serial.printf("[auth] Attempt %d failed: %s\n", _auth_attempt, _auth_error);

    _auth_attempting = false;

    if (_auth_attempt == 1) {
      // First failure — switch to retry screen with bar + Reset button
      _show_auth_retry_screen();
    } else {
      _auth_update_status("PKAM Failed!", COLOR_ERROR);
      _auth_update_error();
      TFT_eSPI &tft = ui_get_tft();
      tft.fillRect(AUTH_BAR_X + 1, AUTH_BAR_Y + 1, AUTH_BAR_W - 2, AUTH_BAR_H - 2, COLOR_BG_DARK);
    }

    // Start countdown for next attempt
    _auth_countdown_start = millis();
    _auth_prev_fill_w = 0;
  }
}

static bool _auth_handle_touch(int16_t tx, int16_t ty) {
  // Reset button only exists on retry screen (after first failure)
  if (_auth_attempt < 1) return false;
  if (ui_touch_in_rect(tx, ty, AUTH_BTN_X, AUTH_BTN_Y, AUTH_BTN_W, AUTH_BTN_H)) {
    Serial.println("[auth] Reset atSign pressed");
    _do_reset();
    return true;
  }
  return false;
}

static void _on_enrolled() {
  // The at-server needs a moment to finish propagating the newly-enrolled
  // PKAM public key before PKAM auth can succeed.  Also gives the idle task
  // time to reclaim the enrollment task's 32 KB stack.  3 s is enough in
  // practice; the "Enrolled successfully!" message stays on screen during
  // the wait.  delay() yields to the FreeRTOS scheduler so WiFi/TCP tasks
  // continue uninterrupted.
  delay(3000);
  if (start_daemon()) {
    current_screen = SCREEN_DASHBOARD;
    ui_dashboard_create(_do_reset, _show_settings, _show_wifi, _show_config);
  } else {
    _enter_auth_screen();
  }
}

static void on_wifi_connected() {
  // Disable modem sleep: under heavy TCP relay traffic the radio can't
  // maintain its periodic sleep schedule and triggers BEACON_TIMEOUT (reason 200),
  // dropping the association.  WIFI_PS_NONE keeps the radio continuously active.
  esp_wifi_set_ps(WIFI_PS_NONE);
  Serial.println("[main] WiFi power save disabled");

  TFT_eSPI &tft = ui_get_tft();

  // Show NTP sync status
  tft.fillRect(0, TFT_HEIGHT / 2 + 15, TFT_WIDTH, 20, COLOR_BG_DARK);
  tft.setTextColor(COLOR_ACCENT);
  tft.setTextDatum(MC_DATUM);
  tft.drawString("Syncing time...", TFT_WIDTH / 2, TFT_HEIGHT / 2 + 20, 2);

  sync_ntp_time();
  
  if (ui_is_configured()) {
    // Check rules are valid before trying to start daemon
    if (!_rules_valid()) {
      Serial.println("[main] Rules missing — opening Rules screen");
      tft.fillRect(0, TFT_HEIGHT / 2 + 15, TFT_WIDTH, 20, COLOR_BG_DARK);
      tft.setTextColor(COLOR_ERROR);
      tft.setTextDatum(MC_DATUM);
      tft.drawString("Rules not configured!", TFT_WIDTH / 2, TFT_HEIGHT / 2 + 20, 2);
      delay(1500);
      current_screen = SCREEN_SETTINGS;
      ui_settings_create(_on_settings_saved);
      return;
    }

    // Show auth retry screen — handles all PKAM attempts with
    // progress bar, status, and "Reset atSign" button
    _enter_auth_screen();
  } else {
    // First run – show enrollment
    tft.fillRect(0, TFT_HEIGHT / 2 + 15, TFT_WIDTH, 20, COLOR_BG_DARK);
    tft.setTextColor(COLOR_ACCENT);
    tft.setTextDatum(MC_DATUM);
    tft.drawString("Starting enrollment...", TFT_WIDTH / 2, TFT_HEIGHT / 2 + 20, 2);
    delay(500);

    current_screen = SCREEN_ENROLL;
    ui_enroll_create(_on_enrolled);
  }
}

// Called after WiFi reconnects from the WiFi screen (during runtime, not first boot)
// Helper: show a full-screen status message during daemon restart
static void _show_restart_status(const char *line1, const char *line2 = nullptr) {
  TFT_eSPI &tft = ui_get_tft();
  tft.fillScreen(COLOR_BG_DARK);
  _draw_page_header();
  tft.setTextColor(COLOR_ACCENT);
  tft.setTextDatum(MC_DATUM);
  tft.drawString(line1, TFT_WIDTH / 2, TFT_HEIGHT / 2 + 5, 2);
  if (line2) {
    tft.setTextColor(COLOR_TEXT_GREY);
    tft.drawString(line2, TFT_WIDTH / 2, TFT_HEIGHT / 2 + 30, 2);
  }
}

static void _on_wifi_reconnected() {
  // Re-apply WIFI_PS_NONE: the reconnect path resets the WiFi stack and
  // the power-save setting is lost on each new association.
  esp_wifi_set_ps(WIFI_PS_NONE);
  Serial.println("[main] WiFi power save disabled (reconnect)");

  _show_restart_status("Syncing time...");
  sync_ntp_time();

  // Return to dashboard — daemon may need restart
  if (!daemon_running || !npDaemon.isRunning()) {
    _show_restart_status("Authenticating atSign...");

    bool started = false;
    for (int attempt = 0; attempt < 3; attempt++) {
      if (attempt > 0) {
        char msg[40];
        snprintf(msg, sizeof(msg), "Retry %d/3...", attempt + 1);
        _show_restart_status("Authenticating atSign...", msg);
        Serial.printf("[main] Daemon start retry %d/3...\n", attempt + 1);
        delay(2000);
      }
      if (start_daemon()) { started = true; break; }
    }
    current_screen = SCREEN_DASHBOARD;
    ui_dashboard_create(_do_reset, _show_settings, _show_wifi, _show_config);
    if (!started) {
      // Log the failure on the dashboard in RED
      ui_event_push(UI_EVT_ERROR, "PKAM auth failed after reconnect");
      Serial.println("[main] WARNING: Daemon failed after WiFi reconnect");
    }
  } else {
    current_screen = SCREEN_DASHBOARD;
    ui_dashboard_create(_do_reset, _show_settings, _show_wifi, _show_config);
  }
}

// Called when user saves settings screen
// Stop and restart the daemon so it picks up changed NVS config, then
// return to the dashboard. Shared by the Rules save and a root-server
// change from the Config screen.
static void _restart_daemon_after_save(const char *saving_msg) {
  // Show status so user knows it's working, not frozen
  _show_restart_status(saving_msg, "Restarting daemon");

  // Daemon restart needed to pick up new config
  if (daemon_running) {
    npDaemon.stop();
    daemon_running = false;
    Serial.println("[main] Daemon stopped for settings change");
  }

  _show_restart_status("Waiting for server...");
  delay(3000);

  // Log heap before restart attempt
  Serial.printf("[main] Free heap before daemon restart: %u bytes\n", ESP.getFreeHeap());

  // Retry daemon start (PKAM can fail transiently after quick restart)
  bool started = false;
  for (int attempt = 0; attempt < 3; attempt++) {
    if (attempt > 0) {
      char msg[40];
      snprintf(msg, sizeof(msg), "Retry %d/3...", attempt + 1);
      _show_restart_status("Authenticating atSign...", msg);
      Serial.printf("[main] Daemon start retry %d/3...\n", attempt + 1);
      delay(3000);
    } else {
      _show_restart_status("Authenticating atSign...");
    }
    if (start_daemon()) { started = true; break; }
  }

  current_screen = SCREEN_DASHBOARD;
  ui_dashboard_create(_do_reset, _show_settings, _show_wifi, _show_config);
  if (!started) {
    // Log the failure on the dashboard in RED
    ui_event_push(UI_EVT_ERROR, "PKAM auth failed after settings save");
    Serial.println("[main] WARNING: Daemon failed to restart after settings save");
  }
}

static void _on_settings_saved() {
  _restart_daemon_after_save("Saving rules...");
}

// Show settings/rules screen (called from dashboard)
static void _show_settings() {
  current_screen = SCREEN_SETTINGS;
  ui_settings_create(_on_settings_saved);
}

// Show config screen (called from dashboard's Settings/Config button)
// Root spec as it was when the Config screen was opened — used to detect a
// change on save, which needs a daemon restart (unlike the live-applied tuning)
static String _root_before_config;

static void _on_config_saved() {
  // Apply new keepalive value to the running daemon — no restart needed
  if (daemon_running) {
    String ka = ui_load_string(NVS_KEY_WORKER_KEEPALIVE);
    uint32_t ka_ms = (ka.length() > 0 && ka.toInt() > 0)
                     ? (uint32_t)ka.toInt() * 60000UL
                     : 0;
    npDaemon.setWorkerKeepaliveMs(ka_ms);
    Serial.printf("[main] Worker keepalive updated: %u ms\n", ka_ms);

    String ms = ui_load_string(NVS_KEY_MAX_RELAYS);
    uint8_t max_r = (ms.length() > 0 && ms.toInt() >= 1)
                    ? (uint8_t)constrain(ms.toInt(), 1, NOPORTS_MAX_RELAYS) : NOPORTS_MAX_RELAYS;
    npDaemon.setMaxRelays(max_r);
    Serial.printf("[main] Max TCP clients updated: %d\n", (int)max_r);
  }

  // A changed root server spec only takes effect on a fresh daemon start
  if (ui_load_string(NVS_KEY_ROOT) != _root_before_config) {
    Serial.println("[main] Root server spec changed — restarting daemon");
    _restart_daemon_after_save("Saving config...");
    return;
  }

  // Return to dashboard
  current_screen = SCREEN_DASHBOARD;
  ui_dashboard_create(_do_reset, _show_settings, _show_wifi, _show_config);
}

static void _show_config() {
  _root_before_config = ui_load_string(NVS_KEY_ROOT);
  current_screen = SCREEN_CONFIG;
  ui_config_create(_on_config_saved);
}

// Show WiFi setup screen (called from dashboard by the user — no auto-search)
static void _show_wifi() {
  if (daemon_running) {
    npDaemon.stop();
    daemon_running = false;
  }
  current_screen = SCREEN_WIFI;
  ui_wifi_create(_on_wifi_reconnected);
}

// Draw consistent page header (title + version) at the top of any full screen.
// y=15 TC_DATUM font4 for title, y=38 font2 for version — same on every screen.
static void _draw_page_header() {
  TFT_eSPI &tft = ui_get_tft();
  tft.setTextColor(COLOR_PRIMARY);
  tft.setTextDatum(TC_DATUM);
  tft.setTextSize(1);
  tft.drawString("NoPorts CYD", TFT_WIDTH / 2, 15, 4);
  tft.setTextColor(COLOR_TEXT_GREY);
  tft.drawString("v" CYD_APP_VERSION, TFT_WIDTH / 2, 38, 2);
}

static void show_splash() {
  TFT_eSPI &tft = ui_get_tft();
  tft.fillScreen(COLOR_BG_DARK);

  _draw_page_header();

  tft.setTextColor(COLOR_TEXT_GREY);
  tft.setTextDatum(MC_DATUM);
  tft.setTextSize(1);
  tft.drawString("Initializing...", TFT_WIDTH / 2, TFT_HEIGHT / 2 + 20, 2);

  delay(1500);
}

// ---------------------------------------------------------------------------
// setup()
// ---------------------------------------------------------------------------

void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println("\n==============================");
  Serial.println("  NoPorts CYD - TFT_eSPI Mode");
  Serial.println("  Memory-Optimized Version");
  Serial.println("==============================\n");

  if (g_reboot_reason.magic == REBOOT_REASON_MAGIC) {
    Serial.printf("[main] Previous reboot was self-initiated: %s\n",
                  g_reboot_reason.reason);
    g_reboot_reason.magic = 0;
  }

  // Hardware watchdog — IDF 4.x API (seconds, not ms struct like IDF 5.x)
  esp_task_wdt_init(60, true);  // 60 s timeout, panic+reboot on trigger
  esp_task_wdt_add(NULL);       // subscribe the Arduino loop task
  Serial.println("[wdt] Hardware watchdog: 60 s");

  // Release Bluetooth controller memory — we never use BT (~30KB heap savings)
  esp_bt_controller_mem_release(ESP_BT_MODE_BTDM);
  Serial.printf("[main] Heap after BT release: %u bytes\n", ESP.getFreeHeap());

  // Enable at_client logging
  atlogger_set_logging_level(ATLOGGER_LOGGING_LEVEL_INFO);

  // Initialize TFT display and touch
  ui_tft_init();
  
  // Run touch calibration on first boot
  if (!ui_touch_is_calibrated()) {
    ui_touch_calibrate();
  }
  
  // Show splash screen
  current_screen = SCREEN_SPLASH;
  show_splash();

  // Check for saved WiFi credentials
  String ssid = ui_load_string(NVS_KEY_SSID);
  
  if (ssid.length() > 0) {
    // ---------------------------------------------------------------
    // Boot WiFi screen: 5-second countdown with "Change WiFi" button.
    // WiFi connection starts immediately but the countdown always runs
    // the full 5 seconds so the user has time to press "Change WiFi".
    // ---------------------------------------------------------------
    TFT_eSPI &tft = ui_get_tft();
    tft.fillScreen(COLOR_BG_DARK);

    // Title + version
    _draw_page_header();

    // SSID
    tft.setTextColor(COLOR_TEXT_WHITE);
    tft.setTextDatum(MC_DATUM);
    tft.drawString(ssid.c_str(), TFT_WIDTH / 2, TFT_HEIGHT / 2 - 30, 2);

    // "Change WiFi" button
    const int btn_x = TFT_WIDTH / 2 - 60;
    const int btn_y = TFT_HEIGHT / 2 + 40;
    const int btn_w = 120;
    const int btn_h = 30;
    ui_draw_rounded_rect(btn_x, btn_y, btn_w, btn_h, 6, COLOR_ACCENT);
    tft.setTextColor(COLOR_TEXT_WHITE);
    tft.setTextDatum(MC_DATUM);
    tft.drawString("Change WiFi", btn_x + btn_w / 2, btn_y + btn_h / 2, 2);

    // Hint text below button
    tft.setTextColor(COLOR_TEXT_GREY);
    tft.setTextDatum(TC_DATUM);
    tft.drawString("Tap button to reconfigure", TFT_WIDTH / 2, btn_y + btn_h + 6, 1);

    // Progress bar outline
    const int bar_x = 30;
    const int bar_y = TFT_HEIGHT / 2;
    const int bar_w = TFT_WIDTH - 60;
    const int bar_h = 14;
    tft.drawRect(bar_x, bar_y, bar_w, bar_h, COLOR_TEXT_GREY);

    // Start WiFi connection attempt in background
    WiFi.mode(WIFI_STA);
    String pass = ui_load_string(NVS_KEY_PASS);
    WiFi.begin(ssid.c_str(), pass.c_str());

    const unsigned long COUNTDOWN_MS = 5000;
    unsigned long boot_wifi_start = millis();
    bool user_aborted = false;
    bool wifi_connected = false;
    int prev_fill_w = 0;
    const char *prev_status = "";

    // Always run the full 5-second countdown so user can press "Change WiFi"
    while (millis() - boot_wifi_start < COUNTDOWN_MS) {
      // Check for touch on "Change WiFi" button
      int16_t tx, ty;
      if (ui_touch_read(&tx, &ty)) {
        if (ui_touch_in_rect(tx, ty, btn_x, btn_y, btn_w, btn_h)) {
          user_aborted = true;
          Serial.println("[main] User pressed Change WiFi");
          WiFi.disconnect();
          break;
        }
        // Ignore taps elsewhere — don't abort
      }

      // Track WiFi status (don't break — keep counting down)
      if (!wifi_connected && WiFi.status() == WL_CONNECTED) {
        wifi_connected = true;
        Serial.println("[main] WiFi connected during countdown");
      }

      // Update countdown bar (incremental fill only — no flicker)
      unsigned long elapsed = millis() - boot_wifi_start;
      int fill_w = (int)((unsigned long)(bar_w - 2) * elapsed / COUNTDOWN_MS);
      if (fill_w > 0 && fill_w > prev_fill_w && fill_w <= bar_w - 2) {
        uint16_t bar_color = wifi_connected ? COLOR_SUCCESS : COLOR_ACCENT;
        tft.fillRect(bar_x + 1 + prev_fill_w, bar_y + 1,
                     fill_w - prev_fill_w, bar_h - 2, bar_color);
        prev_fill_w = fill_w;
      }

      // Status text (only redraw when it changes)
      const char *status;
      int secs_left = (int)((COUNTDOWN_MS - elapsed + 999) / 1000);
      char countdown_buf[48];
      if (wifi_connected) {
        snprintf(countdown_buf, sizeof(countdown_buf), "WiFi OK! Starting in %ds...", secs_left);
        status = countdown_buf;
      } else {
        snprintf(countdown_buf, sizeof(countdown_buf), "Connecting WiFi... %ds", secs_left);
        status = countdown_buf;
      }
      // Always redraw status (secs_left changes)
      tft.fillRect(0, TFT_HEIGHT / 2 - 15, TFT_WIDTH, 14, COLOR_BG_DARK);
      tft.setTextColor(wifi_connected ? COLOR_SUCCESS : COLOR_ACCENT);
      tft.setTextDatum(MC_DATUM);
      tft.drawString(countdown_buf, TFT_WIDTH / 2, TFT_HEIGHT / 2 - 8, 2);

      delay(50);
    }

    if (user_aborted) {
      // User wants to change WiFi
      Serial.println("[main] Showing WiFi setup (user request)");
      current_screen = SCREEN_WIFI;
      ui_wifi_create(on_wifi_connected);
    } else if (wifi_connected || WiFi.status() == WL_CONNECTED) {
      Serial.println("[main] Auto-connected to WiFi");
      ui_set_led(false, false, true);  // Blue = connected

      // Show status while NTP + daemon start (these can take several seconds)
      tft.fillScreen(COLOR_BG_DARK);
      _draw_page_header();
      tft.setTextColor(COLOR_TEXT_WHITE);
      tft.setTextDatum(MC_DATUM);
      tft.drawString(WiFi.localIP().toString().c_str(), TFT_WIDTH / 2, TFT_HEIGHT / 2 - 5, 2);
      tft.setTextColor(COLOR_ACCENT);
      tft.drawString("Syncing time...", TFT_WIDTH / 2, TFT_HEIGHT / 2 + 20, 2);

      on_wifi_connected();
    } else {
      // Countdown expired without connection — try a few more seconds
      Serial.println("[main] Countdown expired, waiting 5s more...");
      tft.fillRect(0, TFT_HEIGHT / 2 - 15, TFT_WIDTH, 14, COLOR_BG_DARK);
      tft.setTextColor(COLOR_ERROR);
      tft.setTextDatum(MC_DATUM);
      tft.drawString("Still connecting...", TFT_WIDTH / 2, TFT_HEIGHT / 2 - 8, 2);

      unsigned long extra_start = millis();
      while (WiFi.status() != WL_CONNECTED && millis() - extra_start < 5000) {
        delay(100);
      }
      if (WiFi.status() == WL_CONNECTED) {
        Serial.println("[main] Connected (late)");
        ui_set_led(false, false, true);

        tft.fillScreen(COLOR_BG_DARK);
        _draw_page_header();
        tft.setTextColor(COLOR_TEXT_WHITE);
        tft.setTextDatum(MC_DATUM);
        tft.drawString(WiFi.localIP().toString().c_str(), TFT_WIDTH / 2, TFT_HEIGHT / 2 - 5, 2);
        tft.setTextColor(COLOR_ACCENT);
        tft.drawString("Syncing time...", TFT_WIDTH / 2, TFT_HEIGHT / 2 + 20, 2);

        on_wifi_connected();
      } else {
        Serial.println("[main] Auto-connect failed - showing WiFi setup with auto-search");
        WiFi.disconnect();
        current_screen = SCREEN_WIFI;
        ui_wifi_create(on_wifi_connected, true);
      }
    }
  } else {
    // No saved WiFi - show setup
    Serial.println("[main] No saved WiFi - showing setup");
    current_screen = SCREEN_WIFI;
    ui_wifi_create(on_wifi_connected);
  }
  
  Serial.printf("[main] Free heap: %u bytes\n", ESP.getFreeHeap());
}

// ---------------------------------------------------------------------------
// loop()
// ---------------------------------------------------------------------------

void loop() {
  _cpu_loop_start_us = micros();

  // -----------------------------------------------------------------------
  // CPU usage: compute rolling 1-second average
  // -----------------------------------------------------------------------
  if (millis() - _cpu_window_start >= 1000) {
    int pct = _cpu_work_us / 10000;  // us -> % of 1s
    if (pct < 0) pct = 0;
    if (pct > 100) pct = 100;
    _cpu_pct = (uint8_t)pct;
    _cpu_work_us = 0;
    _cpu_window_start = millis();
  }

  // -----------------------------------------------------------------------
  // WiFi disconnect watchdog (only when we expect WiFi to be up)
  // -----------------------------------------------------------------------
  if (current_screen == SCREEN_DASHBOARD && millis() - _last_wifi_check_ms > WIFI_CHECK_INTERVAL_MS) {
    _last_wifi_check_ms = millis();
    bool _no_ip = WiFi.status() == WL_CONNECTED && WiFi.localIP() == IPAddress(0, 0, 0, 0);
    if (WiFi.status() != WL_CONNECTED || _no_ip) {
      Serial.println(_no_ip ? "[main] DHCP lease lost (IP gone) — reconnecting..."
                            : "[main] WiFi disconnected — attempting reconnect...");
      ui_set_led(true, false, false);  // Red = disconnected

      // Try quick reconnect with saved credentials
      if (!ui_wifi_auto_connect(WIFI_RECONNECT_TIMEOUT_MS)) {
        Serial.println("[main] Reconnect failed — showing WiFi setup with auto-search");
        if (daemon_running) {
          npDaemon.stop();
          daemon_running = false;
        }
        current_screen = SCREEN_WIFI;
        ui_wifi_create(_on_wifi_reconnected, true);
        return;  // skip rest of this loop iteration
      }
      Serial.println("[main] WiFi reconnected");
      ui_load_led_color();  // restore LED
    }
  }

  // Handle touch input
  int16_t tx, ty;
  if (ui_touch_read(&tx, &ty)) {
    switch (current_screen) {
      case SCREEN_WIFI:
        ui_wifi_handle_touch(tx, ty);
        break;
        
      case SCREEN_ENROLL:
        ui_enroll_handle_touch(tx, ty);
        break;
        
      case SCREEN_DASHBOARD:
        ui_dashboard_handle_touch(tx, ty);
        break;
        
      case SCREEN_SETTINGS:
        ui_settings_handle_touch(tx, ty);
        break;

      case SCREEN_CONFIG:
        ui_config_handle_touch(tx, ty);
        break;

      case SCREEN_AUTH:
        _auth_handle_touch(tx, ty);
        break;

      case SCREEN_NONE:
        // Error screen – any touch triggers reset
        _do_reset();
        break;
        
      default:
        break;
    }
  }
  
  // Update current screen
  switch (current_screen) {
    case SCREEN_WIFI:
      ui_wifi_update();
      break;
      
    case SCREEN_ENROLL:
      ui_enroll_update();
      ui_enroll_process_events();
      break;
      
    case SCREEN_SETTINGS:
      ui_settings_update();
      break;

    case SCREEN_CONFIG:
      ui_config_update();
      break;

    case SCREEN_AUTH:
      _auth_loop();
      break;

    case SCREEN_DASHBOARD:
      // Drive NoPorts daemon
      if (daemon_running && npDaemon.isRunning()) {
        // Exclude daemon loop from CPU measurement — it blocks on
        // socket read (up to 100ms idle wait, not real CPU work)
        uint32_t daemon_start = micros();
        npDaemon.loop();
        _cpu_work_us -= (micros() - daemon_start);  // subtract blocking I/O time
      }

      // Update dashboard periodically.  Outside the isRunning() gate so the
      // display keeps showing the real daemon state after an internal stop
      // instead of freezing on the last value sampled while it was running.
      if (daemon_running) {
        static uint32_t last_update = 0;
        if (millis() - last_update > 500) {
          last_update = millis();
          uint32_t tp_in = 0, tp_out = 0;
          npDaemon.getThroughput(tp_in, tp_out);
          ui_dashboard_update(npDaemon.getActiveRelayCount(),
                            daemon_state_str(npDaemon.getState()),
                            _total_tunnels, _total_pings,
                            tp_in, tp_out, npDaemon.getRelayCpuPct(),
                            npDaemon.getRelayPcbCount(),
                            npDaemon.getRelayPcbMax());
        }
      }

      // Daemon supervision.  Every intentional stop in this sketch clears
      // daemon_running first, so daemon_running with isRunning() false means
      // the daemon stopped on its own (internal error, or the testing
      // shutdown notification).  Restart it in place, escalating to a reboot
      // after DAEMON_RESTART_MAX failed attempts.
      {
        static bool     _sup_active   = false;
        static uint8_t  _sup_attempts = 0;
        static uint32_t _sup_next_ms  = 0;
        static uint32_t _sup_up_since = 0;

        if (daemon_running && npDaemon.isRunning()) {
          if (_sup_up_since == 0) _sup_up_since = millis();
          if (_sup_attempts > 0 && millis() - _sup_up_since > DAEMON_STABLE_MS)
            _sup_attempts = 0;
          _sup_active = false;
        } else {
          _sup_up_since = 0;
          if (daemon_running && !_sup_active) {
            Serial.println("[main] Daemon stopped unexpectedly — supervisor engaged");
            _sup_active  = true;
            _sup_next_ms = millis() + DAEMON_RESTART_DELAY_MS;
          }
          if (_sup_active) {
            if (WiFi.status() != WL_CONNECTED) {
              // WiFi outage: the WiFi watchdog above owns recovery and
              // restarts the daemon after reconnecting — stand down.
              _sup_active = false;
            } else if ((int32_t)(millis() - _sup_next_ms) >= 0) {
              if (_sup_attempts >= DAEMON_RESTART_MAX)
                reboot_with_reason("daemon would not stay up");
              _sup_attempts++;
              Serial.printf("[main] Supervisor: daemon restart %u/%u\n",
                            _sup_attempts, DAEMON_RESTART_MAX);
              if (daemon_running) {
                npDaemon.stop();
                daemon_running = false;
              }
              delay(2000);  // let atServer drain the old session
              if (start_daemon()) {
                Serial.println("[main] Supervisor: daemon restarted");
              } else {
                Serial.printf("[main] Supervisor: restart failed: %s\n",
                              npDaemon.getLastError());
              }
              _sup_next_ms = millis() + DAEMON_RESTART_DELAY_MS;
            }
          }
        }
      }
      break;
      
    default:
      break;
  }
  
  // Record work time before yielding
  _cpu_work_us += (micros() - _cpu_loop_start_us);

  // Daily NTP re-sync — randomized interval (23–25 h) to avoid predictable timing
  if (current_screen == SCREEN_DASHBOARD) {
    static bool     _ntp_init     = false;
    static uint32_t _ntp_last_ms  = 0;
    static uint32_t _ntp_interval = 0;
    if (!_ntp_init) {
      _ntp_init     = true;
      _ntp_last_ms  = millis();
      _ntp_interval = 82800000UL + (esp_random() % 7200000UL);
    } else if (millis() - _ntp_last_ms > _ntp_interval) {
      _ntp_last_ms  = millis();
      _ntp_interval = 82800000UL + (esp_random() % 7200000UL);
      sync_ntp_time();
    }
  }

  ui_led_tick();  // advance breathing LED waveform every ~10ms tick
  esp_task_wdt_reset();
  delay(10);  // yield to FreeRTOS
}
