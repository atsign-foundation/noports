/**
 * @file ui_settings_tft.cpp
 * @brief Settings screen for editing managers/policy and connection rules
 *
 * Mode toggle selects how authorisation works:
 *   MANAGERS – comma-separated list of allowed manager atSigns
 *   POLICY   – single policy-service atSign (RPC-based authorisation)
 *
 * Field 0 changes meaning based on mode; Field 1 is always PermitOpen.
 */

#include "ui_settings_tft.h"
#include "ui_tft.h"
#include <Arduino.h>
#include <WiFi.h>

// ---------------------------------------------------------------------------
// Layout
// ---------------------------------------------------------------------------
#define HEADER_HEIGHT     28
// Mode-toggle bar (drawn just below header)
#define TOGGLE_Y          34
#define TOGGLE_H          28
// Fields start below the toggle bar
#define FIELD_Y_START     (TOGGLE_Y + TOGGLE_H + 2)
#define FIELD_HEIGHT      16
#define FIELD_GAP         2
// Keyboard pushed down slightly to fit the extra toggle bar
#define KEYBOARD_TOP_Y    132
#define KEYS_PER_ROW      10
#define KEY_HEIGHT        18
#define KEY_SPACING       1
#define KEY_WIDTH         ((TFT_WIDTH - 10 - (KEYS_PER_ROW - 1) * KEY_SPACING) / KEYS_PER_ROW)  // 30 @320, 38 @400

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
static void (*_on_save_cb)() = nullptr;

// rules_mode: 0 = managers list, 1 = policy atSign
static int  _rules_mode   = 0;
// Field 0 = Managers -or- Policy atSign depending on _rules_mode
// Field 1 = PermitOpen (always)
static int  _active_field = 0;
static char _managers[256]    = "";
static char _policy_at[128]   = "";
static char _permitopen[256]  = "";

// Keyboard mode: 0=lowercase, 1=uppercase, 2=symbols
static int _kb_mode = 0;

// Keyboard layouts — 4 rows of 10 + bottom row (DEL, SPACE, mode toggle, SAVE)
static const char* _kb_lower[] = {
  "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
  "q", "w", "e", "r", "t", "y", "u", "i", "o", "p",
  "a", "s", "d", "f", "g", "h", "j", "k", "l", "@",
  "z", "x", "c", "v", "b", "n", "m", ":", ".", ",",
  "DEL", "SPACE", "ABC", "SAVE"
};
static const int _kb_lower_count = sizeof(_kb_lower) / sizeof(_kb_lower[0]);

static const char* _kb_upper[] = {
  "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
  "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P",
  "A", "S", "D", "F", "G", "H", "J", "K", "L", "@",
  "Z", "X", "C", "V", "B", "N", "M", ":", ".", ",",
  "DEL", "SPACE", "#$%", "SAVE"
};
static const int _kb_upper_count = sizeof(_kb_upper) / sizeof(_kb_upper[0]);

static const char* _kb_sym[] = {
  "!", "#", "$", "%", "^", "&", "*", "(", ")", "~",
  "+", "=", "[", "]", "{", "}", "|", "\\", ";", "'",
  "\"", "<", ">", "?", "/", ":", "_", "`", "-", ".",
  "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
  "DEL", "SPACE", "abc", "SAVE"
};
static const int _kb_sym_count = sizeof(_kb_sym) / sizeof(_kb_sym[0]);

static const char** _get_kb_keys() {
  switch (_kb_mode) {
    case 1:  return _kb_upper;
    case 2:  return _kb_sym;
    default: return _kb_lower;
  }
}

static int _get_kb_key_count() {
  switch (_kb_mode) {
    case 1:  return _kb_upper_count;
    case 2:  return _kb_sym_count;
    default: return _kb_lower_count;
  }
}

// Scroll offset for long text display
static int _scroll_offset[2] = {0, 0};

// ---------------------------------------------------------------------------
// Forward declarations
// ---------------------------------------------------------------------------
static void _draw_screen();
static void _draw_fields();
static void _draw_mode_toggle();
static void _draw_keyboard();
static bool _check_mode_toggle_tap(int16_t tx, int16_t ty);
static bool _check_keyboard_press(int16_t tx, int16_t ty);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

static char* _get_active_buffer() {
  if (_active_field == 0)
    return (_rules_mode == 1) ? _policy_at : _managers;
  return _permitopen;
}

static size_t _get_active_maxlen() {
  if (_active_field == 0)
    return (_rules_mode == 1) ? sizeof(_policy_at) - 1 : sizeof(_managers) - 1;
  return sizeof(_permitopen) - 1;
}

