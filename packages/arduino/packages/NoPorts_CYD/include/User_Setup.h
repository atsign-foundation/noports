/**
 * @file User_Setup.h
 * @brief TFT_eSPI configuration for CYD boards
 *
 * ESP32  (2432S028R / cyd2usb):  standard CYD SPI pins, XPT2046 resistive touch
 * ESP32-S3 (FNK0104A/B cyd2usb_s3): Freenove display pins, FT6336U capacitive touch
 */

// Display driver
#define ILI9341_DRIVER

#if defined(ESP32S3_2432S028R)
// ── Freenove FNK0104 ESP32-S3 Display pins ──────────────────────────────────
#define TFT_MISO 13
#define TFT_MOSI 11
#define TFT_SCLK 12
#define TFT_CS   10
#define TFT_DC   46
#define TFT_RST  -1
#define TFT_BL   45
#define TFT_BACKLIGHT_ON HIGH
#define TFT_RGB_ORDER TFT_BGR
#define TFT_INVERSION_ON
// Touch: FT6336U capacitive I2C (SDA=16, SCL=15, RST=18, INT=17) — not XPT2046
#define TOUCH_CS -1
#else
// ── Standard CYD (ESP32-2432S028R) HSPI pins ────────────────────────────────
#define TFT_MISO 12
#define TFT_MOSI 13
#define TFT_SCLK 14
#define TFT_CS   15
#define TFT_DC   2
#define TFT_RST  -1  // Connected to ESP32 reset
// Touch controller pins (shared SPI bus)
#define TOUCH_CS 33
#endif

// Display size
#define TFT_WIDTH  240
#define TFT_HEIGHT 320

// Fonts
#define LOAD_GLCD   // Font 1. Original Adafruit 8 pixel font
#define LOAD_FONT2  // Font 2. Small 16 pixel high font
#define LOAD_FONT4  // Font 4. Medium 26 pixel high font
#define LOAD_FONT6  // Font 6. Large 48 pixel font
#define LOAD_FONT7  // Font 7. 7 segment 48 pixel font
#define LOAD_FONT8  // Font 8. Large 75 pixel font
#define LOAD_GFXFF  // FreeFonts

#define SMOOTH_FONT

// SPI frequency
#define SPI_FREQUENCY       40000000
#define SPI_READ_FREQUENCY  16000000
#define SPI_TOUCH_FREQUENCY  2500000
