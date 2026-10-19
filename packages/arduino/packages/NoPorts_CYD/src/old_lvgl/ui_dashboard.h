/**
 * @file ui_dashboard.h
 * @brief Live status dashboard screen
 *
 * Shows:
 *  - Header: atSign, device name, IP address
 *  - Stats: daemon state, active relay count, uptime
 *  - Connection log: scrollable list fed by the UiEvent queue
 *  - RGB LED colour picker
 */

#ifndef UI_DASHBOARD_H
#define UI_DASHBOARD_H

#include <lvgl.h>

/**
 * @brief Create & display the dashboard screen
 */
void ui_dashboard_create();

/**
 * @brief Call from the main loop to process queued events and refresh stats
 * @param active_relays  Current number of active relay tunnels
 * @param daemon_state   Human-readable daemon state string
 */
void ui_dashboard_update(int active_relays, const char *daemon_state);

#endif // UI_DASHBOARD_H
