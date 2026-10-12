/**
 * @file main.cpp
 * @brief NoPorts PoE — headless daemon for M5Stack Unit PoE (ESP32-P4)
 *
 * Boot flow:
 *   1. Init Ethernet (DHCP) — or WiFi AP in test_esp32 build
 *   2. Start web server on port 80 immediately
 *   3. After network is up: mDNS, NTP, daemon (if already configured)
 *   4. loop(): web_server_handle(), npDaemon.loop(), Ethernet watchdog
 *
 * First-time setup:
 *   Browse to http://noports-poe.local  (or device IP printed on serial)
 *   Complete /setup → /enroll → dashboard
 *
 * Test build (NOPORTS_TEST_WIFI_AP):
 *   Compile env=test_esp32, flash any ESP32.
 *   Connect laptop to "NoPorts-Test" AP, browse to 192.168.4.1
 */

#include <Arduino.h>
#include <LittleFS.h>
#include <ESPmDNS.h>
#if ESP_IDF_VERSION_MAJOR >= 5
  #include <esp_sntp.h>        // IDF 5+: esp_sntp_stop()
#else
  #include <lwip/apps/sntp.h>  // IDF 4.x: sntp_stop() (no esp_ wrapper yet)
#endif
#include <NoPorts.h>

extern "C" {
#include "atlogger/atlogger.h"
}

#include "nvsconfig.h"
#include "web_server.h"
#include "led.h"
#include <esp_task_wdt.h>

// ─── Network includes — ETH for P4, WiFi for test build ───────────────────
#ifdef NOPORTS_TEST_WIFI_AP
  #include <WiFi.h>
#else
  #include <ETH.h>

  // ESP32-P4 built-in EMAC (RMII) + IP101GRI PHY
  // Pin assignments from M5Stack Unit PoE-P4 schematic and official demo:
  //   https://docs.m5stack.com/en/arduino/m5unit_poe-p4/ethernet
  //   https://github.com/m5stack/M5Unit-PoE-P4-UserDemo
  // RMII data lines (TXD0/1 TX_EN RXD0/1 CRS_DV CLK) are fixed in P4 silicon;
  // only the MDIO management bus and PHY reset are configurable here.
  // esp32p4 variant pins_arduino.h pre-defines these for TLK110; override for IP101GRI.
  #undef  ETH_PHY_TYPE
  #define ETH_PHY_TYPE   ETH_PHY_IP101
  #undef  ETH_PHY_ADDR
  #define ETH_PHY_ADDR   1    // IP101GRI default PHY address
  #undef  ETH_PHY_MDC
  #define ETH_PHY_MDC    31   // G31 = RMII_MDC
  #undef  ETH_PHY_MDIO
  #define ETH_PHY_MDIO   52   // G52 = RMII_MDIO
  #undef  ETH_PHY_POWER
  #define ETH_PHY_POWER  51   // G51 = PHY_RST (active-low reset / power enable)
  #undef  ETH_CLK_MODE
  #define ETH_CLK_MODE   EMAC_CLK_EXT_IN  // 50 MHz ref clock IN from IP101GRI on G50
#endif

// ─── Globals ──────────────────────────────────────────────────────────────
static NoPortsDaemon npDaemon;
static bool          daemon_running = false;

static DaemonStats   g_stats   = {};
static EnrollStatus  g_enroll  = {};

static bool g_net_up           = false;  // set true once we have an IP
static bool g_post_net_done    = false;  // NTP + mDNS + daemon start done once

static uint32_t g_last_eth_check = 0;
#define ETH_CHECK_INTERVAL_MS   5000

// Hardware watchdog — 60 s covers any plausible TLS handshake or DHCP wait.
// trigger_panic = true writes a stack dump to flash before resetting.
#define WDT_TIMEOUT_MS          60000

// Heap recovery thresholds.  AES DMA needs ~30 KB contiguous; below that
// TLS starts failing.  Thresholds are conservative to catch slow leaks early.
#define HEAP_WARN_BYTES         50000   // log warning only
#define HEAP_RECOVER_BYTES      30000   // restart daemon to free relay buffers
#define HEAP_REBOOT_BYTES       15000   // unrecoverable — reboot

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

