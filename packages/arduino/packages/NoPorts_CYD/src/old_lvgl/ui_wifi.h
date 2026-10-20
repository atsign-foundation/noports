/**
 * @file ui_wifi.h
 * @brief WiFi setup screen - scan, select, enter password, connect
 */

#ifndef UI_WIFI_H
#define UI_WIFI_H

#include <lvgl.h>

/**
 * @brief Create and show the WiFi setup screen
 *
 * Features:
 *  - Scans for WiFi networks and displays them in a list
 *  - Touch to select a network
 *  - On-screen keyboard for password entry
 *  - Saves credentials to NVS on successful connection
 *
 * @param on_connected Callback invoked when WiFi connects successfully
 */
void ui_wifi_create(void (*on_connected)());

/**
 * @brief Attempt to auto-connect using saved credentials
 * @return true if connection succeeded within timeout
 */
bool ui_wifi_auto_connect(int timeout_ms = 10000);

/**
 * @brief Get the current WiFi IP address as a string
 */
const char* ui_wifi_get_ip();

#endif // UI_WIFI_H
