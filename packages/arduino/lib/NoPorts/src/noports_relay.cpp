/**
 * @file noports_relay.cpp
 * @brief TCP socket relay implementation for ESP32
 *
 * This replaces the srv (socket relay valve) from the C sshnpd.
 * Instead of fork() + pthreads, we use FreeRTOS tasks.
 * Instead of mbedtls_net, we use ESP32 WiFiClient.
 *
 * The relay bridges:
 *   RVD (rendezvous host:port) <--> Local service (host:port)
 *
 * With optional AES-CTR end-to-end encryption of the traffic.
 */

#include "noports/noports_relay.h"
#include "noports/noports_config.h"
#include "noports/noports_log.h"
#include <WiFiClient.h>
#include <mbedtls/aes.h>
#include <mbedtls/base64.h>
#include <mbedtls/platform_util.h>  // mbedtls_platform_zeroize
#include <lwip/sockets.h>   // recv, MSG_PEEK, MSG_DONTWAIT, lwip_send
#include <esp_heap_caps.h>  // heap_caps_get_largest_free_block()
#include <esp_system.h>     // esp_random() for ESCR IV generation
#include <errno.h>

// ESCR auth requires atchops RSA signing and cJSON
extern "C" {
  #include "atclient/json.h"    // cJSON
  #include "atchops/rsa.h"      // atchops_rsa_sign, ATCHOPS_MD_SHA256
  #include "atchops/rsa_key.h"  // atchops_rsa_key_private_key
  #include "atchops/sha.h"      // ATCHOPS_MD_SHA256 enum value
}

#define TAG "noports_relay"

// Buffer size for relay forwarding and for heap-allocated ctrl buffers.
// 1×MSS keeps heap-allocated read buffers minimal: buf+crypt_buf = 2×1460 = 2.85 KB.
// Reduced from 2920 (2×MSS): under 3 concurrent sessions the extra 1460 bytes
// per read pushed lwIP pbuf allocation to within 2 KB of OOM (heap=10764 observed),
// causing lwIP to abort the control connection mid-transfer.
#define RELAY_BUF_SIZE 1460
// Max bytes read per sub per direction per main-loop iteration.
// Also the size of the embedded pending_rvd/pending_local buffers inside
// RelaySub — this is the biggest driver of heap usage in subs[] calloc
// (n_subs × 2 × this = total embedded buffer cost).
//
// === Sizing rationale ===
// 1×MSS: each rvd.read() call drains exactly one TCP segment.  lwIP delivers
// data on segment boundaries so a 1460-byte read always returns a full segment
// (or fewer bytes if the segment was partial — correct in both cases).
// Throughput is not limited by chunk size but by the TCP window;
// with CONFIG_LWIP_TCP_WND_DEFAULT=1460 the pipeline depth is 1 segment per
// connection, which is sufficient for SSH interactive and file transfer over LAN.
//
// === Memory: n_subs=3, RELAY_CHUNK_SIZE=1460 ===
//   RelaySub ≈ 2×WiFiClient(16) + 2×aes_ctr(320) + 2×1460 + misc = ~3.8 KB
//   subs[3] = 3×3.8 = 11.4 KB + buf(1460) + crypt_buf(1460) = ~14.3 KB
//   Leaves ~39 KB free from ~54 KB relay-start heap — ample margin above HEAP_CRITICAL_LOW
#define RELAY_CHUNK_SIZE 1460

// Buffer size for early data captured during Phase 2 polling.
// During Phase 2 both SRVD sockets are read byte-by-byte to find the
// connect: message.  Any bytes that arrive on the socket that turns out
// to be the DATA socket are buffered here and replayed in Phase 3.
// SSH banner is ~40 bytes (safe). TLS 1.3 ClientHello with extensions
// (SNI, ALPN, supported_versions, key_share, etc.) is 400-600 bytes.
// 1024 covers all realistic cases; both buffers are freed after Phase 2.
#define EARLY_BUF_SIZE 1024

// Stack size for relay FreeRTOS task
// With all large buffers (earlyA/B, cmsgA/B, buf, crypt_buf) on the heap,
// actual stack usage is ~1200 bytes for the normal relay path.
// RelaySub subs[] is heap-allocated separately (calloc at runtime) so the
// task stack only needs to hold the call chain and local scalars:
//   WiFiClient ctrl:             ~16
//   char ctrl_msg[384]:         384
//   _handle_connect_msg frame   ~450  (parse_buf[384] + overhead)
//   misc locals + call chain:   ~500
//   FreeRTOS context:           ~200
//   ─────────────────────────────────
//   Normal peak:              ~1550
//
// ESCR auth adds mbedtls structs on atchops_rsa_sign()'s stack frame:
//   mbedtls_rsa_context:        ~200
//   mbedtls_entropy_context:    ~800
//   mbedtls_ctr_drbg_context:   ~330
//   _escr_authenticate frame:   ~300
//   ─────────────────────────────────
//   ESCR peak:                ~3180  → 8192 gives ~5012 bytes headroom
#define RELAY_TASK_STACK_SIZE 8192

// Maximum concurrent sub-connections per relay (multi mode).
// Each sub uses 2 sockets (rvd + local) + optional AES state (~1KB).
//
// === Logical PCB pool separation ===
// ESP32 Arduino lwIP is compiled with:
//   CONFIG_LWIP_MAX_SOCKETS      = 16
//   CONFIG_LWIP_MAX_ACTIVE_TCP   = 16
//   CONFIG_LWIP_TCP_SND_BUF      = 1460  (overridden in platformio.ini)
//   CONFIG_LWIP_TCP_WND          = 1460  (overridden in platformio.ini)
// We partition the 16 sockets logically:
//
//   ATSERVER pool (reserved — only 2 are TLS):
//     monitor → atServer TLS  (1, persistent)
//     worker  → atServer TLS  (1, persistent; reconnects free old before connecting new)
//     root.atsign.org TCP     (1, transient during auth/reconnect, NOT TLS, closes fast)
//     reconnect margin        (2, covers brief overlap of old closing + new opening)
//     Total reserved:          5
//
//   RELAY pool (tracked):    ctrl(1) + N×2(subs) ≤ 11
//
// When pcbs=15/16, the daemon cannot open ANY new TCP socket — monitor
// and worker TLS reconnects fail with errno=11 (no free PCBs), causing
// a cascade failure.  5 reserved PCBs is sufficient because only 2 TLS
// sessions ever exist simultaneously (monitor + worker); the reconnect
// path frees the old socket before opening the new one.
// A runtime counter (_relay_pcb_count) tracks every socket the relay
// opens/closes.  New subs are refused if they would exceed the relay
// budget, guaranteeing the atServer TLS connections can never be
// starved by relay traffic.
#ifdef ESP32S3_2432S028R
// S3 (Freenove FNK0104): 512KB SRAM + 8MB PSRAM; CONFIG_LWIP_MAX_ACTIVE_TCP=24
// ctrl(1) + 9×2(subs) = 19 = MAX_RELAY_PCBS — supports up to 9 subs, UI caps at 6
#define LWIP_TOTAL_PCBS        24
#define RESERVED_ATSERVER_PCBS  5   // monitor(1) + worker(1) + root_transient(1) + margin(2)
#define MAX_RELAY_PCBS         (LWIP_TOTAL_PCBS - RESERVED_ATSERVER_PCBS)  // 19
#define MAX_RELAY_SUBS          9   // ctrl(1) + 9×2(subs) = 19 = MAX_RELAY_PCBS
#else
// ESP32 CYD: 16 TCP PCBs total
#define LWIP_TOTAL_PCBS        16
#define RESERVED_ATSERVER_PCBS  5   // monitor(1) + worker(1) + root_transient(1) + margin(2)
#define MAX_RELAY_PCBS         (LWIP_TOTAL_PCBS - RESERVED_ATSERVER_PCBS)  // 11
#define MAX_RELAY_SUBS          5   // ctrl(1) + 5×2(subs) = 11 = MAX_RELAY_PCBS
#endif

// Runtime counter for relay-owned TCP PCBs (ctrl + sub sockets).
// Incremented on every successful connect(), decremented on every stop().
static volatile int _relay_pcb_count = 0;

// Relay task CPU busyness tracking — time-weighted, 1-second rolling window.
// Each loop iteration contributes its nominal delay duration (1ms if data moved,
// _s*3ms if idle) to busy_ms or total_ms.  This makes the stat reflect the
// fraction of wall-clock time spent actively forwarding data, not the fraction
// of loop *passes* (which is diluted by the 3× longer idle delay).
// Updated by the relay task; read from main task via noports_relay_get_cpu_pct().
static volatile uint32_t _relay_busy_ms     = 0;
static volatile uint32_t _relay_total_ms    = 0;
static volatile uint32_t _relay_cpu_win_ms  = 0;  // millis() of current window start
static volatile uint8_t  _relay_cpu_pct     = 0;  // last computed busyness (0-100)

// Minimum free heap required before opening a new sub-connection (2 TCP sockets).
//
// Actual marginal cost of two WiFiClient::connect() calls:
//   - WiFiClientSocketHandle (heap):  ~48 bytes × 2  = ~100 bytes
//   - lwIP PCB structs:  come from the lwIP internal pool, NOT the heap
//   - lwIP pbufs (TX_SND_BUF 5744 + TCP_WND 5744 per socket):  allocated
//       LAZILY as data flows — zero heap cost at connect() time
//   - RelaySub struct (embedded AES states + 2×1460 pending bufs ≈ 3.8 KB):
//       already calloc'd as subs[] at session start — zero marginal cost
// Total marginal heap cost at connect time: ~200 bytes.
//
// This guard is therefore NOT the right tool to protect against TLS heap
// exhaustion — that is already handled by NOPORTS_TLS_MIN_CONTIGUOUS_HEAP.
// This guard's only job: ensure the system isn't completely out of heap.
// 12 KB covers the connect() overhead plus several KB of initial pbufs
// and leaves plenty of margin.  The old 30 KB value exceeded the observed
// ~27 KB free-heap floor under active data transfer, so it incorrectly
// refused connections during normal SSH/HTTP use.
#define MIN_HEAP_FOR_SUB 15000

// Heap level at which the relay loop switches to OOM mode and sleeps 50 ms
// per iteration to let lwIP's tcpip_thread drain in-flight pbufs.
// Set at 20 KB — well below the normal burst floor of ~28 KB observed with
// 2 active sessions, so this only fires when heap is genuinely exhausted
// (not during normal burst dips).  At this level lwIP struggles to allocate
// pbufs; the 50 ms sleep gives tcpip_thread several ACK cycles to free them.
#define HEAP_OOM_FLOOR 20000

// Below this floor evict the oldest active sub immediately (any idle time).
// 15 KB is below lwIP's minimum viable allocation level — if we reach here
// during data transfer, something is genuinely wrong and freeing a sub
// (releasing 2 PCB descriptors + pending buffers ~3 KB) is the best option.
#define HEAP_CRITICAL_LOW 15000

// Minimum idle time before CRITICAL_LOW evicts a sub.  0 = evict the oldest
// active sub immediately regardless of recent activity — at ≤15 KB we cannot
// afford to wait for a zombie.
#define CRITICAL_MIN_IDLE_MS 0UL

// OOM mode flag — set by the main relay loop when heap < HEAP_OOM_FLOOR,
// read by _write_all() to use a shorter stall timeout so it bails quickly
// and lets the eviction logic run instead of spinning for 5 s per call.
static volatile bool _relay_oom_mode = false;

// AES-CTR encryption state
struct aes_ctr_state {
  mbedtls_aes_context ctx;
  unsigned char nonce_counter[16];
  unsigned char stream_block[16];
  size_t nc_off;
};

// Per-sub stall timeout: absolute safety net for connections where the
// peer vanished without sending FIN/RST (e.g. network partition).
// Normal cleanup uses _peer_closed() (immediate) and slot eviction
// (evicts least-recently-active sub when a new connect: arrives and
// all slots are full).  This is just the backstop.
#define SUB_STALL_TIMEOUT_MS 900000UL  // 15 minutes

// Minimum idle time (ms) before a sub can be evicted for a new request.
// Protects mid-transfer HTTP responses from being killed.  Subs that
// finished their response will be detected by _peer_closed() and cleaned
// up immediately; keep-alive subs become evictable after this period.
// Without this, a browser loading a complex page creates a vicious cycle:
// new HTTP request → evict active sub → that request fails → browser
// retries → more evictions → nothing completes.
// Sub eviction grace period: a sub must be idle for this long before
// it is eligible for eviction.  500ms was too short for remote SRVD
// connections where the TLS ClientHello → ServerHello round-trip can
// easily exceed 500ms, causing mid-handshake eviction that RSTs the
// TCP connection and confuses the web server's TLS implementation.
#define SUB_EVICTION_GRACE_MS 10000UL

// When all sub slots are busy, incoming connect: messages are rejected
// by opening a temporary connection to SRVD and immediately closing it.
// The NPT client sees the sub-channel close and gives the browser a
// fast connection-reset error instead of a 30+ second timeout.
// The browser retries with its own backoff; by then a slot has usually
// freed up.

// NOTE: We do NOT use WiFiClient::connected() for disconnect detection.
// On ESP32/lwIP, connected() calls recv(fd, dummy, 0, MSG_DONTWAIT)
// which erroneously returns ENOTCONN on idle sockets — killing
// perfectly healthy connections.  Instead we use _peer_closed() which
// calls recv(fd, tmp, 1, MSG_PEEK|MSG_DONTWAIT) — standard POSIX
// behavior that reliably returns 0 on FIN and EAGAIN when alive.
// Detection layers:
//   - _peer_closed():  detects FIN/RST immediately after data drains
//   - _write_all():    catches dead sockets on write failure
//   - Slot eviction:   evicts oldest-idle sub when slots full
//   - SUB_STALL_TIMEOUT_MS: absolute safety net (15 min)
//   - ctrl_lost + DRAIN_TIMEOUT_MS: catches control channel drops

