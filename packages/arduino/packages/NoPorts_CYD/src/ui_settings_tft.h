/**
 * @file ui_settings_tft.h
 * @brief Settings screen for editing managers and permitopen rules
 */

#ifndef UI_SETTINGS_TFT_H
#define UI_SETTINGS_TFT_H

#include <Arduino.h>

/**
 * @brief Create and display the settings screen
 * @param on_save Callback invoked when user saves and exits
 */
void ui_settings_create(void (*on_save)());

/**
 * @brief Update settings screen (animations, cursor blink)
 */
void ui_settings_update();

/**
 * @brief Handle touch input on settings screen
 * @return true if touch was handled
 */
bool ui_settings_handle_touch(int16_t tx, int16_t ty);

#endif // UI_SETTINGS_TFT_H
