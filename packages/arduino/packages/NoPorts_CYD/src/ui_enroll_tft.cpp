/**
 * @file ui_enroll_tft.cpp
 * @brief APKAM enrollment screen implementation using TFT_eSPI
 */

#include "ui_enroll_tft.h"
#include "ui_tft.h"
#include <Arduino.h>
#include <LittleFS.h>

extern "C" {
  #include "atauth.h"
}

// ---------------------------------------------------------------------------
// Enrollment constants
// ---------------------------------------------------------------------------
static const char *DEFAULT_ROOT_SPEC = "root.atsign.org";
static const char *ENROLL_APP_NAME   = "noports";
static const char *ENROLL_NAMESPACES = "sshnp:rw,sshrvd:rw";

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
enum EnrollState {
  ENROLL_FORM,
  ENROLL_RUNNING,
  ENROLL_SUCCESS,
  ENROLL_FAILED
};

static EnrollState _state = ENROLL_FORM;
static void (*_on_enrolled_cb)() = nullptr;
static uint32_t _enroll_start_ms = 0;
static uint32_t _last_progress_ms = 0;
#define ENROLL_TIMEOUT_MS 300000  // 5 minute timeout

// Form fields
static char _atsign[64] = "";
static char _device_name[64] = "";
static char _otp[16] = "";
static char _manager[64] = "";
static char _policy_at[64] = "";
static char _root[128] = "";  // root server spec: host[:port] or proxy:host[:port]
static int _active_field = 0;  // 0=atsign, 1=device, 2=otp, 3=manager/policy, 4=root
// Field 3 mode — tap its label chip to toggle. 0 = manager atSign(s),
// 1 = policy-service atSign (RPC authorisation). Mirrors the Rules screen.
static int _rules_mode = 0;
static String _status_msg;

// Simple keyboard (similar to WiFi screen). No SPACE key: spaces are not
// valid in any field, and the root server spec needs ':' instead.
static const char* _kb_keys[] = {
  "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
  "q", "w", "e", "r", "t", "y", "u", "i", "o", "p",
  "a", "s", "d", "f", "g", "h", "j", "k", "l", "@",
  "z", "x", "c", "v", "b", "n", "m", "_", "-", ".",
  "DEL", ":", "DONE"
};
static const int _kb_key_count = sizeof(_kb_keys) / sizeof(_kb_keys[0]);

#define KEYS_PER_ROW 10
#define KEY_HEIGHT   18
#define KEY_SPACING  1
#define KEY_WIDTH    ((TFT_WIDTH - 10 - (KEYS_PER_ROW - 1) * KEY_SPACING) / KEYS_PER_ROW)  // 30 @320, 38 @400

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

static char* _get_active_buffer() {
  switch (_active_field) {
    case 0: return _atsign;
    case 1: return _device_name;
    case 2: return _otp;
    case 3: return (_rules_mode == 1) ? _policy_at : _manager;
    case 4: return _root;
    default: return nullptr;
  }
}

// Field 3's value under the current mode (manager list or policy atSign)
static const char* _rules_value() {
  return (_rules_mode == 1) ? _policy_at : _manager;
}

static int _get_active_buffer_len() {
  char *buf = _get_active_buffer();
  return buf ? strlen(buf) : 0;
}

static size_t _get_active_buffer_maxlen() {
  switch (_active_field) {
    case 0: return sizeof(_atsign) - 1;
    case 1: return sizeof(_device_name) - 1;
    case 2: return sizeof(_otp) - 1;
    case 3: return (_rules_mode == 1) ? sizeof(_policy_at) - 1 : sizeof(_manager) - 1;
    case 4: return sizeof(_root) - 1;
    default: return 0;
  }
}

