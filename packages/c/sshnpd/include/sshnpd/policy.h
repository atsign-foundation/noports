#ifndef SSHNPD_POLICY_H
#define SSHNPD_POLICY_H

#include <atclient/atclient.h>
#include <atclient/monitor.h>
#include <sshnpd/params.h>
#include <stdbool.h>
#include <stdint.h>

// The outcome of one auth check against the policy service
typedef struct {
  bool authorized;
  char **permit_open; // owned; free with policy_decision_free
  size_t permit_open_len;
} sshnpd_policy_decision;

/**
 * @brief Ask the policy service (params->policy) whether client_atsign may
 * connect, and wait for its decision.
 *
 * Sends an NPAAuthCheckRequest rpc notification and reads the monitor until
 * the matching response arrives or 10 seconds pass without progress (an ack
 * from the policy service resets the clock). Fails closed: on timeout, nack,
 * error, send failure or malformed response the decision is unauthorized.
 *
 * Notifications which arrive while waiting and are not the rpc response are
 * logged and dropped, matching the single in-flight check of the other
 * NoPorts daemons.
 *
 * @param worker the authenticated worker atclient (used to notify)
 * @param monitor the monitor atclient (used to read the response)
 * @param params daemon params; params->policy must be non-NULL
 * @param client_atsign the atsign asking to connect
 * @param decision receives the decision; call policy_decision_free after use
 * @return int 0 if a definite decision was reached (including deny),
 * non-zero on internal error (decision is deny in every case)
 */
int policy_auth_check(atclient *worker, atclient *monitor, const sshnpd_params *params, const char *client_atsign,
                      sshnpd_policy_decision *decision);

/**
 * @brief Parse the json value of an rpc response notification into a
 * decision. Exposed for unit testing.
 *
 * @param json the decrypted notification value
 * @param expected_req_id the reqId this daemon sent
 * @param decision filled on a "success" response
 * @param resp_type_out receives the respType string ("ack", "success", ...)
 * @param resp_type_size size of resp_type_out
 * @return int 0 when the value parsed and reqId matched, non-zero otherwise
 */
int policy_parse_response_value(const char *json, int64_t expected_req_id, sshnpd_policy_decision *decision,
                                char *resp_type_out, size_t resp_type_size);

/**
 * @brief Whether the policy decision's permitOpen list permits host:port.
 *
 * Entries are 'host:port' with '*' as a wildcard for either part (a port of
 * 0 also matches anything). An empty list permits nothing.
 */
bool policy_permits_open(const sshnpd_policy_decision *decision, const char *host, uint16_t port);

/**
 * @brief Free a decision's permit_open list and zero the struct. Safe to
 * call on a zeroed struct and safe to call twice.
 */
void policy_decision_free(sshnpd_policy_decision *decision);

/**
 * @brief Send the ping response payload to the policy service as a device
 * heartbeat ('<device>.devices.policy'), at most once every 5 minutes.
 * No-op when no policy service is configured.
 */
void policy_send_heartbeat(atclient *worker, const sshnpd_params *params, const char *ping_response);

#endif
