#ifndef HANDLE_PING_H
#define HANDLE_PING_H
#include "sshnpd/params.h"
#include <atclient/monitor.h>
#include <pthread.h>
void handle_ping(sshnpd_params *params, atclient_monitor_response *message, char *ping_response, atclient *atclient,
                 pthread_mutex_t *atclient_lock);
#endif