static void _draw_form() {
  TFT_eSPI &tft = ui_get_tft();
  
  tft.fillScreen(COLOR_BG_DARK);
  
  // Header
  tft.setTextColor(COLOR_PRIMARY);
  tft.setTextDatum(TC_DATUM);
  tft.setTextSize(1);
  tft.drawString("Enrollment", TFT_WIDTH / 2, 5, 4);
  
  // Fields — 5 rows squeezed between the header and the keyboard (y 33..121)
  const char *labels[] = {"atSign:", "Device:", "OTP:",
                          (_rules_mode == 1) ? "Policy:" : "Manager:", "Root:"};
  char *buffers[] = {_atsign, _device_name, _otp,
                     (_rules_mode == 1) ? _policy_at : _manager, _root};

  int y = 33;
  for (int i = 0; i < 5; i++) {
    // Label. Field 3's label is a chip — tapping it toggles Manager/Policy
    if (i == 3) {
      ui_draw_rounded_rect(2, y - 2, 70, 16, 4, COLOR_BUTTON_BG);
      tft.setTextColor(COLOR_TEXT_WHITE);
      tft.setTextDatum(ML_DATUM);
      tft.setTextSize(1);
      tft.drawString(labels[i], 6, y + 6, 2);
      // tiny swap glyph so the chip reads as tappable
      tft.setTextColor(COLOR_ACCENT);
      tft.setTextDatum(MR_DATUM);
      tft.drawString("~", 70, y + 6, 2);
      tft.setTextDatum(TL_DATUM);
    } else {
      tft.setTextColor(COLOR_TEXT_GREY);
      tft.setTextDatum(TL_DATUM);
      tft.setTextSize(1);
      tft.drawString(labels[i], 5, y, 2);
    }

    // Field background
    uint16_t bg_color = (i == _active_field) ? COLOR_BG_CARD : 0x2104;
    ui_draw_rounded_rect(75, y - 2, TFT_WIDTH - 80, 16, 4, bg_color);

    // Field text
    tft.setTextColor(COLOR_TEXT_WHITE);
    tft.setTextDatum(ML_DATUM);
    tft.drawString(buffers[i], 80, y + 6, 2);

    // Cursor on active field
    if (i == _active_field) {
      int tw = tft.textWidth(buffers[i], 2);
      int cursor_x = 80 + tw;
      tft.drawLine(cursor_x, y, cursor_x, y + 12, COLOR_PRIMARY);
    }

    y += 18;
  }
  
  // Note: Enroll button drawn separately at top-right. See _draw_enroll_button().
}

static void _draw_enroll_button() {
  TFT_eSPI &tft = ui_get_tft();
  
  // Always clear the button area (top-right)
  int btn_x = TFT_WIDTH - 85;
  int btn_y = 5;
  tft.fillRect(btn_x - 2, btn_y - 1, 87, 24, COLOR_BG_DARK);
  
  // Only show when all fields are filled
  if (strlen(_atsign) == 0 || strlen(_device_name) == 0 ||
      strlen(_otp) == 0 || strlen(_rules_value()) == 0) {
    return;
  }
  
  Button btn_enroll;
  btn_enroll.x = btn_x;
  btn_enroll.y = btn_y;
  btn_enroll.w = 80;
  btn_enroll.h = 22;
  btn_enroll.label = "Enroll";
  btn_enroll.bg_color = COLOR_SUCCESS;
  btn_enroll.text_color = COLOR_TEXT_WHITE;
  btn_enroll.visible = true;
  ui_draw_button(btn_enroll);
}

static void _draw_keyboard() {
  TFT_eSPI &tft = ui_get_tft();
  
  int kb_start_y = 125;
  tft.fillRect(0, kb_start_y, TFT_WIDTH, TFT_HEIGHT - kb_start_y, COLOR_BG_DARK);
  
  int key_idx = 0;
  int row = 0;
  int x_start = 5;
  
  for (int i = 0; i < _kb_key_count; i++) {
    int col = key_idx % KEYS_PER_ROW;
    int x = x_start + col * (KEY_WIDTH + KEY_SPACING);
    int y = kb_start_y + row * (KEY_HEIGHT + KEY_SPACING) + 2;
    
    // Wide keys: DEL=3cols, ':'=4cols, DONE=3cols (total 10 = full row)
    int key_w = KEY_WIDTH;
    int col_span = 1;
    if (strcmp(_kb_keys[i], "DEL") == 0) {
      key_w = KEY_WIDTH * 3 + KEY_SPACING * 2;
      col_span = 3;
    } else if (strcmp(_kb_keys[i], ":") == 0) {
      key_w = KEY_WIDTH * 4 + KEY_SPACING * 3;
      col_span = 4;
    } else if (strcmp(_kb_keys[i], "DONE") == 0) {
      key_w = KEY_WIDTH * 3 + KEY_SPACING * 2;
      col_span = 3;
    }

    ui_draw_rounded_rect(x, y, key_w, KEY_HEIGHT, 3, COLOR_BUTTON_BG);
    
    tft.setTextColor(COLOR_TEXT_WHITE);
    tft.setTextDatum(MC_DATUM);
    tft.setTextSize(1);
    tft.drawString(_kb_keys[i], x + key_w / 2, y + KEY_HEIGHT / 2, 2);
    
    key_idx += col_span;
    if (key_idx >= KEYS_PER_ROW) {
      row++;
      key_idx = 0;
    }
  }
}