// Sub-connection in a multi-session relay
//
// AES states are embedded (not heap-allocated) to avoid malloc/free churn
// on every connect/close cycle.  Heap fragmentation from repeated alloc/
// free of ~600-byte AES structs would gradually shrink the largest free
// block, starving TLS reconnects.  Embedding them means the structs live
// in the subs[] array for the relay task lifetime — zero fragmentation.
//
// mbedtls_aes_init/free must be called on every connect/close.  The
// 'encrypted' flag gates all enc_state/dec_state accesses.
struct RelaySub {
  WiFiClient rvd;          // data connection to SRVD
  WiFiClient local;        // connection to local service
  aes_ctr_state enc_state; // embedded AES-CTR encrypter (local->SRVD, D2C)
  aes_ctr_state dec_state; // embedded AES-CTR decrypter (SRVD->local, C2D)
  bool active;
  bool encrypted;
  // Non-blocking drain state — set when one peer sends FIN.
  // Drain runs one pass per main-loop iteration so other subs
  // (SSH, etc.) are never starved while an HTTP sub is draining.
  bool draining;               // true while in post-FIN drain phase
  bool dir_flip;                // alternates which direction is serviced first each pass
  unsigned long drain_start_ms; // millis() when drain began
  unsigned long last_activity_ms; // millis() of last data transfer
  uint32_t sub_bytes_in;   // per-sub rvd→local byte counter
  uint32_t sub_bytes_out;  // per-sub local→rvd byte counter
  // Non-blocking WAN write buffer.
  // Bytes read from local that could not be immediately accepted by the
  // TCP send buffer are stored here and retried next loop iteration.
  // Avoids _write_all() spin-blocking the loop when SRVD's receive
  // window is exhausted (100ms RTT → ~57 KB/s per sub).
  uint8_t  pending_rvd[RELAY_CHUNK_SIZE];
  int      pending_rvd_len;   // valid bytes in pending_rvd   (0 = nothing pending)
  // Symmetric pending buffer for local (LAN) writes (rvd→local direction).
  // Same role as pending_rvd but for the local service socket.
  uint8_t  pending_local[RELAY_CHUNK_SIZE];
  int      pending_local_len; // valid bytes in pending_local (0 = nothing pending)
};

// Internal: ESCR (Encrypted Signed Challenge-Response) authentication with SRVD.
//
// Protocol (matches Dart RelayAuthenticatorESCR):
//   1. SRVD sends a random challenge terminated by '\n'
//   2. Daemon builds inner payload p = {"sid": sessionId, "c": challenge, "side": "b"}
//   3. Signs JSON(p) with APKAM RSA private key (SHA-256 / PKCS1v15)
//   4. Builds envelope: {"p": p, "s": base64(sig), "ha": "sha256", "sa": "rsa2048", "sk": uri}
//   5. Base64-encodes JSON(envelope) → envelope64
//   6. PKCS7-pads envelope64 (blockSize=16), then AES-256-CTR encrypts with relayAuthAesKey + random IV
//   7. Builds outer: {"iv": base64(iv), "e": base64(encrypted)}
//   8. Base64-encodes JSON(outer) → authPayload64
//   9. Sends: "{sessionId}:{authPayload64}\n"
//  10. Waits for "ok\n"
//
// Returns true on success.  All intermediate buffers are heap-allocated and
// freed before return to keep relay task stack usage under 300 bytes here.
static bool _escr_authenticate(WiFiClient *sock, const NoPortsRelayConfig *cfg) {
  bool auth_ok = false;

  // Heap-allocated intermediate buffers (all freed in cleanup)
  char *p_json        = NULL;
  char *env_json      = NULL;
  char *outer_json    = NULL;
  char *env64         = NULL;
  char *enc_b64       = NULL;
  char *auth_payload64 = NULL;
  unsigned char *sig  = NULL;
  char *sig_b64       = NULL;
  unsigned char *encrypted = NULL;
  cJSON *p = NULL, *envelope = NULL, *outer = NULL;

  // ---- Step 1: Read challenge (newline-terminated, max 63 chars) ----
  char challenge[64];
  memset(challenge, 0, sizeof(challenge));
  int pos = 0;
  unsigned long t0 = millis();
  while ((millis() - t0) < 5000UL && pos < 63) {
    uint8_t b;
    if (sock->read(&b, 1) == 1) {
      if (b == '\n') break;
      challenge[pos++] = (char)b;
    } else {
      vTaskDelay(pdMS_TO_TICKS(1));
    }
  }
  challenge[pos] = '\0';
  if (pos == 0) {
    NOPORTS_LOGE(TAG, "ESCR: no challenge from SRVD (timeout or empty)");
    goto escr_cleanup;
  }
  NOPORTS_LOGD(TAG, "ESCR: challenge (%d chars) received", pos);

  // ---- Step 2: Build inner payload p ----
  p = cJSON_CreateObject();
  if (!p) goto escr_cleanup;
  cJSON_AddStringToObject(p, "sid",  cfg->session_id);
  cJSON_AddStringToObject(p, "c",    challenge);
  cJSON_AddStringToObject(p, "side", "b");  // daemon is always side 'b'

  p_json = cJSON_PrintUnformatted(p);
  cJSON_Delete(p); p = NULL;
  if (!p_json) goto escr_cleanup;

  // ---- Step 3: RSA sign p_json with APKAM private key ----
  sig = (unsigned char *)malloc(256);
  if (!sig) goto escr_cleanup;
  memset(sig, 0, 256);
  if (atchops_rsa_sign(
        (atchops_rsa_key_private_key *)cfg->escr_signing_key,
        ATCHOPS_MD_SHA256,
        (unsigned char *)p_json, strlen(p_json), sig) != 0) {
    NOPORTS_LOGE(TAG, "ESCR: RSA signing failed");
    goto escr_cleanup;
  }

  // ---- Step 4: Base64-encode signature ----
  sig_b64 = (char *)malloc(352);
  if (!sig_b64) goto escr_cleanup;
  {
    size_t sig_b64_len = 0;
    if (mbedtls_base64_encode((unsigned char *)sig_b64, 352, &sig_b64_len, sig, 256) != 0) {
      NOPORTS_LOGE(TAG, "ESCR: sig b64 failed");
      goto escr_cleanup;
    }
    sig_b64[sig_b64_len] = '\0';
  }
  free(sig); sig = NULL;

  // ---- Step 5: Build envelope JSON (re-parse p from p_json) ----
  p = cJSON_Parse(p_json);
  cJSON_free(p_json); p_json = NULL;
  if (!p) goto escr_cleanup;

  envelope = cJSON_CreateObject();
  if (!envelope) goto escr_cleanup;
  cJSON_AddItemToObject(envelope, "p", p);  // envelope takes ownership
  p = NULL;
  cJSON_AddStringToObject(envelope, "s",  sig_b64);
  free(sig_b64); sig_b64 = NULL;
  cJSON_AddStringToObject(envelope, "ha", "sha256");
  cJSON_AddStringToObject(envelope, "sa", "rsa2048");
  cJSON_AddStringToObject(envelope, "sk", cfg->escr_signing_key_uri);

  env_json = cJSON_PrintUnformatted(envelope);
  cJSON_Delete(envelope); envelope = NULL;
  if (!env_json) goto escr_cleanup;

  // ---- Step 6: Base64-encode envelope JSON → env64 ----
  {
    size_t env_json_len = strlen(env_json);
    size_t env64_max = (env_json_len / 3 + 2) * 4 + 4;
    env64 = (char *)malloc(env64_max);
    if (!env64) goto escr_cleanup;
    size_t env64_len = 0;
    if (mbedtls_base64_encode(
          (unsigned char *)env64, env64_max, &env64_len,
          (unsigned char *)env_json, env_json_len) != 0) {
      NOPORTS_LOGE(TAG, "ESCR: envelope b64 failed");
      goto escr_cleanup;
    }
    env64[env64_len] = '\0';
    cJSON_free(env_json); env_json = NULL;

    // ---- Step 7: Decode relayAuthAesKey (base64 → 32 raw bytes) ----
    unsigned char aes_key[32];
    size_t aes_key_len = 0;
    if (mbedtls_base64_decode(
          aes_key, sizeof(aes_key), &aes_key_len,
          (const unsigned char *)cfg->relay_auth_aes_key,
          strlen(cfg->relay_auth_aes_key)) != 0 || aes_key_len != 32) {
      NOPORTS_LOGE(TAG, "ESCR: AES key decode failed");
      mbedtls_platform_zeroize(aes_key, sizeof(aes_key)); // may hold partial key bytes
      goto escr_cleanup;
    }

    // ---- Step 8: Generate random 16-byte IV using hardware RNG ----
    unsigned char iv[16];
    {
      uint32_t *iv32 = (uint32_t *)iv;
      iv32[0] = esp_random(); iv32[1] = esp_random();
      iv32[2] = esp_random(); iv32[3] = esp_random();
    }

    // ---- Step 9: PKCS7-pad then AES-256-CTR encrypt env64 ----
    // Dart AESEncryptionAlgo (at_chops) adds PKCS7 padding (blockSize=16) to the
    // plaintext BEFORE CTR-encrypting, and removes it after CTR-decrypting.
    // We must match: pad env64, then CTR-encrypt the padded bytes.
    size_t pad_byte  = 16 - (env64_len % 16);   // always 1..16
    size_t padded_len = env64_len + pad_byte;
    // Reuse env64 in place: extend the allocation and append padding.
    {
      char *tmp = (char *)realloc(env64, padded_len);
      if (!tmp) goto escr_cleanup;
      env64 = tmp;
    }
    memset((unsigned char *)env64 + env64_len, (unsigned char)pad_byte, pad_byte);

    encrypted = (unsigned char *)malloc(padded_len);
    if (!encrypted) goto escr_cleanup;
    {
      mbedtls_aes_context aes_ctx;
      mbedtls_aes_init(&aes_ctx);
      mbedtls_aes_setkey_enc(&aes_ctx, aes_key, 256);
      size_t nc_off = 0;
      unsigned char stream_block[16] = {0};
      unsigned char nonce_counter[16];
      memcpy(nonce_counter, iv, 16);
      mbedtls_aes_crypt_ctr(&aes_ctx, padded_len, &nc_off, nonce_counter,
                             stream_block, (unsigned char *)env64, encrypted);
      mbedtls_aes_free(&aes_ctx);
    }
    mbedtls_platform_zeroize(aes_key, sizeof(aes_key)); // raw key no longer needed
    free(env64); env64 = NULL;

    // ---- Step 10: Base64-encode IV and ciphertext ----
    char iv_b64[32];
    size_t iv_b64_len = 0;
    if (mbedtls_base64_encode(
          (unsigned char *)iv_b64, sizeof(iv_b64), &iv_b64_len, iv, 16) != 0) {
      NOPORTS_LOGE(TAG, "ESCR: IV b64 failed");
      goto escr_cleanup;
    }
    iv_b64[iv_b64_len] = '\0';

    size_t enc_b64_max = (padded_len / 3 + 2) * 4 + 4;
    enc_b64 = (char *)malloc(enc_b64_max);
    if (!enc_b64) goto escr_cleanup;
    size_t enc_b64_len = 0;
    if (mbedtls_base64_encode(
          (unsigned char *)enc_b64, enc_b64_max, &enc_b64_len,
          encrypted, padded_len) != 0) {
      NOPORTS_LOGE(TAG, "ESCR: enc b64 failed");
      goto escr_cleanup;
    }
    enc_b64[enc_b64_len] = '\0';
    free(encrypted); encrypted = NULL;

    // ---- Step 11: Build outer JSON {"iv": ..., "e": ...} ----
    outer = cJSON_CreateObject();
    if (!outer) goto escr_cleanup;
    cJSON_AddStringToObject(outer, "iv", iv_b64);
    cJSON_AddStringToObject(outer, "e",  enc_b64);
    free(enc_b64); enc_b64 = NULL;

    outer_json = cJSON_PrintUnformatted(outer);
    cJSON_Delete(outer); outer = NULL;
    if (!outer_json) goto escr_cleanup;

    // ---- Step 12: Base64-encode outer JSON → authPayload64 ----
    size_t outer_json_len = strlen(outer_json);
    size_t auth_payload64_max = (outer_json_len / 3 + 2) * 4 + 4;
    auth_payload64 = (char *)malloc(auth_payload64_max);
    if (!auth_payload64) goto escr_cleanup;
    size_t auth_payload64_len = 0;
    if (mbedtls_base64_encode(
          (unsigned char *)auth_payload64, auth_payload64_max, &auth_payload64_len,
          (const unsigned char *)outer_json, outer_json_len) != 0) {
      NOPORTS_LOGE(TAG, "ESCR: authPayload b64 failed");
      goto escr_cleanup;
    }
    auth_payload64[auth_payload64_len] = '\0';
    cJSON_free(outer_json); outer_json = NULL;
  }  // end local-scope block for env_json_len, aes_key, iv, iv_b64, etc.

  // ---- Step 13: Send "{sessionId}:{authPayload64}\n" ----
  sock->print(cfg->session_id);
  sock->print(":");
  sock->print(auth_payload64);
  sock->print("\n");
  sock->flush();
  free(auth_payload64); auth_payload64 = NULL;
  NOPORTS_LOGD(TAG, "ESCR: response sent for session %.20s...", cfg->session_id);

  // ---- Step 14: Wait for "ok\n" from SRVD ----
  {
    char response[16];
    memset(response, 0, sizeof(response));
    int rpos = 0;
    t0 = millis();
    while ((millis() - t0) < 5000UL && rpos < 15) {
      uint8_t b;
      if (sock->read(&b, 1) == 1) {
        if (b == '\n') break;
        response[rpos++] = (char)b;
      } else {
        vTaskDelay(pdMS_TO_TICKS(1));
      }
    }
    response[rpos] = '\0';
    if (strcmp(response, "ok") == 0) {
      auth_ok = true;
      NOPORTS_LOGI(TAG, "ESCR: authenticated OK");
    } else {
      NOPORTS_LOGE(TAG, "ESCR: auth rejected (got '%s')", response);
    }
  }

escr_cleanup:
  if (p)            cJSON_Delete(p);
  if (envelope)     cJSON_Delete(envelope);
  if (outer)        cJSON_Delete(outer);
  if (p_json)       cJSON_free(p_json);
  if (env_json)     cJSON_free(env_json);
  if (outer_json)   cJSON_free(outer_json);
  if (sig)          free(sig);
  if (sig_b64)      free(sig_b64);
  if (env64)        free(env64);
  if (enc_b64)      free(enc_b64);
  if (encrypted)    free(encrypted);
  if (auth_payload64) free(auth_payload64);
  return auth_ok;
}

// Internal: check if a WiFiClient's peer has closed the connection.
// Uses recv(MSG_PEEK|MSG_DONTWAIT) with size 1 on the raw fd.
// This is MORE reliable than WiFiClient::connected() which uses
// recv(fd, dummy, 0) and erroneously returns ENOTCONN on idle sockets.
//  - Returns true  when FIN received (peer closed) or socket error
//  - Returns false when socket is alive (data available or EAGAIN)
// Wipe a NUL-terminated key/IV string before freeing it: on a single-address-
// space MCU freed heap holding live session keys can surface in later
// allocations or crash dumps. mbedtls_platform_zeroize is never optimized away.
static void _zero_free_key(void *p) {
  if (p) {
    mbedtls_platform_zeroize(p, strlen((char *)p));
    free(p);
  }
}