// ─── Daemon callbacks → stats struct (called from npDaemon internals) ─────

static void on_tunnel_open(const char *host, uint16_t port, const char *) {
  g_stats.total_tunnels++;
  led_on_tunnel_event();
  Serial.printf("[np] Tunnel open %s:%u  free=%u\n", host, port, ESP.getFreeHeap());
}

static void on_tunnel_close(const char *) {
  led_on_tunnel_event();
  Serial.printf("[np] Tunnel closed  free=%u\n", ESP.getFreeHeap());
}

static void on_ping(const char *from) {
  g_stats.total_pings++;
  Serial.printf("[np] Ping from %s\n", from ? from : "?");
}

// ─── Daemon control ───────────────────────────────────────────────────────

// Parse NVS config and start the daemon.  Returns true on success.
static bool start_daemon() {
  static String atsign, device, managers_raw, manager_items[NOPORTS_MAX_MANAGERS];
  static String policy_at, permitopen_raw, po_items[NOPORTS_MAX_PERMITOPEN];
  static String po_hosts[NOPORTS_MAX_PERMITOPEN];
  static String root_spec;

  atsign  = nvs_load(NVS_KEY_ATSIGN);
  device  = nvs_load(NVS_KEY_DEVICE);
  if (atsign.isEmpty() || device.isEmpty()) {
    Serial.println("[main] Missing atSign/device in NVS");
    return false;
  }

  bool policy_mode = (nvs_load(NVS_KEY_RULES_MODE) == "1");
  if (policy_mode) {
    policy_at = nvs_load(NVS_KEY_POLICY_AT);
  } else {
    managers_raw = nvs_load(NVS_KEY_MANAGERS);
    if (managers_raw.isEmpty()) managers_raw = nvs_load(NVS_KEY_MANAGER);
  }

  int mgr_count = policy_mode ? 0
                              : nvs_parse_csv(managers_raw, manager_items, NOPORTS_MAX_MANAGERS);

  permitopen_raw = nvs_load(NVS_KEY_PERMITOPEN);
  int po_count   = nvs_parse_csv(permitopen_raw, po_items, NOPORTS_MAX_PERMITOPEN);

  // Always permit the web UI via NoPorts tunnel regardless of the user's list.
  // Without this, a strict permitopen config would lock out the UI when web_local=1.
  {
    bool ui_covered = false;
    for (int i = 0; i < po_count && !ui_covered; i++) {
      String s = po_items[i]; s.trim();
      if (s == "*" || s == "127.0.0.1:80") ui_covered = true;
    }
    if (!ui_covered && po_count < NOPORTS_MAX_PERMITOPEN)
      po_items[po_count++] = "127.0.0.1:80";
  }

  NoPortsConfig cfg;
  noports_config_init(&cfg);
  cfg.atsign      = atsign.c_str();
  cfg.device_name = device.c_str();

  // Root server spec: host[:port] or proxy:host[:port]; empty → root.atsign.org:64
  root_spec = nvs_load(NVS_KEY_ROOT);
  if (root_spec.length() > 0) cfg.root_domain = root_spec.c_str();

  if (policy_mode) {
    cfg.policy_atsign = policy_at.length() ? policy_at.c_str() : nullptr;
  } else {
    for (int i = 0; i < mgr_count; i++) cfg.manager_list[i] = manager_items[i].c_str();
    cfg.manager_count = mgr_count;
  }

  int po_valid = 0;
  for (int i = 0; i < po_count; i++) {
    int colon = po_items[i].indexOf(':');
    if (colon > 0) {
      String port_str = po_items[i].substring(colon + 1);
      uint16_t port;
      if (port_str == "*") {
        port = 0;  // explicit port wildcard
      } else {
        // Strict parse, fail closed: toInt() stops at the first non-digit
        // ("2x2" -> 2) and the cast wraps out-of-range values ("70000" ->
        // 4464), either of which would silently widen a rule on a typo. Reject
        // the rule instead of permitting an unintended port.
        char *end = nullptr;
        long v = strtol(port_str.c_str(), &end, 10);
        if (end == port_str.c_str() || *end != '\0' || v < 1 || v > UINT16_MAX) {
          Serial.printf("[main] permitopen rule '%s' has invalid port — skipping\n",
                        po_items[i].c_str());
          continue;
        }
        port = (uint16_t)v;
      }
      po_hosts[po_valid] = po_items[i].substring(0, colon);
      cfg.permitopen[po_valid].host = po_hosts[po_valid].c_str();
      cfg.permitopen[po_valid].port = port;
      po_valid++;
    } else if (po_items[i] == "*") {
      po_hosts[po_valid] = "*";
      cfg.permitopen[po_valid].host = po_hosts[po_valid].c_str();
      cfg.permitopen[po_valid].port = 0;
      po_valid++;
    }
  }
  cfg.permitopen_count = po_valid;

  cfg.on_tunnel_open  = on_tunnel_open;
  cfg.on_tunnel_close = on_tunnel_close;
  cfg.on_ping         = on_ping;

  if (!LittleFS.begin(false)) { Serial.println("[main] LittleFS mount failed"); return false; }

  if (noports_keys_load_from_file(&cfg, ATKEYS_PATH) != 0) {
    Serial.printf("[main] Keys not found at %s\n", ATKEYS_PATH);
    return false;
  }

  if (!npDaemon.begin(cfg)) {
    Serial.printf("[main] Daemon failed: %s\n", npDaemon.getLastError());
    noports_keys_free(&cfg);
    return false;
  }
  noports_keys_free(&cfg);

  // Apply NVS-stored tuning
  String ka = nvs_load(NVS_KEY_WORKER_KEEPALIVE);
  if (!ka.isEmpty() && ka.toInt() >= 0)
    npDaemon.setWorkerKeepaliveMs((uint32_t)constrain(ka.toInt(), 0, 15) * 60000UL);

  String mr = nvs_load(NVS_KEY_MAX_RELAYS);
  if (!mr.isEmpty() && mr.toInt() >= 1)
    npDaemon.setMaxRelays((uint8_t)constrain(mr.toInt(), 1, 8));

  daemon_running = true;
  Serial.println("[main] NoPorts daemon running");
  return true;
}

