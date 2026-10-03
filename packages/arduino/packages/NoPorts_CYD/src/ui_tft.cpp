/**
 * @file ui_tft.cpp
 * @brief Lightweight TFT_eSPI-based UI framework implementation
 */

#include "ui_tft.h"
#include <Arduino.h>
#include <SPI.h>
#include <math.h>
#if defined(ESP32S3_2432S028R)
#include <Adafruit_NeoPixel.h>
#endif

// ---------------------------------------------------------------------------
// Global instances
// ---------------------------------------------------------------------------
static TFT_eSPI tft = TFT_eSPI();

// CYD2USB: Touch uses a separate SPI bus (HSPI) with its own pins
// MOSI=32, MISO=39, SCLK=25, CS=33, IRQ=36
// FNK0104 (ESP32-S3): uses FT6336U capacitive I2C touch — XPT2046 not present
#if defined(CROWPANEL_ADVANCE_7)
// CrowPanel Advance: GT911 touch and the panel live in crowpanel_adv7.cpp
#elif !defined(ESP32S3_2432S028R)
static XPT2046_Touchscreen touch(TOUCH_CS, TOUCH_IRQ);
#else
// FNK0104: single WS2812B on GPIO 42
static Adafruit_NeoPixel _ws2812(1, LED_WS2812_PIN, NEO_GRB + NEO_KHZ800);
#endif

static Preferences prefs;
static bool prefs_opened = false;

// Event queue
static UiEvent _event_buf[EVENT_QUEUE_SIZE];
static uint8_t _evt_head = 0;
static uint8_t _evt_tail = 0;
static uint8_t _evt_count = 0;
static SemaphoreHandle_t _evt_mutex = nullptr;

// Touch state for edge detection (fire once per press-release cycle)
static bool _touch_down = false;       // true while finger is on screen
static bool _touch_fired = false;      // true after we reported this press
static unsigned long _last_touch_time = 0;
static unsigned long _release_start = 0; // when we first saw "not touched"
#define TOUCH_DEBOUNCE_MS 150
#define TOUCH_RELEASE_MS  60   // finger must be off for 60ms to count as released

// Runtime touch calibration values (loaded from NVS or defaults)
static int16_t _cal_x_min = TOUCH_MIN_X;
static int16_t _cal_x_max = TOUCH_MAX_X;
static int16_t _cal_y_min = TOUCH_MIN_Y;
static int16_t _cal_y_max = TOUCH_MAX_Y;

// ---------------------------------------------------------------------------
// Touch calibration
// ---------------------------------------------------------------------------

// Draw a crosshair target at screen position
static void _draw_crosshair(int16_t sx, int16_t sy, uint16_t color) {
  tft.drawLine(sx - 10, sy, sx + 10, sy, color);
  tft.drawLine(sx, sy - 10, sx, sy + 10, color);
  tft.drawCircle(sx, sy, 6, color);
}

// Wait for touch and return raw XPT2046 coordinates
static TS_Point _wait_for_touch_raw() {
#if defined(ESP32S3_2432S028R) || defined(CROWPANEL_ADVANCE_7)
  return TS_Point(0, 0, 0);  // capacitive touch: no calibration
#else
  // Wait for release first
  while (touch.touched()) { delay(10); }
  delay(100);
  
  // Wait for press
  while (!touch.touched()) { delay(10); }
  delay(50);  // Settle
  
  // Average multiple samples for accuracy
  int32_t ax = 0, ay = 0;
  int samples = 0;
  uint32_t start = millis();
  while (touch.touched() && (millis() - start < 1000)) {
    TS_Point p = touch.getPoint();
    if (p.z > 300) {
      ax += p.x;
      ay += p.y;
      samples++;
    }
    delay(20);
  }
  
  if (samples > 0) {
    return TS_Point(ax / samples, ay / samples, 1);
  }
  return TS_Point(0, 0, 0);
#endif
}

/**
 * @brief Run touch calibration (3-point)
 * Asks user to touch crosshairs at known screen positions.
 * Saves calibration to NVS.
 */
