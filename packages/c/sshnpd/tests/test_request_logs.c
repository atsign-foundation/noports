// Given the C daemon logging at DEBUG: what it logs for a session request
// carrying a relay-auth key
#include "sshnpd/handle_npt_request.h"
#include "sshnpd/handle_ssh_request.h"
#include "sshnpd/params.h"
#include <atchops/rsa_key.h>
#include <atclient/atclient.h>
#include <atclient/atnotification.h>
#include <atclient/monitor.h>
#include <atlogger/atlogger.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

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

// Hands handler a request from @alice whose decrypted value is value, and
// returns what the daemon logged meanwhile; the caller frees it
static char *log_of_request(request_handler *handler, const char *value) {
  long start = ftell(log_capture);

  sshnpd_params params;
  apply_default_values_to_sshnpd_params(&params);
  atclient atclient;
  atclient_init(&atclient);
  atchops_rsa_key_private_key signing_key;
  atchops_rsa_key_private_key_init(&signing_key);

  atclient_atnotification notification;
  atclient_atnotification_init(&notification);
  atclient_atnotification_set_from(&notification, "@alice");
  atclient_atnotification_set_decrypted_value(&notification, value);
  atclient_monitor_message message;
  atclient_monitor_message_init(&message);
  message.type = ATCLIENT_MONITOR_MESSAGE_TYPE_NOTIFICATION;
  message.notification = &notification;

  bool is_child_process = false;
  handler(&atclient, &params, &is_child_process, &message, signing_key, NULL);

  atclient_atnotification_free(&notification);
  atchops_rsa_key_private_key_free(&signing_key);
  atclient_free(&atclient);

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

// Prints the line of logged around at, after label
static void print_line(const char *label, const char *logged, const char *at) {
  const char *line = at;
  while (line > logged && line[-1] != '\n') {
    line--;
  }
  const char *line_end = strchr(at, '\n');
  printf("%s: %.*s\n", label, (int)(line_end == NULL ? strlen(line) : (size_t)(line_end - line)), line);
}

// Matching either half of the key finds it whole, JSON-encoded or cut short
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

  char *logged = log_of_request(handle_npt_request, NPT_REQUEST);
  check(!holds_key(logged),
        "when it receives an npt request carrying a relay-auth key, then no log line contains the key");
  check(shows_line(logged, "Failed to get public key"), "the npt request reached its signature check");
  free(logged);

  logged = log_of_request(handle_ssh_request, SSH_REQUEST);
  check(!holds_key(logged),
        "when it receives an ssh request carrying a relay-auth key, then no log line contains the key");
  check(shows_line(logged, "Failed to get public key"), "the ssh request reached its signature check");
  free(logged);

  char *cut = strdup(NPT_REQUEST);
  *(strstr(cut, RELAY_AUTH_KEY) + strlen(RELAY_AUTH_KEY) - 4) = '\0';
  logged = log_of_request(handle_npt_request, cut);
  check(!holds_key(logged), "when it receives an npt request cut short partway through its relay-auth key, then no log "
                            "line contains any of the key");
  check(shows_line(logged, "Failed to parse the decrypted notification"), "the cut-short request was read and refused");
  free(logged);
  free(cut);

  fclose(log_capture);
  if (failures > 0) {
    printf("%d check(s) failed\n", failures);
    return 1;
  }
  return 0;
}
