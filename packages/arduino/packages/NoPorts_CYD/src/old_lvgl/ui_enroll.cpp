/**
 * @file ui_enroll.cpp
 * @brief APKAM enrollment screen implementation
 *
 * Provides input fields for atSign, device name, OTP, and manager atSign.
 * On submit, runs atauth_enroll_command() which:
 *   1. Generates APKAM key-pair + symmetric key
 *   2. CRAM-authenticates with the OTP
 *   3. Sends the enrollment request (app="noports", ns="sshnp:rw,sshrvd:rw")
 *   4. Waits for server-side approval
 *   5. Writes the decrypted atKeys to the provided path (/atkeys.json)
 *
 * On success the config values are persisted to NVS and the on_enrolled
 * callback is invoked so the main loop can transition to the dashboard.
 */

#include "ui_enroll.h"
#include "ui_common.h"
#include <Arduino.h>
#include <LittleFS.h>

extern "C" {
  #include "atauth.h"
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------
static const char *ENROLL_APP_NAME   = "noports";
static const char *ENROLL_NAMESPACES = "sshnp:rw,sshrvd:rw";
static const char *ROOT_DOMAIN      = "root.atsign.org";

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
static lv_obj_t *_scr          = nullptr;
static lv_obj_t *_ta_atsign    = nullptr;
static lv_obj_t *_ta_device    = nullptr;
static lv_obj_t *_ta_otp       = nullptr;
static lv_obj_t *_ta_manager   = nullptr;
static lv_obj_t *_keyboard     = nullptr;
static lv_obj_t *_status_label = nullptr;
static lv_obj_t *_enroll_btn   = nullptr;
static lv_obj_t *_spinner      = nullptr;

static lv_obj_t *_focused_ta   = nullptr; // currently focused textarea

static void (*_on_enrolled_cb)() = nullptr;

// Forward declarations
static void _enroll_btn_cb(lv_event_t *e);
static void _ta_focus_cb(lv_event_t *e);
static void _kb_ready_cb(lv_event_t *e);
static void _set_status(const char *msg, lv_color_t color);
static void _show_busy(bool busy);

// ---------------------------------------------------------------------------
// Public
// ---------------------------------------------------------------------------

void ui_enroll_create(void (*on_enrolled)()) {
  _on_enrolled_cb = on_enrolled;

  _scr = lv_obj_create(nullptr);
  lv_obj_set_style_bg_color(_scr, COLOR_BG_DARK, 0);
  lv_obj_set_style_pad_all(_scr, 0, 0);

  // ---- Scrollable form container (above keyboard) ----
  lv_obj_t *form = lv_obj_create(_scr);
  lv_obj_set_size(form, SCREEN_WIDTH, 100);
  lv_obj_align(form, LV_ALIGN_TOP_LEFT, 0, 0);
  lv_obj_set_style_bg_opa(form, LV_OPA_TRANSP, 0);
  lv_obj_set_style_border_width(form, 0, 0);
  lv_obj_set_style_pad_all(form, 6, 0);
  lv_obj_set_flex_flow(form, LV_FLEX_FLOW_ROW_WRAP);
  lv_obj_set_flex_align(form, LV_FLEX_ALIGN_START, LV_FLEX_ALIGN_CENTER,
                        LV_FLEX_ALIGN_START);
  lv_obj_set_scroll_dir(form, LV_DIR_VER);

  // Title
  lv_obj_t *title = ui_create_label(form, LV_SYMBOL_SETTINGS " Enroll Device",
                                    &lv_font_montserrat_16);
  lv_obj_set_width(title, SCREEN_WIDTH - 16);

  // ---- Input fields ----
  // Each field: label + textarea in a row, 50% width each pair

  // atSign
  lv_obj_t *lbl_at = ui_create_label(form, "atSign", &lv_font_montserrat_12);
  lv_obj_set_width(lbl_at, 60);
  _ta_atsign = lv_textarea_create(form);
  lv_obj_set_size(_ta_atsign, 100, 28);
  lv_textarea_set_one_line(_ta_atsign, true);
  lv_textarea_set_placeholder_text(_ta_atsign, "@alice");
  lv_obj_set_style_bg_color(_ta_atsign, COLOR_BG_CARD, 0);
  lv_obj_set_style_text_color(_ta_atsign, COLOR_TEXT_WHITE, 0);
  lv_obj_set_style_text_font(_ta_atsign, &lv_font_montserrat_12, 0);
  lv_obj_add_event_cb(_ta_atsign, _ta_focus_cb, LV_EVENT_FOCUSED, nullptr);

  // Device name
  lv_obj_t *lbl_dev = ui_create_label(form, "Device", &lv_font_montserrat_12);
  lv_obj_set_width(lbl_dev, 60);
  _ta_device = lv_textarea_create(form);
  lv_obj_set_size(_ta_device, 100, 28);
  lv_textarea_set_one_line(_ta_device, true);
  lv_textarea_set_placeholder_text(_ta_device, "cyd");
  lv_textarea_set_text(_ta_device, "cyd");
  lv_obj_set_style_bg_color(_ta_device, COLOR_BG_CARD, 0);
  lv_obj_set_style_text_color(_ta_device, COLOR_TEXT_WHITE, 0);
  lv_obj_set_style_text_font(_ta_device, &lv_font_montserrat_12, 0);
  lv_obj_add_event_cb(_ta_device, _ta_focus_cb, LV_EVENT_FOCUSED, nullptr);

  // OTP
  lv_obj_t *lbl_otp = ui_create_label(form, "OTP", &lv_font_montserrat_12);
  lv_obj_set_width(lbl_otp, 60);
  _ta_otp = lv_textarea_create(form);
  lv_obj_set_size(_ta_otp, 100, 28);
  lv_textarea_set_one_line(_ta_otp, true);
  lv_textarea_set_placeholder_text(_ta_otp, "ABC123");
  lv_obj_set_style_bg_color(_ta_otp, COLOR_BG_CARD, 0);
  lv_obj_set_style_text_color(_ta_otp, COLOR_TEXT_WHITE, 0);
  lv_obj_set_style_text_font(_ta_otp, &lv_font_montserrat_12, 0);
  lv_obj_add_event_cb(_ta_otp, _ta_focus_cb, LV_EVENT_FOCUSED, nullptr);

  // Manager atSign
  lv_obj_t *lbl_mgr = ui_create_label(form, "Manager", &lv_font_montserrat_12);
  lv_obj_set_width(lbl_mgr, 60);
  _ta_manager = lv_textarea_create(form);
  lv_obj_set_size(_ta_manager, 100, 28);
  lv_textarea_set_one_line(_ta_manager, true);
  lv_textarea_set_placeholder_text(_ta_manager, "@manager");
  lv_obj_set_style_bg_color(_ta_manager, COLOR_BG_CARD, 0);
  lv_obj_set_style_text_color(_ta_manager, COLOR_TEXT_WHITE, 0);
  lv_obj_set_style_text_font(_ta_manager, &lv_font_montserrat_12, 0);
  lv_obj_add_event_cb(_ta_manager, _ta_focus_cb, LV_EVENT_FOCUSED, nullptr);

  // Pre-fill from NVS if available
  String saved;
  saved = ui_load_string(NVS_KEY_ATSIGN);
  if (saved.length()) lv_textarea_set_text(_ta_atsign, saved.c_str());
  saved = ui_load_string(NVS_KEY_DEVICE);
  if (saved.length()) lv_textarea_set_text(_ta_device, saved.c_str());
  saved = ui_load_string(NVS_KEY_MANAGER);
  if (saved.length()) lv_textarea_set_text(_ta_manager, saved.c_str());

  // Status label
  _status_label = ui_create_label(form, "", &lv_font_montserrat_12);
  lv_obj_set_width(_status_label, SCREEN_WIDTH - 80);

  // Enroll button
  _enroll_btn = ui_create_btn(form, LV_SYMBOL_OK " Enroll", _enroll_btn_cb);

  // Spinner (hidden initially)
  _spinner = lv_spinner_create(_scr);
  lv_obj_set_size(_spinner, 40, 40);
  lv_obj_center(_spinner);
  lv_obj_add_flag(_spinner, LV_OBJ_FLAG_HIDDEN);

  // Keyboard (bottom of screen)
  _keyboard = lv_keyboard_create(_scr);
  lv_obj_set_size(_keyboard, SCREEN_WIDTH, 130);
  lv_obj_align(_keyboard, LV_ALIGN_BOTTOM_MID, 0, 0);
  lv_obj_set_style_bg_color(_keyboard, COLOR_BG_CARD, 0);
  lv_obj_set_style_text_color(_keyboard, COLOR_TEXT_WHITE, 0);
  lv_obj_add_event_cb(_keyboard, _kb_ready_cb, LV_EVENT_READY, nullptr);

  // Default focus on the first textarea
  lv_keyboard_set_textarea(_keyboard, _ta_atsign);
  _focused_ta = _ta_atsign;

  lv_scr_load(_scr);
}

// ---------------------------------------------------------------------------
// Callbacks
// ---------------------------------------------------------------------------

static void _ta_focus_cb(lv_event_t *e) {
  lv_obj_t *ta = (lv_obj_t *)lv_event_get_target(e);
  if (_keyboard) {
    lv_keyboard_set_textarea(_keyboard, ta);
  }
  _focused_ta = ta;
}

static void _kb_ready_cb(lv_event_t *e) {
  (void)e;
  // Move focus to next field or trigger enroll
  if (_focused_ta == _ta_atsign) {
    lv_obj_add_state(_ta_device, LV_STATE_FOCUSED);
  } else if (_focused_ta == _ta_device) {
    lv_obj_add_state(_ta_otp, LV_STATE_FOCUSED);
  } else if (_focused_ta == _ta_otp) {
    lv_obj_add_state(_ta_manager, LV_STATE_FOCUSED);
  } else {
    _enroll_btn_cb(nullptr);
  }
}

static void _set_status(const char *msg, lv_color_t color) {
  if (_status_label) {
    lv_label_set_text(_status_label, msg);
    lv_obj_set_style_text_color(_status_label, color, 0);
  }
}

static void _show_busy(bool busy) {
  if (busy) {
    lv_obj_clear_flag(_spinner, LV_OBJ_FLAG_HIDDEN);
    lv_obj_add_state(_enroll_btn, LV_STATE_DISABLED);
  } else {
    lv_obj_add_flag(_spinner, LV_OBJ_FLAG_HIDDEN);
    lv_obj_clear_state(_enroll_btn, LV_STATE_DISABLED);
  }
}

// ---------------------------------------------------------------------------
// Enrollment (runs on a FreeRTOS task to avoid blocking LVGL)
// ---------------------------------------------------------------------------

struct EnrollTaskArgs {
  char atsign[64];
  char device[64];
  char otp[32];
  char manager[64];
};

static void _enroll_task(void *param) {
  EnrollTaskArgs *args = (EnrollTaskArgs *)param;

  Serial.printf("[Enroll] atsign=%s device=%s otp=%s\n",
                args->atsign, args->device, args->otp);

  // Make sure LittleFS is mounted
  if (!LittleFS.begin(true)) {
    ui_event_push(UI_EVT_ENROLL_FAIL, "LittleFS mount failed");
    free(args);
    vTaskDelete(nullptr);
    return;
  }

  ui_event_push(UI_EVT_ENROLL_STATUS, "Connecting to root server...");

  // Call the high-level enroll command
  // Signature: atauth_enroll_command(atsign, root_domain, keys_path,
  //                                  passcode, app, device, namespaces, expiry)
  int ret = atauth_enroll_command(
      args->atsign,        // @alice
      ROOT_DOMAIN,         // root.atsign.org
      ATKEYS_PATH,         // /atkeys.json
      args->otp,           // OTP/passcode
      ENROLL_APP_NAME,     // "noports"
      args->device,        // "cyd"
      ENROLL_NAMESPACES,   // "sshnp:rw,sshrvd:rw"
      nullptr              // no expiry
  );

  if (ret == 0) {
    Serial.println("[Enroll] SUCCESS – keys written to " ATKEYS_PATH);

    // Persist config to NVS
    ui_save_string(NVS_KEY_ATSIGN,  args->atsign);
    ui_save_string(NVS_KEY_DEVICE,  args->device);
    ui_save_string(NVS_KEY_MANAGER, args->manager);
    ui_set_configured(true);

    ui_event_push(UI_EVT_ENROLL_OK, LV_SYMBOL_OK " Enrolled!");
  } else {
    Serial.printf("[Enroll] FAILED with code %d\n", ret);
    char buf[80];
    snprintf(buf, sizeof(buf), LV_SYMBOL_WARNING " Enrollment failed (%d)", ret);
    ui_event_push(UI_EVT_ENROLL_FAIL, buf);
  }

  free(args);
  vTaskDelete(nullptr);
}

static void _enroll_btn_cb(lv_event_t *e) {
  (void)e;

  // Validate inputs
  const char *atsign  = lv_textarea_get_text(_ta_atsign);
  const char *device  = lv_textarea_get_text(_ta_device);
  const char *otp     = lv_textarea_get_text(_ta_otp);
  const char *manager = lv_textarea_get_text(_ta_manager);

  if (strlen(atsign) < 2 || atsign[0] != '@') {
    _set_status("atSign must start with @", COLOR_ERROR);
    return;
  }
  if (strlen(device) < 1) {
    _set_status("Device name required", COLOR_ERROR);
    return;
  }
  if (strlen(otp) < 1) {
    _set_status("OTP required", COLOR_ERROR);
    return;
  }
  if (strlen(manager) < 2 || manager[0] != '@') {
    _set_status("Manager must start with @", COLOR_ERROR);
    return;
  }

  _show_busy(true);
  _set_status("Enrolling...", COLOR_ACCENT);

  // Copy args for the FreeRTOS task (form may be destroyed)
  EnrollTaskArgs *args = (EnrollTaskArgs *)malloc(sizeof(EnrollTaskArgs));
  strncpy(args->atsign,  atsign,  sizeof(args->atsign) - 1);
  strncpy(args->device,  device,  sizeof(args->device) - 1);
  strncpy(args->otp,     otp,     sizeof(args->otp) - 1);
  strncpy(args->manager, manager, sizeof(args->manager) - 1);
  args->atsign[sizeof(args->atsign) - 1]   = '\0';
  args->device[sizeof(args->device) - 1]   = '\0';
  args->otp[sizeof(args->otp) - 1]         = '\0';
  args->manager[sizeof(args->manager) - 1] = '\0';

  // Run enrollment on a separate task (crypto is CPU intensive + blocks on
  // network I/O). Stack size 32768 matches the loop task — needed for
  // 4096-bit RSA signature verification during TLS handshake.
  Serial.printf("[Enroll] Free heap: %u bytes, largest block: %u bytes\n",
                ESP.getFreeHeap(), ESP.getMaxAllocHeap());
  xTaskCreatePinnedToCore(_enroll_task, "enroll", 32768, args, 5, nullptr, 1);
}

// ---------------------------------------------------------------------------
// Event processing (called from main LVGL loop)
// ---------------------------------------------------------------------------

void ui_enroll_process_events() {
  UiEvent evt;
  while (ui_event_pop(&evt)) {
    switch (evt.type) {
      case UI_EVT_ENROLL_STATUS:
        _set_status(evt.text, COLOR_ACCENT);
        break;
      case UI_EVT_ENROLL_OK:
        _set_status(evt.text, COLOR_SUCCESS);
        _show_busy(false);
        // Brief pause handled via LVGL timer so we don't block the loop
        if (_on_enrolled_cb) {
          // Schedule callback via a one-shot LVGL timer (1.5s delay)
          lv_timer_t *t = lv_timer_create([](lv_timer_t *tmr) {
            void (*cb)() = (void(*)())lv_timer_get_user_data(tmr);
            if (cb) cb();
            lv_timer_del(tmr);
          }, 1500, (void *)_on_enrolled_cb);
          lv_timer_set_repeat_count(t, 1);
        }
        break;
      case UI_EVT_ENROLL_FAIL:
        _set_status(evt.text, COLOR_ERROR);
        _show_busy(false);
        break;
      default:
        break;
    }
  }
}
