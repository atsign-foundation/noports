/**
 * @file lv_conf.h
 * @brief LVGL configuration for NoPorts_CYD
 *
 * Minimal configuration enabling only the widgets and features needed
 * for the NoPorts CYD touchscreen UI.
 */

#if 1 /* Set to "1" to enable content */

#ifndef LV_CONF_H
#define LV_CONF_H

#include <stdint.h>

/*====================
   COLOR SETTINGS
 *====================*/

/* Color depth: 16 (RGB565) required for ILI9341 */
#define LV_COLOR_DEPTH 16

/*====================
   MEMORY SETTINGS
 *====================*/

/* Size of the memory available for `lv_malloc()` in bytes (>= 2kB) */
#define LV_MEM_SIZE (48 * 1024U)

/* Use the standard `malloc` and `free` from C library */
#define LV_MEM_CUSTOM 0

/*====================
   HAL SETTINGS
 *====================*/

/* Default display refresh, input read and animation step period */
#define LV_DEF_REFR_PERIOD  33    /* [ms] */
#define LV_INDEV_DEF_READ_PERIOD 33 /* [ms] */

/*====================
   FEATURE CONFIGURATION
 *====================*/

/*-------------
 * Drawing
 *-----------*/
#define LV_DRAW_SW_SHADOW_CACHE_SIZE 0
#define LV_DRAW_SW_COMPLEX 1

/*-------------
 * GPU
 *-----------*/
#define LV_USE_GPU_STM32_DMA2D 0
#define LV_USE_GPU_SWM341_DMA2D 0
#define LV_USE_GPU_ARM2D 0

/*-------------
 * Logging
 *-----------*/
#define LV_USE_LOG 1
#if LV_USE_LOG
    #define LV_LOG_LEVEL LV_LOG_LEVEL_WARN
    #define LV_LOG_PRINTF 1
#endif

/*-------------
 * Asserts
 *-----------*/
#define LV_USE_ASSERT_NULL          1
#define LV_USE_ASSERT_MALLOC        1
#define LV_USE_ASSERT_STYLE         0
#define LV_USE_ASSERT_MEM_INTEGRITY 0
#define LV_USE_ASSERT_OBJ           0

/*-------------
 * Debug
 *-----------*/
#define LV_USE_PERF_MONITOR 0
#define LV_USE_MEM_MONITOR  0

/*====================
   FONT USAGE
 *====================*/

#define LV_FONT_MONTSERRAT_8  0
#define LV_FONT_MONTSERRAT_10 0
#define LV_FONT_MONTSERRAT_12 1
#define LV_FONT_MONTSERRAT_14 1
#define LV_FONT_MONTSERRAT_16 1
#define LV_FONT_MONTSERRAT_18 0
#define LV_FONT_MONTSERRAT_20 1
#define LV_FONT_MONTSERRAT_22 0
#define LV_FONT_MONTSERRAT_24 0
#define LV_FONT_MONTSERRAT_26 0
#define LV_FONT_MONTSERRAT_28 0
#define LV_FONT_MONTSERRAT_30 0
#define LV_FONT_MONTSERRAT_32 0
#define LV_FONT_MONTSERRAT_34 0
#define LV_FONT_MONTSERRAT_36 0
#define LV_FONT_MONTSERRAT_38 0
#define LV_FONT_MONTSERRAT_40 0
#define LV_FONT_MONTSERRAT_42 0
#define LV_FONT_MONTSERRAT_44 0
#define LV_FONT_MONTSERRAT_46 0
#define LV_FONT_MONTSERRAT_48 0

#define LV_FONT_MONTSERRAT_28_COMPRESSED 0
#define LV_FONT_DEJAVU_16_PERSIAN_HEBREW 0
#define LV_FONT_SIMSUN_16_CJK           0
#define LV_FONT_UNSCII_8                0
#define LV_FONT_UNSCII_16               0

/* Default font */
#define LV_FONT_DEFAULT &lv_font_montserrat_14

/* Enable FreeType or Tiny TTF */
#define LV_USE_FREETYPE 0
#define LV_USE_TINY_TTF 0

/*====================
   TEXT SETTINGS
 *====================*/

#define LV_TXT_ENC LV_TXT_ENC_UTF8
#define LV_TXT_BREAK_CHARS " ,.;:-_)]}\\/!?#%&@"
#define LV_TXT_LINE_BREAK_LONG_LEN 0
#define LV_TXT_COLOR_CMD "#"

/*====================
   WIDGETS
 *====================*/

/* Core widgets - all needed for our UI */
#define LV_USE_ARC        1
#define LV_USE_BAR        1
#define LV_USE_BTN        1
#define LV_USE_BTNMATRIX  1
#define LV_USE_CANVAS     0
#define LV_USE_CHECKBOX   1
#define LV_USE_DROPDOWN   1
#define LV_USE_IMAGE      1
#define LV_USE_LABEL      1
#define LV_USE_LINE       1
#define LV_USE_ROLLER     0
#define LV_USE_SCALE      0
#define LV_USE_SLIDER     1
#define LV_USE_SWITCH     1
#define LV_USE_TEXTAREA   1
#define LV_USE_TABLE      1

/* Extra widgets */
#define LV_USE_ANIMIMG    0
#define LV_USE_CALENDAR   0
#define LV_USE_CHART      0
#define LV_USE_COLORWHEEL 0
#define LV_USE_IMGBTN     0
#define LV_USE_KEYBOARD   1
#define LV_USE_LED        1
#define LV_USE_LIST       1
#define LV_USE_MENU       0
#define LV_USE_METER      0
#define LV_USE_MSGBOX     1
#define LV_USE_SPAN       0
#define LV_USE_SPINBOX    0
#define LV_USE_SPINNER    1
#define LV_USE_TABVIEW    1
#define LV_USE_TILEVIEW   0
#define LV_USE_WIN        0

/*====================
   LAYOUTS
 *====================*/

#define LV_USE_FLEX 1
#define LV_USE_GRID 1

/*====================
   LIBS
 *====================*/

#define LV_USE_FS_STDIO    0
#define LV_USE_FS_POSIX    0
#define LV_USE_FS_WIN32    0
#define LV_USE_FS_FATFS    0
#define LV_USE_FS_LITTLEFS 0
#define LV_USE_LODEPNG     0
#define LV_USE_LIBPNG      0
#define LV_USE_BMP         0
#define LV_USE_TJPGD       0
#define LV_USE_LIBJPEG_TURBO 0
#define LV_USE_GIF         0
#define LV_USE_QRCODE      0
#define LV_USE_BARCODE     0
#define LV_USE_FREETYPE    0
#define LV_USE_RLOTTIE     0
#define LV_USE_FFMPEG      0
#define LV_USE_SNAPSHOT     0
#define LV_USE_MONKEY       0
#define LV_USE_GRIDNAV      0
#define LV_USE_FRAGMENT     0
#define LV_USE_OBSERVER     1
#define LV_USE_IME_PINYIN   0
#define LV_USE_VECTOR_GRAPHIC 0

/*====================
   OTHERS
 *====================*/

#define LV_USE_OBJ_PROPERTY 0

#define LV_BUILD_EXAMPLES 0

#endif /* LV_CONF_H */

#endif /* Enable content */
