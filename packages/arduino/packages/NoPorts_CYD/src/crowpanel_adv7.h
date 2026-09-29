/**
 * @file crowpanel_adv7.h
 * @brief Elecrow CrowPanel Advance 7.0-HMI (SKU DIS02170A) board support.
 *
 * ESP32-S3-WROOM-1-N16R8, 800x480 IPS on a 16-bit RGB parallel bus, GT911
 * capacitive touch, and an STC8H1K28 companion MCU (I2C 0x30) that owns the
 * backlight and the touch reset line.  Serial console is UART0 via a CH340K.
 *
 * The NoPorts CYD UI is written against TFT_eSPI at a fixed 320x240.  Rather
 * than re-lay-out every screen for 800x480, the UI draws into a 400x240
 * LovyanGFX sprite in PSRAM (CrowCanvas, aliased to TFT_eSPI in ui_tft.h) and
 * a background task pushes it to the panel at 2x (800x480, the whole panel;
 * the CYD screens size themselves from TFT_WIDTH).  Touch is mapped back the same
 * way, so every screen, button and keyboard works unchanged.
 *
 * PSRAM bandwidth is the scarce resource: the RGB panel scans its framebuffer
 * out of PSRAM continuously and any other PSRAM traffic shows up as shimmer.
 * So every draw call records which canvas rows it touched, the flush reads
 * only those rows, and only the ones that actually changed (against a shadow
 * copy) are written to the framebuffer.
 *
 * If the panel still shows an occasional torn frame under heavy WiFi/TLS
 * load, lowering the pixel clock reduces the scan-out's PSRAM demand:
 *   -DCROWPANEL_PCLK_HZ=14000000   (default: 16 MHz on V1.3+, 21 MHz on V1.2)
 *
 * Pin map and companion-MCU protocol are taken verbatim from Elecrow's own
 * LovyanGFX_Driver.h / V1.5 schematic as documented in
 * https://github.com/robominds/Crowpanel-Advance-7.0-HMI-Display
 */
#ifndef CROWPANEL_ADV7_H
#define CROWPANEL_ADV7_H

#ifdef CROWPANEL_ADVANCE_7

#include <Arduino.h>
#include <LovyanGFX.hpp>

// TFT_eSPI text-datum constants live inside namespace lgfx in LovyanGFX.
using lgfx::TL_DATUM; using lgfx::TC_DATUM; using lgfx::TR_DATUM;
using lgfx::ML_DATUM; using lgfx::MC_DATUM; using lgfx::MR_DATUM;
using lgfx::BL_DATUM; using lgfx::BC_DATUM; using lgfx::BR_DATUM;

// Board revision (silkscreen on the back).  Selects the companion-MCU command
// encoding, which INVERTED between V1.2 and V1.3, and the pixel clock.
//   130 = V1.3 / V1.4 / V1.5 (current stock)   120 = V1.2
#ifndef CROWPANEL_ADVANCE_REV
#define CROWPANEL_ADVANCE_REV 130
#endif

// Logical UI canvas (what the CYD screens were designed for) and how it is
// placed on the 800x480 panel.
#define CROW_CANVAS_W   400   // = TFT_WIDTH in ui_tft.h
#define CROW_CANVAS_H   240
#define CROW_SCALE      2
#define CROW_PANEL_W    800
#define CROW_PANEL_H    480
#define CROW_OFFSET_X   ((CROW_PANEL_W - CROW_CANVAS_W * CROW_SCALE) / 2)   // 0
#define CROW_OFFSET_Y   ((CROW_PANEL_H - CROW_CANVAS_H * CROW_SCALE) / 2)   // 0

// Minimal stand-in for XPT2046_Touchscreen's TS_Point, which ui_tft.cpp's
// (unused here) calibration code returns.
void crow_mark_dirty();                              // whole canvas
void crow_mark_dirty_rows(int32_t y0, int32_t y1);   // inclusive row range

struct TS_Point {
  int16_t x = 0, y = 0, z = 0;
  TS_Point() {}
  TS_Point(int16_t x_, int16_t y_, int16_t z_) : x(x_), y(y_), z(z_) {}
};

/**
 * 320x240 off-screen canvas with the handful of TFT_eSPI signatures the CYD UI
 * relies on.  Two things need papering over:
 *   - TFT_eSPI takes font *numbers* (1, 2, 4) in textWidth(); LovyanGFX wants
 *     an IFont*.
 *   - LovyanGFX treats an `int` colour as RGB888.  The CYD palette macros are
 *     plain 0xNNNN literals (RGB565), so every colour-taking call is
 *     re-declared here to force a uint16_t (RGB565) interpretation.
 */
class CrowCanvas : public lgfx::LGFX_Sprite {
 public:
  CrowCanvas() : lgfx::LGFX_Sprite() {}

  // TFT_eSPI compatibility shims
  bool init();                                  // creates the PSRAM sprite
  void setRotation(uint8_t) {}                  // canvas is already landscape
  using lgfx::LGFX_Sprite::textWidth;
  int32_t textWidth(const char *s, uint8_t font) { return lgfx::LGFX_Sprite::textWidth(s, fontFor(font)); }
  int32_t textWidth(const String &s, uint8_t font) { return textWidth(s.c_str(), font); }

