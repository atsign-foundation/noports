/**
 * @file ui_enroll_tft.h
 * @brief APKAM enrollment screen using TFT_eSPI
 */

#ifndef UI_ENROLL_TFT_H
#define UI_ENROLL_TFT_H

#include <Arduino.h>

/**
 * @brief Create and display the enrollment screen
 * @param on_enrolled Callback invoked once enrollment succeeds
 */
void ui_enroll_create(void (*on_enrolled)());

/**
 * @brief Update enrollment UI (process events, show progress)
 * Call this from the main loop while on enrollment screen
 */
void ui_enroll_update();

/**
 * @brief Handle touch input on enrollment screen
 * @return true if touch was handled
 */
bool ui_enroll_handle_touch(int16_t tx, int16_t ty);

/**
 * @brief Process enrollment events from background task
 * Must be called from main loop
 */
void ui_enroll_process_events();

#endif // UI_ENROLL_TFT_H
