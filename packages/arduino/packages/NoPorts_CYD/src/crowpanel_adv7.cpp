/**
 * @file crowpanel_adv7.cpp
 * @brief Elecrow CrowPanel Advance 7.0-HMI board support — see the header.
 */
#ifdef CROWPANEL_ADVANCE_7

#include "crowpanel_adv7.h"
#include <Wire.h>
#include <esp_heap_caps.h>
#include <lgfx/v1/platforms/esp32s3/Bus_RGB.hpp>
#include <lgfx/v1/platforms/esp32s3/Panel_RGB.hpp>

// ---------------------------------------------------------------------------
// Pins.  Every value is quoted from Elecrow's LovyanGFX_Driver.h and
// cross-checked against the V1.5 schematic net names (IO7_R3 ... IO38_B7).
// Elecrow name the nets in RGB888 bit positions; a 16-bit bus feeding a
// 6-bit-per-channel panel lands on R3-R7 / G2-G7 / B3-B7.
// ---------------------------------------------------------------------------
namespace {

constexpr int LCD_R0 = 7,  LCD_R1 = 17, LCD_R2 = 18, LCD_R3 = 3,  LCD_R4 = 46;
constexpr int LCD_G0 = 9,  LCD_G1 = 10, LCD_G2 = 11, LCD_G3 = 12, LCD_G4 = 13, LCD_G5 = 14;
constexpr int LCD_B0 = 21, LCD_B1 = 47, LCD_B2 = 48, LCD_B3 = 45, LCD_B4 = 38;
constexpr int LCD_DE = 42, LCD_VSYNC = 41, LCD_HSYNC = 40, LCD_PCLK = 39;

// Elecrow LOWERED the pixel clock between V1.2 and V1.3.  Lower still trades
// refresh rate (16 MHz ≈ 39 Hz, 14 MHz ≈ 34 Hz) for tolerance of PSRAM
// contention; override with -DCROWPANEL_PCLK_HZ.
#if defined(CROWPANEL_PCLK_HZ)
constexpr uint32_t LCD_PCLK_HZ = CROWPANEL_PCLK_HZ;
#elif CROWPANEL_ADVANCE_REV >= 130
constexpr uint32_t LCD_PCLK_HZ = 16000000;
#else
constexpr uint32_t LCD_PCLK_HZ = 21000000;
#endif
// Porches are the same on both axes.  Not a copy-paste error.
constexpr int LCD_FRONT_PORCH = 8, LCD_PULSE_WIDTH = 4, LCD_BACK_PORCH = 8;

constexpr int      I2C_SDA = 15, I2C_SCL = 16;
constexpr uint32_t I2C_HZ  = 400000;

// STC8H1K28 companion MCU (V1.2+).  V1.0 has a PCA9557 expander at 0x18
// instead, which this firmware does not drive.
constexpr uint8_t PANEL_MCU_ADDR = 0x30;
#if CROWPANEL_ADVANCE_REV >= 130
constexpr uint8_t CMD_BL_ON  = 0;     // 0 = brightest ... 244 = dimmest
constexpr uint8_t CMD_BL_OFF = 245;
constexpr uint8_t CMD_TOUCH  = 250;   // reset / activate the GT911
#else
constexpr uint8_t CMD_BL_ON  = 0x10;  // 0x10 = brightest ... 0x05 = off
constexpr uint8_t CMD_BL_OFF = 0x05;
constexpr uint8_t CMD_TOUCH  = 0x19;
#endif

// GT911: latches its address from INT during reset (low → 0x5D, high → 0x14).
constexpr uint8_t  GT911_ADDR_PRIMARY = 0x5D;
constexpr uint8_t  GT911_ADDR_BACKUP  = 0x14;
constexpr int      TP_INT             = 1;
constexpr uint16_t GT911_REG_STATUS   = 0x814E;   // status, then P1 X/Y at 0x8150
constexpr uint32_t TOUCH_POLL_MS      = 20;

constexpr uint32_t FLUSH_PERIOD_MS    = 50;       // dirty-flag check interval

// ---------------------------------------------------------------------------
// LovyanGFX device: LCD_CAM RGB bus → 800x480 panel, framebuffer in PSRAM
// ---------------------------------------------------------------------------
class CrowLCD : public lgfx::LGFX_Device {
  lgfx::Bus_RGB   _bus;
  lgfx::Panel_RGB _panel;
 public:
  CrowLCD() {
    {
      auto cfg = _bus.config();
      cfg.panel = &_panel;
      cfg.pin_d0  = LCD_B0; cfg.pin_d1  = LCD_B1; cfg.pin_d2  = LCD_B2; cfg.pin_d3  = LCD_B3; cfg.pin_d4  = LCD_B4;
      cfg.pin_d5  = LCD_G0; cfg.pin_d6  = LCD_G1; cfg.pin_d7  = LCD_G2; cfg.pin_d8  = LCD_G3; cfg.pin_d9  = LCD_G4; cfg.pin_d10 = LCD_G5;
      cfg.pin_d11 = LCD_R0; cfg.pin_d12 = LCD_R1; cfg.pin_d13 = LCD_R2; cfg.pin_d14 = LCD_R3; cfg.pin_d15 = LCD_R4;
      cfg.pin_henable = LCD_DE;
      cfg.pin_vsync   = LCD_VSYNC;
      cfg.pin_hsync   = LCD_HSYNC;
      cfg.pin_pclk    = LCD_PCLK;
      cfg.freq_write  = LCD_PCLK_HZ;
      cfg.hsync_polarity = 0; cfg.hsync_front_porch = LCD_FRONT_PORCH; cfg.hsync_pulse_width = LCD_PULSE_WIDTH; cfg.hsync_back_porch = LCD_BACK_PORCH;
      cfg.vsync_polarity = 0; cfg.vsync_front_porch = LCD_FRONT_PORCH; cfg.vsync_pulse_width = LCD_PULSE_WIDTH; cfg.vsync_back_porch = LCD_BACK_PORCH;
      cfg.pclk_idle_high = true;
      _bus.config(cfg);
    }
    {
      auto cfg = _panel.config();
      cfg.memory_width  = CROW_PANEL_W; cfg.memory_height = CROW_PANEL_H;
      cfg.panel_width   = CROW_PANEL_W; cfg.panel_height  = CROW_PANEL_H;
      cfg.offset_x = 0; cfg.offset_y = 0;
      _panel.config(cfg);
    }
    _panel.setBus(&_bus);
    setPanel(&_panel);
  }
};

CrowLCD     g_lcd;
CrowCanvas *g_canvas   = nullptr;
bool        g_lcd_ok   = false;
uint8_t     g_gt911    = 0;          // address that answered, 0 = none
bool        g_pressed  = false;
int16_t     g_tx = 0, g_ty = 0;      // panel coordinates of last press
uint32_t    g_last_poll_ms = 0;
// Dirty row range, inclusive.  Written from the UI task (core 1) through the
// CrowCanvas wrappers, consumed by the flush task (core 0).
portMUX_TYPE g_dirty_mux = portMUX_INITIALIZER_UNLOCKED;
int32_t g_dirty_y0 = 0;
int32_t g_dirty_y1 = CROW_CANVAS_H - 1;   // start fully dirty

// ---- companion MCU ---------------------------------------------------------
bool mcu_send(uint8_t b) {           // one bare byte, no register address
  Wire.beginTransmission(PANEL_MCU_ADDR);
  Wire.write(b);
  return Wire.endTransmission() == 0;
}
bool i2c_probe(uint8_t addr) {
  Wire.beginTransmission(addr);
  return Wire.endTransmission() == 0;
}

// ---- GT911 -----------------------------------------------------------------
bool gt_read(uint16_t reg, uint8_t *out, size_t len) {
  Wire.beginTransmission(g_gt911);
  Wire.write((uint8_t)(reg >> 8));
  Wire.write((uint8_t)(reg & 0xFF));
  if (Wire.endTransmission(false) != 0) return false;
  if (Wire.requestFrom((int)g_gt911, (int)len) != (int)len) return false;
  for (size_t i = 0; i < len; i++) out[i] = Wire.read();
  return true;
}
void gt_write(uint16_t reg, uint8_t v) {
  Wire.beginTransmission(g_gt911);
  Wire.write((uint8_t)(reg >> 8));
  Wire.write((uint8_t)(reg & 0xFF));
  Wire.write(v);
  Wire.endTransmission();
}

void touch_init() {
  // Hold INT low across the companion-MCU-driven reset so the GT911 latches
  // 0x5D.  Probe both addresses afterwards so a mis-latch is reported rather
  // than showing up as "touch is dead".
  pinMode(TP_INT, OUTPUT);
  digitalWrite(TP_INT, LOW);
  mcu_send(CMD_TOUCH);
  delay(120);
  pinMode(TP_INT, INPUT);
  delay(100);

  if (i2c_probe(GT911_ADDR_PRIMARY))      g_gt911 = GT911_ADDR_PRIMARY;
  else if (i2c_probe(GT911_ADDR_BACKUP))  g_gt911 = GT911_ADDR_BACKUP;

  if (g_gt911) Serial.printf("[crow] GT911 touch at 0x%02X%s\n", g_gt911,
                             g_gt911 == GT911_ADDR_BACKUP ? " (address latch missed, still usable)" : "");
  else         Serial.println("[crow] no GT911 at 0x5D or 0x14 — touch disabled");
}

void touch_poll() {
  if (!g_gt911) return;
  uint32_t now = millis();
  if (now - g_last_poll_ms < TOUCH_POLL_MS) return;
  g_last_poll_ms = now;

  // Status byte and first point are contiguous: one 6-byte transaction.
  uint8_t b[6];
  if (!gt_read(GT911_REG_STATUS, b, sizeof(b))) return;
  if ((b[0] & 0x80) == 0) return;             // no fresh result
  if ((b[0] & 0x0F) > 0) {
    int16_t x = (int16_t)(b[2] | (b[3] << 8));
    int16_t y = (int16_t)(b[4] | (b[5] << 8));
    g_tx = constrain(x, 0, CROW_PANEL_W - 1);
    g_ty = constrain(y, 0, CROW_PANEL_H - 1);
    g_pressed = true;
  } else {
    g_pressed = false;
  }
  gt_write(GT911_REG_STATUS, 0);              // must clear or it stops reporting
}

// ---- canvas → panel at 2x ---------------------------------------------------
// Reads the sprite back a row at a time with the same uint16_t interpretation
// LovyanGFX uses for pushImage(), so the byte order round-trips whatever the
// sprite's internal format is.  Each row is compared with a shadow copy of
// what the panel already shows and only rows that differ are written: the
// panel framebuffer lives in PSRAM and every byte written there competes
// with the scan-out DMA, which the eye sees as shimmer.
uint16_t *g_row_src = nullptr;   // 320 px, internal RAM
uint16_t *g_row_dst = nullptr;   // 640 x 2 px, internal RAM
uint16_t *g_shadow  = nullptr;   // 320 x 240, PSRAM: last rows pushed

void flush_canvas(int32_t y0, int32_t y1) {
  if (!g_lcd_ok || !g_canvas || !g_row_src || !g_row_dst || !g_shadow) return;
  g_lcd.startWrite();
  for (int y = y0; y <= y1; y++) {
    g_canvas->readRect(0, y, CROW_CANVAS_W, 1, g_row_src);
    uint16_t *shadow = g_shadow + (size_t)y * CROW_CANVAS_W;
    if (memcmp(shadow, g_row_src, CROW_CANVAS_W * sizeof(uint16_t)) == 0) continue;
    memcpy(shadow, g_row_src, CROW_CANVAS_W * sizeof(uint16_t));
    uint16_t *d0 = g_row_dst;
    uint16_t *d1 = g_row_dst + CROW_CANVAS_W * CROW_SCALE;
    for (int x = 0; x < CROW_CANVAS_W; x++) {
      uint16_t p = g_row_src[x];
      d0[2 * x] = p; d0[2 * x + 1] = p;
      d1[2 * x] = p; d1[2 * x + 1] = p;
    }
    g_lcd.pushImage(CROW_OFFSET_X, CROW_OFFSET_Y + y * CROW_SCALE,
                    CROW_CANVAS_W * CROW_SCALE, CROW_SCALE, g_row_dst);
  }
  g_lcd.endWrite();
}

void flush_task(void *) {
  for (;;) {
    vTaskDelay(pdMS_TO_TICKS(FLUSH_PERIOD_MS));
    // Take the dirty range and reset it BEFORE reading, so a draw that lands
    // while we flush re-arms its rows for the next tick instead of being lost.
    int32_t y0, y1;
    portENTER_CRITICAL(&g_dirty_mux);
    y0 = g_dirty_y0; y1 = g_dirty_y1;
    g_dirty_y0 = CROW_CANVAS_H; g_dirty_y1 = -1;
    portEXIT_CRITICAL(&g_dirty_mux);
    if (y0 > y1) continue;    // nothing drawn since last flush
    flush_canvas(y0, y1);
  }
}

}  // namespace

