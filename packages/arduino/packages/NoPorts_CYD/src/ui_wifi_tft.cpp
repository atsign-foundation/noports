/**
 * @file ui_wifi_tft.cpp
 * @brief WiFi setup screen implementation using TFT_eSPI
 */

#include "ui_wifi_tft.h"
#include "ui_tft.h"
#include <WiFi.h>
#include <Arduino.h>
#include <esp_task_wdt.h>

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------
#define MAX_NETWORKS     8
#define NETWORK_HEIGHT   28
#define LIST_START_Y     50
#define KEYBOARD_HEIGHT  130

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
enum WifiState {
  WIFI_SCANNING,
  WIFI_SHOW_LIST,
  WIFI_ENTER_PASSWORD,
  WIFI_CONNECTING,
  WIFI_CONNECTED,
  WIFI_ERROR
};

static WifiState _state = WIFI_SCANNING;
static String _networks[MAX_NETWORKS];
static int _network_count = 0;
static int _selected_network = -1;
static char _password[64] = "";
static int _password_len = 0;
static void (*_on_connected_cb)() = nullptr;
static uint32_t _scan_start_ms = 0;
static uint32_t _connect_start_ms = 0;
static String _status_msg;
static int _scan_retries = 0;
#define MAX_SCAN_RETRIES 5

// Auto-search: when true the screen rescans periodically and connects
// automatically if the saved SSID reappears.  Cleared when the user taps any
// network to take manual control.
static bool    _auto_search      = false;
static String  _auto_search_ssid;
static String  _auto_search_pass;
static uint32_t _auto_rescan_ms = 0;
#define AUTO_RESCAN_INTERVAL_MS 15000UL

// Keyboard mode: 0=lowercase, 1=uppercase, 2=symbols
static int _wifi_kb_mode = 0;

// Keyboard layouts — 4 rows of 10 + bottom row (DEL, SPACE, mode toggle, OK)
static const char* _wifi_kb_lower[] = {
  "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
  "q", "w", "e", "r", "t", "y", "u", "i", "o", "p",
  "a", "s", "d", "f", "g", "h", "j", "k", "l", "@",
  "z", "x", "c", "v", "b", "n", "m", ",", ".", "-",
  "DEL", "SPACE", "ABC", "OK"
};
static const int _wifi_kb_lower_count = sizeof(_wifi_kb_lower) / sizeof(_wifi_kb_lower[0]);

static const char* _wifi_kb_upper[] = {
  "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
  "Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P",
  "A", "S", "D", "F", "G", "H", "J", "K", "L", "@",
  "Z", "X", "C", "V", "B", "N", "M", ",", ".", "-",
  "DEL", "SPACE", "#$%", "OK"
};
static const int _wifi_kb_upper_count = sizeof(_wifi_kb_upper) / sizeof(_wifi_kb_upper[0]);

static const char* _wifi_kb_sym[] = {
  "!", "#", "$", "%", "^", "&", "*", "(", ")", "~",
  "+", "=", "[", "]", "{", "}", "|", "\\", ";", "'",
  "\"", "<", ">", "?", "/", ":", "_", "`", "@", ".",
  "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
  "DEL", "SPACE", "abc", "OK"
};
static const int _wifi_kb_sym_count = sizeof(_wifi_kb_sym) / sizeof(_wifi_kb_sym[0]);

static const char** _wifi_get_kb_keys() {
  switch (_wifi_kb_mode) {
    case 1:  return _wifi_kb_upper;
    case 2:  return _wifi_kb_sym;
    default: return _wifi_kb_lower;
  }
}

static int _wifi_get_kb_key_count() {
  switch (_wifi_kb_mode) {
    case 1:  return _wifi_kb_upper_count;
    case 2:  return _wifi_kb_sym_count;
    default: return _wifi_kb_lower_count;
  }
}

#define KEYS_PER_ROW 10
#define KEY_HEIGHT   18
#define KEY_SPACING  1
#define KEY_WIDTH    ((TFT_WIDTH - 10 - (KEYS_PER_ROW - 1) * KEY_SPACING) / KEYS_PER_ROW)  // 30 @320, 38 @400

// ---------------------------------------------------------------------------
// Forward declarations
// ---------------------------------------------------------------------------
static void _draw_keyboard();
static bool _check_keyboard_press(int16_t tx, int16_t ty);
static void _draw_network_list();

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