void ui_touch_calibrate() {
  tft.fillScreen(COLOR_BG_DARK);
  tft.setTextColor(COLOR_TEXT_WHITE);
  tft.setTextDatum(MC_DATUM);
  tft.setTextSize(1);
  tft.drawString("Touch Calibration", TFT_WIDTH / 2, TFT_HEIGHT / 2 - 20, 4);
  tft.drawString("Touch each crosshair", TFT_WIDTH / 2, TFT_HEIGHT / 2 + 15, 2);
  delay(2000);
  
  // Calibration points at 10% and 90% of screen
  const int16_t margin_x = TFT_WIDTH / 10;   // 32px
  const int16_t margin_y = TFT_HEIGHT / 10;   // 24px
  
  struct { int16_t sx, sy; } targets[3] = {
    { margin_x,              margin_y },               // Top-left
    { TFT_WIDTH - margin_x,  margin_y },               // Top-right
    { TFT_WIDTH / 2,         TFT_HEIGHT - margin_y }   // Bottom-center
  };
  
  TS_Point raw[3];
  
  for (int i = 0; i < 3; i++) {
    tft.fillScreen(COLOR_BG_DARK);
    tft.setTextColor(COLOR_TEXT_GREY);
    tft.setTextDatum(MC_DATUM);
    char msg[32];
    snprintf(msg, sizeof(msg), "Point %d of 3", i + 1);
    tft.drawString(msg, TFT_WIDTH / 2, TFT_HEIGHT / 2, 2);
    
    _draw_crosshair(targets[i].sx, targets[i].sy, COLOR_PRIMARY);
    
    raw[i] = _wait_for_touch_raw();
    
    // Brief feedback
    _draw_crosshair(targets[i].sx, targets[i].sy, COLOR_SUCCESS);
    delay(300);
    
    Serial.printf("[cal] Point %d: screen(%d,%d) -> raw(%d,%d)\n",
                  i, targets[i].sx, targets[i].sy, raw[i].x, raw[i].y);
  }
  
  // Calculate calibration from the 3 points
  // Use linear interpolation from the calibration points
  // X: raw[0] maps to margin_x, raw[1] maps to (TFT_WIDTH - margin_x)
  // Y: raw[0] maps to margin_y, raw[2] maps to (TFT_HEIGHT - margin_y)
  
  float x_scale = (float)(targets[1].sx - targets[0].sx) / (float)(raw[1].x - raw[0].x);
  float y_scale = (float)(targets[2].sy - targets[0].sy) / (float)(raw[2].y - raw[0].y);
  
  // Extrapolate to 0 and max
  _cal_x_min = raw[0].x - (int16_t)(targets[0].sx / x_scale);
  _cal_x_max = raw[0].x + (int16_t)((TFT_WIDTH - targets[0].sx) / x_scale);
  _cal_y_min = raw[0].y - (int16_t)(targets[0].sy / y_scale);
  _cal_y_max = raw[0].y + (int16_t)((TFT_HEIGHT - targets[0].sy) / y_scale);
  
  Serial.printf("[cal] Result: X[%d..%d] Y[%d..%d]\n",
                _cal_x_min, _cal_x_max, _cal_y_min, _cal_y_max);
  
  // Save to NVS
  prefs.putShort("cal_x_min", _cal_x_min);
  prefs.putShort("cal_x_max", _cal_x_max);
  prefs.putShort("cal_y_min", _cal_y_min);
  prefs.putShort("cal_y_max", _cal_y_max);
  prefs.putBool("cal_done", true);
  
  tft.fillScreen(COLOR_BG_DARK);
  tft.setTextColor(COLOR_SUCCESS);
  tft.setTextDatum(MC_DATUM);
  tft.drawString("Calibration Complete!", TFT_WIDTH / 2, TFT_HEIGHT / 2, 4);
  delay(1000);
}

static void _load_calibration() {
  if (prefs.getBool("cal_done", false)) {
    _cal_x_min = prefs.getShort("cal_x_min", TOUCH_MIN_X);
    _cal_x_max = prefs.getShort("cal_x_max", TOUCH_MAX_X);
    _cal_y_min = prefs.getShort("cal_y_min", TOUCH_MIN_Y);
    _cal_y_max = prefs.getShort("cal_y_max", TOUCH_MAX_Y);
    Serial.printf("[cal] Loaded: X[%d..%d] Y[%d..%d]\n",
                  _cal_x_min, _cal_x_max, _cal_y_min, _cal_y_max);
  } else {
    Serial.println("[cal] No saved calibration, using defaults");
  }
}

