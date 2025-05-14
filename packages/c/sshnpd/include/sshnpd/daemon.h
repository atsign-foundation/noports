#ifndef SSHNPD_DAEMON_H
#define SSHNPD_DAEMON_H

#ifdef __cplusplus
extern "C" {
#endif

#include "atclient/atclient.h"
#include "sshnpd/params.h"
#include "sshnpd/sshnpd.h"
#include <signal.h>

// Global state of the main daemon process
extern struct _notification_key_map {
  char *str;
  enum notification_key key;
} notification_key_map[];

extern atclient worker;
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