static bool _check_keyboard_press(int16_t tx, int16_t ty) {
  int kb_start_y = 125;
  int key_idx = 0;
  int row = 0;
  int x_start = 5;
  
  for (int i = 0; i < _kb_key_count; i++) {
    int col = key_idx % KEYS_PER_ROW;
    int x = x_start + col * (KEY_WIDTH + KEY_SPACING);
    int y = kb_start_y + row * (KEY_HEIGHT + KEY_SPACING) + 2;
    
    // Wide keys: DEL=3cols, ':'=4cols, DONE=3cols
    int key_w = KEY_WIDTH;
    int col_span = 1;
    if (strcmp(_kb_keys[i], "DEL") == 0) {
      key_w = KEY_WIDTH * 3 + KEY_SPACING * 2;
      col_span = 3;
    } else if (strcmp(_kb_keys[i], ":") == 0) {
      key_w = KEY_WIDTH * 4 + KEY_SPACING * 3;
      col_span = 4;
    } else if (strcmp(_kb_keys[i], "DONE") == 0) {
      key_w = KEY_WIDTH * 3 + KEY_SPACING * 2;
      col_span = 3;
    }

    if (ui_touch_in_rect(tx, ty, x, y, key_w, KEY_HEIGHT)) {
      char *buf = _get_active_buffer();
      if (!buf) return false;

      int len = _get_active_buffer_len();
      size_t maxlen = _get_active_buffer_maxlen();

      if (strcmp(_kb_keys[i], "DEL") == 0) {
        if (len > 0) {
          buf[len - 1] = '\0';
        }
      } else if (strcmp(_kb_keys[i], "DONE") == 0) {
        // Move to next field; if on last field, stop advancing
        if (_active_field < 4) {
          _active_field++;
        }
      } else {
        // Regular key
        if (len < maxlen) {
          buf[len] = _kb_keys[i][0];
          buf[len + 1] = '\0';
        }
      }
      
      _draw_form();
      _draw_enroll_button();
      _draw_keyboard();
      return true;
    }
    
    key_idx += col_span;
    if (key_idx >= KEYS_PER_ROW) {
      row++;
      key_idx = 0;
    }
  }
  
  return false;
}