bool ui_touch_is_calibrated() {
#if defined(CROWPANEL_ADVANCE_7)
  return true;   // capacitive GT911 reports panel pixels directly
#endif
  return prefs.getBool("cal_done", false);
}

// ---------------------------------------------------------------------------
// Initialization
// ---------------------------------------------------------------------------

void ui_tft_init() {
#if defined(CROWPANEL_ADVANCE_7)
  // CrowPanel Advance: RGB panel, PSRAM canvas, companion-MCU backlight,
  // GT911 touch and the 2x flush task are all brought up here.
  crow_display_init(tft);
  tft.fillScreen(COLOR_BG_DARK);
#else
  // Turn on backlight (DISPLAY_BCKL: GPIO 21 on CYD, GPIO 45 on FNK0104)
  pinMode(DISPLAY_BCKL, OUTPUT);
  digitalWrite(DISPLAY_BCKL, HIGH);

  // Initialize TFT
  tft.init();
  tft.setRotation(1);  // Landscape mode
  tft.fillScreen(COLOR_BG_DARK);
#endif
  
  // Initialize touch
#if defined(CROWPANEL_ADVANCE_7)
  // done in crow_display_init()
#elif !defined(ESP32S3_2432S028R)
  // CYD2USB (ESP32): XPT2046 resistive touch on dedicated HSPI pins
  // SCLK=25, MISO=39, MOSI=32, CS=33, IRQ=36
  // TFT_eSPI uses its own SPIClass instance, so the global SPI can be
  // redirected to the touch bus without affecting the display.
  SPI.begin(25, 39, 32, TOUCH_CS);
  touch.begin();
  touch.setRotation(1);
#endif
  // FNK0104 (ESP32-S3): FT6336U capacitive I2C touch — no XPT2046
#if defined(ESP32S3_2432S028R)
  // Reset FT6336U, then start I2C
  pinMode(FT6336U_RST, OUTPUT);
  digitalWrite(FT6336U_RST, LOW);
  delay(10);
  digitalWrite(FT6336U_RST, HIGH);
  delay(300);
  Wire.begin(FT6336U_SDA, FT6336U_SCL);
  Serial.println("[ui_tft] FT6336U I2C touch initialized");
  // WS2812B NeoPixel LED on GPIO 42
  _ws2812.begin();
  _ws2812.setBrightness(60);
  _ws2812.clear();
  _ws2812.show();
  Serial.println("[ui_tft] WS2812B LED initialized");
#elif !defined(CROWPANEL_ADVANCE_7)
  // CYD/ESP32: three discrete active-LOW LEDs on GPIO 4/16/17
  pinMode(LED_R, OUTPUT);
  pinMode(LED_G, OUTPUT);
  pinMode(LED_B, OUTPUT);
#endif
  
  // Load saved LED color or default to off
  ui_load_led_color();
  
  // Create event queue mutex
  _evt_mutex = xSemaphoreCreateMutex();
  
  // Open NVS
  if (!prefs_opened) {
    prefs.begin(NVS_NAMESPACE, false);
    prefs_opened = true;
  }
  
  // Load touch calibration from NVS (or use defaults)
  _load_calibration();
  
  Serial.println("[ui_tft] Initialized - TFT_eSPI mode");
}

TFT_eSPI& ui_get_tft() {
  return tft;
}

#if !defined(ESP32S3_2432S028R) && !defined(CROWPANEL_ADVANCE_7)
XPT2046_Touchscreen& ui_get_touch() {
  return touch;
}
#endif

// ---------------------------------------------------------------------------
// Touch handling
// ---------------------------------------------------------------------------

