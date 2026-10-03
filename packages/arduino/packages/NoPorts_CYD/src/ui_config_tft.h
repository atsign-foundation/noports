/**
 * @file ui_config_tft.h
 * @brief Device configuration screen (worker keep-alive and relay settings)
 */

#ifndef UI_CONFIG_TFT_H
#define UI_CONFIG_TFT_H

#include <Arduino.h>

/**
 * @brief Show the config screen.
 * @param on_save Called after user presses SAVE (settings written to NVS).
 */
void ui_config_create(void (*on_save)());

/**
 * @brief Handle touch input on the config screen.
 * @return true if touch was consumed.
 */
bool ui_config_handle_touch(int16_t tx, int16_t ty);

/**
 * @brief Per-loop update (no-op for now; reserved for future animation).
 */
void ui_config_update();

#endif // UI_CONFIG_TFT_H
