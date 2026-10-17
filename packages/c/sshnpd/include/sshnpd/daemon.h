#ifndef SSHNPD_DAEMON_H
#define SSHNPD_DAEMON_H

#ifdef __cplusplus
extern "C" {
#endif

#include "atclient/atclient.h"
#include "atclient/monitor.h"
#include "sshnpd/params.h"
#include "sshnpd/policy.h"
#include "sshnpd/policy_limits.h"
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

/**
 * @brief The main loop's count of quiet monitor reads after a read that
 * returned read_ret with a message of the given type: reset by a
 * notification, a data or error response, or a notification that couldn't be
 * decrypted; one more after an empty read; MONITOR_RECONNECT_COUNTER after
 * any other failed read.
 */
size_t sshnpd_next_timeout_counter(int read_ret, enum atclient_monitor_message_type type, size_t counter);

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

/**
 * @brief Handles a notification the monitor read: checks its sender, then
 * runs the handler for the request it names, deciding with the policy
 * service through decisions, checked_senders and policy_decision when one is
 * configured. Returns true in a child process forked to run a session, which
 * must leave the main loop.
 */
bool sshnpd_handle_notification(atclient_monitor_message *message, policy_cache *decisions,
                                policy_throttle *checked_senders, sshnpd_policy_decision *policy_decision);

// Main daemon loop
void main_loop();

#ifdef __cplusplus
}
#endif
#endif