// Called from loop() (never from inside an HTTP handler) after settings are saved.
static void restart_daemon_cb() {
  bool was_running = daemon_running;
  if (daemon_running) { npDaemon.stop(); daemon_running = false; }
  if (was_running) delay(2000);  // let atServer drain only if we stopped something
  if (!start_daemon() && was_running)
    Serial.println("[main] Daemon restart failed after settings change");
}

// ─── Network helpers ──────────────────────────────────────────────────────

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
  String s = nvs_load(NVS_KEY_NTP_GOOD);
  if (s.length()) {
    time_t persisted = (time_t)strtoll(s.c_str(), nullptr, 10);
    if (persisted > floor) floor = persisted;
  }
  return floor;
}

// Persist forward progress of the known-good clock so the floor survives reboot.
// The ~24h re-sync interval keeps this to about one NVS write per day.
static void _persist_ntp_good(time_t t) {
  String s = nvs_load(NVS_KEY_NTP_GOOD);
  time_t stored = s.length() ? (time_t)strtoll(s.c_str(), nullptr, 10) : 0;
  if (t > stored) {
    char buf[24];
    snprintf(buf, sizeof(buf), "%lld", (long long)t);
    nvs_save(NVS_KEY_NTP_GOOD, buf);
  }
}

static void sync_ntp() {
  Serial.println("[NTP] Syncing...");
  time_t before = time(nullptr);
  configTime(0, 0, "pool.ntp.org", "time.nist.gov", "time.google.com");
  struct tm t;
  int retries = 0;
  while (!getLocalTime(&t, 1000) && ++retries < 10)
    Serial.printf("[NTP] Waiting (%d/10)\n", retries);
  if (retries < 10) {
    time_t after = mktime(&t);
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
      char buf[32]; strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M UTC", &t);
      Serial.printf("[NTP] %s\n", buf);
    }
  } else {
    Serial.println("[NTP] WARNING: Failed");
  }