// Wipe and free the Phase-2 connect: line buffers (they carry the decrypted
// per-session data-channel AES keys). Both are 256-byte calloc'd buffers.
static void _free_cmsgs(char *a, char *b) {
  mbedtls_platform_zeroize(a, 256);
  mbedtls_platform_zeroize(b, 256);
  free(a);
  free(b);
}

static bool _peer_closed(WiFiClient &client) {
  int fd = client.fd();
  if (fd < 0) return true;
  char tmp;
  int res = recv(fd, &tmp, 1, MSG_PEEK | MSG_DONTWAIT);
  if (res > 0) return false;   // data available → alive
  if (res == 0) return true;   // FIN received → closed
  // res < 0: EAGAIN/EWOULDBLOCK means alive-but-no-data
  return (errno != EAGAIN && errno != EWOULDBLOCK);
}

// Internal: initialise an embedded AES-CTR state from base64 key and IV.
// Writes into *state (which must already be allocated by the caller).
// Returns 0 on success, -1 on failure.  Never allocates heap.
static int _init_aes_ctr_state(aes_ctr_state *state,
                                const unsigned char *key_b64,
                                const unsigned char *iv_b64) {
  unsigned char aes_key[32];
  size_t olen;

  int res = mbedtls_base64_decode(aes_key, sizeof(aes_key), &olen,
                                  key_b64, strlen((const char *)key_b64));
  if (res != 0 || olen != 32) {
    NOPORTS_LOGE(TAG, "Failed to decode AES key (res=%d, len=%u)", res, (unsigned)olen);
    return -1;
  }

  unsigned char iv[16];
  res = mbedtls_base64_decode(iv, sizeof(iv), &olen,
                              iv_b64, strlen((const char *)iv_b64));
  if (res != 0 || olen != 16) {
    NOPORTS_LOGE(TAG, "Failed to decode IV (res=%d, len=%u)", res, (unsigned)olen);
    mbedtls_platform_zeroize(aes_key, sizeof(aes_key));
    return -1;
  }

  memset(state, 0, sizeof(*state));
  mbedtls_aes_init(&state->ctx);
  res = mbedtls_aes_setkey_enc(&state->ctx, aes_key, 256);
  // the key schedule now lives in state->ctx; the raw key is no longer needed
  mbedtls_platform_zeroize(aes_key, sizeof(aes_key));
  if (res != 0) {
    mbedtls_aes_free(&state->ctx);
    return -1;
  }
  memcpy(state->nonce_counter, iv, 16);
  state->nc_off = 0;
  memset(state->stream_block, 0, 16);

  return 0;
}

// Internal: initialise embedded encrypter and decrypter from base64 key(s)/IV(s).
// Writes directly into the caller-provided aes_ctr_state objects (no heap alloc).
// Twin-key mode: enc uses D2C key, dec uses C2D key.
// Single-key mode (key_d2c_b64 == NULL): both use the same C2D key.
static int _create_enc_dec(const unsigned char *key_c2d_b64, const unsigned char *iv_c2d_b64,
                           const unsigned char *key_d2c_b64, const unsigned char *iv_d2c_b64,
                           aes_ctr_state *enc_out, aes_ctr_state *dec_out) {
  // Decrypter always uses C2D key (decrypts what client encrypted)
  if (_init_aes_ctr_state(dec_out, key_c2d_b64, iv_c2d_b64) != 0) return -1;

  // Encrypter uses D2C key if available, else same C2D key
  if (key_d2c_b64 && iv_d2c_b64) {
    NOPORTS_LOGI(TAG, "Twin-key mode: separate keys for enc (D2C) and dec (C2D)");
    if (_init_aes_ctr_state(enc_out, key_d2c_b64, iv_d2c_b64) != 0) {
      mbedtls_aes_free(&dec_out->ctx);
      return -1;
    }
  } else {
    NOPORTS_LOGI(TAG, "Single-key mode: same key for enc and dec");
    if (_init_aes_ctr_state(enc_out, key_c2d_b64, iv_c2d_b64) != 0) {
      mbedtls_aes_free(&dec_out->ctx);
      return -1;
    }
  }
  return 0;
}

// Non-blocking write helper using MSG_DONTWAIT.
//
// O_NONBLOCK on the fd affects BOTH reads and writes, causing recv() to
// return EAGAIN on idle sockets even when available() returned > 0 — a
// race between ioctl(FIONREAD) and the actual recv() that breaks the
// reliable available()-before-read() contract.
//
// MSG_DONTWAIT is a per-call send flag: it makes only that single send()
// non-blocking without changing the fd's blocking mode.  It is always
// honoured by lwIP regardless of compile-time options (unlike SO_SNDTIMEO).
//
// Returns bytes written (0 = send buffer full, try again next iteration),
// or -1 on hard error (ECONNABORTED, ECONNRESET, EBADF, etc.).
#define RELAY_WRITE_TIMEOUT_MS 20   // used by _write_all retry budget only

static int _write_nb(WiFiClient &client, const uint8_t *data, size_t len) {
  int fd = client.fd();
  if (fd < 0) return -1;
  int n = lwip_send(fd, data, len, MSG_DONTWAIT);
  if (n < 0) {
    if (errno == EAGAIN || errno == EWOULDBLOCK) return 0;  // buffer full
    return -1;  // hard error (ECONNABORTED etc.)
  }
  return n;
}

// Enable TCP keepalive on a relay socket so the kernel detects dead peers
// in ~10 s (5 s idle + 3 probes × 2 s) instead of waiting for the
// SUB_STALL_TIMEOUT_MS (15 min) backstop.  This matters most when a remote
// client crashes or the network path breaks without sending a FIN/RST:
// without keepalive the socket sits open forever consuming a PCB slot.
static void _set_sock_keepalive(int fd) {
  if (fd < 0) return;
  int yes = 1;
  setsockopt(fd, SOL_SOCKET,   SO_KEEPALIVE,  &yes, sizeof(yes));
  int idle  = 5;  // seconds of inactivity before first probe
  int intvl = 2;  // seconds between probes
  int cnt   = 3;  // probes before giving up
  setsockopt(fd, IPPROTO_TCP, TCP_KEEPIDLE,  &idle,  sizeof(idle));
  setsockopt(fd, IPPROTO_TCP, TCP_KEEPINTVL, &intvl, sizeof(intvl));
  setsockopt(fd, IPPROTO_TCP, TCP_KEEPCNT,   &cnt,   sizeof(cnt));
}

// Internal: shrink TCP send + receive buffer sizes on a sub socket.
// ESP32 lwIP defaults: TCP_SND_BUF = TCP_WND = 5744 B per socket.
// At 3 active subs (6 sockets) that is up to ~69 KB of pbufs in flight,
// which exceeds the ~54 KB heap headroom and causes OOM lockups.
// Halving to 2920 (2 × RELAY_CHUNK_SIZE) saves ~17 KB across 3 subs
// while still allowing two full 1460-byte chunks in the pipe at a time —
// enough headroom for sustained SSH throughput without head-of-line blocking.
// Called immediately after connect() + setNoDelay() on every sub socket.
static void _set_sub_sock_bufs(WiFiClient &c) {
  int fd = c.fd();
  if (fd < 0) return;
  int sz = 1460;  // 1×MSS — matches CONFIG_LWIP_TCP_WND_DEFAULT and SND_BUF_DEFAULT
  setsockopt(fd, SOL_SOCKET, SO_SNDBUF, &sz, sizeof(sz));
  setsockopt(fd, SOL_SOCKET, SO_RCVBUF, &sz, sizeof(sz));
  _set_sock_keepalive(fd);
}

// Internal: write all bytes to a WiFiClient, handling partial writes.
// Used only for the single-relay path (data ↔ local_client).
// The multi-relay path uses _write_nb() with pending_* retry buffers instead.
//
// Retries with 1ms yields until timeout_ms elapses.  With _relay_oom_mode set
// the timeout is shortened to 300ms so the loop bails quickly.
static bool _write_all(WiFiClient *client, const uint8_t *data, size_t len) {
  size_t written = 0;
  unsigned long start = millis();
  const unsigned long timeout_ms = _relay_oom_mode ? 300UL : 5000UL;
  while (written < len) {
    int n = _write_nb(*client, data + written, len - written);
    if (n > 0) {
      written += (size_t)n;
      start = millis();
    } else if (n < 0) {
      NOPORTS_LOGE(TAG, "write_all: hard error errno=%d, giving up (%u/%u)",
                   errno, (unsigned)written, (unsigned)len);
      return false;
    } else {
      // n == 0: send buffer full — yield and retry
      if ((millis() - start) > timeout_ms) {
        NOPORTS_LOGE(TAG, "write_all stalled >%lums%s, giving up (%u/%u)",
                     timeout_ms, _relay_oom_mode ? " (OOM)" : "",
                     (unsigned)written, (unsigned)len);
        return false;
      }
      vTaskDelay(pdMS_TO_TICKS(1));
    }
  }
  return true;
}

// Internal: heap-allocate and initialise an AES-CTR state.
// Used only for the control-channel decrypters which live for the full
// relay session and are freed at cleanup.  Sub-connection AES states
// are embedded in RelaySub (see _init_aes_ctr_state).
static aes_ctr_state *_alloc_aes_ctr_state(const unsigned char *key_b64,
                                            const unsigned char *iv_b64) {
  aes_ctr_state *state = (aes_ctr_state *)calloc(1, sizeof(aes_ctr_state));
  if (!state) return NULL;
  if (_init_aes_ctr_state(state, key_b64, iv_b64) != 0) {
    free(state);
    return NULL;
  }
  return state;
}

static int _aes_ctr_crypt(aes_ctr_state *state, size_t len,
                          const unsigned char *input, unsigned char *output) {
  return mbedtls_aes_crypt_ctr(&state->ctx, len,
                               &state->nc_off, state->nonce_counter,
                               state->stream_block, input, output);
}

// Internal: close a relay sub-connection and free its resources.
// Uses graceful FIN close (no SO_LINGER/RST).
// lwIP auto-recycles the oldest TIME_WAIT PCB when the pool is full,
// so explicit RST is unnecessary and harmful — RST causes the REMOTE
// peer (web server) to reject subsequent SYNs from the same client.
static void _close_relay_sub(RelaySub *sub, int index) {
  NOPORTS_LOGI(TAG, "Sub[%d] closing (in=%u out=%u)", index,
               (unsigned)sub->sub_bytes_in, (unsigned)sub->sub_bytes_out);
  if (sub->rvd.fd() >= 0) { sub->rvd.stop(); _relay_pcb_count--; }
  if (sub->local.fd() >= 0) { sub->local.stop(); _relay_pcb_count--; }
  if (_relay_pcb_count < 0) _relay_pcb_count = 0;  // safety clamp
  // AES states are embedded — just free the mbedtls context, no heap free.
  if (sub->encrypted) {
    mbedtls_aes_free(&sub->enc_state.ctx);
    mbedtls_aes_free(&sub->dec_state.ctx);
  }
  sub->active = false;
  sub->encrypted = false;
  sub->draining = false;
  sub->drain_start_ms = 0;
  sub->pending_rvd_len   = 0;
  sub->pending_local_len = 0;
  // Reset WiFiClient objects for potential slot reuse
  sub->rvd = WiFiClient();
  sub->local = WiFiClient();
}

// Internal: recount active subs and update relay->active_sessions
static void _update_active_session_count(NoPortsRelay *relay, RelaySub *subs, int n_subs) {
  uint8_t count = 0;
  for (int i = 0; i < n_subs; i++) {
    if (subs[i].active) count++;
  }
  relay->active_sessions = count;
}

// Internal: reclaim any subs whose peer has already closed.
// Called before attempting eviction so dead subs free their slots/PCBs
// without needing to evict a live connection.
// Skips draining subs — those are already being handled by the drain
// state machine and must not be reclaimed early (they may still have
// response data in the local receive buffer to forward).
// Reclaims only when BOTH sides are fully closed to avoid cutting off
// a sub where one side is still actively sending (e.g. rvd closed by
// HTTP keep-alive while web server is still sending the response).
static void _reclaim_dead_subs(RelaySub *subs, int n_subs) {
  for (int i = 0; i < n_subs; i++) {
    if (!subs[i].active) continue;
    if (subs[i].draining) continue; // drain state machine owns these
    bool rvd_dead   = !subs[i].rvd.available()   && _peer_closed(subs[i].rvd);
    bool local_dead = !subs[i].local.available() && _peer_closed(subs[i].local);
    if (rvd_dead && local_dead) {   // both sides fully closed — safe to reclaim
      NOPORTS_LOGI(TAG, "Sub[%d] reclaimed (both peers closed)", i);
      _close_relay_sub(&subs[i], i);
    }
  }
}

// Internal: find the longest-idle active sub unconditionally.
// Used only under OOM emergency — no grace-period filter.
// When min_age_ms > 0 only subs older than that are considered;
// pass 0 to force-evict regardless of age.
// Returns -1 if no active sub found.
static int _find_oldest_active_sub(RelaySub *subs, int n_subs, unsigned long min_age_ms) {
  int victim = -1;
  unsigned long oldest_activity = ULONG_MAX;
  unsigned long now = millis();
  for (int i = 0; i < n_subs; i++) {
    if (!subs[i].active) continue;
    if (min_age_ms > 0 && (now - subs[i].last_activity_ms) < min_age_ms) continue;
    if (subs[i].last_activity_ms < oldest_activity) {
      oldest_activity = subs[i].last_activity_ms;
      victim = i;
    }
  }
  return victim;
}

// Internal: find the best eviction victim among active subs.
// Only considers subs that have been idle > SUB_EVICTION_GRACE_MS.
// Subs with zero server-side bytes (sub_bytes_out==0) are protected
// from eviction during the initial SUB_EVICTION_GRACE_MS window only
// (mid-TLS-handshake guard).  After that grace window a zero-bytes-out
// sub is considered stuck and becomes evictable.
// Returns -1 if no eligible victim found.
static int _find_evictable_sub(RelaySub *subs, int n_subs) {
  int victim = -1;
  unsigned long oldest_activity = ULONG_MAX;
  unsigned long now = millis();
  for (int i = 0; i < n_subs; i++) {
    if (!subs[i].active) continue;
    // Protect mid-TLS-handshake subs (sub_bytes_out==0) only during the
    // initial grace window.  After SUB_EVICTION_GRACE_MS a zero-bytes-out
    // sub is stuck (server never responded) and is fair game for eviction.
    if (subs[i].sub_bytes_out == 0 &&
        (now - subs[i].last_activity_ms) < SUB_EVICTION_GRACE_MS) continue;
    // Never evict a sub with pending data in either direction.
    if (subs[i].rvd.available() > 0 || subs[i].local.available() > 0) continue;
    if ((now - subs[i].last_activity_ms) > SUB_EVICTION_GRACE_MS &&
        subs[i].last_activity_ms < oldest_activity) {
      oldest_activity = subs[i].last_activity_ms;
      victim = i;
    }
  }
  return victim;
}

