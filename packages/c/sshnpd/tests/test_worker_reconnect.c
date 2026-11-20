// Given a running daemon whose worker connection the atServer has dropped:
// how the daemon gets the worker back, in particular after a reconnect that
// fails part-way through authenticating. With the atsdk before at_c v0.4.3
// it never did: the failed reconnect left the connection open, still to be
// sent the reply it had stopped waiting for, and took the reconnect hook off
// (#3122).
//
// The atsdk and the daemon's reconnect code run for real. Only the TLS socket
// is replaced, by the scripted atServer below: this file defines every
// function of the atsdk's socket_mbedtls.c, so the linker never pulls that
// object out of libatclient.a.
#include "test_keys.h"
#include <atchops/aes.h>
#include <atchops/base64.h>
#include <atchops/rsa.h>
#include <atchops/rsa_key.h>
#include <atclient/atclient.h>
#include <atclient/atkey.h>
#include <atclient/atkeys.h>
#include <atclient/connection_hooks.h>
#include <atclient/socket.h>
#include <atlogger/atlogger.h>
#include <mbedtls/net_sockets.h>
#include <sshnpd/daemon.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// ---------------------------------------------------------------------------
// The scripted atServer
// ---------------------------------------------------------------------------

#define PROMPT_ANON "@"
#define PROMPT_AUTHED "@alice@"

static struct {
  char rx[4096]; // sent by the atServer, not yet read by the daemon
  size_t rx_len;
  char late[1024]; // a reply still on its way: lands once a read has timed out
  bool authenticated;
  bool reset;     // the atServer dropped this connection while it sat idle
  bool slow_pkam; // the atServer takes longer than the read timeout to answer the next pkam:
  int connects;
  int updates_stored;
} srv;

// "data:<the shared key, RSA encrypted, base64>" as llookup:shared_key answers
static char shared_key_reply[512];

static void srv_reply(const char *line, bool is_late) {
  char *dst = is_late ? srv.late : srv.rx + srv.rx_len;
  size_t room = is_late ? sizeof(srv.late) : sizeof(srv.rx) - srv.rx_len;
  const char *prompt = srv.authenticated ? PROMPT_AUTHED : PROMPT_ANON;
  int n = snprintf(dst, room, "%s\n%s", line, prompt);
  if (!is_late) {
    srv.rx_len += (size_t)n;
  }
}

void atclient_tls_socket_init(struct atclient_tls_socket *socket) { (void)socket; }
void atclient_tls_socket_free(struct atclient_tls_socket *socket) { (void)socket; }
void atclient_tls_socket_set_read_timeout(struct atclient_tls_socket *socket, const int timeout_ms) {
  (void)socket;
  (void)timeout_ms;
}
int atclient_tls_socket_configure(struct atclient_tls_socket *socket, unsigned char *ca_pem, size_t ca_pem_len) {
  (void)socket;
  (void)ca_pem;
  (void)ca_pem_len;
  return 0;
}
int atclient_tls_socket_disconnect(struct atclient_tls_socket *socket) {
  (void)socket;
  return 0;
}

// A new connection: nothing the old one was owed arrives on it
int atclient_tls_socket_connect(struct atclient_tls_socket *socket, const char *host, const uint16_t port) {
  (void)socket;
  (void)host;
  (void)port;
  srv.connects++;
  srv.authenticated = false;
  srv.reset = false;
  srv.late[0] = '\0';
  srv.rx_len = 0;
  memcpy(srv.rx, PROMPT_ANON, strlen(PROMPT_ANON));
  srv.rx_len = strlen(PROMPT_ANON);
  return 0;
}

int atclient_tls_socket_write(struct atclient_tls_socket *socket, const unsigned char *value, size_t value_len) {
  (void)socket;
  const char *cmd = (const char *)value;
  if (srv.reset) {
    return 0; // the write goes out; the RST comes back on the read
  }
#define IS(verb) (value_len >= strlen(verb) && strncmp(cmd, verb, strlen(verb)) == 0)
  if (IS("from:")) {
    srv_reply("data:_3d9a0be1-fd4b-4b46-ae5d-39af4a5cd3d8@alice:f7c1b1c0-3c1b-4f0a-9d2e-2f4b9c2d7e11", false);
  } else if (IS("pkam:")) {
    srv.authenticated = true;
    srv_reply("data:success", srv.slow_pkam);
    srv.slow_pkam = false;
  } else if (IS("noop:")) {
    srv_reply("data:ok", false);
  } else if (!srv.authenticated) {
    srv_reply("error:AT0401-Exception: Command cannot be executed without auth", false);
  } else if (IS("llookup:shared_key.")) {
    srv_reply(shared_key_reply, false);
  } else if (IS("update:")) {
    srv.updates_stored++;
    srv_reply("data:42", false);
  } else {
    srv_reply("error:AT0003-Invalid syntax", false);
  }
#undef IS
  return 0;
}

int atclient_tls_socket_read(struct atclient_tls_socket *socket, unsigned char **value, size_t *value_len,
                             const struct atclient_socket_read_options options) {
  (void)socket;
  char *end = memchr(srv.rx, options.until_char, srv.rx_len);
  if (end == NULL) {
    if (srv.reset) {
      atlogger_log("atclient_socket_mbedtls", ATLOGGER_LOGGING_LEVEL_ERROR, "NET - Connection was reset by peer\n");
      return MBEDTLS_ERR_NET_CONN_RESET;
    }
    // Nothing arrived within the read timeout. A reply that was on its way
    // lands after the daemon has given up on it.
    if (srv.late[0] != '\0') {
      size_t n = strlen(srv.late);
      memcpy(srv.rx + srv.rx_len, srv.late, n);
      srv.rx_len += n;
      srv.late[0] = '\0';
    }
    return ATCLIENT_SSL_TIMEOUT_EXITCODE;
  }
  size_t n = (size_t)(end - srv.rx) + 1;
  if (value != NULL) {
    *value = malloc(n);
    memcpy(*value, srv.rx, n);
  }
  if (value_len != NULL) {
    *value_len = n;
  }
  memmove(srv.rx, srv.rx + n, srv.rx_len - n);
  srv.rx_len -= n;
  return 0;
}