bool ui_touch_read(int16_t *x, int16_t *y) {
#if defined(CROWPANEL_ADVANCE_7)
  // CrowPanel Advance: GT911 polled in crowpanel_adv7.cpp and already mapped
  // to canvas coordinates.  Same edge-trigger / sustained-release logic as
  // the other boards so screens see exactly one event per tap.
  int16_t cx, cy;
  if (!crow_touch_read(&cx, &cy)) {
    if (_touch_down || _touch_fired) {
      unsigned long now = millis();
      if (_release_start == 0) {
        _release_start = now;
      } else if (now - _release_start >= TOUCH_RELEASE_MS) {
        _touch_down  = false;
        _touch_fired = false;
        _release_start = 0;
      }
    }
    return false;
  }
  _release_start = 0;
  if (_touch_fired) return false;  // already reported this press
  unsigned long now = millis();
  if (_touch_down && (now - _last_touch_time < TOUCH_DEBOUNCE_MS)) return false;
  *x = constrain(cx, 0, TFT_WIDTH  - 1);
  *y = constrain(cy, 0, TFT_HEIGHT - 1);
  _touch_down  = true;
  _touch_fired = true;
  _last_touch_time = now;
  return true;
#elif defined(ESP32S3_2432S028R)
  // FNK0104: FT6336U capacitive I2C touch
  // Read TD_STATUS + P1 X/Y in a single burst from reg 0x02
  Wire.beginTransmission(FT6336U_ADDR);
  Wire.write(0x02);  // TD_STATUS register
  Wire.endTransmission(false);
  Wire.requestFrom((uint8_t)FT6336U_ADDR, (uint8_t)5);
  if (Wire.available() < 5) {
    _touch_down = false;
    _touch_fired = false;
    _release_start = 0;
    return false;
  }
  uint8_t td  = Wire.read();  // 0x02 TD_STATUS: lower nibble = number of touch points
  uint8_t xh  = Wire.read();  // 0x03 P1_XH: bits[3:0] = X[11:8]
  uint8_t xl  = Wire.read();  // 0x04 P1_XL: X[7:0]
  uint8_t yh  = Wire.read();  // 0x05 P1_YH: bits[3:0] = Y[11:8]
  uint8_t yl  = Wire.read();  // 0x06 P1_YL: Y[7:0]

  if ((td & 0x0F) == 0) {
    // No touch — sustain release timer before resetting edge state
    if (_touch_down || _touch_fired) {
      unsigned long now = millis();
      if (_release_start == 0) {
        _release_start = now;
      } else if (now - _release_start >= TOUCH_RELEASE_MS) {
        _touch_down  = false;
        _touch_fired = false;
        _release_start = 0;
      }
    }
    return false;
  }

  _release_start = 0;
  if (_touch_fired) return false;  // already reported this press

  unsigned long now = millis();
  if (_touch_down && (now - _last_touch_time < TOUCH_DEBOUNCE_MS)) return false;

  // Decode portrait-space coordinates (raw_x: 0-239, raw_y: 0-319)
  int16_t raw_x = (int16_t)(((xh & 0x0F) << 8) | xl);
  int16_t raw_y = (int16_t)(((yh & 0x0F) << 8) | yl);

  // Transform from portrait to landscape (tft.setRotation(1)):
  //   landscape X (0..319) = portrait Y
  //   landscape Y (0..239) = 239 - portrait X
  *x = raw_y;
  *y = 239 - raw_x;

  *x = constrain(*x, 0, TFT_WIDTH  - 1);
  *y = constrain(*y, 0, TFT_HEIGHT - 1);

  _touch_down  = true;
  _touch_fired = true;
  _last_touch_time = now;
  return true;
#else
  unsigned long now = millis();

  if (!touch.touched()) {
    // Finger appears to be off — but require sustained release to avoid
    // XPT2046 single-poll glitches resetting the edge trigger.
    if (_touch_down || _touch_fired) {
      if (_release_start == 0) {
        _release_start = now;          // start the release timer
      } else if (now - _release_start >= TOUCH_RELEASE_MS) {
        // Sustained release — actually reset edge state
        _touch_down = false;
        _touch_fired = false;
        _release_start = 0;
      }
    }
    return false;
  }

  // Finger is on screen — cancel any pending release
  _release_start = 0;
  
  TS_Point p = touch.getPoint();
  
  // Filter by pressure threshold
  // Low z means noise — DON'T reset edge state, just ignore this sample
  if (p.z < 400) {
    return false;
  }
  
  // Edge-triggered: only fire once per press-release cycle
  if (_touch_fired) {
    return false;  // already reported this press, wait for release
  }
  
  // Debounce: ignore rapid sequential presses
  if (_touch_down && (now - _last_touch_time < TOUCH_DEBOUNCE_MS)) {
    return false;
  }
  
  // Map raw touch coordinates to screen coordinates using calibration
  *x = map(p.x, _cal_x_min, _cal_x_max, 0, TFT_WIDTH);
  *y = map(p.y, _cal_y_min, _cal_y_max, 0, TFT_HEIGHT);
  
  // Constrain to screen bounds
  *x = constrain(*x, 0, TFT_WIDTH - 1);
  *y = constrain(*y, 0, TFT_HEIGHT - 1);
  
  _touch_down = true;
  _touch_fired = true;   // won't fire again until finger lifts
  _last_touch_time = now;
  
  return true;
#endif // !ESP32S3_2432S028R
}