// Back-pressure strategy: when we can't accept a connect request,
// we simply ignore it — no SRVD socket is opened.  NPT's unmatched
// sub-channel will eventually timeout, which naturally rate-limits
// new requests.  This uses zero sockets and zero heap, unlike the
// old approach of opening a temporary SRVD socket to RST-reject.

// Internal: handle a "connect:..." control message in multi mode.
// Opens a new data connection to SRVD and a new connection to the local
// service, then marks the sub slot as active for bidirectional relay.
//
// Eviction strategy (three tiers):
//  1. Reclaim dead subs (peer already closed) — free cleanup
//  2. Evict subs idle > SUB_EVICTION_GRACE_MS — keep-alive waiters
//  3. Silently ignore the connect — back-pressure via NPT timeout
// Tier 3 uses zero sockets and zero heap.  NPT's unmatched SRVD
// sub-channel will timeout on its own, which naturally rate-limits
// new requests and prevents eviction churn.
//
// Return values:
//   0 = success, sub is active
//  -2 = failure (rejected, parse error, AES setup, TCP connect refused)
static int _handle_connect_msg(NoPortsRelay *relay, RelaySub *subs, int n_subs,
                               const char *msg) {
  // Step 1: Reclaim any subs whose peer has already closed.
  // This is free — those connections are already done.
  _reclaim_dead_subs(subs, n_subs);

  // PCB budget guard: refuse if opening 2 more sockets would exceed the relay
  // pool, ensuring atServer (monitor/worker) PCBs are never starved.
  //
  // IMPORTANT: use the session-local socket count derived from the live subs[]
  // state rather than the global _relay_pcb_count.  The global counter is
  // shared across all concurrent relay sessions (up to NOPORTS_MAX_RELAYS=5)
  // and can become inaccurate when sessions exit via error paths or when
  // multiple sessions are running simultaneously.  Counting from subs[] is
  // always correct for THIS session:
  //   - ctrl socket:  always 1 (we hold it for the life of the multi loop)
  //   - each active sub: 2  (rvd + local)
  {
    int session_pcbs = 1;  // ctrl socket
    for (int i = 0; i < n_subs; i++) {
      if (subs[i].active) session_pcbs += 2;
    }
    if (session_pcbs + 2 > MAX_RELAY_PCBS) {
      int victim = _find_evictable_sub(subs, n_subs);
      if (victim >= 0) {
        unsigned long idle_ms = millis() - subs[victim].last_activity_ms;
        NOPORTS_LOGW(TAG, "Sub[%d] evicted (idle %lums, session_pcbs=%d/%d global=%d)",
                     victim, idle_ms, session_pcbs, MAX_RELAY_PCBS, _relay_pcb_count);
        _close_relay_sub(&subs[victim], victim);
      } else {
        NOPORTS_LOGW(TAG, "Multi: session_pcbs=%d/%d (global=%d), all subs active — back-pressure",
                     session_pcbs, MAX_RELAY_PCBS, _relay_pcb_count);
        return -2;
      }
    }
  }

  // Total-heap guard: refuse new subs when heap is critically low.
  // Relay subs are plain TCP (no TLS, ~200 bytes at connect time) but each
  // active sub accumulates pbufs during a burst.  Under heavy traffic the
  // heap will recover on its own once pbufs drain — evicting an active sub
  // to make room just destroys a live SSH session for no benefit.
  // Back-pressure only: return -2 so NPT's sub-channel times out and the
  // client retries once a slot is naturally free.
  {
    uint32_t heap = esp_get_free_heap_size();
    if (heap < MIN_HEAP_FOR_SUB) {
      int active_count = 0;
      for (int i = 0; i < n_subs; i++) {
        if (subs[i].active) active_count++;
      }
      if (active_count > 0) {
        NOPORTS_LOGW(TAG, "Multi: heap %u < %u, %d subs active — back-pressure (no evict)",
                     (unsigned)heap, MIN_HEAP_FOR_SUB, active_count);
        return -2;
      }
      // No active subs — heap is low for another reason; allow the first sub
      NOPORTS_LOGW(TAG, "Multi: heap %u < %u but no active subs — allowing",
                   (unsigned)heap, MIN_HEAP_FOR_SUB);
    }
  }

  // Find free sub slot
  int slot = -1;
  for (int i = 0; i < n_subs; i++) {
    if (!subs[i].active) { slot = i; break; }
  }

  // All slots full — try to evict the longest-idle sub.
  // Only evicts subs idle > SUB_EVICTION_GRACE_MS.  If all subs are
  // actively transferring, we drop this connect request.  The SRVD
  // sub-channel will timeout and the browser will retry once a slot
  // frees up naturally (via _peer_closed).
  if (slot < 0) {
    int victim = _find_evictable_sub(subs, n_subs);
    if (victim >= 0) {
      unsigned long idle_ms = millis() - subs[victim].last_activity_ms;
      NOPORTS_LOGW(TAG, "Sub[%d] evicted (idle %lums) to make room", victim, idle_ms);
      _close_relay_sub(&subs[victim], victim);
      slot = victim;
    } else {
      NOPORTS_LOGW(TAG, "Multi: all %d subs active — ignoring (back-pressure, heap=%u)",
                   n_subs, (unsigned)esp_get_free_heap_size());
      return -2;
    }
  }

  if (slot < 0) {
    NOPORTS_LOGE(TAG, "Multi: no free sub slots (max %d) — ignoring (back-pressure)", n_subs);
    return -2;
  }

  RelaySub *sub = &subs[slot];
  sub->encrypted = false;

  // Parse: "connect:key:iv[:keyD2C:ivD2C]" or "connect:no:encrypt"
  const char *data_start = msg + 8; // skip "connect:"

  if (strcmp(data_start, "no:encrypt") == 0 || *data_start == '\0') {
    NOPORTS_LOGI(TAG, "Sub[%d] plain (no e2ee)", slot);
  } else {
    // Parse colon-separated fields from a mutable copy
    char parse_buf[384];
    strncpy(parse_buf, data_start, sizeof(parse_buf) - 1);
    parse_buf[sizeof(parse_buf) - 1] = '\0';

    char *fields[4] = {NULL, NULL, NULL, NULL};
    int nfields = 0;
    char *p = parse_buf;
    fields[nfields++] = p;
    while (*p && nfields < 4) {
      if (*p == ':') {
        *p = '\0';
        fields[nfields++] = p + 1;
      }
      p++;
    }

    if (nfields < 2) {
      NOPORTS_LOGE(TAG, "Sub[%d] malformed connect (need key:iv, got %d)",
                   slot, nfields);
      return -2;  // permanent: bad message
    }

    const char *key_d2c = (nfields >= 4) ? fields[2] : NULL;
    const char *iv_d2c  = (nfields >= 4) ? fields[3] : NULL;

    int rc = _create_enc_dec(
      (const unsigned char *)fields[0], (const unsigned char *)fields[1],
      (const unsigned char *)key_d2c,   (const unsigned char *)iv_d2c,
      &sub->enc_state, &sub->dec_state);
    if (rc != 0) {
      NOPORTS_LOGE(TAG, "Sub[%d] AES setup failed", slot);
      return -2;  // permanent: crypto failure
    }
    sub->encrypted = true;
    NOPORTS_LOGI(TAG, "Sub[%d] e2ee %s", slot,
                 key_d2c ? "twin-key" : "single-key");
  }

  // Connect to SRVD (new data socket)
  sub->rvd = WiFiClient();
  if (!sub->rvd.connect(relay->config.rvd_host, relay->config.rvd_port)) {
    NOPORTS_LOGE(TAG, "Sub[%d] failed to connect to SRVD", slot);
    goto sub_fail;
  }
  _relay_pcb_count++;
  sub->rvd.setNoDelay(true);
  _set_sub_sock_bufs(sub->rvd);
  if (relay->config.escr_auth && relay->config.escr_signing_key &&
      relay->config.relay_auth_aes_key) {
    if (!_escr_authenticate(&sub->rvd, &relay->config)) {
      NOPORTS_LOGE(TAG, "Sub[%d] ESCR auth failed", slot);
      sub->rvd.stop();
      _relay_pcb_count--;
      goto sub_fail;
    }
  } else if (relay->config.rv_auth && relay->config.rvd_auth_string) {
    sub->rvd.print(relay->config.rvd_auth_string);
    sub->rvd.print("\n");
    sub->rvd.flush();
  }

  // Connect to local service
  sub->local = WiFiClient();
  if (!sub->local.connect(relay->config.local_host, relay->config.local_port)) {
    NOPORTS_LOGE(TAG, "Sub[%d] failed to connect local %s:%d",
                 slot, relay->config.local_host, relay->config.local_port);
    sub->rvd.stop();
    _relay_pcb_count--;  // rvd was counted
    goto sub_fail;
  }
  sub->local.setNoDelay(true);
  _set_sub_sock_bufs(sub->local);
  _relay_pcb_count++;

  sub->active = true;
  sub->last_activity_ms = millis();
  sub->sub_bytes_in = 0;
  sub->sub_bytes_out = 0;
  _update_active_session_count(relay, subs, n_subs);
  NOPORTS_LOGI(TAG, "Sub[%d] active: SRVD <-> %s:%d (sessions=%d, pcbs=%d/%d, heap=%u)",
               slot, relay->config.local_host, relay->config.local_port,
               relay->active_sessions, _relay_pcb_count, MAX_RELAY_PCBS,
               (unsigned)esp_get_free_heap_size());
  return 0;

sub_fail:
  if (sub->encrypted) {
    mbedtls_aes_free(&sub->enc_state.ctx);
    mbedtls_aes_free(&sub->dec_state.ctx);
    sub->encrypted = false;
  }
  return -2;  // permanent: TCP connect failed
}

