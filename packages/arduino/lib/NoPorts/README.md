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
| Monitor for notifications | **Working** | Long-lived TLS connection with auto-reconnect and exponential backoff |
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

  NoPortsPermitOpen permitopen[255]; // Allowed tunnel targets (LAN hosts)
  uint8_t           permitopen_count;

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

### Key Loading

| Function | Description |
|---|---|
| `noports_keys_set(config, ...)` | Set keys from hardcoded base64 strings |
| `noports_keys_load_from_file(config, path)` | Load keys from LittleFS/SPIFFS JSON |
| `noports_keys_free(config)` | Free dynamically loaded keys |

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

### RSA operations are slow
- RSA-2048 takes 1-2 seconds on ESP32 — this is expected

---

## License

BSD-3-Clause — same as the upstream
[noports](https://github.com/atsign-foundation/noports) project.