bool ui_touch_in_rect(int16_t tx, int16_t ty, int16_t x, int16_t y, int16_t w, int16_t h) {
  return (tx >= x && tx < x + w && ty >= y && ty < y + h);
}

// ---------------------------------------------------------------------------
// Drawing primitives
// ---------------------------------------------------------------------------

void ui_draw_rounded_rect(int16_t x, int16_t y, int16_t w, int16_t h, int16_t r, uint16_t color) {
  tft.fillRoundRect(x, y, w, h, r, color);
}

void ui_draw_button(const Button &btn) {
  if (!btn.visible) return;
  
  // Draw button background
  ui_draw_rounded_rect(btn.x, btn.y, btn.w, btn.h, 6, btn.bg_color);
  
  // Draw button text centered
  tft.setTextColor(btn.text_color);
  tft.setTextDatum(MC_DATUM);  // Middle center
  tft.setTextSize(1);
  tft.drawString(btn.label, btn.x + btn.w / 2, btn.y + btn.h / 2, 2);
}

bool ui_check_button_press(Button &btn, int16_t tx, int16_t ty) {
  if (!btn.visible) return false;
  
  if (ui_touch_in_rect(tx, ty, btn.x, btn.y, btn.w, btn.h)) {
    if (btn.callback) {
      btn.callback();
    }
    return true;
  }
  return false;
}

void ui_draw_textfield(const TextField &field) {
  // Draw field background
  ui_draw_rounded_rect(field.x, field.y, field.w, field.h, 4, 
                       field.is_active ? COLOR_BG_CARD : 0x2104);
  
  // Draw text or placeholder
  tft.setTextColor(field.buffer[0] ? COLOR_TEXT_WHITE : COLOR_TEXT_GREY);
  tft.setTextDatum(ML_DATUM);  // Middle left
  tft.setTextSize(1);
  
  const char *display_text = field.buffer[0] ? field.buffer : field.placeholder;
  
  // Handle password masking
  if (field.is_password && field.buffer[0]) {
    String masked(strlen(field.buffer), '*');
    tft.drawString(masked.c_str(), field.x + 8, field.y + field.h / 2, 2);
  } else {
    tft.drawString(display_text, field.x + 8, field.y + field.h / 2, 2);
  }
  
  // Draw cursor if active
  if (field.is_active) {
    int16_t cursor_x = field.x + 8 + tft.textWidth(field.buffer, 2);
    tft.drawLine(cursor_x, field.y + 6, cursor_x, field.y + field.h - 6, COLOR_PRIMARY);
  }
}

void ui_draw_text_centered(const char *text, int16_t y, uint16_t color, uint8_t font_size) {
  tft.setTextColor(color);
  tft.setTextDatum(TC_DATUM);  // Top center
  tft.setTextSize(font_size);
  tft.drawString(text, TFT_WIDTH / 2, y, 2);
}

// ---------------------------------------------------------------------------
// LED control
// ---------------------------------------------------------------------------

// Breathe state
static bool _breathe_active = false;
static bool _breathe_r = false, _breathe_g = false, _breathe_b = false;
static uint32_t _breathe_start_ms = 0;  // millis() when armed, for phase continuity

