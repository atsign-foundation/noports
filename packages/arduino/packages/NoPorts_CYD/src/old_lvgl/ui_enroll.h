/**
 * @file ui_enroll.h
 * @brief APKAM enrollment screen – enrolls the device with the atSign
 *
 * Collects: atSign, device name, OTP, manager atSign.
 * Hardcoded: appName="noports", namespaces="sshnp:rw,sshrvd:rw"
 * Calls atauth_enroll_command() → writes /atkeys.json → persists config in NVS.
 */

#ifndef UI_ENROLL_H
#define UI_ENROLL_H

#include <lvgl.h>

/**
 * @brief Create & display the enrollment screen
 * @param on_enrolled Callback invoked once enrollment succeeds and keys are
 *                    saved to LittleFS. The UI may then transition to the
 *                    dashboard.
 */
void ui_enroll_create(void (*on_enrolled)());

/**
 * @brief Process enrollment events from the FreeRTOS task.
 *        Must be called from the main LVGL loop.
 */
void ui_enroll_process_events();

#endif // UI_ENROLL_H