static void _draw_header(const char *title) {
  TFT_eSPI &tft = ui_get_tft();
  tft.setTextColor(COLOR_PRIMARY);
  tft.setTextDatum(TC_DATUM);
  tft.setTextSize(1);
  tft.drawString(title, TFT_WIDTH / 2, 10, 4);
}

static void _draw_status(const char *msg) {
  TFT_eSPI &tft = ui_get_tft();
  
  // Clear status area
  tft.fillRect(0, 30, TFT_WIDTH, 16, COLOR_BG_DARK);
  
  // Draw message
  tft.setTextColor(COLOR_TEXT_GREY);
  tft.setTextDatum(TC_DATUM);
  tft.setTextSize(1);
  tft.drawString(msg, TFT_WIDTH / 2, 30, 2);
}

static void _start_scan() {
  _state = WIFI_SCANNING;
  _network_count = 0;
  _scan_start_ms = millis();

  // Show scanning message before blocking
  _draw_status("Scanning...");

  WiFi.scanDelete();
  WiFi.mode(WIFI_STA);

  // Synchronous scan — blocks 2-4 seconds but is far more reliable
  // than the async variant on ESP32 (which often returns WIFI_SCAN_FAILED)
  Serial.printf("[ui_wifi] Starting WiFi scan (attempt %d)...\n", _scan_retries + 1);
  int n = WiFi.scanNetworks(false);  // synchronous

  if (n < 0) {
    // Scan failed
    _scan_retries++;
    Serial.printf("[ui_wifi] Scan failed (err=%d), retries=%d\n", n, _scan_retries);
    if (_scan_retries < MAX_SCAN_RETRIES) {
      char msg[48];
      snprintf(msg, sizeof(msg), "Scan failed, retrying (%d/%d)...", _scan_retries, MAX_SCAN_RETRIES);
      _draw_status(msg);
      WiFi.scanDelete();
      // Retry immediately (recursive, but bounded by MAX_SCAN_RETRIES)
      _start_scan();
      return;
    }
    _state = WIFI_SHOW_LIST;
    _network_count = 0;
    if (_auto_search && _auto_search_ssid.length() > 0) {
      char msg[64];
      snprintf(msg, sizeof(msg), "Scanning for %s...", _auto_search_ssid.c_str());
      _draw_status(msg);
      _auto_rescan_ms = millis();
    } else {
      _draw_status("No networks found - tap Rescan");
    }
    _draw_network_list();
    return;
  }

  // Filter out empty/hidden SSIDs
  _network_count = 0;
  for (int i = 0; i < n && _network_count < MAX_NETWORKS; i++) {
    String ssid = WiFi.SSID(i);
    if (ssid.length() > 0) {
      _networks[_network_count++] = ssid;
    }
  }
  WiFi.scanDelete();
  _scan_retries = 0;

  Serial.printf("[ui_wifi] Found %d networks\n", _network_count);

  // Auto-search: if the saved SSID is visible, connect immediately without
  // waiting for user input.
  if (_auto_search && _auto_search_ssid.length() > 0) {
    for (int i = 0; i < _network_count; i++) {
      if (_networks[i] == _auto_search_ssid) {
        Serial.printf("[ui_wifi] Auto-search: '%s' visible — auto-connecting\n",
                      _auto_search_ssid.c_str());
        _selected_network = i;
        strncpy(_password, _auto_search_pass.c_str(), sizeof(_password) - 1);
        _password[sizeof(_password) - 1] = '\0';
        _password_len = strlen(_password);
        _state = WIFI_SHOW_LIST;
        _draw_status("Found! Reconnecting...");
        _draw_network_list();
        _state = WIFI_CONNECTING;
        _connect_start_ms = millis();
        WiFi.begin(_auto_search_ssid.c_str(), _auto_search_pass.c_str());
        return;
      }
    }
    // Saved SSID not in this scan — show list and schedule next rescan
    char msg[64];
    snprintf(msg, sizeof(msg), "Scanning for %s...", _auto_search_ssid.c_str());
    _state = WIFI_SHOW_LIST;
    _draw_status(msg);
    _draw_network_list();
    _auto_rescan_ms = millis();
    return;
  }

  _state = WIFI_SHOW_LIST;
  _draw_status(_network_count > 0 ? "Touch to select network" : "No networks found - tap Rescan");
  _draw_network_list();
}