// ---------------------------------------------------------------------------
// CrowCanvas
// ---------------------------------------------------------------------------
bool CrowCanvas::init() {
  setPsram(true);
  setColorDepth(16);
  if (createSprite(CROW_CANVAS_W, CROW_CANVAS_H) == nullptr) {
    Serial.println("[crow] canvas allocation failed — is OPI PSRAM enabled?");
    return false;
  }
  return true;
}

const lgfx::IFont *CrowCanvas::fontFor(uint8_t font) {
  switch (font) {
    case 2:  return &fonts::Font2;
    case 4:  return &fonts::Font4;
    case 6:  return &fonts::Font6;
    case 7:  return &fonts::Font7;
    case 8:  return &fonts::Font8;
    default: return &fonts::Font0;   // TFT_eSPI font 1 (GLCD)
  }
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------
bool crow_display_init(CrowCanvas &canvas) {
  g_canvas = &canvas;

  Wire.begin(I2C_SDA, I2C_SCL, I2C_HZ);

  Serial.printf("[crow] CrowPanel Advance 7.0 rev %d.%d, PSRAM %u KB free\n",
                CROWPANEL_ADVANCE_REV / 100, (CROWPANEL_ADVANCE_REV / 10) % 10,
                (unsigned)(heap_caps_get_free_size(MALLOC_CAP_SPIRAM) / 1024));

  g_lcd_ok = g_lcd.init();
  if (!g_lcd_ok) {
    Serial.println("[crow] RGB panel init FAILED");
  } else {
    g_lcd.setColorDepth(16);
    g_lcd.fillScreen(0);
  }

  if (!canvas.init()) return false;

  // Row buffers live in internal RAM: the flush reads PSRAM (sprite) and
  // writes PSRAM (framebuffer) — keeping the scratch lines off that bus
  // matters for scan-out jitter.
  g_row_src = (uint16_t *)heap_caps_malloc(CROW_CANVAS_W * sizeof(uint16_t), MALLOC_CAP_INTERNAL | MALLOC_CAP_8BIT);
  g_row_dst = (uint16_t *)heap_caps_malloc(CROW_CANVAS_W * CROW_SCALE * CROW_SCALE * sizeof(uint16_t), MALLOC_CAP_INTERNAL | MALLOC_CAP_8BIT);
  g_shadow  = (uint16_t *)heap_caps_calloc((size_t)CROW_CANVAS_W * CROW_CANVAS_H, sizeof(uint16_t), MALLOC_CAP_SPIRAM);
  if (g_shadow) memset(g_shadow, 0xFF, (size_t)CROW_CANVAS_W * CROW_CANVAS_H * sizeof(uint16_t));  // first flush pushes every row
  crow_mark_dirty();

  if (i2c_probe(PANEL_MCU_ADDR)) {
    Serial.printf("[crow] companion MCU at 0x%02X (driving as V%d.%d — if the screen stays dark, set -DCROWPANEL_ADVANCE_REV=%d)\n",
                  PANEL_MCU_ADDR, CROWPANEL_ADVANCE_REV / 100, (CROWPANEL_ADVANCE_REV / 10) % 10,
                  CROWPANEL_ADVANCE_REV >= 130 ? 120 : 130);
  } else {
    Serial.printf("[crow] nothing at 0x%02X — V1.0 board (PCA9557 at 0x18) is not supported; backlight/touch will not work\n", PANEL_MCU_ADDR);
  }

  touch_init();

  // Backlight last, after the RGB clocks have settled, or the panel flashes.
  delay(50);
  crow_backlight(true);

  // Flush task on core 0 (the Arduino loop and UI drawing run on core 1).
  xTaskCreatePinnedToCore(flush_task, "crow_flush", 4096, nullptr, 1, nullptr, 0);

  Serial.printf("[crow] pclk %u Hz\n", (unsigned)LCD_PCLK_HZ);
  Serial.printf("[crow] panel %s, canvas %dx%d @%dx → %dx%d at (%d,%d)\n",
                g_lcd_ok ? "up" : "DOWN", CROW_CANVAS_W, CROW_CANVAS_H, CROW_SCALE,
                CROW_CANVAS_W * CROW_SCALE, CROW_CANVAS_H * CROW_SCALE, CROW_OFFSET_X, CROW_OFFSET_Y);
  return g_lcd_ok;
}

void crow_backlight(bool on) {
  mcu_send(on ? CMD_BL_ON : CMD_BL_OFF);
}

bool crow_touch_read(int16_t *x, int16_t *y) {
  touch_poll();
  if (!g_pressed) return false;
  int16_t cx = (g_tx - CROW_OFFSET_X) / CROW_SCALE;
  int16_t cy = (g_ty - CROW_OFFSET_Y) / CROW_SCALE;
  if (cx < 0 || cx >= CROW_CANVAS_W || cy < 0 || cy >= CROW_CANVAS_H) return false;  // side bars
  *x = cx;
  *y = cy;
  return true;
}

void crow_mark_dirty_rows(int32_t y0, int32_t y1) {
  if (y0 < 0) y0 = 0;
  if (y1 > CROW_CANVAS_H - 1) y1 = CROW_CANVAS_H - 1;
  if (y0 > y1) return;
  portENTER_CRITICAL(&g_dirty_mux);
  if (y0 < g_dirty_y0) g_dirty_y0 = y0;
  if (y1 > g_dirty_y1) g_dirty_y1 = y1;
  portEXIT_CRITICAL(&g_dirty_mux);
}

void crow_mark_dirty() {
  crow_mark_dirty_rows(0, CROW_CANVAS_H - 1);
}

#endif  // CROWPANEL_ADVANCE_7
