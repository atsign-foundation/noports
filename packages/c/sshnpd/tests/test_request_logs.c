// Goal: no relay-auth key, socket key or IV, or whole request reaches a log line. Non-goals: hiding other error
// detail, and sanitising a third-party component's own error text.
#include "sshnpd/daemon.h"
#include "sshnpd/handle_npt_request.h"
#include "sshnpd/handle_ssh_request.h"
#include "sshnpd/params.h"
#include "sshnpd/policy.h"
#include "sshnpd/policy_limits.h"
#include <atchops/rsa_key.h>
#include <atclient/atclient.h>
#include <atclient/atnotification.h>
#include <atclient/monitor.h>
#include <atlogger/atlogger.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define SCENARIO                                                                                                       \
  "Given the C daemon logging at DEBUG, when it receives an npt or ssh request carrying a relay-auth key, whole or "   \
  "cut short partway through it, then no log line contains any of the key."
#define RELAY_AUTH_KEY "cmVsYXktYXV0aC1rZXktZm9yLWxvZy1jaGVja3MhIQ=="
#define SESSION_ID "9e13521b-9ad0-4237-9104-5824e6e6c483"
#define ENVELOPE_TAIL "},\"signature\":\"c2lnbmF0dXJl\",\"hashingAlgo\":\"sha256\",\"signingAlgo\":\"rsa2048\"}"

static const char *NPT_REQUEST =
    "{\"payload\":{\"sessionId\":\"" SESSION_ID "\",\"rvdHost\":\"127.0.0.1\",\"rvdPort\":1,"
    "\"requestedHost\":\"127.0.0.1\",\"requestedPort\":22,\"authenticateToRvd\":true,"
    "\"relayAuthMode\":\"escr\",\"relayAuthAesKey\":\"" RELAY_AUTH_KEY "\",\"clientNonce\":\"client-nonce\","
    "\"rvdNonce\":\"rvd-nonce\",\"encryptRvdTraffic\":false" ENVELOPE_TAIL;

static const char *SSH_REQUEST =
    "{\"payload\":{\"direct\":true,\"sessionId\":\"" SESSION_ID "\",\"host\":\"127.0.0.1\",\"port\":1,"
    "\"authenticateToRvd\":true,\"relayAuthMode\":\"escr\",\"relayAuthAesKey\":\"" RELAY_AUTH_KEY "\","
    "\"clientNonce\":\"client-nonce\",\"rvdNonce\":\"rvd-nonce\",\"encryptRvdTraffic\":false" ENVELOPE_TAIL;

typedef void request_handler(atclient *atclient, sshnpd_params *params, bool *is_child_process,
                             atclient_monitor_message *message, atchops_rsa_key_private_key signing_key,
                             const sshnpd_policy_decision *policy);

static int failures = 0;
static FILE *log_capture;

static void check(bool ok, const char *what) {
  if (!ok) {
    printf("FAIL: %s\n", what);
    failures++;
  } else {
    printf("ok: %s\n", what);
  }
}

// What the daemon logged since start; the caller frees it
static char *logged_since(long start) {
  fflush(log_capture);
  long end = ftell(log_capture);
  char *logged = calloc(end - start + 1, 1);
  fseek(log_capture, start, SEEK_SET);
  if (fread(logged, 1, end - start, log_capture) != (size_t)(end - start)) {
    logged[0] = '\0';
  }
  fseek(log_capture, end, SEEK_SET);
  return logged;
}

// A notification from @alice whose decrypted value is value
static void notification_from_alice(atclient_atnotification *notification, atclient_monitor_message *message,
                                    const char *value) {
  atclient_atnotification_init(notification);
  atclient_atnotification_set_from(notification, "@alice");
  atclient_atnotification_set_decrypted_value(notification, value);
  atclient_monitor_message_init(message);
  message->type = ATCLIENT_MONITOR_MESSAGE_TYPE_NOTIFICATION;
  message->notification = notification;
}

// Hands handler a request from @alice whose decrypted value is value, and
// returns what the daemon logged meanwhile; the caller frees it
static char *log_of_request(request_handler *handler, const char *value) {
  long start = ftell(log_capture);

  sshnpd_params request_params;
  apply_default_values_to_sshnpd_params(&request_params);
  atclient atclient;
  atclient_init(&atclient);
  atchops_rsa_key_private_key signing_key;
  atchops_rsa_key_private_key_init(&signing_key);

  atclient_atnotification notification;
  atclient_monitor_message message;
  notification_from_alice(&notification, &message, value);

  bool is_child_process = false;
  handler(&atclient, &request_params, &is_child_process, &message, signing_key, NULL);

  atclient_atnotification_free(&notification);
  atchops_rsa_key_private_key_free(&signing_key);
  atclient_free(&atclient);
  return logged_since(start);
}