#if ESP_IDF_VERSION_MAJOR >= 5
  esp_sntp_stop();  // IDF 5+: wrapper in <esp_sntp.h>
#else
  sntp_stop();      // IDF 4.x: lwIP-level function
#endif
}

// Run once after we first get a network IP.
static void post_network_setup() {
  if (g_post_net_done) return;
  g_post_net_done = true;

  Serial.printf("[main] IP: %s\n", web_server_ip().c_str());
  Serial.println("[main] Browse to http://noports-poe.local  (or the IP above)");

  // mDNS — skip when web UI is localhost-only; advertising a hostname that
  // points to a loopback-bound server is pointless and leaks device presence.
  if (!web_server_is_local()) {
    const char *hostname =
#ifdef NOPORTS_TEST_WIFI_AP
      "noports-test";
#else
      "noports-poe";
#endif
    if (MDNS.begin(hostname)) {
      MDNS.addService("http", "tcp", 80);
      Serial.printf("[mDNS] http://%s.local\n", hostname);
    }
  } else {
    Serial.println("[mDNS] Skipped — web UI is localhost-only");
  }

  sync_ntp();

  // Auto-start daemon if already enrolled
  if (nvs_is_configured() && LittleFS.exists(ATKEYS_PATH)) {
    if (!nvs_rules_valid()) {
      Serial.println("[main] Config incomplete — open web UI to complete setup");
    } else {
      Serial.println("[main] Auto-starting daemon...");
      if (!start_daemon())
        Serial.println("[main] Auto-start failed — check web UI for status");
    }
  } else {
    Serial.println("[main] Not configured — open web UI to set up");
  }
}

// ─── Ethernet event handler (production build only) ───────────────────────
#ifndef NOPORTS_TEST_WIFI_AP
static void on_eth_event(arduino_event_id_t event, arduino_event_info_t) {
  switch (event) {
    case ARDUINO_EVENT_ETH_START:
      Serial.println("[ETH] Started");
      ETH.setHostname("noports-poe");
      break;
    case ARDUINO_EVENT_ETH_CONNECTED:
      Serial.println("[ETH] Link up");
      break;
    case ARDUINO_EVENT_ETH_GOT_IP:
      g_net_up = true;
      Serial.printf("[ETH] IP: %s  speed: %d Mbps %s\n",
                    ETH.localIP().toString().c_str(),
                    ETH.linkSpeed(),
                    ETH.fullDuplex() ? "FD" : "HD");
      break;
    case ARDUINO_EVENT_ETH_LOST_IP:
      // DHCP lease expired and renewal failed — IP is gone, link may still be up.
      // Treat identically to link-down: stop daemon and re-arm post-network setup
      // so that when GOT_IP fires again (renewed lease) the daemon restarts cleanly.
      Serial.println("[ETH] IP lost (DHCP lease expired)");
      g_net_up        = false;
      g_post_net_done = false;
      if (daemon_running) { npDaemon.stop(); daemon_running = false; }
      break;
    case ARDUINO_EVENT_ETH_DISCONNECTED:
      Serial.println("[ETH] Link down");
      g_net_up       = false;
      g_post_net_done = false;  // allow full re-init (mDNS, NTP, daemon) on reconnect
      if (daemon_running) { npDaemon.stop(); daemon_running = false; }
      break;
    case ARDUINO_EVENT_ETH_STOP:
      Serial.println("[ETH] Stopped");
      g_net_up        = false;
      g_post_net_done = false;
      if (daemon_running) { npDaemon.stop(); daemon_running = false; }
      break;
    default: break;
  }
}
#endif

// ─── setup() ──────────────────────────────────────────────────────────────