// ---------------------------------------------------------------------------
// The daemon
// ---------------------------------------------------------------------------

static int failures = 0;

static void check(bool ok, const char *what) {
  if (!ok) {
    printf("FAIL: %s\n", what);
    failures++;
  } else {
    printf("ok: %s\n", what);
  }
}

// What send_next_device_info does each hour for a manager
static int refresh_device_info(void) {
  atclient_atkey atkey;
  atclient_atkey_init(&atkey);
  int ret = atclient_atkey_from_string(&atkey, "@bob:device_info.dev.sshnp@alice");
  if (ret == 0) {
    ret = atclient_put_shared_key(&worker, &atkey, "{\"devicename\":\"dev\"}", NULL, NULL);
  }
  atclient_atkey_free(&atkey);
  return ret;
}

static int make_shared_key_reply(void) {
  unsigned char aes_key[ATCHOPS_AES_256 / 8];
  memset(aes_key, 7, sizeof(aes_key));
  char aes_key_b64[64];
  size_t aes_key_b64_len = 0;
  unsigned char encrypted[256];
  size_t encrypted_len = 0;
  size_t reply_len = 0;
  atchops_rsa_key_public_key public_key;
  atchops_rsa_key_public_key_init(&public_key);
  int ret = atchops_rsa_key_populate_public_key(&public_key, TEST_PUBLIC_KEY_B64, strlen(TEST_PUBLIC_KEY_B64));
  if (ret == 0) {
    ret = atchops_base64_encode(aes_key, sizeof(aes_key), aes_key_b64, sizeof(aes_key_b64), &aes_key_b64_len);
  }
  if (ret == 0) {
    ret = atchops_rsa_encrypt(&public_key, (unsigned char *)aes_key_b64, aes_key_b64_len, encrypted, sizeof(encrypted),
                              &encrypted_len);
  }
  if (ret == 0) {
    memcpy(shared_key_reply, "data:", 5);
    ret = atchops_base64_encode(encrypted, encrypted_len, shared_key_reply + 5, sizeof(shared_key_reply) - 5,
                                &reply_len);
  }
  atchops_rsa_key_public_key_free(&public_key);
  return ret;
}

int main(void) {
  atlogger_set_logging_level(ATLOGGER_LOGGING_LEVEL_INFO);

  // The daemon as main() leaves it for main_loop: worker authenticated, its
  // reconnect hook set
  params.atsign = "@alice";
  atclient_atkeys_init(&atkeys);
  int ret = atclient_atkeys_populate_pkam_private_key(&atkeys, TEST_PRIVATE_KEY_B64, strlen(TEST_PRIVATE_KEY_B64));
  if (ret == 0) {
    ret = atclient_atkeys_populate_encrypt_private_key(&atkeys, TEST_PRIVATE_KEY_B64, strlen(TEST_PRIVATE_KEY_B64));
  }
  if (ret == 0) {
    ret = make_shared_key_reply();
  }
  if (ret != 0) {
    printf("FAIL: test setup: %d\n", ret);
    return 1;
  }
  // an atServer address, so that no atDirectory lookup is made
  worker_options.atserver_host = "alice.example";
  worker_options.atserver_port = 6464;
  atclient_init(&worker);
  ret = atclient_pkam_authenticate(&worker, params.atsign, &atkeys, &worker_options, NULL);
  if (ret == 0) {
    ret = set_worker_hooks();
  }
  check(ret == 0 && srv.connects == 1, "the daemon starts with its worker authenticated");

  check(refresh_device_info() == 0 && srv.updates_stored == 1, "the device info is stored for @bob");

  printf("\n--- the atServer drops the worker's idle connection\n");
  srv.reset = true;
  check(refresh_device_info() == 0 && srv.connects == 2 && srv.updates_stored == 2,
        "when the atServer has dropped the worker's idle connection, then the next refresh reconnects and is stored");

  printf("\n--- the atServer drops it again, and is slow to answer the reconnect's pkam:\n");
  srv.reset = true;
  srv.slow_pkam = true;
  check(refresh_device_info() != 0 && srv.updates_stored == 2,
        "when the reconnect times out waiting for the atServer, then that refresh fails");
  int connects_before = srv.connects;

  // The main loop comes round again: the atServer answers promptly from here on
  for (int pass = 1; pass <= 3; pass++) {
    printf("\n--- main loop pass %d after the failed reconnect\n", pass);
    ret = refresh_device_info();
    printf("refresh: %d, updates stored: %d, connections made: %d\n", ret, srv.updates_stored, srv.connects);
  }
  check(ret == 0 && srv.updates_stored >= 3,
        "when a reconnect of the worker has failed, then the next refresh reconnects it and @bob's device info is "
        "stored");
  check(srv.connects == connects_before + 1,
        "when a reconnect of the worker has failed, then the connection it was made on is dropped and one new connection "
        "replaces it");

  if (failures > 0) {
    printf("%d check(s) failed\n", failures);
    return 1;
  }
  return 0;
}