void ui_set_backlight(bool on) {
#if defined(CROWPANEL_ADVANCE_7)
  crow_backlight(on);   // I2C command to the companion MCU, not a GPIO
#else
  digitalWrite(DISPLAY_BCKL, on ? HIGH : LOW);
#endif
}

void ui_set_led(bool r, bool g, bool b) {
  _breathe_active = false;  // solid colour cancels breathe
#if defined(CROWPANEL_ADVANCE_7)
  (void)r; (void)g; (void)b;   // no status LED on the CrowPanel
#elif defined(ESP32S3_2432S028R)
  // FNK0104: WS2812B NeoPixel — map bool r/g/b to full RGB byte values
  _ws2812.setPixelColor(0, _ws2812.Color(r ? 80 : 0, g ? 80 : 0, b ? 80 : 0));
  _ws2812.show();
#else
  // CYD: active-low LEDs via analogWrite (LEDC) for consistency with breathe mode
  analogWrite(LED_R, r ? 0 : 255);
  analogWrite(LED_G, g ? 0 : 255);
  analogWrite(LED_B, b ? 0 : 255);
#endif
}

void ui_led_breathe_start(bool r, bool g, bool b) {
  if (!_breathe_active || _breathe_r != r || _breathe_g != g || _breathe_b != b) {
    _breathe_active   = true;
    _breathe_r = r; _breathe_g = g; _breathe_b = b;
    // Don't reset _breathe_start_ms so phase stays continuous across calls
  }
}

void ui_led_tick() {
  if (!_breathe_active) return;

  static uint32_t last_ms = 0;
  uint32_t now = millis();
  if (now - last_ms < 30) return;  // ~33 fps cap
  last_ms = now;

  // 4-second sine cycle with gamma — rise² keeps the LED dim most of the time
  // (the Apple sleep-indicator characteristic)
  float t     = (float)(now % 4000u) / 4000.0f;
  float rise  = (1.0f - cosf(2.0f * (float)M_PI * t)) * 0.5f;
  float gamma = rise * rise;
  uint8_t val = (uint8_t)(gamma * 60.0f + 0.5f);  // peak ≈ 24%

#if defined(CROWPANEL_ADVANCE_7)
  (void)val;
#elif defined(ESP32S3_2432S028R)
  _ws2812.setPixelColor(0, _ws2812.Color(
    _breathe_r ? val : 0,
    _breathe_g ? val : 0,
    _breathe_b ? val : 0));
  _ws2812.show();
#else
  analogWrite(LED_R, _breathe_r ? (255 - val) : 255);
  analogWrite(LED_G, _breathe_g ? (255 - val) : 255);
  analogWrite(LED_B, _breathe_b ? (255 - val) : 255);
#endif
}

void ui_load_led_color() {
  uint32_t color = ui_prefs().getUInt(NVS_KEY_LED_COLOR, 0);
  bool r = (color >> 16) & 1;
  bool g = (color >> 8) & 1;
  bool b = color & 1;
  ui_set_led(r, g, b);
}

void ui_save_led_color(bool r, bool g, bool b) {
  uint32_t color = ((r ? 1 : 0) << 16) | ((g ? 1 : 0) << 8) | (b ? 1 : 0);
  ui_prefs().putUInt(NVS_KEY_LED_COLOR, color);
  ui_set_led(r, g, b);
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
  if (!prefs_opened) {
    prefs.begin(NVS_NAMESPACE, false);
    prefs_opened = true;
  }
  return prefs;
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
// Utility functions
// ---------------------------------------------------------------------------

void ui_format_uptime(unsigned long ms, char *buf, size_t buflen) {
  unsigned long seconds = ms / 1000;
  unsigned long minutes = seconds / 60;
  unsigned long hours = minutes / 60;
  
  if (hours > 0) {
    snprintf(buf, buflen, "%luh %lum", hours, minutes % 60);
  } else if (minutes > 0) {
    snprintf(buf, buflen, "%lum", minutes);
  } else {
    snprintf(buf, buflen, "%lus", seconds);
  }
}