// Internal: FreeRTOS relay task – dual-connection, poll-both architecture
//
// The NPT client opens 2 connections to SRVD (control + data).
// SRVD pairs connections FIFO. The daemon opens 2 connections too.
// We don't know which daemon connection pairs with which client connection,
// so we poll BOTH for the connect: message. Whichever receives it is the
// control channel; the other becomes the data channel for relay traffic.
// We keep the control channel alive (closing it causes SRVD port teardown).
// Inner function: runs the relay logic. Returns normally so C++ destructors
// (sockA) run. The outer wrapper calls vTaskDelete(NULL) after this returns.
static void _relay_task_inner(NoPortsRelay *relay) {
  uint8_t *buf = (uint8_t *)malloc(RELAY_BUF_SIZE);
  uint8_t *crypt_buf = NULL;

  if (!buf) {
    NOPORTS_LOGE(TAG, "Failed to allocate relay buffer");
    relay->state = RELAY_ERROR;
    return;
  }

  crypt_buf = (uint8_t *)malloc(RELAY_BUF_SIZE);
  if (!crypt_buf) {
    NOPORTS_LOGE(TAG, "Failed to allocate crypto buffer");
    free(buf);
    relay->state = RELAY_ERROR;
    return;
  }

  NOPORTS_LOGI(TAG, "Relay task started: %s:%d <-> %s:%d (free heap: %u)",
               relay->config.rvd_host, relay->config.rvd_port,
               relay->config.local_host, relay->config.local_port,
               (unsigned)esp_get_free_heap_size());

  // Declare ALL variables before any goto (C++ requirement)
  WiFiClient sockA;           // first connection to SRVD
  // sockB = relay->rvd_client  // second connection to SRVD
  WiFiClient *ctrl = NULL;     // whichever gets connect: message
  WiFiClient *data = NULL;     // the other one – used for relay
  aes_ctr_state *ctrl_dec_A = NULL;  // decrypter for sockA if it's ctrl
  aes_ctr_state *ctrl_dec_B = NULL;  // decrypter for rvd_client if it's ctrl
  aes_ctr_state data_enc = {};       // embedded: valid when data_encrypted
  aes_ctr_state data_dec = {};       // embedded: valid when data_encrypted
  bool data_encrypted = false;
  unsigned long idle_since = 0;
  const unsigned long IDLE_TIMEOUT_MS =
      (relay->config.idle_timeout_ms > 0) ? relay->config.idle_timeout_ms : 60000UL;
  unsigned long total_rvd_to_local = 0;
  unsigned long total_local_to_rvd = 0;
  unsigned long last_stats_time = 0;

  // Raw bytes consumed from each socket during Phase 2 polling.
  // The data socket may receive encrypted data before we know which socket
  // is which. We save raw bytes so we can replay them through data_dec later.
  // Heap-allocated to reduce stack pressure (prevents stack overflow).
  uint8_t *earlyA = (uint8_t *)calloc(EARLY_BUF_SIZE, 1);
  uint8_t *earlyB = (uint8_t *)calloc(EARLY_BUF_SIZE, 1);
  int earlyLenA = 0, earlyLenB = 0;

  if (!earlyA || !earlyB) {
    NOPORTS_LOGE(TAG, "Failed to allocate early buffers");
    free(buf);
    free(crypt_buf);
    if (earlyA) free(earlyA);
    if (earlyB) free(earlyB);
    relay->state = RELAY_ERROR;
    return;
  }

  // ======================================================================
  // PHASE 1: Open 2 connections to SRVD, authenticate both
  // ======================================================================
  relay->state = RELAY_CONNECTING;

  NOPORTS_LOGI(TAG, "Connecting to RVD %s:%d (sockA)",
               relay->config.rvd_host, relay->config.rvd_port);
  if (!sockA.connect(relay->config.rvd_host, relay->config.rvd_port)) {
    NOPORTS_LOGE(TAG, "Failed to connect to RVD (sockA)");
    relay->state = RELAY_ERROR;
    goto cleanup;
  }
  _relay_pcb_count++;
  sockA.setNoDelay(true);
  _set_sock_keepalive(sockA.fd());
  NOPORTS_LOGI(TAG, "Connected to RVD (sockA)");

  if (relay->config.escr_auth && relay->config.escr_signing_key &&
      relay->config.relay_auth_aes_key) {
    relay->state = RELAY_AUTHENTICATING;
    if (!_escr_authenticate(&sockA, &relay->config)) {
      NOPORTS_LOGE(TAG, "ESCR auth failed (sockA)");
      relay->state = RELAY_ERROR;
      goto cleanup;
    }
  } else if (relay->config.rv_auth && relay->config.rvd_auth_string) {
    relay->state = RELAY_AUTHENTICATING;
    sockA.print(relay->config.rvd_auth_string);
    sockA.print("\n");
    sockA.flush();
    NOPORTS_LOGI(TAG, "Legacy auth sent (sockA)");
  }

  NOPORTS_LOGI(TAG, "Connecting to RVD %s:%d (sockB)",
               relay->config.rvd_host, relay->config.rvd_port);
  if (!relay->rvd_client.connect(relay->config.rvd_host, relay->config.rvd_port)) {
    NOPORTS_LOGE(TAG, "Failed to connect to RVD (sockB)");
    relay->state = RELAY_ERROR;
    goto cleanup;
  }
  _relay_pcb_count++;
  relay->rvd_client.setNoDelay(true);
  _set_sock_keepalive(relay->rvd_client.fd());
  NOPORTS_LOGI(TAG, "Connected to RVD (sockB)");

  if (relay->config.escr_auth && relay->config.escr_signing_key &&
      relay->config.relay_auth_aes_key) {
    if (!_escr_authenticate(&relay->rvd_client, &relay->config)) {
      NOPORTS_LOGE(TAG, "ESCR auth failed (sockB)");
      relay->state = RELAY_ERROR;
      goto cleanup;
    }
  } else if (relay->config.rv_auth && relay->config.rvd_auth_string) {
    relay->rvd_client.print(relay->config.rvd_auth_string);
    relay->rvd_client.print("\n");
    relay->rvd_client.flush();
    NOPORTS_LOGI(TAG, "Legacy auth sent (sockB)");
  }

  NOPORTS_LOGI(TAG, "Both SRVD connections established");

  // Set up separate decrypters for each socket (so we can try both)
  if (relay->decrypter) {
    // We already have one decrypter (for the connect: message).
    // Create a second one from the same session keys for the other socket.
    ctrl_dec_A = (aes_ctr_state *)relay->decrypter;
    relay->decrypter = NULL;  // take ownership

    // Create duplicate for sockB from the same C2D session keys
    if (relay->config.session_aes_key && relay->config.session_iv) {
      ctrl_dec_B = _alloc_aes_ctr_state(relay->config.session_aes_key,
                                         relay->config.session_iv);
    }
  }

  // ======================================================================
  // PHASE 2: Poll BOTH sockets for the connect: message
  // SRVD FIFO pairing means we don't know which socket pairs with the
  // client's control socket. Read from whichever gets data first.
  // Use separate heap buffers so we don't disturb the relay buffers.
  // ======================================================================
  {
    unsigned long connect_wait_start = millis();
    const unsigned long CONNECT_TIMEOUT_MS = 30000;
    char *cmsgA = (char *)calloc(256, 1);  // connect: msg buffer for sockA
    char *cmsgB = (char *)calloc(256, 1);  // connect: msg buffer for sockB
    if (!cmsgA || !cmsgB) {
      NOPORTS_LOGE(TAG, "Failed to allocate cmsg buffers");
      if (cmsgA) free(cmsgA);
      if (cmsgB) free(cmsgB);
      relay->state = RELAY_ERROR;
      goto cleanup;
    }
    int posA = 0, posB = 0;
    bool got_connect = false;
    char *connect_msg = NULL;

    NOPORTS_LOGI(TAG, "Waiting for connect: on either socket (e2ee=%d)...",
                 ctrl_dec_A != NULL);

    while ((millis() - connect_wait_start) < CONNECT_TIMEOUT_MS && !got_connect) {
      // Check sockA
      if (sockA.connected() && sockA.available() && posA < 254) {
        if (ctrl_dec_A) {
          uint8_t raw, dec;
          if (sockA.read(&raw, 1) == 1) {
            if (earlyLenA < EARLY_BUF_SIZE) earlyA[earlyLenA++] = raw;
            _aes_ctr_crypt(ctrl_dec_A, 1, &raw, &dec);
            cmsgA[posA++] = (char)dec;
            if (dec == '\n') {
              got_connect = true;
              ctrl = &sockA;
              data = &relay->rvd_client;
              connect_msg = cmsgA;
              NOPORTS_LOGI(TAG, "connect: arrived on sockA");
            }
          }
        } else {
          uint8_t b;
          if (sockA.read(&b, 1) == 1) {
            if (earlyLenA < EARLY_BUF_SIZE) earlyA[earlyLenA++] = b;
            cmsgA[posA++] = (char)b;
            if (b == '\n') {
              got_connect = true;
              ctrl = &sockA;
              data = &relay->rvd_client;
              connect_msg = cmsgA;
              NOPORTS_LOGI(TAG, "connect: arrived on sockA (plain)");
            }
          }
        }
        if (got_connect) break;
      }

      // Check sockB (rvd_client)
      if (relay->rvd_client.connected() && relay->rvd_client.available() && posB < 254) {
        if (ctrl_dec_B) {
          uint8_t raw, dec;
          if (relay->rvd_client.read(&raw, 1) == 1) {
            if (earlyLenB < EARLY_BUF_SIZE) earlyB[earlyLenB++] = raw;
            _aes_ctr_crypt(ctrl_dec_B, 1, &raw, &dec);
            cmsgB[posB++] = (char)dec;
            if (dec == '\n') {
              got_connect = true;
              ctrl = &relay->rvd_client;
              data = &sockA;
              connect_msg = cmsgB;
              NOPORTS_LOGI(TAG, "connect: arrived on sockB");
            }
          }
        } else {
          uint8_t b;
          if (relay->rvd_client.read(&b, 1) == 1) {
            if (earlyLenB < EARLY_BUF_SIZE) earlyB[earlyLenB++] = b;
            cmsgB[posB++] = (char)b;
            if (b == '\n') {
              got_connect = true;
              ctrl = &relay->rvd_client;
              data = &sockA;
              connect_msg = cmsgB;
              NOPORTS_LOGI(TAG, "connect: arrived on sockB (plain)");
            }
          }
        }
        if (got_connect) break;
      }

      if (!sockA.connected() && !relay->rvd_client.connected()) {
        NOPORTS_LOGE(TAG, "Both SRVD sockets disconnected while waiting for connect:");
        _free_cmsgs(cmsgA, cmsgB);
        relay->state = RELAY_ERROR;
        goto cleanup;
      }

      vTaskDelay(pdMS_TO_TICKS(20));
    }

    if (!got_connect || !connect_msg) {
      NOPORTS_LOGE(TAG, "Timed out waiting for connect: on both sockets (A=%d B=%d)",
                   posA, posB);
      _free_cmsgs(cmsgA, cmsgB);
      relay->state = RELAY_ERROR;
      goto cleanup;
    }

    // Strip trailing newline
    int cmsg_len = (connect_msg == cmsgA) ? posA : posB;
    if (cmsg_len > 0 && connect_msg[cmsg_len - 1] == '\n')
      connect_msg[cmsg_len - 1] = '\0';
    connect_msg[cmsg_len] = '\0';

    // Do NOT log connect_msg verbatim — it carries the per-session data-channel
    // AES keys and IVs (connect:keyC2D:ivC2D[:keyD2C:ivD2C]). Logging them at the
    // default INFO level would leak the session keys to anyone reading the serial
    // console, defeating the relay's end-to-end encryption. Log length only.
    NOPORTS_LOGI(TAG, "Received connect message (%d bytes)", cmsg_len);

    if (strncmp(connect_msg, "connect:", 8) != 0) {
      NOPORTS_LOGE(TAG, "Invalid connect message (expected 'connect:' prefix)");
      _free_cmsgs(cmsgA, cmsgB);
      relay->state = RELAY_ERROR;
      goto cleanup;
    }

    char *key_start = connect_msg + 8;

    if (strcmp(key_start, "no:encrypt") == 0 || *key_start == '\0') {
      NOPORTS_LOGI(TAG, "No e2ee for data channel, plain relay");
      data_encrypted = false;
    } else {
      // Parse fields: connect:keyC2D:ivC2D[:keyD2C:ivD2C]\n
      // Split on colons to find all fields
      char *fields[4] = {NULL, NULL, NULL, NULL};
      int nfields = 0;
      char *p = key_start;
      fields[nfields++] = p;
      while (*p && nfields < 4) {
        if (*p == ':') {
          *p = '\0';
          fields[nfields++] = p + 1;
        }
        p++;
      }

      if (nfields < 2) {
        NOPORTS_LOGE(TAG, "Invalid connect message (need at least key:iv, got %d fields)", nfields);
        _free_cmsgs(cmsgA, cmsgB);
        relay->state = RELAY_ERROR;
        goto cleanup;
      }

      char *key_c2d = fields[0];
      char *iv_c2d = fields[1];
      char *key_d2c = (nfields >= 4) ? fields[2] : NULL;
      char *iv_d2c = (nfields >= 4) ? fields[3] : NULL;

      NOPORTS_LOGI(TAG, "Data E2EE: keyC2D=%d iv=%d %s",
                   (int)strlen(key_c2d), (int)strlen(iv_c2d),
                   key_d2c ? "TWIN-KEY" : "single-key");

      int enc_res = _create_enc_dec((const unsigned char *)key_c2d,
                                     (const unsigned char *)iv_c2d,
                                     (const unsigned char *)key_d2c,
                                     (const unsigned char *)iv_d2c,
                                     &data_enc, &data_dec);
      if (enc_res != 0) {
        NOPORTS_LOGE(TAG, "Failed to create data channel AES-CTR state");
        _free_cmsgs(cmsgA, cmsgB);
        relay->state = RELAY_ERROR;
        goto cleanup;
      }
      data_encrypted = true;
    }
    _free_cmsgs(cmsgA, cmsgB);
  }

  // ======================================================================
  // PHASE 3: Bridge data socket ↔ local service
  // Keep control socket alive (SRVD tears down port if either side closes)
  // ======================================================================

  // Free control channel decrypters – no longer needed
  if (ctrl_dec_A) {
    mbedtls_aes_free(&ctrl_dec_A->ctx);
    free(ctrl_dec_A);
    ctrl_dec_A = NULL;
  }
  if (ctrl_dec_B) {
    mbedtls_aes_free(&ctrl_dec_B->ctx);
    free(ctrl_dec_B);
    ctrl_dec_B = NULL;
  }
  if (relay->encrypter) {
    mbedtls_aes_free(&((aes_ctr_state *)relay->encrypter)->ctx);
    free(relay->encrypter);
    relay->encrypter = NULL;
  }

  NOPORTS_LOGI(TAG, "Data socket: %s, control kept alive",
               (data == &sockA) ? "sockA" : "sockB");

  // Connect to local service
  NOPORTS_LOGI(TAG, "Connecting to local service %s:%d",
               relay->config.local_host, relay->config.local_port);
  if (!relay->local_client.connect(relay->config.local_host, relay->config.local_port)) {
    NOPORTS_LOGE(TAG, "Failed to connect to local service %s:%d",
                 relay->config.local_host, relay->config.local_port);
    relay->state = RELAY_ERROR;
    goto cleanup;
  }
  _relay_pcb_count++;
  NOPORTS_LOGI(TAG, "Connected to local service (pcbs=%d/%d)",
               _relay_pcb_count, MAX_RELAY_PCBS);
  relay->local_client.setNoDelay(true);
  _set_sock_keepalive(relay->local_client.fd());

  // Replay any early bytes consumed from the data socket during Phase 2.
  // During polling, we read from both sockets not knowing which is data.
  // Those raw bytes were encrypted with the DATA CHANNEL key but we consumed
  // them from the TCP buffer. We must replay them through data_dec so the
  // AES-CTR counter stays in sync with the client.
  {
    uint8_t *early_raw = (data == &relay->rvd_client) ? earlyB : earlyA;
    int early_len = (data == &relay->rvd_client) ? earlyLenB : earlyLenA;
    if (early_len > 0) {
      NOPORTS_LOGI(TAG, "Replaying %d early bytes from data socket", early_len);
      if (data_encrypted) {
        _aes_ctr_crypt(&data_dec, early_len, early_raw, crypt_buf);
        _write_all(&relay->local_client, crypt_buf, early_len);
      } else {
        _write_all(&relay->local_client, early_raw, early_len);
      }
      total_rvd_to_local += early_len;
    }
  }

  relay->state = RELAY_RUNNING;
  relay->start_ms = millis();
  NOPORTS_LOGI(TAG, "Relay running for session %s (e2ee=%d) data=%s",
               relay->config.session_id, data_encrypted,
               (data == &sockA) ? "sockA" : "sockB");

  NOPORTS_LOGI(TAG, "Data: c=%d a=%d | Ctrl: c=%d a=%d",
               data->connected(), data->available(),
               ctrl->connected(), ctrl->available());

  idle_since = millis();
  last_stats_time = millis();

  // Bidirectional relay loop: data ↔ local_client
  while (relay->should_run) {
    bool activity = false;

    // Data socket (RVD) -> Local (with optional decryption)
    if (data->available()) {
      int n = data->read(buf, RELAY_BUF_SIZE);
      if (n > 0) {
        activity = true;
        idle_since = millis();
        total_rvd_to_local += n;
        relay->bytes_in = (uint32_t)total_rvd_to_local;
        if (total_rvd_to_local == (unsigned long)n) {
          NOPORTS_LOGI(TAG, "First RVD->Local: %d bytes", n);
        }
        if (data_encrypted) {
          _aes_ctr_crypt(&data_dec, n, buf, crypt_buf);
          if (!_write_all(&relay->local_client, crypt_buf, n)) {
            NOPORTS_LOGI(TAG, "Local write failed (RVD->Local)");
            break;
          }
        } else {
          if (!_write_all(&relay->local_client, buf, n)) {
            NOPORTS_LOGI(TAG, "Local write failed (RVD->Local)");
            break;
          }
        }
      } else if (n < 0) {
        NOPORTS_LOGI(TAG, "Data read error");
        break;
      }
    }

    // Local -> Data socket (RVD) (with optional encryption)
    if (relay->local_client.available()) {
      int n = relay->local_client.read(buf, RELAY_BUF_SIZE);
      if (n > 0) {
        activity = true;
        idle_since = millis();
        total_local_to_rvd += n;
        relay->bytes_out = (uint32_t)total_local_to_rvd;
        if (total_local_to_rvd == (unsigned long)n) {
          NOPORTS_LOGI(TAG, "First Local->RVD: %d bytes", n);
        }
        if (data_encrypted) {
          _aes_ctr_crypt(&data_enc, n, buf, crypt_buf);
          if (!_write_all(data, crypt_buf, n)) {
            NOPORTS_LOGI(TAG, "Data write failed (Local->RVD)");
            break;
          }
        } else {
          if (!_write_all(data, buf, n)) {
            NOPORTS_LOGI(TAG, "Data write failed (Local->RVD)");
            break;
          }
        }
      } else if (n < 0) {
        NOPORTS_LOGI(TAG, "Local read error");
        break;
      }
    }

    // Drain control channel (heartbeats / keepalive messages)
    // The NPT client sends periodic heartbeats on the control channel.
    // If we don't read them, the TCP receive buffer fills up and SRVD
    // may tear down the port. Read and discard any data.
    if (ctrl && ctrl->available()) {
      int n = ctrl->read(buf, RELAY_BUF_SIZE);
      if (n > 0) {
        activity = true;  // heartbeat counts as activity for idle timeout
        idle_since = millis();
        NOPORTS_LOGD(TAG, "Ctrl channel heartbeat: %d bytes drained", n);
      }
    }

    // Periodic stats
    if ((millis() - last_stats_time) > 10000) {
      NOPORTS_LOGI(TAG, "Stats: R->L %lu, L->R %lu | data(c=%d) ctrl(c=%d) local(c=%d)",
                   total_rvd_to_local, total_local_to_rvd,
                   data->connected(), ctrl->connected(),
                   relay->local_client.connected());
      last_stats_time = millis();
    }

    // Peer-close detection using reliable recv(MSG_PEEK).
    // Only close when all buffered data has been drained (available()==0)
    // so we never discard unread bytes.
    {
      bool data_closed  = !data->available()  && _peer_closed(*data);
      bool local_closed = !relay->local_client.available() && _peer_closed(relay->local_client);
      if (data_closed || local_closed) {
        NOPORTS_LOGI(TAG, "%s closed (R->L %lu, L->R %lu)",
                     data_closed ? "Data" : "Local",
                     total_rvd_to_local, total_local_to_rvd);
        break;
      }
    }

    if ((millis() - idle_since) > IDLE_TIMEOUT_MS) {
      NOPORTS_LOGI(TAG, "Idle timeout (R->L %lu, L->R %lu)",
                   total_rvd_to_local, total_local_to_rvd);
      break;
    }

    // Yield policy: 5 ms — see multi version for rationale (1 sub = N×5 = 5ms).
    vTaskDelay(pdMS_TO_TICKS(5));
  }

cleanup:
  NOPORTS_LOGI(TAG, "Relay stopping session %s (R->L %lu, L->R %lu)",
               relay->config.session_id, total_rvd_to_local, total_local_to_rvd);

  sockA.stop();         _relay_pcb_count--;
  relay->rvd_client.stop(); _relay_pcb_count--;
  relay->local_client.stop(); _relay_pcb_count--;
  if (_relay_pcb_count < 0) _relay_pcb_count = 0;

  // Free control channel decrypters if still allocated (error path)
  if (ctrl_dec_A) {
    mbedtls_aes_free(&ctrl_dec_A->ctx);
    free(ctrl_dec_A);
  }
  if (ctrl_dec_B) {
    mbedtls_aes_free(&ctrl_dec_B->ctx);
    free(ctrl_dec_B);
  }
  if (relay->encrypter) {
    mbedtls_aes_free(&((aes_ctr_state *)relay->encrypter)->ctx);
    free(relay->encrypter);
    relay->encrypter = NULL;
  }
  if (relay->decrypter) {
    mbedtls_aes_free(&((aes_ctr_state *)relay->decrypter)->ctx);
    free(relay->decrypter);
    relay->decrypter = NULL;
  }

  // Free data channel encryption (from connect: message keys)
  if (data_encrypted) {
    mbedtls_aes_free(&data_enc.ctx);
    mbedtls_aes_free(&data_dec.ctx);
  }

  free(buf);
  if (crypt_buf) free(crypt_buf);
  if (earlyA) free(earlyA);
  if (earlyB) free(earlyB);

  if (relay->config.rvd_auth_string) {
    free(relay->config.rvd_auth_string);
    relay->config.rvd_auth_string = NULL;
  }
  if (relay->config.relay_auth_aes_key) {
    _zero_free_key(relay->config.relay_auth_aes_key);
    relay->config.relay_auth_aes_key = NULL;
  }
  if (relay->config.escr_signing_key_uri) {
    free(relay->config.escr_signing_key_uri);
    relay->config.escr_signing_key_uri = NULL;
  }
  // escr_signing_key is NOT freed — owned by the daemon (_pkam_signing_key)
  if (relay->config.rvd_host) {
    free((void *)relay->config.rvd_host);
    relay->config.rvd_host = NULL;
  }
  if (relay->config.local_host) {
    free((void *)relay->config.local_host);
    relay->config.local_host = NULL;
  }
  if (relay->config.session_aes_key) {
    _zero_free_key(relay->config.session_aes_key);
    relay->config.session_aes_key = NULL;
  }
  if (relay->config.session_iv) {
    _zero_free_key(relay->config.session_iv);
    relay->config.session_iv = NULL;
  }
  if (relay->config.session_aes_key_d2c) {
    _zero_free_key(relay->config.session_aes_key_d2c);
    relay->config.session_aes_key_d2c = NULL;
  }
  if (relay->config.session_iv_d2c) {
    _zero_free_key(relay->config.session_iv_d2c);
    relay->config.session_iv_d2c = NULL;
  }

  // Log stack high-water mark for diagnostics
  UBaseType_t hwm = uxTaskGetStackHighWaterMark(NULL);
  NOPORTS_LOGI(TAG, "Relay task stack HWM: %u words (%u bytes free)",
               (unsigned)hwm, (unsigned)(hwm * sizeof(StackType_t)));

  relay->state = RELAY_STOPPED;
  relay->task_handle = NULL;
  // Return from inner function — C++ destructors (sockA) run here.
  // Wrapper function calls vTaskDelete(NULL) after this.
}

