# NoPorts Arduino Library (sshnpd for ESP32)

An Arduino/ESP32 library implementing the NoPorts daemon (`sshnpd`), based on the
[C implementation](https://github.com/atsign-foundation/noports/tree/trunk/packages/c)
from the [Atsign Foundation's noports project](https://github.com/atsign-foundation/noports).

This allows an ESP32 to register on the atProtocol network and accept
**encrypted tunnel requests** from remote clients — without opening any
inbound ports, without a public IP address, and without traditional VPN
infrastructure.

**Depends on:** [at_client_arduino](https://github.com/atsign-foundation/at_client_arduino) (atSDK for ESP32)

---

## What Works

| Capability | Status | Notes |
|---|---|---|
| atProtocol authentication (PKAM) | **Working** | Via the at_client library |
| Monitor for notifications | **Working** | Long-lived TLS connection; dead sessions detected at once, silence probed with a heartbeat, reconnect with capped backoff (see [Staying connected](#staying-connected)) |
| Ping/heartbeat responses | **Working** | JSON notify via atProtocol |
| NPT (network port tunneling) | **Working** | Dual-connection relay via WiFiClient + FreeRTOS tasks; SSH tested |
| AES-CTR end-to-end encryption | **Working** | Twin-key (C2D + D2C) via ESP-IDF mbedTLS; compatible with Dart NPT client |
| RSA-2048 signing/verification | **Working** | Supported by mbedTLS on ESP32 (~1-2 seconds per operation) |
| Device info publishing | **Working** | Standard atProtocol notify |

### Limitations

- **ESP32 only** — ESP8266 lacks sufficient RAM and crypto capability
- **No SSH server** — the ESP32 tunnels to TCP services on the local network
- **Limited concurrent tunnels** — realistically 2-4 simultaneous connections
- **RSA operations are slow** — envelope verification takes 1-2 seconds

---

## Prerequisites

- **ESP32** dev board (ESP32-WROOM, ESP32-S3, ESP32-C3, etc.)
- **Arduino IDE 2.x** or **PlatformIO**
- Two activated **atSigns** — a device atSign for the ESP32 and a manager atSign
  for the remote client. Get them at [atsign.com](https://atsign.com).

---

## Installation

### Arduino IDE

1. Install `at_client` — download from [at_client_arduino releases](https://github.com/atsign-foundation/at_client_arduino/releases)
   or search for **at_client** in the Arduino Library Manager.
2. Copy this library into your Arduino libraries directory:

```bash
cp -r lib/NoPorts   ~/Documents/Arduino/libraries/
```

### PlatformIO

See `packages/NoPorts/` for a complete reference project, or add to your own
project's `platformio.ini`:

```ini
[env:esp32dev]
platform = espressif32
board = esp32dev
framework = arduino
board_build.filesystem = littlefs
monitor_speed = 115200
build_flags = -DARDUINO_LOOP_STACK_SIZE=32768
lib_extra_dirs = ../../lib
lib_deps =
  atsign-foundation/at_client
  NoPorts
```

---

## Loading atKeys

### Method 1: Load from LittleFS (Recommended)

1. Rename your `@atsign_key.atKeys` file to `atkeys.json`
2. Place it in the `data/` folder of your PlatformIO project
3. Upload to LittleFS: `pio run -t uploadfs`
4. Use `noports_keys_load_from_file()` in your sketch

### Method 2: Onboard directly on ESP32

Use the `at_authenticate` example from the [at_client_arduino](https://github.com/atsign-foundation/at_client_arduino) library to activate a
brand-new atSign directly on the ESP32.

### Method 3: Hardcode keys

Use `noports_keys_set()` with base64-encoded keys extracted from your
`.atKeys` file. See the top-level README for a Python extraction script.

> **Security:** atSign keys stored on the device — whether hardcoded in the
> sketch, loaded from the filesystem, or written during enrollment — are
> recoverable from a flash dump by anyone with physical access, unless ESP32
> flash encryption is enabled. Because keys are per-device and revocable, the
> primary mitigation is to rotate/revoke a compromised device's enrollment; for
> physically untrusted deployments, additionally enable flash encryption. See
> [docs/security-key-storage.md](../../docs/security-key-storage.md).

---

## Quick Start

```cpp
#include <WiFi.h>
#include <NoPorts.h>

NoPortsDaemon daemon;

void setup() {
  Serial.begin(115200);

  WiFi.begin("MyWiFi", "MyPassword");
  while (WiFi.status() != WL_CONNECTED) delay(500);

  NoPortsConfig config;
  noports_config_init(&config);
  config.atsign      = "@myesp32";
  config.device_name = "esp32";
  config.manager_list[0] = "@mylaptop";
  config.manager_count   = 1;

  noports_keys_load_from_file(&config, "/atkeys.json");

  config.permitopen[0] = { "192.168.1.100", 22 };
  config.permitopen_count = 1;

  daemon.begin(config);
}

void loop() {
  daemon.loop();
  delay(10);
}
```

Connect from your laptop:
```bash
npt -f @mylaptop -t @myesp32 -d esp32 -h 192.168.1.100 -p 22 -l 2222
ssh user@localhost -p 2222
```

---

## Examples

| Example | Description |
|---|---|
| `BasicDaemon` | Minimal NoPorts daemon with hardcoded keys |
| `LoadKeysFromSPIFFS` | Load atKeys from LittleFS filesystem |
| `WebServerWithNoPorts` | Run a web server alongside the NoPorts daemon |

---

## API Reference

### NoPortsConfig

```cpp
struct NoPortsConfig {
  const char *atsign;          // Device's atSign (required)
  const char *device_name;     // Device name for discovery (required)
  const char *manager_list[16]; // Allowed manager atSigns
  uint8_t     manager_count;   // Number of managers

  const char *root_domain;     // atDirectory host (default: root.atsign.org)
  uint16_t    root_port;       // atDirectory port (default: 64)
  bool        verbose;         // Enable debug logging
  bool        hide;            // Don't publish device info

  const char *policy_atsign;   // Policy service atSign, instead of manager_list
  uint16_t    policy_cache_size; // Clients' policy decisions reused for 15 s (0-64, default 8)

  NoPortsPermitOpen permitopen[255]; // Allowed tunnel targets (LAN hosts)
  uint8_t           permitopen_count;

  uint32_t client_key_check_secs;    // How often to check each client's enrollment is
                                     // still valid, ending its session once it isn't
                                     // (default 10; 0 turns it off)
  bool     require_enrollment_signature; // Refuse requests not signed with the
                                         // client's enrollment key

  // Callbacks (optional)
  void (*on_tunnel_open)(const char *host, uint16_t port, const char *session_id);
  void (*on_tunnel_close)(const char *session_id);
  void (*on_ping)(const char *from_atsign);
};
```

### NoPortsDaemon

| Method | Description |
|---|---|
| `bool begin(config)` | Initialize, authenticate, and start monitoring |
| `void loop()` | Process one notification (call from Arduino `loop()`) |
| `void stop()` | Gracefully shut down |
| `bool isRunning()` | Check if daemon is active |
| `NoPortsDaemonState getState()` | Get current state |
| `uint8_t getActiveRelayCount()` | Number of active tunnel relays |
| `const char* getLastError()` | Last error message |
| `uint32_t getMonitorSilentSecs()` | Seconds since the atServer last sent anything on the monitor; normally under 20 |
| `uint8_t getReconnectFailures()` | Consecutive failed reconnect attempts (monitor or worker); reboots at 10 |
| `void notifyNetworkChanged()` | Call after a WiFi re-association or a new DHCP lease: reconnects the monitor at once and heartbeats the worker |

### Key Loading

| Function | Description |
|---|---|
| `noports_keys_set(config, ...)` | Set keys from hardcoded base64 strings |
| `noports_keys_load_from_file(config, path)` | Load keys from LittleFS/SPIFFS JSON |
| `noports_keys_free(config)` | Free dynamically loaded keys |

---

## Staying connected

The daemon holds two TLS sessions to the atServer: the **monitor**, which the
atServer pushes notifications down, and the **worker**, which the daemon uses
to fetch keys and send replies. A ping is only answered if both are up, so the
daemon watches both and never lets either stay dead quietly:

- **Dead sessions fail fast.** The at_client socket layer (1.0.2 and later)
  reports a closed TLS session as a read error rather than a timeout, keeps
  TCP keepalive on every session (a half-open path errors within about a
  minute), and caps the TLS handshake at 20 s.
- **Monitor.** The atServer sends a stats notification every ~15 s, so a
  healthy monitor is never silent for long. After 20 s of silence the daemon
  sends it `noop:0`; the `data:ok` reply proves it alive. After 40 s of
  silence, or on any read error, the monitor is torn down and reconnected,
  and the worker is checked with a heartbeat.
- **Worker.** A heartbeat every `setWorkerKeepaliveMs()` (default 4 min)
  keeps NAT tables from expiring the session; a failed heartbeat, notify or
  key lookup reconnects it.
- **Escalation.** Reconnects back off 2.5, 5, 10 then 15 s and wait at most
  10 s for heap, so one attempt stays inside the sketch's 60 s task watchdog.
  Ten consecutive failures on either session restart the ESP32: on a
  microcontroller a reboot is the only reliable cure for heap fragmentation
  or a wedged network stack, and the Linux sshnpd gets the same from
  systemd.
- **Health line.** Once a minute at INFO:

  <!-- pyml disable-num-lines 3 md013-->
  ```text
  Health: heap=142880 largest=110592 monitor_silent=12s worker_idle=180s reconnect_failures=0 relays=0 pcbs=0/11
  ```

  `reconnect_failures` above 0 or `monitor_silent` past 20 s means recovery
  is in progress; include a few of these lines in any bug report about a
  device that stopped answering.

The daemon also frees each session's resources itself before every reconnect,
so it does not depend on the SDK for that (at_client before 1.0.2 leaked about
6 KB on every reconnect that failed part-way, which eventually left too little
heap for a TLS handshake while the monitor still looked connected).

---

## Architecture

### How It Maps to the C sshnpd

```
C sshnpd (Linux)                      Arduino NoPorts (ESP32)
─────────────────                      ──────────────────────
main.c (main function)           -->   NoPortsDaemon::begin()
daemon.c (main_loop)             -->   NoPortsDaemon::loop()
handle_ping.c                    -->   NoPortsDaemon::_handlePing()
handle_npt_request.c             -->   NoPortsDaemon::_handleNptRequest()
handle_ssh_request.c             -->   NOT IMPLEMENTED (no SSH on ESP32)
handler_commons.c                -->   NoPortsDaemon::_verifyEnvelope*()
policy.c + policy_limits.c       -->   NoPortsDaemon::_handlePolicyResponse() + noports_policy_limits.c
run_srv_process.c + srv/srv.c    -->   noports_relay.cpp (FreeRTOS tasks)
params.c (argparse)              -->   NoPortsConfig struct
atkeys_file.c (filesystem)      -->   noports_keys.cpp (LittleFS)
fork() + waitpid()               -->   xTaskCreatePinnedToCore()
pthreads                         -->   FreeRTOS tasks
POSIX signals                    -->   volatile bool flags
```

### Relay Architecture (Dual-Connection, Poll-Both)

The relay uses the same SRVD dual-connection architecture as the Dart NPT client:

1. **Two connections** opened to SRVD, both authenticated
2. **Poll both** — SRVD pairing is FIFO, so either socket may receive the
   `connect:` message. Whichever gets it becomes the **control channel**;
   the other becomes the **data channel**
3. **Twin-key AES-CTR** — the client sends
   `connect:keyC2D:ivC2D:keyD2C:ivD2C\n` through the control channel
   - C2D key: client encrypts, daemon decrypts
   - D2C key: daemon encrypts, client decrypts
4. **Early data buffering** — raw bytes consumed from the data socket during
   polling are replayed through `data_dec` after setup
5. **Full-write guarantee** — `_write_all()` loops on partial writes
6. **Control socket kept alive** — closing either SRVD connection tears down
   the session

### Data Flow

```
                           atProtocol Cloud
                                │
                    ┌───────────┴───────────┐
                    │                       │
              Monitor Connection      Worker Connection
              (notifications)         (CRUD + notify)
                    │                       │
                    └───────────┬───────────┘
                                │
                         ┌──────┴──────┐
                         │  ESP32      │
                         │  NoPorts    │
                         │  Daemon     │
                         └──────┬──────┘
                                │
                    ┌───────────┼───────────┐
                    │           │           │
              Ping Handler  NPT Handler  (other)
                    │           │
                    │     ┌─────┴─────┐
                    │     │   Relay   │  <-- FreeRTOS task
                    │     │  (srv)    │
                    │     └─────┬─────┘
                    │           │
                    │   ┌───────┴───────┐
                    │   │               │
                    │ Ctrl conn      Data conn
                    │ (keepalive)    (AES-CTR E2EE)
                    │   │               │
                    │   └───┬───────────┘
                    │       │
                    │     SRVD (rendezvous)
                    │       │
                    │     NPT Client
                    │
                    │     Data conn ←→ Local TCP Service
                    │                  (SSH, web, etc.)
```

---

## Host tests

`test/` holds tests for the library's plain-C modules, which run on the
development machine rather than the ESP32:

```bash
cmake -S test -B build/host-tests
cmake --build build/host-tests
ctest --test-dir build/host-tests --output-on-failure
```

## Troubleshooting

### "Monitor PKAM auth failed"
- Check that your atSign is activated and the keys are correct
- Verify WiFi connectivity and that `root.atsign.org:64` is reachable
- Ensure atKeys are properly decrypted

### "No free relay slots"
- Maximum 4 concurrent tunnels — close existing connections first

### ESP32 crashes or runs out of memory
- Use `ESP.getFreeHeap()` to monitor available RAM
- Reduce `NOPORTS_MAX_RELAYS` to 2
- Avoid running other memory-intensive tasks alongside the daemon

### Device stops answering pings but still looks connected
- Read the `Health:` line on serial (see
  [Staying connected](#staying-connected)). `reconnect_failures` climbing
  means the atServer cannot be reached on the
  worker session; the daemon reboots at 10. A `heap` that only ever goes
  down points at a leak: make sure the build uses at_client 1.0.2 or later.
- The CYD dashboard shows the same thing as its state indicator: `quiet Ns`
  or `retry n/10` instead of `running`.

### RSA operations are slow
- RSA-2048 takes 1-2 seconds on ESP32 — this is expected

---

## License

BSD-3-Clause — same as the upstream
[noports](https://github.com/atsign-foundation/noports) project.
