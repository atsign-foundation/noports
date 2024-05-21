#ifndef HANDLE_PING_H
#define HANDLE_PING_H
#include "sshnpd/params.h"
#include <atclient/monitor.h>
void handle_ping(sshnpd_params *params, atclient_monitor_message *message, char *ping_response, atclient *atclient,
                 pthread_mutex_t *atclient_lock);
#endif
