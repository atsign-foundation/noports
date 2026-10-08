#include <atclient/atkey.h>
#include <atlogger/atlogger.h>
#include <sshnpd/client_sessions.h>
#include <sshnpd/client_signing_key.h>
#include <sshnpd/enrollment_signature.h>
#include <sshnpd/handler_commons.h>
#include <sshnpd/public_lookup.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define LOGGER_TAG "CLIENT_SIGNING_KEY"

static const char unsigned_refused[] = "This daemon requires session requests signed with the client's enrollment key";

// Asks this daemon's own atServer for the `_apsk` record uri
static enum public_lookup_result lookup_via_own_atserver(atclient *atclient, const char *uri, char **value) {
  const char *name = uri + strlen("public:");
  const char *namespace_start = strstr(name, ".a.__e@");
  if (namespace_start == NULL) {
    return PUBLIC_LOOKUP_FAILED;
  }
  char *key_name = strndup(name, (size_t)(namespace_start - name));
  if (key_name == NULL) {
    return PUBLIC_LOOKUP_FAILED;
  }
  atclient_atkey atkey;
  atclient_atkey_init(&atkey);
  int res = atclient_atkey_create_public_key(&atkey, key_name, strrchr(uri, '@'), "a.__e");
  free(key_name);
  if (res == 0) {
    res = atclient_get_public_key(atclient, &atkey, value, NULL);
  }
  atclient_atkey_free(&atkey);
  if (res != 0) {
    free(*value);
    *value = NULL;
    return PUBLIC_LOOKUP_FAILED;
  }
  return PUBLIC_LOOKUP_FOUND;
}

// Looks uri up straight from its atServer, or from this daemon's own when
// the record's atServer doesn't serve it over HTTP
static enum public_lookup_result lookup_with_fallback(const char *uri, char **value, void *ctx) {
  enum public_lookup_result result = public_lookup_direct(uri, value);
  if (result != PUBLIC_LOOKUP_NOT_SERVED) {
    return result;
  }
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_INFO,
               "%s is not served over HTTP, so asking this daemon's own atServer for it\n", uri);
  return lookup_via_own_atserver((atclient *)ctx, uri, value);
}

static int refuse(atclient *atclient, sshnpd_params *params, char *requesting_atsign, const char *session_id,
                  const char *why) {
  atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_WARN, "Refusing session %s from %s: %s\n", session_id,
               requesting_atsign, why);
  send_session_error(atclient, params, requesting_atsign, session_id, why);
  return 1;
}

int check_client_signing_key(atclient *atclient, sshnpd_params *params, char *requesting_atsign,
                             const cJSON *envelope, char **signing_key) {
  *signing_key = NULL;
  const char *session_id =
      cJSON_GetStringValue(cJSON_GetObjectItem(cJSON_GetObjectItem(envelope, "payload"), "sessionId"));
  if (session_id == NULL) {
    return 1;
  }
  char message[1024];
  if (client_sessions_is_watched(session_id)) {
    snprintf(message, sizeof(message), "A session with id %s is already live", session_id);
    return refuse(atclient, params, requesting_atsign, session_id, message);
  }
  char why[768];
  enum enrollment_signature_result result =
      verify_enrollment_signature(envelope, requesting_atsign, lookup_with_fallback, atclient, signing_key, why,
                                  sizeof(why));
  switch (result) {
  case ENROLLMENT_SIGNATURE_VERIFIED:
    return 0;
  case ENROLLMENT_SIGNATURE_REFUSED:
    snprintf(message, sizeof(message), "Enrollment signature not verified: %s", why);
    return refuse(atclient, params, requesting_atsign, session_id, message);
  case ENROLLMENT_SIGNATURE_UNCHECKED:
    if (params->require_enrollment_signature) {
      snprintf(message, sizeof(message), "Could not check the enrollment signature: %s", why);
      return refuse(atclient, params, requesting_atsign, session_id, message);
    }
    atlogger_log(LOGGER_TAG, ATLOGGER_LOGGING_LEVEL_WARN,
                 "Could not check the enrollment signature on session %s from %s, so it goes ahead unwatched, as an "
                 "unsigned request would: %s\n",
                 session_id, requesting_atsign, why);
    return 0;
  case ENROLLMENT_SIGNATURE_ABSENT:
    if (params->require_enrollment_signature) {
      return refuse(atclient, params, requesting_atsign, session_id, unsigned_refused);
    }
    return 0;
  }
  return 1;
}
