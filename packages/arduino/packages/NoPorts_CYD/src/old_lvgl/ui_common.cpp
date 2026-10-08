/**
 * @file ui_common.cpp
 * @brief Shared UI utilities implementation
 */

#include "ui_common.h"
#include <freertos/FreeRTOS.h>
#include <freertos/semphr.h>
#include <Arduino.h>

// ---------------------------------------------------------------------------
// Event queue (ring buffer with mutex)
// ---------------------------------------------------------------------------
static UiEvent    _event_buf[EVENT_QUEUE_SIZE];
static uint8_t    _evt_head = 0;
static uint8_t    _evt_tail = 0;
static uint8_t    _evt_count = 0;
static SemaphoreHandle_t _evt_mutex = nullptr;

// ---------------------------------------------------------------------------
// NVS
// ---------------------------------------------------------------------------
static Preferences _prefs;
static bool _prefs_opened = false;

// ---------------------------------------------------------------------------
// Init
// ---------------------------------------------------------------------------

void ui_common_init() {
  // Create event queue mutex
  _evt_mutex = xSemaphoreCreateMutex();

  // Open NVS
  if (!_prefs_opened) {
    _prefs.begin(NVS_NAMESPACE, false);
    _prefs_opened = true;
  }
}

// ---------------------------------------------------------------------------
// Event queue
// ---------------------------------------------------------------------------

void ui_event_push(UiEventType type, const char *text) {
  if (!_evt_mutex) return;
  if (xSemaphoreTake(_evt_mutex, pdMS_TO_TICKS(50)) == pdTRUE) {
    if (_evt_count < EVENT_QUEUE_SIZE) {
      UiEvent &e = _event_buf[_evt_head];
      e.type = type;
      e.timestamp = millis();
      if (text) {
        strncpy(e.text, text, EVENT_TEXT_LEN - 1);
        e.text[EVENT_TEXT_LEN - 1] = '\0';
      } else {
        e.text[0] = '\0';
      }
      _evt_head = (_evt_head + 1) % EVENT_QUEUE_SIZE;
      _evt_count++;
    }
    xSemaphoreGive(_evt_mutex);
  }
}

bool ui_event_pop(UiEvent *evt) {
  if (!_evt_mutex || !evt) return false;
  bool got = false;
  if (xSemaphoreTake(_evt_mutex, pdMS_TO_TICKS(10)) == pdTRUE) {
    if (_evt_count > 0) {
      *evt = _event_buf[_evt_tail];
      _evt_tail = (_evt_tail + 1) % EVENT_QUEUE_SIZE;
      _evt_count--;
      got = true;
    }
    xSemaphoreGive(_evt_mutex);
  }
  return got;
}

// ---------------------------------------------------------------------------
// NVS helpers
// ---------------------------------------------------------------------------

Preferences& ui_prefs() {
  if (!_prefs_opened) {
    _prefs.begin(NVS_NAMESPACE, false);
    _prefs_opened = true;
  }
  return _prefs;
}

bool ui_is_configured() {
  return ui_prefs().getBool(NVS_KEY_CONFIGURED, false);
}

void ui_set_configured(bool val) {
  ui_prefs().putBool(NVS_KEY_CONFIGURED, val);
}

String ui_load_string(const char *key) {
  return ui_prefs().getString(key, "");
}

void ui_save_string(const char *key, const char *value) {
  ui_prefs().putString(key, value);
}

// ---------------------------------------------------------------------------
// UI factory helpers
// ---------------------------------------------------------------------------

lv_obj_t* ui_create_btn(lv_obj_t *parent, const char *text, lv_event_cb_t cb, void *user_data) {
  lv_obj_t *btn = lv_btn_create(parent);
  lv_obj_set_size(btn, LV_SIZE_CONTENT, 36);
  lv_obj_set_style_bg_color(btn, COLOR_PRIMARY, 0);
  lv_obj_set_style_radius(btn, 6, 0);
  lv_obj_set_style_pad_hor(btn, 16, 0);

  lv_obj_t *lbl = lv_label_create(btn);
  lv_label_set_text(lbl, text);
  lv_obj_set_style_text_color(lbl, COLOR_TEXT_WHITE, 0);
  lv_obj_set_style_text_font(lbl, &lv_font_montserrat_14, 0);
  lv_obj_center(lbl);

  if (cb) {
    lv_obj_add_event_cb(btn, cb, LV_EVENT_CLICKED, user_data);
  }
  return btn;
}

lv_obj_t* ui_create_label(lv_obj_t *parent, const char *text, const lv_font_t *font) {
  lv_obj_t *lbl = lv_label_create(parent);
  lv_label_set_text(lbl, text);
  lv_obj_set_style_text_color(lbl, COLOR_TEXT_WHITE, 0);
  if (font) {
    lv_obj_set_style_text_font(lbl, font, 0);
  }
  return lbl;
}

lv_obj_t* ui_create_input(lv_obj_t *parent, const char *label_text, const char *placeholder,
                           bool one_line, bool password) {
  // Label
  lv_obj_t *lbl = lv_label_create(parent);
  lv_label_set_text(lbl, label_text);
  lv_obj_set_style_text_color(lbl, COLOR_TEXT_GREY, 0);
  lv_obj_set_style_text_font(lbl, &lv_font_montserrat_12, 0);

  // Textarea
  lv_obj_t *ta = lv_textarea_create(parent);
  lv_obj_set_width(ta, lv_pct(100));
  lv_textarea_set_one_line(ta, one_line);
  lv_textarea_set_placeholder_text(ta, placeholder);
  lv_obj_set_style_bg_color(ta, COLOR_BG_CARD, 0);
  lv_obj_set_style_text_color(ta, COLOR_TEXT_WHITE, 0);
  lv_obj_set_style_border_color(ta, COLOR_ACCENT, LV_STATE_FOCUSED);
  lv_obj_set_style_border_width(ta, 2, LV_STATE_FOCUSED);

  if (password) {
    lv_textarea_set_password_mode(ta, true);
  }

  return ta;
}

lv_obj_t* ui_create_card(lv_obj_t *parent) {
  lv_obj_t *card = lv_obj_create(parent);
  lv_obj_set_width(card, lv_pct(100));
  lv_obj_set_height(card, LV_SIZE_CONTENT);
  lv_obj_set_style_bg_color(card, COLOR_BG_CARD, 0);
  lv_obj_set_style_radius(card, 8, 0);
  lv_obj_set_style_pad_all(card, 10, 0);
  lv_obj_set_style_border_width(card, 0, 0);
  lv_obj_set_flex_flow(card, LV_FLEX_FLOW_COLUMN);
  lv_obj_set_flex_align(card, LV_FLEX_ALIGN_START, LV_FLEX_ALIGN_START, LV_FLEX_ALIGN_START);
  lv_obj_set_style_pad_row(card, 4, 0);
  return card;
}

// ---------------------------------------------------------------------------
// Utility
// ---------------------------------------------------------------------------

void ui_format_uptime(uint32_t ms, char *buf, size_t len) {
  uint32_t secs = ms / 1000;
  uint32_t mins = secs / 60;
  uint32_t hrs  = mins / 60;
  uint32_t days = hrs / 24;

  if (days > 0) {
    snprintf(buf, len, "%lud %luh %lum", (unsigned long)days,
             (unsigned long)(hrs % 24), (unsigned long)(mins % 60));
  } else if (hrs > 0) {
    snprintf(buf, len, "%luh %lum", (unsigned long)hrs, (unsigned long)(mins % 60));
  } else {
    snprintf(buf, len, "%lum %lus", (unsigned long)mins, (unsigned long)(secs % 60));
  }
}