// ---------------------------------------------------------------------------
// Drawing
// ---------------------------------------------------------------------------

static void _draw_header() {
  TFT_eSPI &tft = ui_get_tft();

  // Background bar
  ui_draw_rounded_rect(3, 3, TFT_WIDTH - 6, HEADER_HEIGHT, 5, COLOR_BG_CARD);

  // Title
  tft.setTextColor(COLOR_PRIMARY);
  tft.setTextDatum(ML_DATUM);
  tft.setTextSize(1);
  tft.drawString("Rules", 10, 3 + HEADER_HEIGHT / 2, 4);
}

// ---------------------------------------------------------------------------
// Mode toggle bar: [Managers]  [Policy]
// ---------------------------------------------------------------------------
static void _draw_mode_toggle() {
  TFT_eSPI &tft = ui_get_tft();
  tft.fillRect(0, TOGGLE_Y, TFT_WIDTH, TOGGLE_H, COLOR_BG_DARK);

  int half    = TFT_WIDTH / 2;
  int gap     = 3;
  int btn_w   = half - gap - 2;
  int btn_h   = TOGGLE_H - 4;
  int btn_y   = TOGGLE_Y + 2;
  int mid_y   = btn_y + btn_h / 2;

  // Left: Managers
  uint16_t mgr_bg = (_rules_mode == 0) ? COLOR_PRIMARY : COLOR_BUTTON_BG;
  ui_draw_rounded_rect(2, btn_y, btn_w, btn_h, 4, mgr_bg);
  // Radio-dot indicator
  int mgr_dot_x = 11;
  tft.drawCircle(mgr_dot_x, mid_y, 4, COLOR_TEXT_WHITE);
  if (_rules_mode == 0) tft.fillCircle(mgr_dot_x, mid_y, 2, COLOR_TEXT_WHITE);
  tft.setTextColor(COLOR_TEXT_WHITE);
  tft.setTextDatum(ML_DATUM);
  tft.setTextSize(1);
  tft.drawString("Managers", mgr_dot_x + 7, mid_y, 2);

  // Right: Policy
  uint16_t pol_bg = (_rules_mode == 1) ? COLOR_PRIMARY : COLOR_BUTTON_BG;
  ui_draw_rounded_rect(half + gap, btn_y, btn_w, btn_h, 4, pol_bg);
  // Radio-dot indicator
  int pol_dot_x = half + gap + 11;
  tft.drawCircle(pol_dot_x, mid_y, 4, COLOR_TEXT_WHITE);
  if (_rules_mode == 1) tft.fillCircle(pol_dot_x, mid_y, 2, COLOR_TEXT_WHITE);
  tft.setTextDatum(ML_DATUM);
  tft.drawString("Policy", pol_dot_x + 7, mid_y, 2);
}

static void _draw_fields() {
  TFT_eSPI &tft = ui_get_tft();

  struct FieldInfo {
    const char *label;
    const char *hint;
    char *buf;
  };

  FieldInfo fields[] = {
    (_rules_mode == 1)
      ? FieldInfo{"Policy at:", "@policyservice", _policy_at}
      : FieldInfo{"Managers:",  "@alice,@bob",    _managers},
    {"Permit:", "*:*", _permitopen},
  };

  int y = FIELD_Y_START;
  // In policy mode only one field is needed (the policy atSign);
  // the policy server owns all permitOpen decisions.
  int field_count = (_rules_mode == 1) ? 1 : 2;

  for (int i = 0; i < field_count; i++) {
    // Label row
    tft.setTextColor(COLOR_TEXT_GREY);
    tft.setTextDatum(TL_DATUM);
    tft.setTextSize(1);
    tft.drawString(fields[i].label, 8, y, 2);

    // "Active" indicator
    if (i == _active_field) {
      tft.fillCircle(TFT_WIDTH - 12, y + 6, 3, COLOR_PRIMARY);
    }

    y += 16;

    // Value box
    uint16_t bg = (i == _active_field) ? COLOR_BG_CARD : 0x2104;
    ui_draw_rounded_rect(5, y, TFT_WIDTH - 10, FIELD_HEIGHT, 4, bg);

    // Value text (scrolled if long)
    const char *text = fields[i].buf;
    bool empty = (strlen(text) == 0);
    if (empty) {
      tft.setTextColor(0x5AEB);  // dim placeholder
      text = fields[i].hint;
    } else {
      tft.setTextColor(COLOR_TEXT_WHITE);
    }

    // Clip to field bounds
    tft.setTextDatum(ML_DATUM);
    // Calculate visible portion
    int max_w = TFT_WIDTH - 20;
    int tw = tft.textWidth(text, 2);
    const char *display_text = text;
    // If text is wider than field, show the tail (so cursor position is visible)
    if (!empty && tw > max_w && i == _active_field) {
      // Find offset to show the end
      int skip = 0;
      while (tft.textWidth(text + skip, 2) > max_w && text[skip]) skip++;
      display_text = text + skip;
    }
    tft.drawString(display_text, 10, y + FIELD_HEIGHT / 2, 2);

    // Cursor on active field
    if (i == _active_field && !empty) {
      int disp_w = tft.textWidth(display_text, 2);
      int cx = 10 + disp_w;
      if (cx > TFT_WIDTH - 15) cx = TFT_WIDTH - 15;
      tft.drawLine(cx, y + 2, cx, y + FIELD_HEIGHT - 2, COLOR_PRIMARY);
    }

    y += FIELD_HEIGHT + FIELD_GAP + 2;
  }
}

