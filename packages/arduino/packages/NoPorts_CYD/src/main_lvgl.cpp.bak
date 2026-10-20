/**
 * @file main.cpp
 * @brief NoPorts CYD – main entry point
 *
 * Boot flow:
 *   1. Init smart display (ILI9341 + XPT2046 + RGB LED)
 *   2. Init LVGL common resources
 *   3. If previously configured → auto-connect WiFi → load keys → daemon →
 *      dashboard
 *   4. If not configured → WiFi screen → enroll screen → dashboard
 *
 * loop():
 *   - lv_timer_handler()   (drives LVGL)
 *   - npDaemon.loop()      (drives NoPorts monitor/relay)
 *   - ui_dashboard_update() (refreshes stats from event queue)
 */

#include <Arduino.h>
#include <LittleFS.h>
#include <esp32_smartdisplay.h>
#include <NoPorts.h>

extern "C" {
  #include "atlogger/atlogger.h"
}

#include "ui_common.h"
#include "ui_calibrate.h"
#include "ui_wifi.h"
#include "ui_enroll.h"
#include "ui_dashboard.h"

// ---------------------------------------------------------------------------
// Globals
// ---------------------------------------------------------------------------
static NoPortsDaemon npDaemon;
static bool          daemon_running = false;

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

static void on_tunnel_open(const char *host, uint16_t port,
                           const char *session_id) {
  char buf[EVENT_TEXT_LEN];
  snprintf(buf, sizeof(buf), "Tunnel %s:%u [%s]", host, port,
           session_id ? session_id : "");
  ui_event_push(UI_EVT_TUNNEL_OPEN, buf);
}

static void on_tunnel_close(const char *session_id) {
  char buf[EVENT_TEXT_LEN];
  snprintf(buf, sizeof(buf), "Closed [%s]",
           session_id ? session_id : "");
  ui_event_push(UI_EVT_TUNNEL_CLOSE, buf);
}

static void on_ping(const char *from_atsign) {
  char buf[EVENT_TEXT_LEN];
  snprintf(buf, sizeof(buf), "Ping from %s",
           from_atsign ? from_atsign : "?");
  ui_event_push(UI_EVT_PING, buf);
}

// ---------------------------------------------------------------------------
// Start the NoPorts daemon (called after WiFi + enrollment are done)
// ---------------------------------------------------------------------------

static bool start_daemon() {
  String atsign  = ui_load_string(NVS_KEY_ATSIGN);
  String device  = ui_load_string(NVS_KEY_DEVICE);
  String manager = ui_load_string(NVS_KEY_MANAGER);

  if (atsign.length() == 0 || device.length() == 0) {
    Serial.println("[main] Missing atSign/device in NVS – cannot start daemon");
    return false;
  }

  NoPortsConfig config;
  noports_config_init(&config);
  config.atsign          = atsign.c_str();
  config.device_name     = device.c_str();
  config.manager_list[0] = manager.c_str();
  config.manager_count   = 1;

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
    Serial.printf("[main] Failed to load keys from %s (err=%d)\n",
                  ATKEYS_PATH, res);
    return false;
  }
  Serial.println("[main] Keys loaded from LittleFS");

  // Load permitopen from LittleFS if present
  // (future: parse /permitopen.json and populate config.permitopen[])

  if (!npDaemon.begin(config)) {
    Serial.printf("[main] Daemon begin failed: %s\n", npDaemon.getLastError());
    noports_keys_free(&config);
    return false;
  }

  noports_keys_free(&config);
  daemon_running = true;
  Serial.println("[main] NoPorts daemon running!");
  return true;
}

// ---------------------------------------------------------------------------
// Screen transition callbacks
// ---------------------------------------------------------------------------

// Sync system time via NTP (required for TLS certificate validation)
static void sync_ntp_time() {
  Serial.println("[NTP] Syncing time...");
  configTime(0, 0, "pool.ntp.org", "time.nist.gov");

  struct tm timeinfo;
  int retries = 0;
  while (!getLocalTime(&timeinfo, 1000) && retries < 10) {
    retries++;
    Serial.printf("[NTP] Waiting for time... (%d/10)\n", retries);
  }
  if (retries < 10) {
    char buf[64];
    strftime(buf, sizeof(buf), "%Y-%m-%d %H:%M:%S UTC", &timeinfo);
    Serial.printf("[NTP] Time set: %s\n", buf);
  } else {
    Serial.println("[NTP] WARNING: Failed to get time – TLS may fail");
  }
}

// Called when WiFi connects (both fresh setup and re-setup paths)
static void on_wifi_connected() {
  sync_ntp_time();
  if (ui_is_configured()) {
    // Already enrolled – go straight to daemon + dashboard
    if (start_daemon()) {
      ui_dashboard_create();
    } else {
      // Failed to start daemon – show enrollment again
      ui_enroll_create([]() {
        if (start_daemon()) {
          ui_dashboard_create();
        }
      });
    }
  } else {
    // First run – show enrollment screen
    ui_enroll_create([]() {
      if (start_daemon()) {
        ui_dashboard_create();
      }
    });
  }
}

// ---------------------------------------------------------------------------
// Continue boot after calibration (or if calibration was already loaded)
// ---------------------------------------------------------------------------

static void continue_boot();  // forward declaration

// Show a splash with saved SSID and a "Change WiFi" button.
// If the button isn't tapped within 5 seconds, auto-connect.
static lv_timer_t *_wifi_countdown_timer = nullptr;