// ==========================================================================
// Multi-session relay: one control channel + N data sub-connections.
//
// The Dart sshnpd sends each TCP session through the tunnel as a separate
// "connect:" message on the encrypted control channel.  This mirrors that
// protocol:
//   1. Open ONE connection to SRVD for the control channel
//   2. Listen for connect: messages (each carrying per-session AES keys)
//   3. For each connect: open NEW SRVD + local connections and bridge them
//   4. Relay data for all active sub-connections simultaneously
// ==========================================================================
static void _relay_task_inner_multi(NoPortsRelay *relay) {
  uint8_t *buf = (uint8_t *)malloc(RELAY_BUF_SIZE);
  uint8_t *crypt_buf = (uint8_t *)malloc(RELAY_BUF_SIZE);
  if (!buf || !crypt_buf) {
    NOPORTS_LOGE(TAG, "Multi: failed to allocate buffers");
    relay->state = RELAY_ERROR;
    if (buf) free(buf);
    if (crypt_buf) free(crypt_buf);
    return;
  }

  NOPORTS_LOGI(TAG, "Multi: relay task started (free heap: %u)",
               (unsigned)esp_get_free_heap_size());

  // Early heap guard: running a relay session requires heap for the ctrl
  // socket, up to MAX_RELAY_SUBS×2 TCP sockets, AES contexts, and the
  // daemon's own TLS worker reconnects.  If heap is critically low on
  // entry (e.g. another relay session is still active), bail out now
  // before consuming more resources and crashing TLS allocations.
  if (esp_get_free_heap_size() < 30000) {
    NOPORTS_LOGE(TAG, "Multi: insufficient heap (%u < 30000), aborting relay",
                 (unsigned)esp_get_free_heap_size());
    relay->state = RELAY_ERROR;
    if (buf) free(buf);
    if (crypt_buf) free(crypt_buf);
    return;
  }

  // Sub-connection tracking (heap-allocated so it doesn't consume task stack)
  // Clamp configured max_subs to [1, MAX_RELAY_SUBS]; 0 = use default.
  int n_subs = (relay->config.max_subs >= 1 && relay->config.max_subs <= MAX_RELAY_SUBS)
               ? (int)relay->config.max_subs : MAX_RELAY_SUBS;
  RelaySub *subs = (RelaySub *)calloc(n_subs, sizeof(RelaySub));
  if (!subs) {
    NOPORTS_LOGE(TAG, "Multi: failed to allocate subs array");
    relay->state = RELAY_ERROR;
    free(buf);
    free(crypt_buf);
    return;
  }
  for (int i = 0; i < n_subs; i++) {
    new (&subs[i]) RelaySub();  // placement-new: run WiFiClient constructors
    subs[i].active = false;
    subs[i].encrypted = false;
    subs[i].draining = false;
  }
  relay->active_sessions = 0;

  // --- Declare ALL variables before any goto (C++ requirement) ---
  WiFiClient ctrl;
  aes_ctr_state *ctrl_dec = NULL;
  char ctrl_msg[384];
  int ctrl_msg_pos = 0;
  unsigned long idle_since = 0;
  unsigned long last_stats_time = 0;
  bool ctrl_lost = false;            // control channel lost, draining subs
  unsigned long ctrl_lost_since = 0; // when ctrl was lost
  const unsigned long DRAIN_TIMEOUT_MS = 15000UL; // max time to drain after ctrl lost
  int consecutive_connect_fails = 0;     // diagnostic tracking
  const unsigned long IDLE_TIMEOUT_MS =
      (relay->config.idle_timeout_ms > 0) ? relay->config.idle_timeout_ms : 60000UL;



  // ==================================================================
  // PHASE 1: Open control connection to SRVD, authenticate
  // ==================================================================
  relay->state = RELAY_CONNECTING;

  NOPORTS_LOGI(TAG, "Multi: connecting control to SRVD %s:%d",
               relay->config.rvd_host, relay->config.rvd_port);
  if (!ctrl.connect(relay->config.rvd_host, relay->config.rvd_port)) {
    NOPORTS_LOGE(TAG, "Multi: failed to connect control channel");
    relay->state = RELAY_ERROR;
    goto cleanup;
  }
  _relay_pcb_count++;
  ctrl.setNoDelay(true);
  _set_sock_keepalive(ctrl.fd());
  NOPORTS_LOGI(TAG, "Multi: control channel connected (pcbs=%d/%d)",
               _relay_pcb_count, MAX_RELAY_PCBS);

  if (relay->config.escr_auth && relay->config.escr_signing_key &&
      relay->config.relay_auth_aes_key) {
    relay->state = RELAY_AUTHENTICATING;
    if (!_escr_authenticate(&ctrl, &relay->config)) {
      NOPORTS_LOGE(TAG, "Multi: ESCR auth failed on control channel");
      relay->state = RELAY_ERROR;
      goto cleanup;
    }
  } else if (relay->config.rv_auth && relay->config.rvd_auth_string) {
    relay->state = RELAY_AUTHENTICATING;
    ctrl.print(relay->config.rvd_auth_string);
    ctrl.print("\n");
    ctrl.flush();
    NOPORTS_LOGI(TAG, "Multi: legacy auth sent on control channel");
  }

  // Take ownership of control channel decrypter
  if (relay->decrypter) {
    ctrl_dec = (aes_ctr_state *)relay->decrypter;
    relay->decrypter = NULL;
  }
  // Free control-channel encrypter if set (daemon doesn't write to ctrl)
  if (relay->encrypter) {
    mbedtls_aes_free(&((aes_ctr_state *)relay->encrypter)->ctx);
    free(relay->encrypter);
    relay->encrypter = NULL;
  }

  relay->state = RELAY_RUNNING;
  relay->start_ms = millis();
  idle_since = millis();
  last_stats_time = millis();

  NOPORTS_LOGI(TAG, "Multi: relay running session %s (ctrl e2ee=%d)",
               relay->config.session_id, ctrl_dec != NULL);

  // ==================================================================
  // PHASE 2: Main loop - control messages + relay sub-connections
  // ==================================================================
  while (relay->should_run) {
    bool activity = false;

    // --- Read control channel, parse line-delimited messages ---
    // Use available() only — ctrl.connected() is unreliable on ESP32.
    // If the control channel is truly gone, _peer_closed() will catch
    // it in the ctrl_lost detection below.
    while (ctrl.available()) {
      uint8_t raw;
      if (ctrl.read(&raw, 1) != 1) break;

      uint8_t decoded = raw;
      if (ctrl_dec) {
        _aes_ctr_crypt(ctrl_dec, 1, &raw, &decoded);
      }

      if (decoded == '\n') {
        ctrl_msg[ctrl_msg_pos] = '\0';
        if (ctrl_msg_pos > 0) {
          if (strncmp(ctrl_msg, "connect:", 8) == 0) {
            NOPORTS_LOGI(TAG, "Multi: connect request received");
            int rc = _handle_connect_msg(relay, subs, n_subs, ctrl_msg);
            if (rc != 0) {
              // _handle_connect_msg already rejected via SRVD if needed
              consecutive_connect_fails++;
            } else {
              consecutive_connect_fails = 0;
            }
            idle_since = millis();
            activity = true;
            // Break out of ctrl read loop so existing subs get relay
            // time before we process the next connect: message.
            ctrl_msg_pos = 0;
            break;
          } else if (strncmp(ctrl_msg, "heartbeat:", 10) == 0) {
            NOPORTS_LOGD(TAG, "Multi: heartbeat");
            idle_since = millis();
            activity = true;
          } else {
            // Never log the message body: after a CTR keystream desync a
            // corrupted connect: line (which carries session keys) can land
            // here, so dumping it verbatim would leak key material. Length only.
            NOPORTS_LOGW(TAG, "Multi: unknown ctrl msg (%d bytes)", ctrl_msg_pos);
          }
        }
        ctrl_msg_pos = 0;
      } else if (ctrl_msg_pos < (int)sizeof(ctrl_msg) - 1) {
        ctrl_msg[ctrl_msg_pos++] = (char)decoded;
      }
    }

    // --- Relay data for all active sub-connections ---
    for (int i = 0; i < n_subs; i++) {
      // Non-blocking drain state machine.
      // When a peer sends FIN we enter draining=true and do ONE pass of
      // buffer-flushing per main-loop iteration, then continue to the next
      // sub so all other subs (SSH etc.) stay fully serviced.
      //
      // Close policy: close immediately when nothing moved on a pass
      // (all buffered data has been forwarded), or on any write error.
      // No quiet timer — a FIN means that side is done; any bytes it
      // sent are already in lwIP's receive buffer and will be drained
      // within a few loop iterations.  The 30s hard cap is a safety net
      // only for genuinely stuck connections.
      if (subs[i].active && subs[i].draining) {
        // Close condition: both sides have sent FIN AND buffers are empty.
        // If nothing moved but one side is still open (server still responding),
        // keep polling — the non-blocking design means we yield to other subs
        // every iteration at zero cost.
        // Hard timeout guards against servers that never respond.
        const unsigned long PEER_DRAIN_MAX_MS = 10000UL; // give up after 10s
        unsigned long now_d = millis();
        bool done = false;
        if ((now_d - subs[i].drain_start_ms) >= PEER_DRAIN_MAX_MS) {
          NOPORTS_LOGI(TAG, "Sub[%d] drain cap reached (%lums)", i,
                       now_d - subs[i].drain_start_ms);
          done = true;
        } else {
          bool moved = false;
          // rvd → local (request tail bytes still in receive buffer)
          // Non-blocking: flush pending_local first, read new data only when clear.
          if (subs[i].pending_local_len > 0) {
            int _wl = _write_nb(subs[i].local, subs[i].pending_local,
                                subs[i].pending_local_len);
            if (_wl < 0) { done = true; }
            else if (_wl > 0) {
              size_t w = (size_t)_wl;
              if (w < (size_t)subs[i].pending_local_len)
                memmove(subs[i].pending_local, subs[i].pending_local + w,
                        subs[i].pending_local_len - (int)w);
              subs[i].pending_local_len -= (int)w;
              moved = true; activity = true;
            }
          }
          if (!done && subs[i].pending_local_len == 0 && subs[i].rvd.available()) {
            int n = subs[i].rvd.read(buf, RELAY_CHUNK_SIZE);
            if (n > 0) {
              relay->bytes_in += n;
              subs[i].sub_bytes_in += n;
              const uint8_t *to_send = buf;
              if (subs[i].encrypted) {
                _aes_ctr_crypt(&subs[i].dec_state, n, buf, crypt_buf);
                to_send = crypt_buf;
              }
              int _wl = _write_nb(subs[i].local, to_send, n);
              if (_wl < 0) { done = true; }
              else {
                size_t w = (size_t)(_wl > 0 ? _wl : 0);
                if ((int)w < n) {
                  subs[i].pending_local_len = n - (int)w;
                  memcpy(subs[i].pending_local, to_send + w, n - (int)w);
                }
              }
              moved = true; activity = true;
            }
          }
          // local → rvd (response bytes still in receive buffer)
          // Non-blocking single-shot write: flush pending_rvd first, then
          // read new data only when the pending buffer is clear.
          if (!done) {
            // Step 1: flush leftover bytes from a prior iteration.
            if (subs[i].pending_rvd_len > 0) {
              int _wr = _write_nb(subs[i].rvd, subs[i].pending_rvd,
                                  subs[i].pending_rvd_len);
              if (_wr < 0) { done = true; }
              else if (_wr > 0) {
                size_t w = (size_t)_wr;
                if (w < (size_t)subs[i].pending_rvd_len)
                  memmove(subs[i].pending_rvd, subs[i].pending_rvd + w,
                          subs[i].pending_rvd_len - (int)w);
                subs[i].pending_rvd_len -= (int)w;
                moved = true; activity = true;
              }
            }
            // Step 2: read new data only once pending is cleared.
            if (!done && subs[i].pending_rvd_len == 0 &&
                subs[i].local.available()) {
              int n = subs[i].local.read(buf, RELAY_CHUNK_SIZE);
              if (n > 0) {
                relay->bytes_out += n;
                subs[i].sub_bytes_out += n;
                const uint8_t *to_send = buf;
                if (subs[i].encrypted) {
                  _aes_ctr_crypt(&subs[i].enc_state, n, buf, crypt_buf);
                  to_send = crypt_buf;
                }
                int _wr = _write_nb(subs[i].rvd, to_send, n);
                if (_wr < 0) { done = true; }
                else {
                  size_t w = (size_t)(_wr > 0 ? _wr : 0);
                  if ((int)w < n) {
                    subs[i].pending_rvd_len = n - (int)w;
                    memcpy(subs[i].pending_rvd, to_send + w, n - (int)w);
                  }
                }
                moved = true; activity = true;
              }
            }
          }
          // Nothing moved this pass: close if local (the service) has closed
          // and its buffer is empty — all data has been forwarded.
          // We do NOT wait for rvd (NPT client) to close: HTTP/1.1 keep-alive
          // keeps that side open indefinitely, which would stall the slot for
          // up to PEER_DRAIN_MAX_MS and block new connections (SSH etc.).
          // Once the service has finished speaking, we are done.
          if (!done && !moved) {
            bool local_gone = !subs[i].local.available() && _peer_closed(subs[i].local);
            if (local_gone) done = true;
            // else: server still sending response — keep polling (non-blocking)
          }
        }
        if (done) {
          NOPORTS_LOGI(TAG, "Sub[%d] drain done (%lums)", i,
                       millis() - subs[i].drain_start_ms);
          _close_relay_sub(&subs[i], i);
        }
        continue; // always: don't run normal relay for a draining sub
      }

      if (!subs[i].active) continue;

      // Bidirectional relay — direction-fair.
      // dir_flip alternates which direction is serviced first each pass.
      // Without this, a download flood (rvd→local) always leaves
      // upload (local→rvd — keystrokes, SCP acks) waiting one extra
      // full loop iteration before getting a turn.
      // _d==0 serves the "first" direction; _d==1 serves the other.
      // The loop exits early if the sub becomes inactive mid-pass.
      for (int _d = 0; _d < 2 && subs[i].active; _d++) {
        if ((_d == 0) != subs[i].dir_flip) {
          // SRVD → local (decrypt + non-blocking single-shot write)
          // Flush pending_local first; read new rvd data only when clear.
          {
            // Step 1: flush leftover bytes from last iteration.
            if (subs[i].pending_local_len > 0) {
              int _wl = _write_nb(subs[i].local, subs[i].pending_local,
                                  subs[i].pending_local_len);
              if (_wl < 0) {
                NOPORTS_LOGE(TAG, "Sub[%d] local write error, draining", i);
                subs[i].draining = true; subs[i].drain_start_ms = millis();
              } else if (_wl > 0) {
                size_t w = (size_t)_wl;
                if (w < (size_t)subs[i].pending_local_len)
                  memmove(subs[i].pending_local, subs[i].pending_local + w,
                          subs[i].pending_local_len - (int)w);
                subs[i].pending_local_len -= (int)w;
                activity = true;
                idle_since = millis();
                subs[i].last_activity_ms = millis();
              }
              // Local socket still full → skip reading more rvd data this pass.
            }
            // Step 2: read new data only when pending is fully flushed.
            // Always drain receive buffers regardless of heap level — not
            // reading frees NO pbufs (they stay allocated until consumed),
            // so withholding reads deadlocks: heap never recovers because
            // the pbufs never get freed.  The pending_local guard above
            // already provides natural back-pressure (we stop reading once
            // the pending buffer is non-empty).
            if (subs[i].pending_local_len == 0 && subs[i].rvd.available()) {
              int n = subs[i].rvd.read(buf, RELAY_CHUNK_SIZE);
              if (n > 0) {
                const uint8_t *to_send = buf;
                if (subs[i].encrypted) {
                  _aes_ctr_crypt(&subs[i].dec_state, n, buf, crypt_buf);
                  to_send = crypt_buf;
                }
                int _wl = _write_nb(subs[i].local, to_send, n);
                if (_wl < 0) {
                  NOPORTS_LOGE(TAG, "Sub[%d] local write error, draining", i);
                  subs[i].draining = true; subs[i].drain_start_ms = millis();
                } else {
                  size_t w = (size_t)(_wl > 0 ? _wl : 0);
                  relay->bytes_in += n;
                  subs[i].sub_bytes_in += n;
                  activity = true;
                  idle_since = millis();
                  subs[i].last_activity_ms = millis();
                  if ((int)w < n) {
                    subs[i].pending_local_len = n - (int)w;
                    memcpy(subs[i].pending_local, to_send + w, n - (int)w);
                  }
                }
              }
            }
          }
        } else {
          // local → SRVD (encrypt + non-blocking single-shot write)
          // Flush pending_rvd first; read new local data only when clear.
          {
            // Step 1: flush leftover bytes from last iteration.
            if (subs[i].pending_rvd_len > 0) {
              int _wr = _write_nb(subs[i].rvd, subs[i].pending_rvd,
                                  subs[i].pending_rvd_len);
              if (_wr < 0) {
                NOPORTS_LOGE(TAG, "Sub[%d] rvd write error, draining", i);
                subs[i].draining = true; subs[i].drain_start_ms = millis();
              } else if (_wr > 0) {
                size_t w = (size_t)_wr;
                if (w < (size_t)subs[i].pending_rvd_len)
                  memmove(subs[i].pending_rvd, subs[i].pending_rvd + w,
                          subs[i].pending_rvd_len - (int)w);
                subs[i].pending_rvd_len -= (int)w;
                activity = true;
                idle_since = millis();
                subs[i].last_activity_ms = millis();
              }
              // Send buffer still full → skip reading more this pass.
            }
            // Step 2: read new data only when pending is fully flushed.
            // Same reasoning as rvd→local: always drain to free pbufs.
            if (subs[i].pending_rvd_len == 0 && subs[i].local.available()) {
              int n = subs[i].local.read(buf, RELAY_CHUNK_SIZE);
              if (n > 0) {
                const uint8_t *to_send = buf;
                if (subs[i].encrypted) {
                  _aes_ctr_crypt(&subs[i].enc_state, n, buf, crypt_buf);
                  to_send = crypt_buf;
                }
                int _wr = _write_nb(subs[i].rvd, to_send, n);
                if (_wr < 0) {
                  NOPORTS_LOGE(TAG, "Sub[%d] rvd write error, draining", i);
                  subs[i].draining = true; subs[i].drain_start_ms = millis();
                } else {
                  size_t w = (size_t)(_wr > 0 ? _wr : 0);
                  relay->bytes_out += n;
                  subs[i].sub_bytes_out += n;
                  activity = true;
                  idle_since = millis();
                  subs[i].last_activity_ms = millis();
                  if ((int)w < n) {
                    // TCP send buffer couldn't absorb all bytes; stash remainder.
                    subs[i].pending_rvd_len = n - (int)w;
                    memcpy(subs[i].pending_rvd, to_send + w, n - (int)w);
                  }
                }
              }
            }
          }
        }
      }
      subs[i].dir_flip = !subs[i].dir_flip;

      if (!subs[i].active) continue;

      // Peer-close detection using reliable recv(MSG_PEEK).
      // When EITHER side sends FIN, close both ends immediately so
      // the opposite peer (NPT or local service) receives the FIN
      // without any delay.
      //
      // Previously this entered a non-blocking drain state, but that
      // caused the NPT to hang: when local (host service) closed its
      // connection, the relay kept trying to forward buffered rvd→local
      // data to the (CLOSE_WAIT) local socket.  Writes often succeeded
      // because TCP still accepts the bytes, so `moved` stayed true for
      // many iterations and the `done` condition was never reached until
      // the 10s hard cap — leaving NPT waiting with no FIN for up to 10s.
      //
      // The pending_local / pending_rvd buffers only hold partial writes
      // from the current iteration; at the point a FIN is detected
      // local.available()==0 guarantees the receive buffer is empty, so
      // there is nothing useful left to drain.  Closing both sides
      // immediately is safe and matches the single-relay cleanup path.
      {
        bool rvd_closed   = !subs[i].rvd.available()   && _peer_closed(subs[i].rvd);
        bool local_closed = !subs[i].local.available() && _peer_closed(subs[i].local);
        if (rvd_closed || local_closed) {
          NOPORTS_LOGI(TAG, "Sub[%d] closing immediately (%s%s closed)", i,
                       rvd_closed   ? "rvd"   : "",
                       local_closed ? (rvd_closed ? "+local" : "local") : "");
          _close_relay_sub(&subs[i], i);
          continue;
        }
      }

      // Stall detection: close sub if no data in either direction for too long.
      // Catches cases where TCP keepalive hasn't fired but peer is gone.
      if ((millis() - subs[i].last_activity_ms) > SUB_STALL_TIMEOUT_MS) {
        NOPORTS_LOGW(TAG, "Sub[%d] stalled for %lus, closing",
                     i, (millis() - subs[i].last_activity_ms) / 1000UL);
        _close_relay_sub(&subs[i], i);
        continue;
      }
    }

    // Update session count (visible to daemon/UI)
    _update_active_session_count(relay, subs, n_subs);

    // --- Periodic stats ---
    if ((millis() - last_stats_time) > 10000) {
      NOPORTS_LOGI(TAG, "Multi: subs=%d pcbs=%d/%d in=%u out=%u heap=%u",
                   relay->active_sessions,
                   _relay_pcb_count, MAX_RELAY_PCBS,
                   (unsigned)relay->bytes_in,
                   (unsigned)relay->bytes_out,
                   (unsigned)esp_get_free_heap_size());
      last_stats_time = millis();
    }

    // --- Control channel lost ---
    if (!ctrl_lost && !ctrl.available() && _peer_closed(ctrl)) {
      ctrl_lost = true;
      ctrl_lost_since = millis();
      if (relay->active_sessions == 0) {
        NOPORTS_LOGI(TAG, "Multi: control lost + no active subs, exiting");
        break;
      }
      NOPORTS_LOGI(TAG, "Multi: control lost, draining %d subs (max %lums)",
                   relay->active_sessions, DRAIN_TIMEOUT_MS);
    }

    // --- Drain timeout: ctrl lost and subs still lingering ---
    if (ctrl_lost) {
      if (relay->active_sessions == 0) {
        NOPORTS_LOGI(TAG, "Multi: all subs drained after ctrl lost, exiting");
        break;
      }
      if ((millis() - ctrl_lost_since) > DRAIN_TIMEOUT_MS) {
        NOPORTS_LOGW(TAG, "Multi: drain timeout, force-closing %d subs",
                     relay->active_sessions);
        break;
      }
    }

    // --- Idle timeout ---
    // Only fires when there are NO active sub-connections.  Once subs are
    // established they own their own lifecycle: stall detection after
    // SUB_STALL_TIMEOUT_MS (15 min) and peer-close detection via _peer_closed().
    // Applying the idle timeout while subs are active would kill a live SSH
    // session just because TCP flow-control caused a gap ≥30 s (e.g. a large
    // file transfer paced by a slow receiver puts write() into back-pressure
    // for tens of seconds without any bytes actually moving in the relay loop).
    // When all subs have gone, the per-session idle timer kicks back in so
    // an abandoned NPT session (connected but never re-opened a sub after the
    // last one closed) still gets reaped after IDLE_TIMEOUT_MS.
    if (relay->active_sessions == 0 && (millis() - idle_since) > IDLE_TIMEOUT_MS) {
      NOPORTS_LOGI(TAG, "Multi: idle timeout (%lu ms, no active subs)", IDLE_TIMEOUT_MS);
      break;
    }

    // Heap-floor OOM management.
    //
    // Only fires when heap is truly exhausted (< HEAP_OOM_FLOOR = 20 KB).
    // Normal burst dips with 2-3 sessions (~28-36 KB floor) do NOT trigger
    // this — those are temporary and self-resolve once pbufs drain.
    //
    //   HEAP_OOM_FLOOR (20 KB): back-pressure — sleep 50 ms to let
    //     tcpip_thread ACK and free in-flight pbufs.
    //
    //   HEAP_CRITICAL_LOW (15 KB): also evict the oldest active sub
    //     immediately (any idle time) to free 2 PCB slots + pending buffers.
    {
      uint32_t cur_heap = esp_get_free_heap_size();
      if (cur_heap < HEAP_OOM_FLOOR) {
        _relay_oom_mode = true;
        if (cur_heap < HEAP_CRITICAL_LOW) {
          // Evict oldest active sub regardless of idle time at CRITICAL_LOW
          int victim = _find_oldest_active_sub(subs, n_subs, CRITICAL_MIN_IDLE_MS);
          if (victim < 0) victim = _find_evictable_sub(subs, n_subs);
          if (victim >= 0) {
            NOPORTS_LOGW(TAG, "CRITICAL evict Sub[%d] (heap=%u < %u, idle=%lums — freeing for TLS)",
                         victim, (unsigned)cur_heap, HEAP_CRITICAL_LOW,
                         millis() - subs[victim].last_activity_ms);
            _close_relay_sub(&subs[victim], victim);
          } else {
            NOPORTS_LOGD(TAG, "CRITICAL back-pressure: heap=%u < %u — all subs active, draining",
                         (unsigned)cur_heap, HEAP_CRITICAL_LOW);
          }
        } else {
          // OOM floor: back-pressure only
          NOPORTS_LOGD(TAG, "OOM back-pressure: heap=%u < %u — draining pbufs",
                       (unsigned)cur_heap, HEAP_OOM_FLOOR);
        }
        vTaskDelay(pdMS_TO_TICKS(50));
      } else {
        _relay_oom_mode = false;
      }
    }

    // Yield policy: keyed on whether THIS iteration moved data.
    //
    // Why not the old "15ms window" heuristic:
    //   TCP pacing on a 100ms RTT link (SRVD) creates natural silent gaps
    //   >15ms between bursts.  The window triggers "idle" backoff exactly
    //   when we are waiting for the next burst — adding 5×N ms of latency
    //   at the worst possible time.
    //
    // Why not scaling active delay by sub count:
    //   More subs = more work/iteration (2×1460 bytes per sub per pass).
    //   Scaling the active delay UP with sub count is backwards.
    //
    // Current policy:
    //   Data moved this pass → 1ms yield (tcpip_thread needs one tick to
    //     ACK and free pbufs; skipping this causes heap pressure under load).
    //   Nothing moved this pass → 3ms × sub_count yield (yield CPU and
    //     WiFi driver when the link truly has no data; 3ms per active sub
    //     keeps the idle burn reasonable without adding latency on next burst).
    //
    // Note: ESP32 WiFi throughput is ~2 MB/s (16 Mbps) *total* bidirectional.
    // The relay forwards traffic in both directions simultaneously, so each byte
    // traverses the WiFi link twice (in + out).  Effective relay throughput
    // ceiling is therefore ~1 MB/s per direction (~125 KB/s).
    // At that rate, one 2920-byte chunk arrives every ~23 ms when fully loaded,
    // so idle iterations are short gaps between bursts — 3ms×_s keeps
    // tcpip_thread well-fed without burning CPU.
    int _s = relay->active_sessions > 0 ? relay->active_sessions : 1;
    if (_s > 4) _s = 4;
    if (activity)
      vTaskDelay(pdMS_TO_TICKS(1));          // minimal: let tcpip_thread ACK
    else
      vTaskDelay(pdMS_TO_TICKS(_s * 3));     // idle: yield proportional to load

    // --- Relay CPU busyness tracking (1-second rolling window, time-weighted) ---
    // Weight each iteration by its nominal delay so that a 3ms idle iter and a
    // 1ms busy iter contribute their actual share of wall-clock time.  The result
    // is the fraction of the second spent actively forwarding data (0-100%).
    {
      uint32_t iter_ms = activity ? 1u : (uint32_t)(_s * 3);
      _relay_total_ms += iter_ms;
      if (activity) _relay_busy_ms += iter_ms;
      uint32_t _now = millis();
      if (_now - _relay_cpu_win_ms >= 1000) {
        uint32_t t = _relay_total_ms;
        uint8_t  p = (uint8_t)(t > 0 ? (_relay_busy_ms * 100u / t) : 0u);
        if (p > 100) p = 100;
        _relay_cpu_pct  = p;
        _relay_busy_ms  = 0;
        _relay_total_ms = 0;
        _relay_cpu_win_ms = _now;
      }
    }
  }

cleanup:
  NOPORTS_LOGI(TAG, "Multi: stopping session %s (in=%u out=%u)",
               relay->config.session_id,
               (unsigned)relay->bytes_in,
               (unsigned)relay->bytes_out);

  // Close all active sub-connections
  for (int i = 0; i < n_subs; i++) {
    if (subs[i].active) {
      _close_relay_sub(&subs[i], i);
    }
  }
  relay->active_sessions = 0;

  // Close control channel
  ctrl.stop();
  _relay_pcb_count--;
  if (_relay_pcb_count < 0) _relay_pcb_count = 0;
  NOPORTS_LOGI(TAG, "Multi: cleanup done (pcbs=%d)", _relay_pcb_count);
  if (ctrl_dec) {
    mbedtls_aes_free(&ctrl_dec->ctx);
    free(ctrl_dec);
  }

  // Free relay enc/dec if not already consumed
  if (relay->encrypter) {
    mbedtls_aes_free(&((aes_ctr_state *)relay->encrypter)->ctx);
    free(relay->encrypter);
    relay->encrypter = NULL;
  }
  if (relay->decrypter) {
    mbedtls_aes_free(&((aes_ctr_state *)relay->decrypter)->ctx);
    free(relay->decrypter);
    relay->decrypter = NULL;
  }

  free(buf);
  free(crypt_buf);
  // Explicitly destroy RelaySub objects (WiFiClient dtors) then free heap block.
  if (subs) {
    for (int i = 0; i < n_subs; i++) subs[i].~RelaySub();
    free(subs);
  }

  if (relay->config.rvd_auth_string) {
    free(relay->config.rvd_auth_string);
    relay->config.rvd_auth_string = NULL;
  }
  if (relay->config.relay_auth_aes_key) {
    _zero_free_key(relay->config.relay_auth_aes_key);
    relay->config.relay_auth_aes_key = NULL;
  }
  if (relay->config.escr_signing_key_uri) {
    free(relay->config.escr_signing_key_uri);
    relay->config.escr_signing_key_uri = NULL;
  }
  // escr_signing_key is NOT freed — owned by the daemon (_pkam_signing_key)
  if (relay->config.rvd_host) {
    free((void *)relay->config.rvd_host);
    relay->config.rvd_host = NULL;
  }
  if (relay->config.local_host) {
    free((void *)relay->config.local_host);
    relay->config.local_host = NULL;
  }
  if (relay->config.session_aes_key) {
    _zero_free_key(relay->config.session_aes_key);
    relay->config.session_aes_key = NULL;
  }
  if (relay->config.session_iv) {
    _zero_free_key(relay->config.session_iv);
    relay->config.session_iv = NULL;
  }
  if (relay->config.session_aes_key_d2c) {
    _zero_free_key(relay->config.session_aes_key_d2c);
    relay->config.session_aes_key_d2c = NULL;
  }
  if (relay->config.session_iv_d2c) {
    _zero_free_key(relay->config.session_iv_d2c);
    relay->config.session_iv_d2c = NULL;
  }

  UBaseType_t hwm = uxTaskGetStackHighWaterMark(NULL);
  NOPORTS_LOGI(TAG, "Multi: stack HWM: %u words (%u bytes free)",
               (unsigned)hwm, (unsigned)(hwm * sizeof(StackType_t)));

  relay->state = RELAY_STOPPED;
  relay->task_handle = NULL;

  // Reset CPU tracking so dashboard shows 0% after this session ends.
  _relay_busy_ms  = 0;
  _relay_total_ms = 0;
  _relay_cpu_pct  = 0;
}