void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println("\n=============================");
  Serial.println("  NoPorts PoE  v" POE_APP_VERSION);
  Serial.println("=============================\n");

  if (g_reboot_reason.magic == REBOOT_REASON_MAGIC) {
    Serial.printf("[main] Previous reboot was self-initiated: %s\n",
                  g_reboot_reason.reason);
    g_reboot_reason.magic = 0;
  }

  atlogger_set_logging_level(ATLOGGER_LOGGING_LEVEL_INFO);

  // Hardware task watchdog — catches infinite loops and hard hangs.
  // The loop task feeds it via esp_task_wdt_reset() every iteration.
  {
#if ESP_IDF_VERSION_MAJOR >= 5
    esp_task_wdt_config_t wdt_cfg = {
      .timeout_ms     = WDT_TIMEOUT_MS,
      .idle_core_mask = 0,
      .trigger_panic  = true,
    };
    esp_task_wdt_reconfigure(&wdt_cfg);
#else
    // IDF 4.x (test_esp32s3 env): seconds-based API, no config struct
    esp_task_wdt_init(WDT_TIMEOUT_MS / 1000, true);
#endif
    esp_task_wdt_add(NULL);  // subscribe the current (loop) task
    Serial.printf("[wdt] Hardware watchdog: %u s\n", WDT_TIMEOUT_MS / 1000);
  }

  if (!LittleFS.begin(true)) {
    Serial.println("[main] LittleFS init failed — halting");
    while (true) delay(1000);
  }

  {
    String lm = nvs_load(NVS_KEY_LED_MODE);
    LedMode mode = lm.isEmpty() ? LedMode::STATUS : (LedMode)constrain(lm.toInt(), 0, 3);
    led_init(mode);
  }

#ifdef NOPORTS_TEST_WIFI_AP
  // ── Test mode: create a WiFi AP ─────────────────────────────────────────
  Serial.println("[test] Starting WiFi AP: " TEST_WIFI_SSID);
  WiFi.mode(WIFI_AP);
  WiFi.softAP(TEST_WIFI_SSID, TEST_WIFI_PASS);
  Serial.printf("[test] AP IP: %s\n", WiFi.softAPIP().toString().c_str());
  Serial.println("[test] Connect to '" TEST_WIFI_SSID "' then browse to http://192.168.4.1");
  g_net_up = true;  // AP is immediately available
#else
  // ── Production: Ethernet ─────────────────────────────────────────────────
  Network.onEvent(on_eth_event);
  ETH.begin(ETH_PHY_TYPE, ETH_PHY_ADDR, ETH_PHY_MDC, ETH_PHY_MDIO,
            ETH_PHY_POWER, ETH_CLK_MODE);
  Serial.println("[ETH] Ethernet init — waiting for link + DHCP...");
#endif

  // Start web server immediately (reachable once IP is assigned)
  web_server_begin(&npDaemon, &daemon_running, &g_stats, &g_enroll, restart_daemon_cb);

#ifdef NOPORTS_TEST_WIFI_AP
  // Post-network setup runs now since AP IP is available immediately
  post_network_setup();
#else
  Serial.println("[main] Web server started — waiting for Ethernet IP...");
#endif

  Serial.printf("[main] Free heap: %u bytes\n", ESP.getFreeHeap());
}

// ─── loop() ───────────────────────────────────────────────────────────────

