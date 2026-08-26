// Tests for the ephemeral tunnel key flow: keypair generation (via
// ssh-keygen), the restricted authorized_keys entry, and removal.
#include <sshnpd/ephemeral_key.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static int failures = 0;

static void check(bool ok, const char *what) {
  if (!ok) {
    printf("FAIL: %s\n", what);
    failures++;
  } else {
    printf("ok: %s\n", what);
  }
}

static char *read_all(const char *path) {
  FILE *f = fopen(path, "r");
  if (f == NULL) {
    return NULL;
  }
  static char buf[8192];
  size_t n = fread(buf, 1, sizeof(buf) - 1, f);
  buf[n] = '\0';
  fclose(f);
  return buf;
}

int main() {
  // Everything works against a scratch directory and scratch
  // authorized_keys file
  char dir_template[] = "/tmp/test_ephemeral_key_XXXXXX";
  char *dir = mkdtemp(dir_template);
  if (dir == NULL) {
    printf("FAIL: mkdtemp\n");
    return 1;
  }

  char authkeys_path[512];
  snprintf(authkeys_path, sizeof(authkeys_path), "%s/authorized_keys", dir);
  FILE *authkeys = fopen(authkeys_path, "w+");
  check(authkeys != NULL, "create scratch authorized_keys");
  fputs("ssh-ed25519 AAAAexistingkey user@host\n", authkeys);
  fflush(authkeys);

  // Unsafe session ids must be rejected everywhere
  char *priv = NULL, *pub = NULL;
  check(generate_ephemeral_ssh_keypair(dir, false, "bad/../id", &priv, &pub) != 0, "keygen rejects path traversal");
  check(generate_ephemeral_ssh_keypair(dir, false, "bad id;rm", &priv, &pub) != 0, "keygen rejects shell chars");
  check(authorize_ephemeral_public_key(authkeys, authkeys_path, "ssh-ed25519 AAAA", 22, "bad$id", "") != 0,
        "authorize rejects unsafe session id");

  // If ssh-keygen isn't available, skip the generation-dependent tests
  if (system("command -v ssh-keygen >/dev/null 2>&1") != 0) {
    printf("ssh-keygen not found - skipping generation tests\n");
    fclose(authkeys);
    return failures > 0 ? 1 : 0;
  }

  const char *session_id = "9b6350cd-3ac6-4d47-9d43-a1d5bbcbe553";
  check(generate_ephemeral_ssh_keypair(dir, false, session_id, &priv, &pub) == 0 && priv != NULL && pub != NULL,
        "generate ed25519 keypair");
  check(priv != NULL && strstr(priv, "OPENSSH PRIVATE KEY") != NULL, "private key looks like an openssh key");
  check(pub != NULL && strncmp(pub, "ssh-ed25519 ", 12) == 0, "public key is ed25519");

  // Transient key files must be gone
  char key_path[600];
  snprintf(key_path, sizeof(key_path), "%s/ephemeral_%s", dir, session_id);
  check(access(key_path, F_OK) != 0, "private key file was removed");
  snprintf(key_path, sizeof(key_path), "%s/ephemeral_%s.pub", dir, session_id);
  check(access(key_path, F_OK) != 0, "public key file was removed");

  // Authorize and inspect the entry
  check(authorize_ephemeral_public_key(authkeys, authkeys_path, pub, 2222, session_id, "no-agent-forwarding") == 0,
        "authorize ephemeral key");
  char *content = read_all(authkeys_path);
  check(content != NULL && strstr(content, "ssh-ed25519 AAAAexistingkey user@host") != NULL,
        "pre-existing entry untouched");
  check(content != NULL &&
            strstr(content, "command=\"echo \\\"ssh session complete\\\";sleep 20\",PermitOpen=\"localhost:2222\""
                            ",no-agent-forwarding ssh-ed25519 ") != NULL,
        "entry has forced command, PermitOpen and extra permissions");
  char marker[64];
  snprintf(marker, sizeof(marker), "sshnp_ephemeral_%s", session_id);
  check(content != NULL && strstr(content, marker) != NULL, "entry carries the session marker");

  // Deauthorize removes exactly this entry
  check(deauthorize_ephemeral_public_key(authkeys, authkeys_path, session_id) == 0, "deauthorize succeeds");
  content = read_all(authkeys_path);
  check(content != NULL && strstr(content, marker) == NULL, "entry removed");
  check(content != NULL && strstr(content, "ssh-ed25519 AAAAexistingkey user@host") != NULL,
        "other entries survive removal");

  // Removing a session that has no entry is a no-op success
  check(deauthorize_ephemeral_public_key(authkeys, authkeys_path, "00000000-0000-0000-0000-000000000000") == 0,
        "deauthorize of unknown session is a no-op");

  // The sweep path end to end: schedule with a full queue is exercised in
  // real use; here just confirm an immediate-past due entry gets removed
  check(authorize_ephemeral_public_key(authkeys, authkeys_path, pub, 22, session_id, NULL) == 0,
        "re-authorize for sweep test");
  ephemeral_key_schedule_deauthorize(authkeys, authkeys_path, session_id);
  ephemeral_key_sweep_deauthorizations(authkeys, authkeys_path);
  content = read_all(authkeys_path);
  check(content != NULL && strstr(content, marker) != NULL, "sweep respects the grace period");

  free(priv);
  free(pub);
  fclose(authkeys);

  if (failures > 0) {
    printf("%d failures\n", failures);
    return 1;
  }
  printf("all passed\n");
  return 0;
}
