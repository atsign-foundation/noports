/**
 * @file ui_calibrate.h
 * @brief 3-point touch calibration screen
 *
 * Shows crosshair targets at three corners of the display.
 * The user taps each one, and calibration data is computed
 * via smartdisplay_compute_touch_calibration() and saved to NVS.
 */

#ifndef UI_CALIBRATE_H
#define UI_CALIBRATE_H

/**
 * @brief Try to load saved calibration from NVS.
 * @return true if valid calibration was loaded and applied.
 */
bool ui_calibrate_load();

/**
 * @brief Show the calibration screen. Calls on_done() when finished.
 */
void ui_calibrate_create(void (*on_done)());

#endif // UI_CALIBRATE_H
