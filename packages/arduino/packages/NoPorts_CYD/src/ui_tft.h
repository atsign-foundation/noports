/**
 * @file ui_tft.h
 * @brief Lightweight TFT_eSPI-based UI framework for NoPorts CYD
 *
 * Memory-efficient replacement for LVGL, optimized for ESP32-2432S028R (CYD).
 * Provides simple UI primitives for dashboard, config screens, and touch handling.
 */

#ifndef UI_TFT_H
#define UI_TFT_H

#if defined(CROWPANEL_ADVANCE_7)
// Elecrow CrowPanel Advance 7.0: LovyanGFX RGB panel, UI drawn on a 320x240
// canvas that is pushed to the 800x480 panel at 2x.  CrowCanvas exposes the
// TFT_eSPI signatures the screens use, so the rest of the UI is unchanged.
#include "crowpanel_adv7.h"
typedef CrowCanvas TFT_eSPI;
#else
#include <TFT_eSPI.h>
#include <XPT2046_Touchscreen.h>
#endif
#include <Preferences.h>
#include <Wire.h>
#include <freertos/FreeRTOS.h>
#include <freertos/semphr.h>

// ---------------------------------------------------------------------------
// Hardware configuration for CYD (ESP32-2432S028R)
// Display is 240x320 natively, used in landscape (320x240)
// ---------------------------------------------------------------------------
#undef TFT_WIDTH
#undef TFT_HEIGHT
#if defined(CROWPANEL_ADVANCE_7)
// 5:3 panel (800x480) shown at 2x — a 400x240 canvas fills it exactly.
// Every screen lays itself out from TFT_WIDTH, so the extra width is used.
#define TFT_WIDTH  400
#else
#define TFT_WIDTH  320
#endif
#define TFT_HEIGHT 240

// Application version — shown on every boot/status screen and the dashboard
#define CYD_APP_VERSION "1.2.1"

// XPT2046 Touch pins (standard CYD configuration)
#ifndef TOUCH_CS
#define TOUCH_CS   33
#endif
#define TOUCH_IRQ  36

// RGB LED pins (active low) — standard CYD (ESP32) only
// GPIO 16 and 17 are FT6336U I2C pins on FNK0104 (ESP32-S3)
#define LED_R 4
#define LED_G 16
#define LED_B 17

#if defined(ESP32S3_2432S028R)
// FNK0104 (Freenove ESP32-S3): FT6336U capacitive touch via I2C
#define FT6336U_SDA   16
#define FT6336U_SCL   15
#define FT6336U_RST   18
#define FT6336U_INT   17
#define FT6336U_ADDR  0x38
// FNK0104 RGB LED: single WS2812B NeoPixel on GPIO 42
// (GPIO 16/17 are used for FT6336U I2C, not discrete LEDs)
#define LED_WS2812_PIN 42
#endif

// ---------------------------------------------------------------------------
// Color palette (16-bit RGB565)
// ---------------------------------------------------------------------------
#define COLOR_BG_DARK     0x1082   // Dark blue-grey
#define COLOR_BG_CARD     0x2945   // Lighter card background
#define COLOR_PRIMARY     0xF300   // Orange
#define COLOR_ACCENT      0x05F3   // Teal
#define COLOR_TEXT_WHITE  0xFFFF   // White
#define COLOR_TEXT_GREY   0xAD55   // Light grey
#define COLOR_SUCCESS     0x2E65   // Green
#define COLOR_ERROR       0xE8A4   // Red
#define COLOR_BUTTON_BG   0x6B4D   // Button background

// ---------------------------------------------------------------------------
// Event queue (thread-safe communication from callbacks to UI)
// ---------------------------------------------------------------------------
#define EVENT_QUEUE_SIZE 16
#define EVENT_TEXT_LEN   128

enum UiEventType {
  UI_EVT_NONE = 0,
  UI_EVT_TUNNEL_OPEN,
  UI_EVT_TUNNEL_CLOSE,
  UI_EVT_PING,
  UI_EVT_DAEMON_STATE,
  UI_EVT_ERROR,
  UI_EVT_ENROLL_STATUS,
  UI_EVT_ENROLL_OK,
  UI_EVT_ENROLL_FAIL,
};

struct UiEvent {
  UiEventType type;
  char        text[EVENT_TEXT_LEN];
  uint32_t    timestamp;
};

// ---------------------------------------------------------------------------
// NVS keys
// ---------------------------------------------------------------------------
#define NVS_NAMESPACE     "noports_cyd"
#define NVS_KEY_SSID      "wifi_ssid"
#define NVS_KEY_PASS      "wifi_pass"
#define NVS_KEY_ATSIGN    "atsign"
#define NVS_KEY_DEVICE    "device_name"
#define NVS_KEY_MANAGER   "manager"
#define NVS_KEY_LED_COLOR "led_color"
#define NVS_KEY_CONFIGURED "configured"
#define NVS_KEY_NTP_GOOD  "ntp_good"    // last known-good NTP epoch (monotonic time floor across reboots)
#define NVS_KEY_MANAGERS   "managers"    // comma-separated atSign list e.g. "@colin,@cconstab"
#define NVS_KEY_PERMITOPEN  "permitopen"  // comma-separated host:port rules e.g. "localhost:22,localhost:80"
#define NVS_KEY_RULES_MODE  "rules_mode"  // "0" = managers list, "1" = policy atSign
#define NVS_KEY_POLICY_AT   "policy_at"   // single policy-service atSign e.g. "@mypolicy"
#define NVS_KEY_WORKER_KEEPALIVE "worker_ka"  // worker TLS keepalive interval in minutes (0=off)
#define NVS_KEY_ROOT        "root_spec"   // root server spec: host[:port] or proxy:host[:port]; "" = root.atsign.org
#define NVS_KEY_MAX_RELAYS       "max_relays"  // max relay sub-connections per session (1-5 on ESP32, 1-6 on S3)