static void _start_enrollment() {
  // Validate fields
  if (strlen(_atsign) == 0 || strlen(_device_name) == 0 ||
      strlen(_otp) == 0 || strlen(_rules_value()) == 0) {
    _status_msg = "All fields required!";
    // Draw the error over the header title; the next redraw restores it
    TFT_eSPI &tft = ui_get_tft();
    tft.fillRect(0, 0, TFT_WIDTH - 90, 28, COLOR_BG_DARK);
    tft.setTextColor(COLOR_ERROR);
    tft.setTextDatum(TL_DATUM);
    tft.setTextSize(1);
    tft.drawString(_status_msg.c_str(), 5, 8, 2);
    return;
  }
  
  // Show progress screen
  _state = ENROLL_RUNNING;
  _enroll_start_ms = millis();
  _last_progress_ms = 0;  // Force immediate first update
  TFT_eSPI &tft = ui_get_tft();
  tft.fillScreen(COLOR_BG_DARK);
  tft.setTextColor(COLOR_PRIMARY);
  tft.setTextDatum(MC_DATUM);
  tft.setTextSize(1);
  tft.drawString("Enrolling...", TFT_WIDTH / 2, TFT_HEIGHT / 2 - 15, 4);
  tft.setTextColor(COLOR_TEXT_GREY);
  tft.drawString("Connecting to atServer...", TFT_WIDTH / 2, TFT_HEIGHT / 2 + 15, 2);
  
  // Save to NVS
  ui_save_string(NVS_KEY_ATSIGN, _atsign);
  ui_save_string(NVS_KEY_DEVICE, _device_name);
  if (_rules_mode == 1) {
    // Policy mode: the policy-service atSign authorises via RPC
    ui_save_string(NVS_KEY_POLICY_AT, _policy_at);
    ui_save_string(NVS_KEY_RULES_MODE, "1");
  } else {
    ui_save_string(NVS_KEY_MANAGER, _manager);
    ui_save_string(NVS_KEY_MANAGERS, _manager);  // also save to new multi-manager key
    ui_save_string(NVS_KEY_RULES_MODE, "0");
    // Managers mode needs permitopen rules to start the daemon; the wipe
    // clears them, so default to allow-all (same default the Rules screen
    // offers) — tighten later via Rules.
    if (ui_load_string(NVS_KEY_PERMITOPEN).length() == 0) {
      ui_save_string(NVS_KEY_PERMITOPEN, "*:*");
    }
  }
  // Persist the root spec only when it differs from the default, so a
  // default-valued field doesn't shadow a future default change
  ui_save_string(NVS_KEY_ROOT,
                 (strcmp(_root, DEFAULT_ROOT_SPEC) == 0) ? "" : _root);
  
  Serial.printf("[ui_enroll] Starting enrollment for %s\n", _atsign);
  Serial.printf("[ui_enroll] Free heap: %u bytes, largest block: %u bytes\n",
                ESP.getFreeHeap(), ESP.getMaxAllocHeap());
  
  // Copy args for the FreeRTOS task (form fields may change)
  struct EnrollTaskArgs {
    char atsign[64];
    char device[64];
    char otp[32];
    char manager[64];
    char root[128];
  };

  EnrollTaskArgs *args = (EnrollTaskArgs *)malloc(sizeof(EnrollTaskArgs));
  if (!args) {
    _state = ENROLL_FAILED;
    _status_msg = "Out of memory";
    return;
  }
  strncpy(args->atsign,  _atsign,      sizeof(args->atsign) - 1);
  strncpy(args->device,  _device_name,  sizeof(args->device) - 1);
  strncpy(args->otp,     _otp,          sizeof(args->otp) - 1);
  strncpy(args->manager, _manager,      sizeof(args->manager) - 1);
  strncpy(args->root, strlen(_root) ? _root : DEFAULT_ROOT_SPEC, sizeof(args->root) - 1);
  args->atsign[sizeof(args->atsign) - 1]   = '\0';
  args->device[sizeof(args->device) - 1]   = '\0';
  args->otp[sizeof(args->otp) - 1]         = '\0';
  args->manager[sizeof(args->manager) - 1] = '\0';
  args->root[sizeof(args->root) - 1]       = '\0';
  
  // Run enrollment on a separate FreeRTOS task because it does:
  //   - TLS handshake (mbedtls, needs large stack)
  //   - RSA 2048/4096-bit key generation & crypto
  //   - Blocking network I/O (root lookup, atServer connect, PKAM auth)
  // Stack: 32KB needed for TLS + RSA. Pinned to core 1 (app core).
  xTaskCreatePinnedToCore(
    [](void *param) {
      EnrollTaskArgs *a = (EnrollTaskArgs *)param;
      
      Serial.printf("[enroll_task] atsign=%s device=%s otp=%s root=%s\n",
                    a->atsign, a->device, a->otp, a->root);
      
      // Ensure LittleFS is available for writing atKeys
      if (!LittleFS.begin(true)) {
        Serial.println("[enroll_task] LittleFS mount failed");
        ui_event_push(UI_EVT_ENROLL_FAIL, "LittleFS mount failed");
        free(a);
        vTaskDelete(nullptr);
        return;
      }
      
      // Remove any existing atKeys file so enroll doesn't refuse
      if (LittleFS.exists(ATKEYS_PATH)) {
        Serial.println("[enroll_task] Removing old atKeys file");
        LittleFS.remove(ATKEYS_PATH);
      }
      
      ui_event_push(UI_EVT_ENROLL_STATUS, "Connecting to root server...");
      
      // Use ATKEYS_PATH_VFS (/littlefs/atkeys.json) because the at_client C
      // library writes via fopen() which needs the full ESP32 VFS mount path.
      // The Arduino LittleFS API auto-prepends /littlefs, but fopen() does not.
      int ret = atauth_enroll_command(
        a->atsign,           // @alice
        a->root,             // root spec: host[:port] or proxy:host[:port]
        ATKEYS_PATH_VFS,     // /littlefs/atkeys.json (full VFS path for C fopen)
        a->otp,              // OTP/passcode
        ENROLL_APP_NAME,     // "noports"
        a->device,           // device name
        ENROLL_NAMESPACES,   // "sshnp:rw,sshrvd:rw"
        nullptr              // no expiry
      );
      
      if (ret == 0) {
        Serial.println("[enroll_task] SUCCESS - keys written to " ATKEYS_PATH_VFS);
        ui_set_configured(true);
        ui_event_push(UI_EVT_ENROLL_OK, "Enrolled successfully!");
      } else {
        Serial.printf("[enroll_task] FAILED with code %d\n", ret);
        char buf[64];
        snprintf(buf, sizeof(buf), "Enrollment failed (err=%d)", ret);
        ui_event_push(UI_EVT_ENROLL_FAIL, buf);
      }
      
      free(a);
      vTaskDelete(nullptr);
    },
    "enroll",    // task name
    32768,       // stack size (32KB for TLS+RSA)
    args,        // parameter
    5,           // priority
    nullptr,     // task handle (not needed)
    1            // core 1 (app core)
  );
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

void ui_enroll_create(void (*on_enrolled)()) {
  _on_enrolled_cb = on_enrolled;
  _state = ENROLL_FORM;
  _active_field = 0;
  
  // Clear fields
  memset(_atsign, 0, sizeof(_atsign));
  memset(_device_name, 0, sizeof(_device_name));
  memset(_otp, 0, sizeof(_otp));
  memset(_manager, 0, sizeof(_manager));
  memset(_policy_at, 0, sizeof(_policy_at));

  // Restore the last rules mode (fresh wipe → managers)
  _rules_mode = (ui_load_string(NVS_KEY_RULES_MODE) == "1") ? 1 : 0;

  // Prefill root spec: previously saved value, else the default directory.
  // Editable for 443-only networks, e.g. "proxy:proxy0001.atsign.org:443".
  String saved_root = ui_load_string(NVS_KEY_ROOT);
  strncpy(_root, saved_root.length() ? saved_root.c_str() : DEFAULT_ROOT_SPEC,
          sizeof(_root) - 1);
  _root[sizeof(_root) - 1] = '\0';
  
  _draw_form();
  _draw_enroll_button();
  _draw_keyboard();
  
  Serial.println("[ui_enroll] Created enrollment form");
}

void ui_enroll_update() {
  // Handle enrollment state changes
  if (_state == ENROLL_RUNNING) {
    uint32_t elapsed = millis() - _enroll_start_ms;
    
    // Check for timeout
    if (elapsed > ENROLL_TIMEOUT_MS) {
      Serial.println("[ui_enroll] Enrollment timed out");
      _state = ENROLL_FAILED;
      _status_msg = "Timeout - no approval received";
      return;
    }
    
    // Update progress display every second
    if (millis() - _last_progress_ms >= 1000) {
      _last_progress_ms = millis();
      
      TFT_eSPI &tft = ui_get_tft();
      uint32_t remaining_s = (ENROLL_TIMEOUT_MS - elapsed) / 1000;
      uint32_t mins = remaining_s / 60;
      uint32_t secs = remaining_s % 60;
      
      // Clear status area
      tft.fillRect(0, TFT_HEIGHT / 2 + 10, TFT_WIDTH, 50, COLOR_BG_DARK);
      
      // Show what's happening
      tft.setTextColor(COLOR_TEXT_GREY);
      tft.setTextDatum(MC_DATUM);
      tft.setTextSize(1);
      
      const char *phase;
      if (elapsed < 5000) {
        phase = "Connecting to atServer...";
      } else if (elapsed < 15000) {
        phase = "Sending enrollment request...";
      } else {
        phase = "Waiting for approval...";
      }
      tft.drawString(phase, TFT_WIDTH / 2, TFT_HEIGHT / 2 + 15, 2);
      
      // Countdown
      char countdown[16];
      snprintf(countdown, sizeof(countdown), "%d:%02d remaining", mins, secs);
      tft.setTextColor(COLOR_ACCENT);
      tft.drawString(countdown, TFT_WIDTH / 2, TFT_HEIGHT / 2 + 40, 2);
      
      // Animated dots on the "Enrolling" text
      int dots = (elapsed / 500) % 4;
      char title[20];
      snprintf(title, sizeof(title), "Enrolling%.*s", dots, "...");
      tft.fillRect(0, TFT_HEIGHT / 2 - 30, TFT_WIDTH, 30, COLOR_BG_DARK);
      tft.setTextColor(COLOR_PRIMARY);
      tft.drawString(title, TFT_WIDTH / 2, TFT_HEIGHT / 2 - 15, 4);
    }
  } else if (_state == ENROLL_SUCCESS) {
    TFT_eSPI &tft = ui_get_tft();
    tft.fillScreen(COLOR_BG_DARK);
    tft.setTextColor(COLOR_SUCCESS);
    tft.setTextDatum(MC_DATUM);
    tft.setTextSize(1);
    tft.drawString("Enrollment Success!", TFT_WIDTH / 2, TFT_HEIGHT / 2, 4);
    
    delay(2000);
    
    if (_on_enrolled_cb) {
      _on_enrolled_cb();
    }
    
    _state = ENROLL_FORM;  // Reset for next time
  } else if (_state == ENROLL_FAILED) {
    TFT_eSPI &tft = ui_get_tft();
    tft.fillScreen(COLOR_BG_DARK);
    tft.setTextColor(COLOR_ERROR);
    tft.setTextDatum(MC_DATUM);
    tft.setTextSize(1);
    tft.drawString("Enrollment Failed", TFT_WIDTH / 2, TFT_HEIGHT / 2 - 20, 4);
    tft.setTextColor(COLOR_TEXT_GREY);
    tft.drawString(_status_msg.c_str(), TFT_WIDTH / 2, TFT_HEIGHT / 2 + 20, 2);
    
    delay(3000);
    
    // Return to form
    _state = ENROLL_FORM;
    _draw_form();
    _draw_enroll_button();
    _draw_keyboard();
  }
}

bool ui_enroll_handle_touch(int16_t tx, int16_t ty) {
  if (_state != ENROLL_FORM) return false;
  
  // Check Enroll button (top-right, only active when all fields filled)
  int btn_x = TFT_WIDTH - 85;
  int btn_y = 5;
  if (strlen(_atsign) > 0 && strlen(_device_name) > 0 &&
      strlen(_otp) > 0 && strlen(_rules_value()) > 0) {
    if (ui_touch_in_rect(tx, ty, btn_x, btn_y, 80, 22)) {
      _start_enrollment();
      return true;
    }
  }
  
  // Field 3's label chip toggles between Manager and Policy atSign
  if (ui_touch_in_rect(tx, ty, 2, 33 + 3 * 18 - 2, 70, 16)) {
    _rules_mode = (_rules_mode == 0) ? 1 : 0;
    _active_field = 3;
    _draw_form();
    _draw_enroll_button();
    _draw_keyboard();
    return true;
  }

  // Check field selection (33, 51, 69, 87, 105)
  int y = 33;
  for (int i = 0; i < 5; i++) {
    if (ui_touch_in_rect(tx, ty, 75, y - 2, TFT_WIDTH - 80, 16)) {
      _active_field = i;
      _draw_form();
      _draw_enroll_button();
      _draw_keyboard();
      return true;
    }
    y += 18;
  }
  
  // Check keyboard
  return _check_keyboard_press(tx, ty);
}

void ui_enroll_process_events() {
  UiEvent evt;
  while (ui_event_pop(&evt)) {
    if (evt.type == UI_EVT_ENROLL_OK) {
      _state = ENROLL_SUCCESS;
      ui_set_configured(true);
    } else if (evt.type == UI_EVT_ENROLL_FAIL) {
      _state = ENROLL_FAILED;
      _status_msg = evt.text;
    } else if (evt.type == UI_EVT_ENROLL_STATUS) {
      // Update status message
      Serial.printf("[ui_enroll] Status: %s\n", evt.text);
    }
  }
}
