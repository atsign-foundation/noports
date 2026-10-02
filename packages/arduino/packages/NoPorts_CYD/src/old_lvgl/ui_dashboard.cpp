/**
 * @file ui_dashboard.cpp
 * @brief Live status dashboard screen implementation
 */

#include "ui_dashboard.h"
#include "ui_common.h"
#include "ui_wifi.h"
#include <Arduino.h>
#include <esp32_smartdisplay.h>

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
static lv_obj_t *_scr            = nullptr;

// Header
static lv_obj_t *_lbl_atsign     = nullptr;
static lv_obj_t *_lbl_device     = nullptr;
static lv_obj_t *_lbl_ip         = nullptr;

// Stats
static lv_obj_t *_lbl_state      = nullptr;
static lv_obj_t *_lbl_relays     = nullptr;
static lv_obj_t *_lbl_uptime     = nullptr;

// Connection log
static lv_obj_t *_log_list       = nullptr;

// LED colour controls
static lv_obj_t *_led_indicator  = nullptr;

static uint32_t _boot_ms = 0;

// Forward declarations
static void _add_log_entry(const char *icon, const char *text, lv_color_t color);
static void _led_color_cb(lv_event_t *e);

// ---------------------------------------------------------------------------
// Colour presets for the LED picker
// ---------------------------------------------------------------------------
struct LedPreset {
  const char *label;
  bool r, g, b;       // RGB LED is on/off per channel (active-low hardware)
  uint32_t   hex;     // colour shown on the UI button
};

static const LedPreset _led_presets[] = {
    {"Off",    false, false, false, 0x333333},
    {"Green",  false, true,  false, 0x00FF00},
    {"Blue",   false, false, true,  0x0000FF},
    {"Red",    true,  false, false, 0xFF0000},
    {"Cyan",   false, true,  true,  0x00FFFF},
    {"White",  true,  true,  true,  0xFFFFFF},
};
static const int _led_preset_count = sizeof(_led_presets) / sizeof(_led_presets[0]);

// ---------------------------------------------------------------------------
// Public
// ---------------------------------------------------------------------------