#define PERMITOPEN_PATH   "/permitopen.json"
#define ATKEYS_PATH       "/atkeys.json"           // Arduino LittleFS API (auto-prepends /littlefs)
#define ATKEYS_PATH_VFS   "/littlefs/atkeys.json"  // C fopen() needs full VFS mount path

// ---------------------------------------------------------------------------
// Touch calibration (adjust these based on your CYD calibration)
// ---------------------------------------------------------------------------
#define TOUCH_MIN_X 200
#define TOUCH_MAX_X 3700
#define TOUCH_MIN_Y 200
#define TOUCH_MAX_Y 3700

// ---------------------------------------------------------------------------
// UI primitives
// ---------------------------------------------------------------------------

struct Button {
  int16_t x, y, w, h;
  const char *label;
  uint16_t bg_color;
  uint16_t text_color;
  bool visible;
  void (*callback)();
};

struct TextField {
  int16_t x, y, w, h;
  char *buffer;
  size_t buffer_size;
  const char *placeholder;
  bool is_password;
  bool is_active;
};

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * @brief Initialize TFT display, touch, and LED
 */
void ui_tft_init();

/**
 * @brief Run touch screen calibration (saves to NVS)
 */
void ui_touch_calibrate();

/**
 * @brief Check if touch calibration has been done
 */
bool ui_touch_is_calibrated();

/**
 * @brief Get reference to TFT instance
 */
TFT_eSPI& ui_get_tft();

#if !defined(ESP32S3_2432S028R) && !defined(CROWPANEL_ADVANCE_7)
/**
 * @brief Get reference to touch controller (CYD/ESP32 only — not on FNK0104 S3)
 */
XPT2046_Touchscreen& ui_get_touch();
#endif

/**
 * @brief Poll touch input and return screen coordinates
 * @return true if screen is currently touched
 */
bool ui_touch_read(int16_t *x, int16_t *y);

/**
 * @brief Check if a touch point is within a rectangular area
 */
bool ui_touch_in_rect(int16_t tx, int16_t ty, int16_t x, int16_t y, int16_t w, int16_t h);

/**
 * @brief Draw a filled rectangle with rounded corners
 */
void ui_draw_rounded_rect(int16_t x, int16_t y, int16_t w, int16_t h, int16_t r, uint16_t color);

/**
 * @brief Draw a button
 */
void ui_draw_button(const Button &btn);

/**
 * @brief Check if button is pressed and call its callback
 * @return true if button was pressed
 */
bool ui_check_button_press(Button &btn, int16_t tx, int16_t ty);

/**
 * @brief Draw a text field
 */
void ui_draw_textfield(const TextField &field);

/**
 * @brief Draw centered text
 */
void ui_draw_text_centered(const char *text, int16_t y, uint16_t color, uint8_t font_size = 2);

/**
 * @brief Control TFT backlight on/off (GPIO 21 on CYD)
 */
void ui_set_backlight(bool on);

/**
 * @brief Set RGB LED color (active low hardware). Clears any active breathe.
 */
void ui_set_led(bool r, bool g, bool b);

/**
 * @brief Arm the breathing LED effect (sine-wave ramp like Apple sleep indicator).
 * Call once when entering standby state; ui_led_tick() does the actual updates.
 */
void ui_led_breathe_start(bool r, bool g, bool b);

/**
 * @brief Drive LED updates — call from main loop every tick.
 * Advances the breathe waveform when armed; no-op otherwise.
 */
void ui_led_tick();

/**
 * @brief Load RGB LED state from NVS and apply
 */
void ui_load_led_color();

/**
 * @brief Save RGB LED state to NVS
 */
void ui_save_led_color(bool r, bool g, bool b);

// ---------------------------------------------------------------------------
// Event queue
// ---------------------------------------------------------------------------

/**
 * @brief Push an event to the queue (thread-safe)
 */
void ui_event_push(UiEventType type, const char *text);

/**
 * @brief Pop an event from the queue
 * @return true if an event was available
 */
bool ui_event_pop(UiEvent *evt);

// ---------------------------------------------------------------------------
// NVS helpers
// ---------------------------------------------------------------------------

/**
 * @brief Get shared Preferences instance
 */
Preferences& ui_prefs();

/**
 * @brief Check if first-run setup is complete
 */
bool ui_is_configured();

/**
 * @brief Mark configuration as complete
 */
void ui_set_configured(bool val);

/**
 * @brief Load a string from NVS
 */
String ui_load_string(const char *key);

/**
 * @brief Save a string to NVS
 */
void ui_save_string(const char *key, const char *value);

/**
 * @brief Format uptime as "Xh Ym" or "Xm" or "Xs"
 */
void ui_format_uptime(unsigned long ms, char *buf, size_t buflen);

#endif // UI_TFT_H
