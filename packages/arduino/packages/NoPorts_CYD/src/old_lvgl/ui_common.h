/**
 * @file ui_common.h
 * @brief Shared UI utilities, styles, event queue, and NVS persistence
 *        for NoPorts_CYD
 */

#ifndef UI_COMMON_H
#define UI_COMMON_H

#include <lvgl.h>
#include <Preferences.h>

// ---------------------------------------------------------------------------
// Screen dimensions (landscape)
// ---------------------------------------------------------------------------
#define SCREEN_WIDTH  320
#define SCREEN_HEIGHT 240

// ---------------------------------------------------------------------------
// Color palette (Atsign brand-inspired)
// ---------------------------------------------------------------------------
#define COLOR_BG_DARK     lv_color_hex(0x1B2735)
#define COLOR_BG_CARD     lv_color_hex(0x233345)
#define COLOR_PRIMARY     lv_color_hex(0xF05E3B)  // Atsign orange
#define COLOR_ACCENT      lv_color_hex(0x00C4B3)  // Teal
#define COLOR_TEXT_WHITE   lv_color_hex(0xFFFFFF)
#define COLOR_TEXT_GREY    lv_color_hex(0xAABBCC)
#define COLOR_SUCCESS      lv_color_hex(0x2ECC71)
#define COLOR_ERROR        lv_color_hex(0xE74C3C)

// ---------------------------------------------------------------------------
// Event queue - thread-safe communication from NoPorts callbacks to LVGL
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
  UI_EVT_ENROLL_STATUS,   // enrollment status text (info)
  UI_EVT_ENROLL_OK,       // enrollment succeeded
  UI_EVT_ENROLL_FAIL,     // enrollment failed
};

struct UiEvent {
  UiEventType type;
  char        text[EVENT_TEXT_LEN];
  uint32_t    timestamp;  // millis()
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

// Permitopen config stored as JSON in LittleFS
#define PERMITOPEN_PATH   "/permitopen.json"
#define ATKEYS_PATH       "/atkeys.json"

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/**
 * @brief Initialize common styles and event queue
 * Must be called after smartdisplay_init()
 */
void ui_common_init();

/**
 * @brief Push an event into the thread-safe queue (call from any task/ISR)
 */
void ui_event_push(UiEventType type, const char *text);

/**
 * @brief Pop an event from the queue (call from LVGL loop only)
 * @return true if an event was available
 */
bool ui_event_pop(UiEvent *evt);

/**
 * @brief Get the shared Preferences instance
 */
Preferences& ui_prefs();

/**
 * @brief Check if first-run setup is complete
 */
bool ui_is_configured();

/**
 * @brief Mark setup as complete
 */
void ui_set_configured(bool val);

/**
 * @brief Load a string from NVS
 * @return Empty string if not found
 */
String ui_load_string(const char *key);

/**
 * @brief Save a string to NVS
 */
void ui_save_string(const char *key, const char *value);

/**
 * @brief Create a styled button with label
 */
lv_obj_t* ui_create_btn(lv_obj_t *parent, const char *text, lv_event_cb_t cb, void *user_data = nullptr);

/**
 * @brief Create a styled label
 */
lv_obj_t* ui_create_label(lv_obj_t *parent, const char *text, const lv_font_t *font = nullptr);

/**
 * @brief Create a text input field with label above it
 * @return The textarea object
 */
lv_obj_t* ui_create_input(lv_obj_t *parent, const char *label_text, const char *placeholder,
                           bool one_line = true, bool password = false);

/**
 * @brief Create a card-style container with rounded corners
 */
lv_obj_t* ui_create_card(lv_obj_t *parent);

/**
 * @brief Format uptime string from millis
 */
void ui_format_uptime(uint32_t ms, char *buf, size_t len);

#endif // UI_COMMON_H
