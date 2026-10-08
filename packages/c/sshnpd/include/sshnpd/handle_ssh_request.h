#ifndef HANDLE_SSH_REQUEST_H
#define HANDLE_SSH_REQUEST_H
#include "sshnpd/params.h"
#include "sshnpd/policy.h"
#include <atclient/monitor.h>

// policy is the policy service's decision for this request, or NULL when the
// requester was approved without a policy check (manager atsign, or no
// policy service configured)
void handle_ssh_request(atclient *atclient, sshnpd_params *params, bool *is_child_process,
                        atclient_monitor_message *message, atchops_rsa_key_private_key signing_key,
                        const sshnpd_policy_decision *policy);

#endif