// Bottom row key positions (explicit pixel layout to avoid overlap)
// DEL(60) + 4 + SPACE(88) + 4 + mode(52) + 4 + SAVE(98) = 310
#define BROW_DEL_X    5
#define BROW_DEL_W    60
#define BROW_SPC_X    (BROW_DEL_X + BROW_DEL_W + 4)
#define BROW_SPC_W    88
#define BROW_MODE_X   (BROW_SPC_X + BROW_SPC_W + 4)
#define BROW_MODE_W   52
#define BROW_SAVE_X   (BROW_MODE_X + BROW_MODE_W + 4)
#define BROW_SAVE_W   (TFT_WIDTH - 5 - BROW_SAVE_X)

static void _draw_keyboard() {
  TFT_eSPI &tft = ui_get_tft();
  tft.fillRect(0, KEYBOARD_TOP_Y, TFT_WIDTH, TFT_HEIGHT - KEYBOARD_TOP_Y, COLOR_BG_DARK);

  const char **keys = _get_kb_keys();
  int count = _get_kb_key_count();
  int x_start = 5;

  // Draw character rows (rows 0-3, 10 keys each = indices 0..39)
  int char_count = count - 4;  // last 4 are action keys
  for (int i = 0; i < char_count; i++) {
    int row = i / KEYS_PER_ROW;
    int col = i % KEYS_PER_ROW;
    int x = x_start + col * (KEY_WIDTH + KEY_SPACING);
    int y = KEYBOARD_TOP_Y + row * (KEY_HEIGHT + KEY_SPACING) + 2;

    ui_draw_rounded_rect(x, y, KEY_WIDTH, KEY_HEIGHT, 3, COLOR_BUTTON_BG);
    tft.setTextColor(COLOR_TEXT_WHITE);
    tft.setTextDatum(MC_DATUM);
    tft.setTextSize(1);
    tft.drawString(keys[i], x + KEY_WIDTH / 2, y + KEY_HEIGHT / 2, 2);
  }

  // Draw bottom row (explicit positions)
  int brow_y = KEYBOARD_TOP_Y + 4 * (KEY_HEIGHT + KEY_SPACING) + 2;

  // DEL
  ui_draw_rounded_rect(BROW_DEL_X, brow_y, BROW_DEL_W, KEY_HEIGHT, 3, COLOR_BUTTON_BG);
  tft.setTextColor(COLOR_TEXT_WHITE);
  tft.setTextDatum(MC_DATUM);
  tft.drawString("DEL", BROW_DEL_X + BROW_DEL_W / 2, brow_y + KEY_HEIGHT / 2, 2);

  // SPACE
  ui_draw_rounded_rect(BROW_SPC_X, brow_y, BROW_SPC_W, KEY_HEIGHT, 3, COLOR_BUTTON_BG);
  tft.drawString("SPACE", BROW_SPC_X + BROW_SPC_W / 2, brow_y + KEY_HEIGHT / 2, 2);

  // Mode toggle (ABC / #$% / abc)
  const char *mode_label = keys[count - 2];  // second-to-last key
  ui_draw_rounded_rect(BROW_MODE_X, brow_y, BROW_MODE_W, KEY_HEIGHT, 3, COLOR_PRIMARY);
  tft.drawString(mode_label, BROW_MODE_X + BROW_MODE_W / 2, brow_y + KEY_HEIGHT / 2, 2);

  // SAVE
  ui_draw_rounded_rect(BROW_SAVE_X, brow_y, BROW_SAVE_W, KEY_HEIGHT, 3, COLOR_SUCCESS);
  tft.drawString("SAVE", BROW_SAVE_X + BROW_SAVE_W / 2, brow_y + KEY_HEIGHT / 2, 2);
}

