/**
 * @file nvsconfig.h
 * @brief NVS config helpers for NoPorts PoE (no display dependency)
 *
 * Intentionally uses the SAME NVS namespace and keys as NoPorts_CYD so that
 * a device previously enrolled via CYD firmware keeps its configuration when
 * reflashed with the PoE firmware.
 */

#ifndef NVSCONFIG_H
#define NVSCONFIG_H

#include <Arduino.h>
#include <Preferences.h>

// ─── NVS namespace & keys (identical to NoPorts_CYD) ──────────────────────
#define NVS_NAMESPACE         "noports_cyd"
#define NVS_KEY_ATSIGN        "atsign"
#define NVS_KEY_DEVICE        "device_name"
#define NVS_KEY_MANAGER       "manager"       // legacy single-manager key
#define NVS_KEY_MANAGERS      "managers"      // comma-separated list
#define NVS_KEY_PERMITOPEN    "permitopen"    // comma-separated host:port rules
#define NVS_KEY_RULES_MODE    "rules_mode"    // "0" = managers, "1" = policy atSign
#define NVS_KEY_POLICY_AT     "policy_at"
#define NVS_KEY_WORKER_KEEPALIVE "worker_ka"  // minutes (0 = off)
#define NVS_KEY_MAX_RELAYS    "max_relays"
#define NVS_KEY_WEB_LOCAL     "web_local"   // "1" = only accept localhost connections
#define NVS_KEY_LED_MODE      "led_mode"    // "0"=off "1"=heartbeat "2"=status "3"=full
#define NVS_KEY_ROOT          "root_spec"   // root server spec: host[:port] or proxy:host[:port]; "" = root.atsign.org
#define NVS_KEY_CONFIGURED    "configured"
#define NVS_KEY_NTP_GOOD      "ntp_good"    // last known-good NTP epoch (monotonic time floor across reboots)
#define NVS_KEY_WEB_PIN       "web_pin"     // admin PIN gating the web UI; auto-generated initial value on first boot
#define NVS_KEY_WEB_PIN_SET   "web_pin_ok"  // "1" once the operator has set their own PIN (else forced change at first login)

// ─── Filesystem paths ─────────────────────────────────────────────────────
#define ATKEYS_PATH     "/atkeys.json"           // Arduino LittleFS API path
#define ATKEYS_PATH_VFS "/littlefs/atkeys.json"  // C fopen() full VFS path

// ─── App version ──────────────────────────────────────────────────────────
#define POE_APP_VERSION "1.2.1"

// ─── Public API ───────────────────────────────────────────────────────────

/** Open (or reuse) the shared Preferences instance. */
Preferences& nvs_prefs();

/** Read a string value from NVS; returns "" if key not found. */
String nvs_load(const char *key);

/** Write a string value to NVS. */
void   nvs_save(const char *key, const char *value);

/** True if device has been enrolled (atKeys present + configured flag set). */
bool   nvs_is_configured();

/** Set or clear the configured flag. */
void   nvs_set_configured(bool val);

/**
 * Return true when enough config is present to start the daemon.
 * Requires: atsign, device_name, and either (managers + permitopen) or policy_at.
 */
bool   nvs_rules_valid();

/**
 * Parse a comma-separated string into an array of trimmed items.
 * Returns count of items (up to max_items).
 */
int    nvs_parse_csv(const String &input, String *out, int max_items);

/** Format uptime millis as "Xh Ym", "Xm Ys" or "Xs". */
void   nvs_format_uptime(unsigned long ms, char *buf, size_t len);

#endif // NVSCONFIG_H
