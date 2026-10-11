// Given daemon @daemon with device name "mydevice": which request a
// notification key from @alice names
#include <sshnpd/daemon.h>
#include <sshnpd/sshnpd.h>
#include <stdio.h>

static int failures = 0;

static void check(bool ok, const char *what) {
  if (!ok) {
    printf("FAIL: %s\n", what);
    failures++;
  } else {
    printf("ok: %s\n", what);
  }
}

static enum notification_key kind_of(const char *key) {
  return sshnpd_notification_kind(key, "@daemon", "mydevice", "@alice");
}

int main(void) {
  check(kind_of("@daemon:ping.mydevice.sshnp@alice") == NK_PING, "a ping key names a ping");
  check(kind_of("@daemon:npt_request.mydevice.sshnp@alice") == NK_NPT_REQUEST, "an npt_request key names one");
  check(kind_of("@daemon:ssh_request.mydevice.sshnp@alice") == NK_SSH_REQUEST, "an ssh_request key names one");
  check(kind_of("@daemon:sshpublickey.mydevice.sshnp@alice") == NK_SSHPUBLICKEY, "an sshpublickey key names one");
  check(kind_of("@daemon:something.mydevice.sshnp@alice") == NK_NONE, "a key naming no request names none");
  check(kind_of("@daemon:ping.otherdevice.sshnp@alice") == NK_NONE, "a key for another device names none");
  check(kind_of("@domain:ping.mydevice.sshnp@alice") == NK_NONE, "a key for another atSign names none");
  check(kind_of("@daemon:.mydevice.sshnp@alice") == NK_NONE, "a key naming nothing names none");
  check(kind_of("@daemon.mydevice.sshnp@alice") == NK_NONE, "a key with no request part names none");
  check(sshnpd_notification_kind("@daemon:ping.mydevice.sshnp@alice", NULL, "mydevice", "@alice") == NK_NONE,
        "a notification with no recipient names none");
#ifndef SSHNPD_ENABLE_TESTING_SHUTDOWN_NOTIFICATION
  check(kind_of("@daemon:graceful_shutdown.mydevice.sshnp@alice") == NK_NONE,
        "a shutdown key names none outside test builds");
#endif
  if (failures > 0) {
    printf("%d check(s) failed\n", failures);
    return 1;
  }
  return 0;
}
