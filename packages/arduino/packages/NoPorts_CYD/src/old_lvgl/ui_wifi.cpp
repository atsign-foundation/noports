/**
 * @file ui_wifi.cpp
 * @brief WiFi setup screen implementation
 */

#include "ui_wifi.h"
#include "ui_common.h"
#include <WiFi.h>
#include <Arduino.h>

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
static lv_obj_t *_scr            = nullptr;
static lv_obj_t *_wifi_list      = nullptr;
static lv_obj_t *_password_ta    = nullptr;
static lv_obj_t *_keyboard       = nullptr;
static lv_obj_t *_status_label   = nullptr;
static lv_obj_t *_connect_btn    = nullptr;
static lv_obj_t *_scan_btn       = nullptr;
static lv_obj_t *_password_panel = nullptr;

static char _selected_ssid[64]   = {0};
static char _saved_password[128] = {0};
static char _ip_str[20]          = {0};
static void (*_on_connected_cb)() = nullptr;

// Forward declarations
static void _scan_cb(lv_event_t *e);
static void _ssid_clicked_cb(lv_event_t *e);
static void _connect_cb(lv_event_t *e);
static void _kb_ready_cb(lv_event_t *e);
static void _populate_list();
static void _show_password_panel(const char *ssid);
static void _set_status(const char *msg, lv_color_t color);

// ---------------------------------------------------------------------------
// Public
// ---------------------------------------------------------------------------

void ui_wifi_create(void (*on_connected)()) {
  _on_connected_cb = on_connected;

  _scr = lv_obj_create(nullptr);
  lv_obj_set_style_bg_color(_scr, COLOR_BG_DARK, 0);

  // Title
  lv_obj_t *title = ui_create_label(_scr, LV_SYMBOL_WIFI "  WiFi Setup",
                                    &lv_font_montserrat_20);
  lv_obj_align(title, LV_ALIGN_TOP_LEFT, 10, 8);

  // Scan button
  _scan_btn = ui_create_btn(_scr, LV_SYMBOL_REFRESH " Scan", _scan_cb);
  lv_obj_align(_scan_btn, LV_ALIGN_TOP_RIGHT, -10, 6);

  // Status label
  _status_label = ui_create_label(_scr, "Tap Scan to find networks",
                                  &lv_font_montserrat_12);
  lv_obj_set_style_text_color(_status_label, COLOR_TEXT_GREY, 0);
  lv_obj_align(_status_label, LV_ALIGN_TOP_LEFT, 10, 36);

  // WiFi network list
  _wifi_list = lv_list_create(_scr);
  lv_obj_set_size(_wifi_list, SCREEN_WIDTH - 20, 140);
  lv_obj_align(_wifi_list, LV_ALIGN_TOP_LEFT, 10, 54);
  lv_obj_set_style_bg_color(_wifi_list, COLOR_BG_CARD, 0);
  lv_obj_set_style_radius(_wifi_list, 6, 0);
  lv_obj_set_style_border_width(_wifi_list, 0, 0);
  lv_obj_set_style_pad_all(_wifi_list, 4, 0);

  // Password entry panel (hidden initially – full-screen overlay)
  _password_panel = lv_obj_create(_scr);
  lv_obj_set_size(_password_panel, SCREEN_WIDTH, SCREEN_HEIGHT);
  lv_obj_set_pos(_password_panel, 0, 0);
  lv_obj_set_style_bg_color(_password_panel, COLOR_BG_DARK, 0);
  lv_obj_set_style_bg_opa(_password_panel, LV_OPA_COVER, 0);
  lv_obj_set_style_border_width(_password_panel, 0, 0);
  lv_obj_set_style_pad_all(_password_panel, 0, 0);
  lv_obj_add_flag(_password_panel, LV_OBJ_FLAG_HIDDEN);

  lv_scr_load(_scr);

  // Auto-scan on entry
  _scan_cb(nullptr);
}