// FreeRTOS task entry point: calls inner function then deletes task.
// Split so that C++ stack objects (WiFiClient sockA) get their destructors
// called when the inner function returns, before the task stack is freed.
static void _relay_task(void *pvParameters) {
  NoPortsRelay *relay = (NoPortsRelay *)pvParameters;
  if (relay->config.multi) {
    _relay_task_inner_multi(relay);
  } else {
    _relay_task_inner(relay);
  }
  vTaskDelete(NULL);
}

uint8_t noports_relay_subs_for_clients(uint8_t n_clients) {
  if (n_clients < 1) n_clients = 1;
  int n = (MAX_RELAY_PCBS - (int)n_clients) / ((int)n_clients * 2);
  if (n < 1) n = 1;
  if (n > MAX_RELAY_SUBS) n = MAX_RELAY_SUBS;
  return (uint8_t)n;
}

void noports_relay_config_init(NoPortsRelayConfig *cfg) {
  memset(cfg, 0, sizeof(NoPortsRelayConfig));
  cfg->local_host = "127.0.0.1";
  cfg->local_port = 0;
  cfg->rv_auth = false;
  cfg->rv_e2ee = false;
  cfg->multi = false;
  cfg->max_subs = 0;  // 0 = use MAX_RELAY_SUBS default
}