// Y position for the Rescan button (below the network list)
#define RESCAN_BTN_W  70
#define RESCAN_BTN_H  24
#define RESCAN_BTN_X  ((TFT_WIDTH - RESCAN_BTN_W) / 2)
#define RESCAN_BTN_Y  (TFT_HEIGHT - RESCAN_BTN_H - 4)

static void _draw_network_list() {
  TFT_eSPI &tft = ui_get_tft();
  
  // Clear list area
  tft.fillRect(0, LIST_START_Y, TFT_WIDTH, TFT_HEIGHT - LIST_START_Y, COLOR_BG_DARK);
  
  int y = LIST_START_Y;
  for (int i = 0; i < _network_count && i < MAX_NETWORKS; i++) {
    // Highlight selected network
    uint16_t bg_color = (i == _selected_network) ? COLOR_BG_CARD : COLOR_BG_DARK;
    tft.fillRoundRect(5, y, TFT_WIDTH - 10, NETWORK_HEIGHT - 4, 4, bg_color);
    
    // Draw SSID and signal strength
    tft.setTextColor(COLOR_TEXT_WHITE);
    tft.setTextDatum(ML_DATUM);
    tft.setTextSize(1);
    tft.drawString(_networks[i].c_str(), 10, y + NETWORK_HEIGHT / 2, 2);
    
    y += NETWORK_HEIGHT;
  }

  // Draw Rescan button at the bottom
  ui_draw_rounded_rect(RESCAN_BTN_X, RESCAN_BTN_Y, RESCAN_BTN_W, RESCAN_BTN_H, 4, COLOR_BG_CARD);
  tft.setTextColor(COLOR_ACCENT);
  tft.setTextDatum(MC_DATUM);
  tft.setTextSize(1);
  tft.drawString("Rescan", RESCAN_BTN_X + RESCAN_BTN_W / 2, RESCAN_BTN_Y + RESCAN_BTN_H / 2, 2);
}

// Draw just the password field (no keyboard redraw — avoids flicker)
static void _draw_password_field() {
  TFT_eSPI &tft = ui_get_tft();
  int kb_start_y = TFT_HEIGHT - KEYBOARD_HEIGHT;
  int field_y = kb_start_y - 28;  // place field 28px above keyboard

  // Clear field area
  tft.fillRect(0, LIST_START_Y, TFT_WIDTH, field_y + 26 - LIST_START_Y, COLOR_BG_DARK);

  // SSID label
  tft.setTextColor(COLOR_PRIMARY);
  tft.setTextDatum(TC_DATUM);
  tft.setTextSize(1);
  tft.drawString(_networks[_selected_network].c_str(), TFT_WIDTH / 2, LIST_START_Y + 2, 2);

  // Password field box
  ui_draw_rounded_rect(10, field_y, TFT_WIDTH - 20, 24, 4, COLOR_BG_CARD);

  // Show password text with cursor
  tft.setTextDatum(ML_DATUM);
  if (_password_len > 0) {
    tft.setTextColor(COLOR_TEXT_WHITE);
    // Show the tail of the password if it's too wide for the field
    const char *display = _password;
    int max_w = TFT_WIDTH - 50;  // leave room for count
    int tw = tft.textWidth(_password, 2);
    if (tw > max_w) {
      int skip = 0;
      while (tft.textWidth(_password + skip, 2) > max_w && _password[skip]) skip++;
      display = _password + skip;
    }
    tft.drawString(display, 15, field_y + 12, 2);
    // Cursor
    int cx = 15 + tft.textWidth(display, 2);
    if (cx > TFT_WIDTH - 25) cx = TFT_WIDTH - 25;
    tft.drawLine(cx, field_y + 4, cx, field_y + 20, COLOR_PRIMARY);
  } else {
    tft.setTextColor(COLOR_TEXT_GREY);
    tft.drawString("Enter password", 15, field_y + 12, 2);
  }

}

// Draw SSID, password field, and keyboard (full redraw)
static void _draw_password_entry() {
  _draw_password_field();
  _draw_keyboard();
}