void ui_dashboard_create() {
  _boot_ms = millis();

  _scr = lv_obj_create(nullptr);
  lv_obj_set_style_bg_color(_scr, COLOR_BG_DARK, 0);
  lv_obj_set_style_pad_all(_scr, 0, 0);

  // ========== Header bar ==========
  lv_obj_t *header = ui_create_card(_scr);
  lv_obj_set_size(header, SCREEN_WIDTH - 10, 42);
  lv_obj_align(header, LV_ALIGN_TOP_MID, 0, 4);
  lv_obj_set_flex_flow(header, LV_FLEX_FLOW_ROW);
  lv_obj_set_flex_align(header, LV_FLEX_ALIGN_SPACE_BETWEEN,
                        LV_FLEX_ALIGN_CENTER, LV_FLEX_ALIGN_CENTER);
  lv_obj_set_style_pad_hor(header, 8, 0);

  // atSign
  String atsign = ui_load_string(NVS_KEY_ATSIGN);
  _lbl_atsign = ui_create_label(header, atsign.c_str(), &lv_font_montserrat_14);
  lv_obj_set_style_text_color(_lbl_atsign, COLOR_PRIMARY, 0);

  // Device name
  String device = ui_load_string(NVS_KEY_DEVICE);
  char dev_buf[80];
  snprintf(dev_buf, sizeof(dev_buf), LV_SYMBOL_SETTINGS " %s", device.c_str());
  _lbl_device = ui_create_label(header, dev_buf, &lv_font_montserrat_12);

  // IP
  _lbl_ip = ui_create_label(header, ui_wifi_get_ip(), &lv_font_montserrat_12);
  lv_obj_set_style_text_color(_lbl_ip, COLOR_ACCENT, 0);

  // ========== Stats row ==========
  lv_obj_t *stats = ui_create_card(_scr);
  lv_obj_set_size(stats, SCREEN_WIDTH - 10, 32);
  lv_obj_align_to(stats, header, LV_ALIGN_OUT_BOTTOM_MID, 0, 4);
  lv_obj_set_flex_flow(stats, LV_FLEX_FLOW_ROW);
  lv_obj_set_flex_align(stats, LV_FLEX_ALIGN_SPACE_EVENLY,
                        LV_FLEX_ALIGN_CENTER, LV_FLEX_ALIGN_CENTER);

  _lbl_state  = ui_create_label(stats, "State: init",     &lv_font_montserrat_12);
  _lbl_relays = ui_create_label(stats, "Relays: 0",       &lv_font_montserrat_12);
  _lbl_uptime = ui_create_label(stats, "Up: 0m",          &lv_font_montserrat_12);

  // ========== Connection log ==========
  _log_list = lv_list_create(_scr);
  lv_obj_set_size(_log_list, SCREEN_WIDTH - 10, 100);
  lv_obj_align_to(_log_list, stats, LV_ALIGN_OUT_BOTTOM_MID, 0, 4);
  lv_obj_set_style_bg_color(_log_list, COLOR_BG_CARD, 0);
  lv_obj_set_style_radius(_log_list, 6, 0);
  lv_obj_set_style_border_width(_log_list, 0, 0);
  lv_obj_set_style_pad_all(_log_list, 4, 0);

  // Initial log entry
  _add_log_entry(LV_SYMBOL_OK, "Dashboard started", COLOR_SUCCESS);

  // ========== LED colour buttons ==========
  lv_obj_t *led_row = lv_obj_create(_scr);
  lv_obj_set_size(led_row, SCREEN_WIDTH - 10, 30);
  lv_obj_align_to(led_row, _log_list, LV_ALIGN_OUT_BOTTOM_MID, 0, 4);
  lv_obj_set_style_bg_opa(led_row, LV_OPA_TRANSP, 0);
  lv_obj_set_style_border_width(led_row, 0, 0);
  lv_obj_set_style_pad_all(led_row, 0, 0);
  lv_obj_set_flex_flow(led_row, LV_FLEX_FLOW_ROW);
  lv_obj_set_flex_align(led_row, LV_FLEX_ALIGN_SPACE_EVENLY,
                        LV_FLEX_ALIGN_CENTER, LV_FLEX_ALIGN_CENTER);

  for (int i = 0; i < _led_preset_count; i++) {
    lv_obj_t *btn = lv_btn_create(led_row);
    lv_obj_set_size(btn, 44, 22);
    lv_obj_set_style_bg_color(btn, lv_color_hex(_led_presets[i].hex), 0);
    lv_obj_set_style_radius(btn, 4, 0);
    if (!_led_presets[i].r && !_led_presets[i].g &&
        !_led_presets[i].b) {
      // "Off" button – show border so it's visible on dark background
      lv_obj_set_style_border_color(btn, COLOR_TEXT_GREY, 0);
      lv_obj_set_style_border_width(btn, 1, 0);
    }

    lv_obj_t *lbl = lv_label_create(btn);
    lv_label_set_text(lbl, _led_presets[i].label);
    lv_obj_set_style_text_font(lbl, &lv_font_montserrat_12, 0);
    // Dark text on bright buttons, white on dark
    bool bright = (_led_presets[i].r && _led_presets[i].g) ||
                  (_led_presets[i].r && _led_presets[i].b) ||
                  (_led_presets[i].g && _led_presets[i].b);
    lv_obj_set_style_text_color(lbl, bright ? lv_color_hex(0x000000) : COLOR_TEXT_WHITE, 0);
    lv_obj_center(lbl);

    lv_obj_add_event_cb(btn, _led_color_cb, LV_EVENT_CLICKED,
                        (void *)(intptr_t)i);
  }

  lv_scr_load(_scr);
}