static void _draw_screen() {
  TFT_eSPI &tft = ui_get_tft();
  tft.fillScreen(COLOR_BG_DARK);
  _draw_header();
  _draw_mode_toggle();
  _draw_fields();
  _draw_keyboard();
}

// ---------------------------------------------------------------------------
// Touch handling
// ---------------------------------------------------------------------------

static bool _check_mode_toggle_tap(int16_t tx, int16_t ty) {
  int half  = TFT_WIDTH / 2;
  int gap   = 3;
  int btn_w = half - gap - 2;

  // Expand hit area: from just below the header to the top of the first field.
  // This makes the tap zone ~30px tall rather than the 22px drawn height.
  int hit_y = HEADER_HEIGHT + 3;           // just below header bottom
  int hit_h = FIELD_Y_START - hit_y;       // down to first field

  int new_mode = -1;
  if (ui_touch_in_rect(tx, ty, 2,        hit_y, btn_w, hit_h)) new_mode = 0; // Managers
  if (ui_touch_in_rect(tx, ty, half+gap, hit_y, btn_w, hit_h)) new_mode = 1; // Policy

  if (new_mode >= 0 && new_mode != _rules_mode) {
    _rules_mode = new_mode;
    // Switching mode makes field 0 change meaning; keep the active field
    TFT_eSPI &tft = ui_get_tft();
    tft.fillRect(0, TOGGLE_Y, TFT_WIDTH, KEYBOARD_TOP_Y - TOGGLE_Y, COLOR_BG_DARK);
    _draw_mode_toggle();
    _draw_fields();
    return true;
  }
  // Consume the tap even if same mode (don't let it fall through to field checks)
  return (new_mode >= 0);
}

static bool _check_field_tap(int16_t tx, int16_t ty) {
  int y0 = FIELD_Y_START;
  int field_count = (_rules_mode == 1) ? 1 : 2;

  for (int i = 0; i < field_count; i++) {
    int label_y = y0;
    int field_y = label_y + 16;

    // Check tap in the label or value area
    if (ui_touch_in_rect(tx, ty, 3, label_y, TFT_WIDTH - 6, 16 + FIELD_HEIGHT)) {
      if (_active_field != i) {
        _active_field = i;
        // Redraw fields area
        TFT_eSPI &tft = ui_get_tft();
        tft.fillRect(0, FIELD_Y_START,
                     TFT_WIDTH, KEYBOARD_TOP_Y - FIELD_Y_START,
                     COLOR_BG_DARK);
        _draw_fields();
        return true;
      }
    }

    y0 += 16 + FIELD_HEIGHT + FIELD_GAP + 2;
  }

  return false;
}

