#ifndef SSHNPD_DAEMON_H
#define SSHNPD_DAEMON_H

#ifdef __cplusplus
extern "C" {
#endif

#include "atclient/atclient.h"
#include "atclient/monitor.h"
#include "sshnpd/params.h"
#include "sshnpd/sshnpd.h"
#include <signal.h>

// Global state of the main daemon process
extern struct _notification_key_map {
  char *str;
  enum notification_key key;
} notification_key_map[];

extern atclient_authenticate_options worker_options;
extern atclient worker;
extern atclient_authenticate_options monitor_options;
extern atclient monitor_ctx;
extern char *ping_response;
extern char *atserver_host;
extern uint16_t atserver_port;
extern atclient_atkeys atkeys;
extern sshnpd_params params;
extern char *regex;
extern FILE *authkeys_file;
extern char *authkeys_filename;
extern char *home_dir;
extern atchops_rsa_key_private_key signingkey;
extern bool is_child_process;

extern volatile sig_atomic_t should_run;

// device info
extern size_t device_info_pos;
extern time_t *device_info_last_sent;
extern uint8_t device_info_attempts;

#define MONITOR_READ_TIMEOUT_MS 5000
#define MONITOR_NOOP_TIMEOUT_MS 40000

// A count of quiet monitor reads high enough to make the main loop reconnect
#define MONITOR_RECONNECT_COUNTER (MONITOR_NOOP_TIMEOUT_MS / MONITOR_READ_TIMEOUT_MS + 1)

// The longest pause between monitor reconnect attempts. The main loop keeps
// running its other duties (reaping session children, answering the policy
// service) each second through the pause, so it need not be short.
#define MONITOR_RECONNECT_MAX_DELAY_S 30

/**
 * @brief The main loop's count of quiet monitor reads after a read that
 * returned read_ret with a message of the given type: reset by a
 * notification, a data or error response, or a notification that couldn't be
 * decrypted; one more after an empty read; MONITOR_RECONNECT_COUNTER after
 * any other failed read.
 */
size_t sshnpd_next_timeout_counter(int read_ret, enum atclient_monitor_message_type type, size_t counter);

/**
 * @brief Seconds to pause before the next monitor reconnect attempt,
 * `attempts` having been made since the monitor last delivered anything:
 * none before the first, 1 after it, doubling with each, up to
 * MONITOR_RECONNECT_MAX_DELAY_S. An attempt counts whether or not its
 * handshake succeeded, so an atServer that accepts the connection and drops
 * it at once is backed off from like one that refuses it.
 */
unsigned sshnpd_reconnect_delay_s(unsigned attempts);

/**
 * @brief Whether the pause after the last monitor reconnect attempt has
 * passed at now_ms (sshnpd_monotonic_ms), so another may be made.
 */
bool monitor_reconnect_due(long now_ms);

/**
 * @brief The monitor delivered something (any read that didn't fail): the
 * reconnect attempts so far are forgotten, so the next outage starts over.
 */
void monitor_connection_alive(void);

/**
 * @brief The request a notification key names: the text between "<to>:" and
 * ".<device>.sshnp<from>", matched against notification_key_map; NK_NONE when
 * the key isn't shaped that way or names no request this daemon handles.
 */
enum notification_key sshnpd_notification_kind(const char *key, const char *to, const char *device, const char *from);

// Utility functions that act on global state
int lock_atclient(void);
int unlock_atclient(int);
int reconnect_atclient();
int reconnect_monitor();
void free_atclient_without_disconnect(atclient *atclient);
int set_worker_hooks();

// Main daemon loop
void main_loop();

#ifdef __cplusplus
}
#endif
#endif