static void _cancel_countdown_cb(lv_event_t *e) {
  (void)e;
  if (_wifi_countdown_timer) {
    // Free the countdown context
    free(_wifi_countdown_timer->user_data);
    lv_timer_del(_wifi_countdown_timer);
    _wifi_countdown_timer = nullptr;
  }
  Serial.println("[main] User chose to change WiFi");
  ui_wifi_create(on_wifi_connected);
}

static void show_wifi_splash() {
  String ssid = ui_load_string(NVS_KEY_SSID);

  lv_obj_t *splash = lv_obj_create(nullptr);
  lv_obj_set_style_bg_color(splash, COLOR_BG_DARK, 0);

  char msg[80];
  snprintf(msg, sizeof(msg), LV_SYMBOL_WIFI "  Connecting to: %s", ssid.c_str());
  lv_obj_t *lbl = ui_create_label(splash, msg, &lv_font_montserrat_16);
  lv_obj_align(lbl, LV_ALIGN_CENTER, 0, -30);

  // Countdown label
  lv_obj_t *countdown = ui_create_label(splash, "Auto-connect in 5s...",
                                        &lv_font_montserrat_12);
  lv_obj_set_style_text_color(countdown, COLOR_TEXT_GREY, 0);
  lv_obj_align(countdown, LV_ALIGN_CENTER, 0, 0);

  // "Change WiFi" button
  lv_obj_t *btn = ui_create_btn(splash, LV_SYMBOL_REFRESH " Change WiFi",
                                _cancel_countdown_cb);
  lv_obj_align(btn, LV_ALIGN_CENTER, 0, 40);

  lv_scr_load(splash);
  lv_timer_handler();

  // Create countdown timer (ticks every 1s, 5 times)
  struct CountdownCtx {
    lv_obj_t *label;
    int remaining;
  };
  CountdownCtx *ctx = (CountdownCtx *)malloc(sizeof(CountdownCtx));
  ctx->label = countdown;
  ctx->remaining = 5;

  _wifi_countdown_timer = lv_timer_create([](lv_timer_t *t) {
    CountdownCtx *c = (CountdownCtx *)t->user_data;
    c->remaining--;
    if (c->remaining > 0) {
      char buf[32];
      snprintf(buf, sizeof(buf), "Auto-connect in %ds...", c->remaining);
      lv_label_set_text(c->label, buf);
    } else {
      free(c);
      lv_timer_del(t);
      _wifi_countdown_timer = nullptr;

      // Auto-connect with saved creds
      Serial.println("[main] Auto-connect timeout – connecting with saved WiFi");
      if (ui_wifi_auto_connect(10000)) {
        smartdisplay_led_set_rgb(false, false, true);
        sync_ntp_time();
        if (ui_is_configured()) {
          if (start_daemon()) {
            ui_dashboard_create();
          } else {
            ui_enroll_create([]() {
              if (start_daemon()) ui_dashboard_create();
            });
          }
        } else {
          ui_enroll_create([]() {
            if (start_daemon()) ui_dashboard_create();
          });
        }
      } else {
        Serial.println("[main] Auto-connect failed – showing WiFi setup");
        ui_wifi_create(on_wifi_connected);
      }
    }
  }, 1000, ctx);
}

static void continue_boot() {
  String ssid = ui_load_string(NVS_KEY_SSID);

  if (ssid.length() > 0) {
    // We have saved WiFi – show splash with change option
    show_wifi_splash();
  } else {
    // No saved WiFi – go straight to WiFi setup
    Serial.println("[main] No saved WiFi – showing WiFi setup");
    ui_wifi_create(on_wifi_connected);
  }
}

// ---------------------------------------------------------------------------
// setup()
// ---------------------------------------------------------------------------

void setup() {
  Serial.begin(115200);
  delay(500);
  Serial.println("\n==============================");
  Serial.println("  NoPorts CYD – Starting up");
  Serial.println("==============================\n");

  // Enable at_client logging
  atlogger_set_logging_level(ATLOGGER_LOGGING_LEVEL_INFO);

  // Initialise the smart display (configures ILI9341, XPT2046, RGB LED)
  smartdisplay_init();

  // LVGL 9.x requires a tick source – tell it to use Arduino millis()
  lv_tick_set_cb([]() -> uint32_t { return (uint32_t)millis(); });

  // Set backlight to full brightness
  smartdisplay_lcd_set_backlight(1.0f);

  // Green LED during boot (API takes bool: on/off per channel)
  smartdisplay_led_set_rgb(false, true, false);

  // Init LVGL common styles and event queue
  ui_common_init();

  // Load or run touch calibration
  if (!ui_calibrate_load()) {
    Serial.println("[main] No calibration found – running calibration");
    ui_calibrate_create([]() {
      continue_boot();
    });
    return;  // setup() done – calibration screen is active
  }

  // Calibration loaded – proceed with normal boot
  continue_boot();
}

// ---------------------------------------------------------------------------
// loop()
// ---------------------------------------------------------------------------

void loop() {
  // Drive LVGL
  lv_timer_handler();

  // Process enrollment events (thread-safe LVGL updates)
  ui_enroll_process_events();

  // Drive NoPorts daemon
  if (daemon_running && npDaemon.isRunning()) {
    npDaemon.loop();

    // Update dashboard every ~500ms
    static uint32_t last_update = 0;
    if (millis() - last_update > 500) {
      last_update = millis();
      ui_dashboard_update(npDaemon.getActiveRelayCount(),
                          daemon_state_str(npDaemon.getState()));
    }
  }

  delay(5);
}