// Hands the daemon's notification handling an npt request from @alice to
// @daemon, with @alice a manager when alice_manages and the notification
// carrying an id when with_id, and returns what the daemon logged meanwhile;
// the caller frees it
static char *log_of_notification(const char *value, bool alice_manages, bool with_id) {
  long start = ftell(log_capture);

  apply_default_values_to_sshnpd_params(&params);
  params.device = "mydevice";
  char *managers[] = {"@alice"};
  if (alice_manages) {
    params.manager_list = managers;
    params.manager_list_len = 1;
  }
  should_run = 1;
  atclient_init(&worker);
  policy_cache decisions;
  policy_cache_init(&decisions, 0);
  policy_throttle checked_senders;
  policy_throttle_init(&checked_senders);
  sshnpd_policy_decision decision;
  memset(&decision, 0, sizeof(decision));

  atclient_atnotification notification;
  atclient_monitor_message message;
  notification_from_alice(&notification, &message, value);
  if (with_id) {
    atclient_atnotification_set_id(&notification, "notification-id");
  }
  atclient_atnotification_set_to(&notification, "@daemon");
  atclient_atnotification_set_key(&notification, "@daemon:npt_request.mydevice.sshnp@alice");

  sshnpd_handle_notification(&message, &decisions, &checked_senders, &decision);

  atclient_atnotification_free(&notification);
  atclient_free(&worker);
  policy_decision_free(&decision);
  policy_cache_free(&decisions);
  return logged_since(start);
}

// Prints the line of logged around at, after label
static void print_line(const char *label, const char *logged, const char *at) {
  const char *line = at;
  while (line > logged && line[-1] != '\n') {
    line--;
  }
  const char *line_end = strchr(at, '\n');
  printf("%s: %.*s\n", label, (int)(line_end == NULL ? strlen(line) : (size_t)(line_end - line)), line);
}

// NOTE matching either half finds the key whole or JSON-encoded, or cut short where the cut keeps at least half of it
static bool holds_key(const char *logged) {
  const char *key = RELAY_AUTH_KEY;
  const size_t half = strlen(key) / 2;
  char first[64] = {0};
  memcpy(first, key, half);
  const char *at = strstr(logged, first);
  if (at == NULL) {
    at = strstr(logged, key + half);
  }
  if (at != NULL) {
    print_line("holds the key", logged, at);
  }
  return at != NULL;
}

// Whether a line of logged holds expected, printing it so a run shows what
// matched
static bool shows_line(const char *logged, const char *expected) {
  const char *at = strstr(logged, expected);
  if (at == NULL) {
    printf("no line holds \"%s\" in:\n%s\n", expected, logged);
    return false;
  }
  print_line("matched", logged, at);
  return true;
}

int main(void) {
  log_capture = tmpfile();
  if (log_capture == NULL) {
    printf("could not open a file to capture the log\n");
    return 1;
  }
  atlogger_set_logging_stream(log_capture);
  atlogger_set_logging_level(ATLOGGER_LOGGING_LEVEL_DEBUG);

  printf("%s\n", SCENARIO);

  char *logged = log_of_notification(NPT_REQUEST, false, true);
  check(!holds_key(logged), "case: the daemon's notification handling, given an npt request");
  check(shows_line(logged, "Rejecting request from unauthorized atSign: @alice"),
        "reach: the daemon read the notification and checked its sender");
  free(logged);

  logged = log_of_notification(NPT_REQUEST, true, true);
  check(!holds_key(logged), "case: the daemon's notification handling, given a manager's npt request");
  check(shows_line(logged, "Executing handle_npt_request"), "reach: the daemon handed the npt request to its handler");
  check(shows_line(logged, "Failed to get public key"), "reach: the handler reached the request's signature check");
  free(logged);

  logged = log_of_notification(NPT_REQUEST, true, false);
  check(!holds_key(logged), "case: the daemon's notification handling, given a manager's npt request with no id");
  check(shows_line(logged, "Notification received: @daemon:npt_request.mydevice.sshnp@alice"),
        "reach: the daemon read the notification");
  check(strstr(logged, "Executing handle_npt_request") == NULL, "reach: the daemon handed nothing to a handler");
  free(logged);

  logged = log_of_request(handle_npt_request, NPT_REQUEST);
  check(!holds_key(logged), "case: the npt request handler, given an npt request");
  check(shows_line(logged, "Failed to get public key"), "reach: the npt request reached its signature check");
  free(logged);

  logged = log_of_request(handle_ssh_request, SSH_REQUEST);
  check(!holds_key(logged), "case: the ssh request handler, given an ssh request");
  check(shows_line(logged, "Failed to get public key"), "reach: the ssh request reached its signature check");
  free(logged);

  char *cut = strdup(NPT_REQUEST);
  *(strstr(cut, RELAY_AUTH_KEY) + strlen(RELAY_AUTH_KEY) - 4) = '\0';
  logged = log_of_request(handle_npt_request, cut);
  check(!holds_key(logged), "case: the npt request handler, given an npt request cut short partway through its key");
  check(shows_line(logged, "Failed to parse the decrypted notification"),
        "reach: the cut-short request was read and refused");
  free(logged);
  free(cut);

  fclose(log_capture);
  if (failures > 0) {
    printf("%d check(s) failed\n", failures);
    return 1;
  }
  return 0;
}