  // Text: same overloads as LovyanGFX, plus dirty-row tracking.  The datum
  // can put the glyphs above or below y, so mark one font height either side.
  size_t drawString(const char *s, int32_t x, int32_t y, uint8_t font) { int32_t h = fontHeight(font); crow_mark_dirty_rows(y - h, y + h); return lgfx::LGFX_Sprite::drawString(s, x, y, font); }
  size_t drawString(const char *s, int32_t x, int32_t y)               { int32_t h = fontHeight();     crow_mark_dirty_rows(y - h, y + h); return lgfx::LGFX_Sprite::drawString(s, x, y); }
  size_t drawString(const String &s, int32_t x, int32_t y, uint8_t font) { return drawString(s.c_str(), x, y, font); }
  size_t drawString(const String &s, int32_t x, int32_t y)             { return drawString(s.c_str(), x, y); }

  // RGB565 colour forcing (see class comment) + dirty-row tracking
  void fillScreen(uint32_t c)                                            { crow_mark_dirty(); lgfx::LGFX_Sprite::fillScreen((uint16_t)c); }
  void setTextColor(uint32_t fg)                                         { lgfx::LGFX_Sprite::setTextColor((uint16_t)fg); }
  void setTextColor(uint32_t fg, uint32_t bg)                            { lgfx::LGFX_Sprite::setTextColor((uint16_t)fg, (uint16_t)bg); }
  void fillRect(int32_t x, int32_t y, int32_t w, int32_t h, uint32_t c)  { crow_mark_dirty_rows(y, y + h); lgfx::LGFX_Sprite::fillRect(x, y, w, h, (uint16_t)c); }
  void drawRect(int32_t x, int32_t y, int32_t w, int32_t h, uint32_t c)  { crow_mark_dirty_rows(y, y + h); lgfx::LGFX_Sprite::drawRect(x, y, w, h, (uint16_t)c); }
  void fillRoundRect(int32_t x, int32_t y, int32_t w, int32_t h, int32_t r, uint32_t c) { crow_mark_dirty_rows(y, y + h); lgfx::LGFX_Sprite::fillRoundRect(x, y, w, h, r, (uint16_t)c); }
  void drawRoundRect(int32_t x, int32_t y, int32_t w, int32_t h, int32_t r, uint32_t c) { crow_mark_dirty_rows(y, y + h); lgfx::LGFX_Sprite::drawRoundRect(x, y, w, h, r, (uint16_t)c); }
  void drawLine(int32_t x0, int32_t y0, int32_t x1, int32_t y1, uint32_t c) { crow_mark_dirty_rows(y0 < y1 ? y0 : y1, y0 < y1 ? y1 : y0); lgfx::LGFX_Sprite::drawLine(x0, y0, x1, y1, (uint16_t)c); }
  void fillCircle(int32_t x, int32_t y, int32_t r, uint32_t c)           { crow_mark_dirty_rows(y - r, y + r); lgfx::LGFX_Sprite::fillCircle(x, y, r, (uint16_t)c); }
  void drawCircle(int32_t x, int32_t y, int32_t r, uint32_t c)           { crow_mark_dirty_rows(y - r, y + r); lgfx::LGFX_Sprite::drawCircle(x, y, r, (uint16_t)c); }
  void drawPixel(int32_t x, int32_t y, uint32_t c)                       { crow_mark_dirty_rows(y, y); lgfx::LGFX_Sprite::drawPixel(x, y, (uint16_t)c); }
  void drawFastHLine(int32_t x, int32_t y, int32_t w, uint32_t c)        { crow_mark_dirty_rows(y, y); lgfx::LGFX_Sprite::drawFastHLine(x, y, w, (uint16_t)c); }
  void drawFastVLine(int32_t x, int32_t y, int32_t h, uint32_t c)        { crow_mark_dirty_rows(y, y + h); lgfx::LGFX_Sprite::drawFastVLine(x, y, h, (uint16_t)c); }

  static const lgfx::IFont *fontFor(uint8_t font);
};

/** Bring up panel, canvas, companion MCU, touch and the flush task.  Logs
 *  what it found on Serial.  Returns false only if the panel itself failed. */
bool crow_display_init(CrowCanvas &canvas);

/** Backlight via the companion MCU (there is no backlight GPIO). */
void crow_backlight(bool on);

/** Latest GT911 state mapped to canvas coordinates.  Polls the controller at
 *  most every 20 ms (faster starves the RGB DMA and makes the panel shake).
 *  Returns true while a finger is on the *canvas* area; touches in the black
 *  side bars report false. */
bool crow_touch_read(int16_t *x, int16_t *y);

/** Flag the canvas as changed so the flush task pushes it on its next tick.
 *  Every CrowCanvas draw call does this; only call it yourself if you draw
 *  through a path CrowCanvas does not wrap. */
void crow_mark_dirty();

#endif  // CROWPANEL_ADVANCE_7
#endif  // CROWPANEL_ADV7_H