void ui_dashboard_update(int active_relays, const char *daemon_state) {
  // Update stats labels
  if (_lbl_state) {
    char buf[48];
    snprintf(buf, sizeof(buf), "State: %s", daemon_state ? daemon_state : "?");
    lv_label_set_text(_lbl_state, buf);
  }

  if (_lbl_relays) {
    char buf[32];
    snprintf(buf, sizeof(buf), "Relays: %d", active_relays);
    lv_label_set_text(_lbl_relays, buf);
    lv_obj_set_style_text_color(
        _lbl_relays, active_relays > 0 ? COLOR_SUCCESS : COLOR_TEXT_GREY, 0);
  }

  if (_lbl_uptime) {
    char buf[32];
    ui_format_uptime(millis() - _boot_ms, buf, sizeof(buf));
    char full[48];
    snprintf(full, sizeof(full), "Up: %s", buf);
    lv_label_set_text(_lbl_uptime, full);
  }

  // Update IP in case WiFi reconnected
  if (_lbl_ip) {
    lv_label_set_text(_lbl_ip, ui_wifi_get_ip());
  }

  // Process queued events
  UiEvent evt;
  while (ui_event_pop(&evt)) {
    switch (evt.type) {
      case UI_EVT_TUNNEL_OPEN:
        _add_log_entry(LV_SYMBOL_OK, evt.text, COLOR_SUCCESS);
        break;
      case UI_EVT_TUNNEL_CLOSE:
        _add_log_entry(LV_SYMBOL_CLOSE, evt.text, COLOR_TEXT_GREY);
        break;
      case UI_EVT_PING:
        _add_log_entry(LV_SYMBOL_REFRESH, evt.text, COLOR_ACCENT);
        break;
      case UI_EVT_DAEMON_STATE:
        _add_log_entry(LV_SYMBOL_SETTINGS, evt.text, COLOR_TEXT_WHITE);
        break;
      case UI_EVT_ERROR:
        _add_log_entry(LV_SYMBOL_WARNING, evt.text, COLOR_ERROR);
        break;
      default:
        break;
    }
  }
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

static void _add_log_entry(const char *icon, const char *text,
                           lv_color_t color) {
  if (!_log_list) return;

  // Build timestamped string
  char buf[160];
  uint32_t sec = millis() / 1000;
  snprintf(buf, sizeof(buf), "%s %02u:%02u  %s", icon, (sec / 60) % 100,
           sec % 60, text);

  lv_obj_t *btn = lv_list_add_btn(_log_list, nullptr, buf);
  lv_obj_set_style_bg_color(btn, COLOR_BG_DARK, 0);
  lv_obj_set_style_text_color(btn, color, 0);
  lv_obj_set_style_text_font(btn, &lv_font_montserrat_12, 0);
  lv_obj_set_style_min_height(btn, 20, 0);
  lv_obj_set_style_pad_ver(btn, 2, 0);

  // Auto-scroll to bottom
  lv_obj_scroll_to_y(_log_list, LV_COORD_MAX, LV_ANIM_ON);

  // Limit log entries to keep memory bounded
  uint32_t count = lv_obj_get_child_count(_log_list);
  while (count > 50) {
    lv_obj_t *first = lv_obj_get_child(_log_list, 0);
    if (first) lv_obj_del(first);
    count--;
  }
}

static void _led_color_cb(lv_event_t *e) {
  int idx = (int)(intptr_t)lv_event_get_user_data(e);
  if (idx < 0 || idx >= _led_preset_count) return;

  const LedPreset &p = _led_presets[idx];
  smartdisplay_led_set_rgb(p.r, p.g, p.b);

  // Persist choice
  ui_save_string(NVS_KEY_LED_COLOR, p.label);

  Serial.printf("[LED] Set to %s (r=%d,g=%d,b=%d)\n", p.label, p.r, p.g, p.b);
}