void loop() {
  // Run-once post-network setup (triggered by ETH_GOT_IP event in production)
  if (g_net_up && !g_post_net_done) {
    post_network_setup();
  }

  // Serve HTTP requests
  web_server_handle();

  // Deferred daemon restart (requested by /api/settings POST — runs after response sent)
  if (web_server_restart_pending()) {
    web_server_clear_restart();
    restart_daemon_cb();
  }

  // Drive NoPorts daemon
  if (daemon_running && npDaemon.isRunning()) {
    npDaemon.loop();
  }

  // Refresh stats for web dashboard (every 500 ms).
  // Outside the isRunning() gate so the dashboard keeps showing the real
  // daemon state after an internal stop instead of freezing on the last
  // value sampled while it was still running.
  if (daemon_running) {
    static uint32_t last_stat = 0;
    if (millis() - last_stat > 500) {
      last_stat = millis();
      g_stats.state         = npDaemon.getState();
      g_stats.active_relays = npDaemon.getActiveRelayCount();
      g_stats.relay_cpu     = npDaemon.getRelayCpuPct();
      g_stats.pcb_count     = npDaemon.getRelayPcbCount();
      g_stats.pcb_max       = npDaemon.getRelayPcbMax();
      npDaemon.getThroughput(g_stats.bytes_in, g_stats.bytes_out);
    }
  }

  // Feed hardware watchdog — must happen at least once per WDT_TIMEOUT_MS
  esp_task_wdt_reset();

  // Heap monitor + recovery (every 10 s)
  {
    static uint32_t _last_heap_ms    = 0;
    static uint32_t _last_recover_ms = 0;
    if (millis() - _last_heap_ms > 10000) {
      _last_heap_ms = millis();
      uint32_t free_h = ESP.getFreeHeap();
      uint32_t min_h  = ESP.getMinFreeHeap();
      uint32_t large  = ESP.getMaxAllocHeap();
      Serial.printf("[mem] free=%u min=%u largest=%u\n", free_h, min_h, large);

      if (free_h < HEAP_REBOOT_BYTES) {
        reboot_with_reason("heap critically low");
      } else if (free_h < HEAP_RECOVER_BYTES) {
        // Restart daemon to release relay buffers; rate-limit to once per 5 min
        if (millis() - _last_recover_ms > 300000UL) {
          _last_recover_ms = millis();
          Serial.printf("[mem] LOW free=%u — restarting daemon\n", free_h);
          restart_daemon_cb();
        }
      } else if (free_h < HEAP_WARN_BYTES) {
        Serial.printf("[mem] WARN free=%u\n", free_h);
      }
    }
  }

  // Daemon supervision.  Every intentional stop in this sketch clears
  // daemon_running first, so daemon_running with isRunning() false means the
  // daemon stopped on its own (internal error, or the testing shutdown
  // notification).  Restart it in place, escalating to a reboot after
  // DAEMON_RESTART_MAX failed attempts.  This replaces the old "stuck in
  // ERROR" check, which never fired: g_stats.state stopped refreshing the
  // moment isRunning() went false, so it could never observe DAEMON_ERROR.
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
        if (!g_net_up) {
          // Network outage: the ETH event handlers re-arm post_network_setup()
          // and restart the daemon when the link returns — stand down.
          _sup_active = false;
        } else if ((int32_t)(millis() - _sup_next_ms) >= 0) {
          if (_sup_attempts >= DAEMON_RESTART_MAX)
            reboot_with_reason("daemon would not stay up");
          _sup_attempts++;
          Serial.printf("[main] Supervisor: daemon restart %u/%u\n",
                        _sup_attempts, DAEMON_RESTART_MAX);
          restart_daemon_cb();
          _sup_next_ms = millis() + DAEMON_RESTART_DELAY_MS;
        }
      }
    }
  }

  // Ethernet watchdog (production only)
#ifndef NOPORTS_TEST_WIFI_AP
  if (g_net_up && millis() - g_last_eth_check > ETH_CHECK_INTERVAL_MS) {
    g_last_eth_check = millis();
    if (!ETH.linkUp()) {
      Serial.println("[ETH] Link lost — stopping daemon, awaiting reconnect");
      g_net_up        = false;
      g_post_net_done = false;  // re-arm post_network_setup for when link returns
      if (daemon_running) { npDaemon.stop(); daemon_running = false; }
    }
  }
#endif

  // Daily NTP re-sync — randomized interval (23–25 h) to avoid predictable timing
  if (g_net_up) {
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
      sync_ntp();
    }
  }

  // Update LED
  {
    LedState ls;
    if (g_enroll.phase == ENROLL_RUNNING)         ls = LedState::ENROLLING;
    else if (!g_net_up)                            ls = LedState::NO_NETWORK;
    else if (!nvs_is_configured())                 ls = LedState::UNCONFIGURED;
    else if (!daemon_running)                      ls = LedState::ERROR;
    else                                           ls = LedState::RUNNING;
    led_update(ls);
  }

  delay(10);  // yield to FreeRTOS scheduler
}