// Bottom row key positions (explicit pixel layout to avoid overlap)
// DEL(60) + 4 + SPACE(88) + 4 + mode(52) + 4 + OK(98) = 310
#define WBROW_DEL_X    5
#define WBROW_DEL_W    60
#define WBROW_SPC_X    (WBROW_DEL_X + WBROW_DEL_W + 4)
#define WBROW_SPC_W    88
#define WBROW_MODE_X   (WBROW_SPC_X + WBROW_SPC_W + 4)
#define WBROW_MODE_W   52
#define WBROW_OK_X     (WBROW_MODE_X + WBROW_MODE_W + 4)
#define WBROW_OK_W     (TFT_WIDTH - 5 - WBROW_OK_X)

static void _draw_keyboard() {
  TFT_eSPI &tft = ui_get_tft();
  
  int kb_start_y = TFT_HEIGHT - KEYBOARD_HEIGHT;
  tft.fillRect(0, kb_start_y, TFT_WIDTH, KEYBOARD_HEIGHT, COLOR_BG_DARK);
  
  const char **keys = _wifi_get_kb_keys();
  int count = _wifi_get_kb_key_count();
  int x_start = 5;

  // Draw character rows (rows 0-3, 10 keys each = indices 0..39)
  int char_count = count - 4;  // last 4 are action keys
  for (int i = 0; i < char_count; i++) {
    int row = i / KEYS_PER_ROW;
    int col = i % KEYS_PER_ROW;
    int x = x_start + col * (KEY_WIDTH + KEY_SPACING);
    int y = kb_start_y + row * (KEY_HEIGHT + KEY_SPACING) + 2;

    ui_draw_rounded_rect(x, y, KEY_WIDTH, KEY_HEIGHT, 3, COLOR_BUTTON_BG);
    tft.setTextColor(COLOR_TEXT_WHITE);
    tft.setTextDatum(MC_DATUM);
    tft.setTextSize(1);
    tft.drawString(keys[i], x + KEY_WIDTH / 2, y + KEY_HEIGHT / 2, 2);
  }

  // Draw bottom row (explicit positions)
  int brow_y = kb_start_y + 4 * (KEY_HEIGHT + KEY_SPACING) + 2;

  // DEL
  ui_draw_rounded_rect(WBROW_DEL_X, brow_y, WBROW_DEL_W, KEY_HEIGHT, 3, COLOR_BUTTON_BG);
  tft.setTextColor(COLOR_TEXT_WHITE);
  tft.setTextDatum(MC_DATUM);
  tft.drawString("DEL", WBROW_DEL_X + WBROW_DEL_W / 2, brow_y + KEY_HEIGHT / 2, 2);

  // SPACE
  ui_draw_rounded_rect(WBROW_SPC_X, brow_y, WBROW_SPC_W, KEY_HEIGHT, 3, COLOR_BUTTON_BG);
  tft.drawString("SPACE", WBROW_SPC_X + WBROW_SPC_W / 2, brow_y + KEY_HEIGHT / 2, 2);

  // Mode toggle (ABC / #$% / abc)
  const char *mode_label = keys[count - 2];  // second-to-last key
  ui_draw_rounded_rect(WBROW_MODE_X, brow_y, WBROW_MODE_W, KEY_HEIGHT, 3, COLOR_PRIMARY);
  tft.drawString(mode_label, WBROW_MODE_X + WBROW_MODE_W / 2, brow_y + KEY_HEIGHT / 2, 2);

  // OK (connect)
  ui_draw_rounded_rect(WBROW_OK_X, brow_y, WBROW_OK_W, KEY_HEIGHT, 3, COLOR_SUCCESS);
  tft.drawString("OK", WBROW_OK_X + WBROW_OK_W / 2, brow_y + KEY_HEIGHT / 2, 2);
}