bool ui_wifi_auto_connect(int timeout_ms) {
  String ssid = ui_load_string(NVS_KEY_SSID);
  String pass = ui_load_string(NVS_KEY_PASS);
  if (ssid.length() == 0) return false;

  Serial.printf("[WiFi] Auto-connecting to '%s'...\n", ssid.c_str());
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid.c_str(), pass.c_str());

  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED &&
         (millis() - start) < (unsigned long)timeout_ms) {
    delay(250);
  }

  if (WiFi.status() == WL_CONNECTED) {
    snprintf(_ip_str, sizeof(_ip_str), "%s",
             WiFi.localIP().toString().c_str());
    Serial.printf("[WiFi] Connected: %s\n", _ip_str);
    return true;
  }

  Serial.println("[WiFi] Auto-connect failed");
  return false;
}

const char *ui_wifi_get_ip() {
  if (WiFi.status() == WL_CONNECTED) {
    snprintf(_ip_str, sizeof(_ip_str), "%s",
             WiFi.localIP().toString().c_str());
  } else {
    strcpy(_ip_str, "N/A");
  }
  return _ip_str;
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

static void _set_status(const char *msg, lv_color_t color) {
  if (_status_label) {
    lv_label_set_text(_status_label, msg);
    lv_obj_set_style_text_color(_status_label, color, 0);
  }
}

static void _populate_list() {
  int n = WiFi.scanComplete();
  if (n < 0) n = WiFi.scanNetworks(false, false);

  for (int i = 0; i < n && i < 20; i++) {
    const char *lock =
        (WiFi.encryptionType(i) == WIFI_AUTH_OPEN) ? LV_SYMBOL_EYE_OPEN
                                                   : LV_SYMBOL_CLOSE;
    int rssi = WiFi.RSSI(i);
    const char *signal =
        (rssi > -50) ? LV_SYMBOL_WIFI
                     : ((rssi > -70) ? LV_SYMBOL_WIFI : LV_SYMBOL_WARNING);

    char label[80];
    snprintf(label, sizeof(label), "%s %s  %s  %ddBm", signal,
             WiFi.SSID(i).c_str(), lock, rssi);

    lv_obj_t *btn = lv_list_add_btn(_wifi_list, nullptr, label);
    lv_obj_set_style_bg_color(btn, COLOR_BG_DARK, 0);
    lv_obj_set_style_text_color(btn, COLOR_TEXT_WHITE, 0);
    lv_obj_set_style_text_font(btn, &lv_font_montserrat_12, 0);
    lv_obj_set_style_bg_color(btn, COLOR_PRIMARY, LV_STATE_PRESSED);

    lv_obj_add_event_cb(btn, _ssid_clicked_cb, LV_EVENT_CLICKED,
                        (void *)(intptr_t)i);
  }
}

static void _show_password_panel(const char *ssid) {
  lv_obj_clean(_password_panel);
  lv_obj_clear_flag(_password_panel, LV_OBJ_FLAG_HIDDEN);

  char title[80];
  snprintf(title, sizeof(title), "Connect to: %s", ssid);
  lv_obj_t *lbl =
      ui_create_label(_password_panel, title, &lv_font_montserrat_14);
  lv_obj_align(lbl, LV_ALIGN_TOP_LEFT, 10, 8);

  // Password input
  _password_ta = lv_textarea_create(_password_panel);
  lv_obj_set_size(_password_ta, SCREEN_WIDTH - 100, 36);
  lv_obj_align(_password_ta, LV_ALIGN_TOP_LEFT, 10, 34);
  lv_textarea_set_one_line(_password_ta, true);
  lv_textarea_set_placeholder_text(_password_ta, "Password");
  lv_textarea_set_password_mode(_password_ta, true);
  lv_obj_set_style_bg_color(_password_ta, COLOR_BG_CARD, 0);
  lv_obj_set_style_text_color(_password_ta, COLOR_TEXT_WHITE, 0);
  lv_obj_set_style_border_color(_password_ta, COLOR_ACCENT, LV_STATE_FOCUSED);
  lv_obj_set_style_border_width(_password_ta, 2, LV_STATE_FOCUSED);

  // Connect button
  _connect_btn = ui_create_btn(_password_panel, "Connect", _connect_cb);
  lv_obj_align(_connect_btn, LV_ALIGN_TOP_RIGHT, -10, 34);

  // On-screen keyboard
  _keyboard = lv_keyboard_create(_password_panel);
  lv_keyboard_set_textarea(_keyboard, _password_ta);
  lv_obj_set_size(_keyboard, SCREEN_WIDTH, 100);
  lv_obj_align(_keyboard, LV_ALIGN_BOTTOM_MID, 0, 0);
  lv_obj_set_style_bg_color(_keyboard, COLOR_BG_CARD, 0);
  lv_obj_set_style_text_color(_keyboard, COLOR_TEXT_WHITE, 0);
  lv_obj_add_event_cb(_keyboard, _kb_ready_cb, LV_EVENT_READY, nullptr);

  lv_obj_add_state(_password_ta, LV_STATE_FOCUSED);
}

// ---------------------------------------------------------------------------
// Callbacks
// ---------------------------------------------------------------------------

static void _scan_cb(lv_event_t *e) {
  (void)e;
  _set_status("Scanning...", COLOR_TEXT_GREY);
  lv_obj_clean(_wifi_list);

  WiFi.mode(WIFI_STA);
  WiFi.disconnect();
  delay(100);

  int n = WiFi.scanNetworks(false, false);
  if (n == 0) {
    _set_status("No networks found", COLOR_ERROR);
  } else {
    char buf[64];
    snprintf(buf, sizeof(buf), "Found %d networks", n);
    _set_status(buf, COLOR_ACCENT);
    _populate_list();
  }
}

static void _ssid_clicked_cb(lv_event_t *e) {
  int idx = (int)(intptr_t)lv_event_get_user_data(e);
  String ssid = WiFi.SSID(idx);
  strncpy(_selected_ssid, ssid.c_str(), sizeof(_selected_ssid) - 1);
  _selected_ssid[sizeof(_selected_ssid) - 1] = '\0';

  if (WiFi.encryptionType(idx) == WIFI_AUTH_OPEN) {
    WiFi.begin(_selected_ssid);
    _set_status("Connecting to open network...", COLOR_ACCENT);
  } else {
    _show_password_panel(_selected_ssid);
  }
}

static void _connect_cb(lv_event_t *e) {
  (void)e;
  if (!_password_ta) return;

  const char *password = lv_textarea_get_text(_password_ta);
  if (strlen(password) < 1) return;

  // Copy password before we destroy the panel
  strncpy(_saved_password, password, sizeof(_saved_password) - 1);
  _saved_password[sizeof(_saved_password) - 1] = '\0';

  // Hide overlay
  lv_obj_add_flag(_password_panel, LV_OBJ_FLAG_HIDDEN);
  _keyboard    = nullptr;
  _password_ta = nullptr;

  char buf[80];
  snprintf(buf, sizeof(buf), "Connecting to %s...", _selected_ssid);
  _set_status(buf, COLOR_ACCENT);

  WiFi.begin(_selected_ssid, _saved_password);

  // Poll via LVGL timer so the UI stays responsive
  lv_timer_create(
      [](lv_timer_t *t) {
        static int attempts = 0;
        attempts++;

        if (WiFi.status() == WL_CONNECTED) {
          snprintf(_ip_str, sizeof(_ip_str), "%s",
                   WiFi.localIP().toString().c_str());

          char msg[64];
          snprintf(msg, sizeof(msg), LV_SYMBOL_OK " Connected: %s", _ip_str);
          _set_status(msg, COLOR_SUCCESS);

          // Persist credentials
          ui_save_string(NVS_KEY_SSID, _selected_ssid);
          ui_save_string(NVS_KEY_PASS, _saved_password);
          memset(_saved_password, 0, sizeof(_saved_password));

          Serial.printf("[WiFi] Connected to %s as %s\n", _selected_ssid,
                        _ip_str);

          lv_timer_del(t);
          attempts = 0;

          if (_on_connected_cb) _on_connected_cb();
        } else if (attempts > 40) {  // ~10 s
          _set_status(LV_SYMBOL_WARNING " Connection failed – try again",
                      COLOR_ERROR);
          memset(_saved_password, 0, sizeof(_saved_password));
          lv_timer_del(t);
          attempts = 0;
        }
      },
      250, nullptr);
}

static void _kb_ready_cb(lv_event_t *e) {
  (void)e;
  _connect_cb(nullptr);
}