int noports_relay_start(NoPortsRelay *relay, const NoPortsRelayConfig *config) {
  if (!relay || !config) return -1;

  // Reset WiFiClient objects to clean state (important when reusing a relay slot)
  relay->rvd_client = WiFiClient();
  relay->local_client = WiFiClient();

  memcpy(&relay->config, config, sizeof(NoPortsRelayConfig));

  // Deep-copy string pointers so the relay owns them
  // (the originals may be freed by cJSON_Delete before the task uses them)
  if (config->rvd_host) relay->config.rvd_host = strdup(config->rvd_host);
  if (config->local_host) relay->config.local_host = strdup(config->local_host);
  if (config->relay_auth_aes_key)
    relay->config.relay_auth_aes_key = strdup(config->relay_auth_aes_key);
  if (config->escr_signing_key_uri)
    relay->config.escr_signing_key_uri = strdup(config->escr_signing_key_uri);
  // escr_signing_key is a pointer to daemon-owned key — copy the pointer only

  relay->state = RELAY_IDLE;
  relay->should_run = true;
  relay->bytes_in = 0;
  relay->bytes_out = 0;
  relay->start_ms = 0;
  relay->encrypter = NULL;
  relay->decrypter = NULL;

  // Set up control channel decrypter from daemon-generated session keys.
  // This is used to decrypt the client's connect: message on the control channel.
  // The data channel uses separate keys from the connect: message itself.
  // Control channel uses C2D key for decrypting (client encrypts with C2D).
  if (config->rv_e2ee && config->session_aes_key && config->session_iv) {
    aes_ctr_state *dec = _alloc_aes_ctr_state(config->session_aes_key, config->session_iv);
    if (!dec) {
      NOPORTS_LOGE(TAG, "Failed to setup control channel decrypter");
      return -1;
    }
    relay->decrypter = dec;  // used to decrypt incoming connect: message
    relay->encrypter = NULL; // not needed for control channel
  }

  // Create FreeRTOS task (replaces fork() from C sshnpd)
  BaseType_t ret = xTaskCreatePinnedToCore(
    _relay_task,
    "np_relay",
    RELAY_TASK_STACK_SIZE,
    relay,
    5,                    // priority (higher = less starvation from other tasks)
    &relay->task_handle,
    1                     // core 1 (keep core 0 for WiFi)
  );

  if (ret != pdPASS) {
    NOPORTS_LOGE(TAG, "Failed to create relay task (stack=%d, free heap=%u)",
                 RELAY_TASK_STACK_SIZE, (unsigned)esp_get_free_heap_size());
    if (relay->encrypter) {
      mbedtls_aes_free(&((aes_ctr_state *)relay->encrypter)->ctx);
      free(relay->encrypter);
      relay->encrypter = NULL;
    }
    if (relay->decrypter) {
      mbedtls_aes_free(&((aes_ctr_state *)relay->decrypter)->ctx);
      free(relay->decrypter);
      relay->decrypter = NULL;
    }
    // The task never ran, so its teardown will not free the copies made above.
    // Free them here so the caller only has to free its own originals. Only the
    // strdup'd copies are freed — session_aes_key/iv and rvd_auth_string are the
    // caller's pointers (shallow-copied via memcpy) and remain caller-owned.
    if (relay->config.rvd_host) {
      free((void *)relay->config.rvd_host);
      relay->config.rvd_host = NULL;
    }
    if (relay->config.local_host) {
      free((void *)relay->config.local_host);
      relay->config.local_host = NULL;
    }
    if (relay->config.relay_auth_aes_key) {
      _zero_free_key(relay->config.relay_auth_aes_key);
      relay->config.relay_auth_aes_key = NULL;
    }
    if (relay->config.escr_signing_key_uri) {
      free(relay->config.escr_signing_key_uri);
      relay->config.escr_signing_key_uri = NULL;
    }
    return -1;
  }

  return 0;
}

void noports_relay_stop(NoPortsRelay *relay) {
  if (!relay) return;
  relay->should_run = false;
  // The task will clean up and delete itself
}

int noports_relay_get_pcb_count() { return _relay_pcb_count; }

int noports_relay_get_pcb_max() { return MAX_RELAY_PCBS; }

uint8_t noports_relay_get_cpu_pct() { return _relay_cpu_pct; }

bool noports_relay_is_running(const NoPortsRelay *relay) {
  if (!relay) return false;
  // If the task handle exists, verify the FreeRTOS task is actually alive
  if (relay->task_handle != NULL) {
    eTaskState ts = eTaskGetState(relay->task_handle);
    if (ts == eDeleted || ts == eInvalid) {
      // Task is gone but state wasn't updated — force cleanup
      ((NoPortsRelay *)relay)->state = RELAY_STOPPED;
      ((NoPortsRelay *)relay)->task_handle = NULL;
      return false;
    }
  }
  return relay->state == RELAY_RUNNING ||
         relay->state == RELAY_CONNECTING ||
         relay->state == RELAY_AUTHENTICATING;
}