static bool _check_keyboard_press(int16_t tx, int16_t ty) {
  int kb_start_y = TFT_HEIGHT - KEYBOARD_HEIGHT;
  const char **keys = _wifi_get_kb_keys();
  int count = _wifi_get_kb_key_count();
  int char_count = count - 4;  // last 4 are bottom-row action keys
  int x_start = 5;

  // Check character keys (rows 0-3)
  for (int i = 0; i < char_count; i++) {
    int row = i / KEYS_PER_ROW;
    int col = i % KEYS_PER_ROW;
    int x = x_start + col * (KEY_WIDTH + KEY_SPACING);
    int y = kb_start_y + row * (KEY_HEIGHT + KEY_SPACING) + 2;

    if (ui_touch_in_rect(tx, ty, x, y, KEY_WIDTH, KEY_HEIGHT)) {
      if (_password_len < 63) {
        _password[_password_len++] = keys[i][0];
        _password[_password_len] = '\0';
      }
      _draw_password_field();  // only refresh field, not keyboard
      return true;
    }
  }

  // Check bottom row (explicit positions)
  int brow_y = kb_start_y + 4 * (KEY_HEIGHT + KEY_SPACING) + 2;

  // DEL
  if (ui_touch_in_rect(tx, ty, WBROW_DEL_X, brow_y, WBROW_DEL_W, KEY_HEIGHT)) {
    if (_password_len > 0) {
      _password[--_password_len] = '\0';
    }
    _draw_password_field();
    return true;
  }

  // SPACE
  if (ui_touch_in_rect(tx, ty, WBROW_SPC_X, brow_y, WBROW_SPC_W, KEY_HEIGHT)) {
    if (_password_len < 63) {
      _password[_password_len++] = ' ';
      _password[_password_len] = '\0';
    }
    _draw_password_field();
    return true;
  }

  // Mode toggle
  if (ui_touch_in_rect(tx, ty, WBROW_MODE_X, brow_y, WBROW_MODE_W, KEY_HEIGHT)) {
    _wifi_kb_mode = (_wifi_kb_mode + 1) % 3;
    _draw_keyboard();
    return true;
  }

  // OK (connect)
  if (ui_touch_in_rect(tx, ty, WBROW_OK_X, brow_y, WBROW_OK_W, KEY_HEIGHT)) {
    _state = WIFI_CONNECTING;
    _connect_start_ms = millis();
    WiFi.begin(_networks[_selected_network].c_str(), _password);
    Serial.printf("[ui_wifi] Connecting to %s...\n", _networks[_selected_network].c_str());
    return true;
  }

  return false;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

void ui_wifi_create(void (*on_connected)(), bool auto_search) {
  _on_connected_cb = on_connected;
  _scan_retries = 0;
  _selected_network = -1;
  _password_len = 0;
  _password[0] = '\0';
  _wifi_kb_mode = 0;

  _auto_search = auto_search;
  if (auto_search) {
    _auto_search_ssid = ui_load_string(NVS_KEY_SSID);
    _auto_search_pass = ui_load_string(NVS_KEY_PASS);
    if (_auto_search_ssid.length() == 0) {
      _auto_search = false;  // no saved SSID — nothing to search for
    }
  }
  _auto_rescan_ms = 0;

  TFT_eSPI &tft = ui_get_tft();
  tft.fillScreen(COLOR_BG_DARK);

  _draw_header("WiFi Setup");
  _start_scan();
}

void ui_wifi_update() {
  switch (_state) {
    case WIFI_SCANNING:
      // Synchronous scan is handled entirely inside _start_scan() now.
      // If we still land here, the scan completed and transitioned state.
      break;

    case WIFI_SHOW_LIST:
      // Auto-search: rescan periodically until the saved SSID reappears.
      if (_auto_search && _auto_search_ssid.length() > 0
          && millis() - _auto_rescan_ms >= AUTO_RESCAN_INTERVAL_MS) {
        Serial.println("[ui_wifi] Auto-search: rescanning...");
        TFT_eSPI &tft = ui_get_tft();
        tft.fillScreen(COLOR_BG_DARK);
        _draw_header("WiFi Setup");
        _scan_retries = 0;
        _start_scan();
      }
      break;

    case WIFI_CONNECTING: {
      // Check connection status
      if (WiFi.status() == WL_CONNECTED) {
        _state = WIFI_CONNECTED;

        // Save credentials (no-op if auto-connecting to the already-saved SSID)
        ui_save_string(NVS_KEY_SSID, _networks[_selected_network].c_str());
        ui_save_string(NVS_KEY_PASS, _password);

        Serial.printf("[ui_wifi] Connected! IP: %s\n", WiFi.localIP().toString().c_str());

        TFT_eSPI &tft = ui_get_tft();
        tft.fillScreen(COLOR_BG_DARK);
        tft.setTextColor(COLOR_SUCCESS);
        tft.setTextDatum(MC_DATUM);
        tft.setTextSize(1);
        tft.drawString("Connected!", TFT_WIDTH / 2, TFT_HEIGHT / 2 - 20, 4);
        tft.setTextColor(COLOR_TEXT_WHITE);
        tft.drawString(WiFi.localIP().toString().c_str(), TFT_WIDTH / 2, TFT_HEIGHT / 2 + 20, 2);

        delay(2000);

        if (_on_connected_cb) {
          _on_connected_cb();
        }
      } else if (millis() - _connect_start_ms > 15000) {
        // Timeout
        _state = WIFI_ERROR;
        TFT_eSPI &tft = ui_get_tft();
        tft.fillScreen(COLOR_BG_DARK);
        tft.setTextColor(COLOR_ERROR);
        tft.setTextDatum(MC_DATUM);
        tft.setTextSize(1);
        tft.drawString("Connection Failed", TFT_WIDTH / 2, TFT_HEIGHT / 2, 4);
        delay(2000);

        // Return to list
        _state = WIFI_SHOW_LIST;
        _selected_network = -1;
        _password_len = 0;
        _password[0] = '\0';

        TFT_eSPI &tft2 = ui_get_tft();
        tft2.fillScreen(COLOR_BG_DARK);
        _draw_header("WiFi Setup");
        if (_auto_search && _auto_search_ssid.length() > 0) {
          // Auto-search was connecting — trigger immediate rescan
          char msg[64];
          snprintf(msg, sizeof(msg), "Scanning for %s...", _auto_search_ssid.c_str());
          _draw_status(msg);
          _auto_rescan_ms = millis() - AUTO_RESCAN_INTERVAL_MS;  // rescan immediately
        } else {
          _draw_status("Touch to select network");
        }
        _draw_network_list();
      } else {
        // Still connecting
        _draw_status("Connecting...");
      }
      break;
    }

    default:
      break;
  }
}

bool ui_wifi_handle_touch(int16_t tx, int16_t ty) {
  if (_state == WIFI_SHOW_LIST) {
    // Check Rescan button first
    if (ui_touch_in_rect(tx, ty, RESCAN_BTN_X, RESCAN_BTN_Y - 5, RESCAN_BTN_W, RESCAN_BTN_H + 10)) {
      Serial.println("[ui_wifi] Rescan pressed");
      TFT_eSPI &tft = ui_get_tft();
      tft.fillScreen(COLOR_BG_DARK);
      _draw_header("WiFi Setup");
      _scan_retries = 0;
      _start_scan();
      return true;
    }

    // Check if a network was tapped
    int y = LIST_START_Y;
    for (int i = 0; i < _network_count && i < MAX_NETWORKS; i++) {
      if (ui_touch_in_rect(tx, ty, 5, y, TFT_WIDTH - 10, NETWORK_HEIGHT - 4)) {
        _auto_search = false;  // user is taking manual control
        _selected_network = i;
        _password_len = 0;
        _password[0] = '\0';
        _wifi_kb_mode = 0;  // start in lowercase
        _state = WIFI_ENTER_PASSWORD;
        
        TFT_eSPI &tft = ui_get_tft();
        tft.fillScreen(COLOR_BG_DARK);
        _draw_header("Enter Password");
        _draw_password_entry();
        
        Serial.printf("[ui_wifi] Selected: %s\n", _networks[i].c_str());
        return true;
      }
      y += NETWORK_HEIGHT;
    }
  } else if (_state == WIFI_ENTER_PASSWORD) {
    return _check_keyboard_press(tx, ty);
  }
  
  return false;
}

bool ui_wifi_auto_connect(int timeout_ms) {
  String ssid = ui_load_string(NVS_KEY_SSID);
  String pass = ui_load_string(NVS_KEY_PASS);
  
  if (ssid.length() == 0) {
    Serial.println("[ui_wifi] No saved credentials");
    return false;
  }
  
  Serial.printf("[ui_wifi] Auto-connecting to: %s\n", ssid.c_str());
  
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid.c_str(), pass.c_str());
  
  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED) {
    if (millis() - start > timeout_ms) {
      Serial.println("[ui_wifi] Auto-connect timeout");
      WiFi.disconnect();
      return false;
    }
    esp_task_wdt_reset();
    delay(100);
  }
  
  Serial.printf("[ui_wifi] Auto-connected! IP: %s\n", WiFi.localIP().toString().c_str());
  return true;
}

String ui_wifi_get_ip() {
  if (WiFi.status() == WL_CONNECTED) {
    return WiFi.localIP().toString();
  }
  return "0.0.0.0";
}