static bool _check_keyboard_press(int16_t tx, int16_t ty) {
  const char **keys = _get_kb_keys();
  int count = _get_kb_key_count();
  int char_count = count - 4;  // last 4 are bottom-row action keys
  int x_start = 5;

  // Check character keys (rows 0-3)
  for (int i = 0; i < char_count; i++) {
    int row = i / KEYS_PER_ROW;
    int col = i % KEYS_PER_ROW;
    int x = x_start + col * (KEY_WIDTH + KEY_SPACING);
    int y = KEYBOARD_TOP_Y + row * (KEY_HEIGHT + KEY_SPACING) + 2;

    if (ui_touch_in_rect(tx, ty, x, y, KEY_WIDTH, KEY_HEIGHT)) {
      char *buf = _get_active_buffer();
      int len = strlen(buf);
      size_t maxlen = _get_active_maxlen();
      if (len < (int)maxlen) {
        buf[len] = keys[i][0];
        buf[len + 1] = '\0';
      }
      // Redraw fields
      TFT_eSPI &tft = ui_get_tft();
      tft.fillRect(0, FIELD_Y_START,
                   TFT_WIDTH, KEYBOARD_TOP_Y - FIELD_Y_START,
                   COLOR_BG_DARK);
      _draw_fields();
      return true;
    }
  }

  // Check bottom row (explicit positions)
  int brow_y = KEYBOARD_TOP_Y + 4 * (KEY_HEIGHT + KEY_SPACING) + 2;

  // DEL
  if (ui_touch_in_rect(tx, ty, BROW_DEL_X, brow_y, BROW_DEL_W, KEY_HEIGHT)) {
    char *buf = _get_active_buffer();
    int len = strlen(buf);
    if (len > 0) buf[len - 1] = '\0';
    TFT_eSPI &tft = ui_get_tft();
    tft.fillRect(0, FIELD_Y_START,
                 TFT_WIDTH, KEYBOARD_TOP_Y - FIELD_Y_START,
                 COLOR_BG_DARK);
    _draw_fields();
    return true;
  }

  // SPACE inserts a comma separator for multi-entry fields.
  // In policy-atSign field (single value) a comma makes no sense — ignore it.
  if (ui_touch_in_rect(tx, ty, BROW_SPC_X, brow_y, BROW_SPC_W, KEY_HEIGHT)) {
    bool comma_ok = !(_rules_mode == 1 && _active_field == 0);
    if (comma_ok) {
      char *buf = _get_active_buffer();
      int len = strlen(buf);
      size_t maxlen = _get_active_maxlen();
      if (len > 0 && len < (int)maxlen && buf[len - 1] != ',') {
        buf[len] = ',';
        buf[len + 1] = '\0';
      }
      TFT_eSPI &tft = ui_get_tft();
      tft.fillRect(0, FIELD_Y_START,
                   TFT_WIDTH, KEYBOARD_TOP_Y - FIELD_Y_START,
                   COLOR_BG_DARK);
      _draw_fields();
    }
    return true;
  }

  // Mode toggle
  if (ui_touch_in_rect(tx, ty, BROW_MODE_X, brow_y, BROW_MODE_W, KEY_HEIGHT)) {
    _kb_mode = (_kb_mode + 1) % 3;
    _draw_keyboard();
    return true;
  }

  // SAVE
  if (ui_touch_in_rect(tx, ty, BROW_SAVE_X, brow_y, BROW_SAVE_W, KEY_HEIGHT)) {
    // Persist mode selection + both possible auth values + permitopen
    char mode_str[4];
    snprintf(mode_str, sizeof(mode_str), "%d", _rules_mode);
    ui_save_string(NVS_KEY_RULES_MODE, mode_str);
    ui_save_string(NVS_KEY_MANAGERS,   _managers);
    ui_save_string(NVS_KEY_POLICY_AT,  _policy_at);
    ui_save_string(NVS_KEY_PERMITOPEN, _permitopen);
    Serial.printf("[settings] Saved rules_mode: %d\n",    _rules_mode);
    Serial.printf("[settings] Saved managers:   %s\n",    _managers);
    Serial.printf("[settings] Saved policy_at:  %s\n",    _policy_at);
    Serial.printf("[settings] Saved permitopen: %s\n",    _permitopen);
    if (_on_save_cb) {
      _on_save_cb();
    }
    return true;
  }

  return false;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

void ui_settings_create(void (*on_save)()) {
  _on_save_cb = on_save;

  // Load mode (0=managers, 1=policy)
  String mode_str = ui_load_string(NVS_KEY_RULES_MODE);
  _rules_mode = (mode_str == "1") ? 1 : 0;

  // Load managers (with legacy fallback)
  String mgr = ui_load_string(NVS_KEY_MANAGERS);
  if (mgr.length() == 0) {
    mgr = ui_load_string(NVS_KEY_MANAGER);
  }
  strncpy(_managers, mgr.c_str(), sizeof(_managers) - 1);
  _managers[sizeof(_managers) - 1] = '\0';

  // Load policy atSign
  String pol = ui_load_string(NVS_KEY_POLICY_AT);
  strncpy(_policy_at, pol.c_str(), sizeof(_policy_at) - 1);
  _policy_at[sizeof(_policy_at) - 1] = '\0';

  // Load permitopen (default *:*)
  String po = ui_load_string(NVS_KEY_PERMITOPEN);
  if (po.length() == 0) po = "*:*";
  strncpy(_permitopen, po.c_str(), sizeof(_permitopen) - 1);
  _permitopen[sizeof(_permitopen) - 1] = '\0';

  _active_field = 0;

  _draw_screen();
}

void ui_settings_update() {
  // Cursor blink could go here; keeping simple for now
}

bool ui_settings_handle_touch(int16_t tx, int16_t ty) {
  // Mode toggle (Managers / Policy buttons)
  if (_check_mode_toggle_tap(tx, ty)) return true;

  // Check field taps
  if (_check_field_tap(tx, ty)) return true;

  // Check keyboard
  if (_check_keyboard_press(tx, ty)) return true;

  return false;
}
