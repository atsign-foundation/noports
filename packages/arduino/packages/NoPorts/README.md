# NoPorts Daemon for ESP32 — Getting Started

This is a PlatformIO project that builds and runs the
[NoPorts](https://noports.com) daemon (`sshnpd`) on an ESP32.
It lets you SSH (or tunnel any TCP traffic) into devices on your local network
**through** the ESP32 — with no open inbound ports, no public IP, and no VPN.

All tunnel traffic is **end-to-end encrypted** (AES-256-CTR) and
**RSA-2048 signed**.

---

## What You Need

| Item | Details |
|---|---|
| **ESP32 dev board** | ESP32-WROOM-32, ESP32-S3, ESP32-C3, or similar |
| **PlatformIO** | [Install guide](https://docs.platformio.org/en/latest/core/installation.html) — PlatformIO IDE (VS Code) or CLI |
| **Two atSigns** | One for the ESP32 ("device"), one for your laptop ("manager"). Get free atSigns at [atsign.com](https://atsign.com) |
| **Activated atKeys** | Use the [at_activate](https://pub.dev/packages/at_activate) tool or the `at_authenticate` example in this repo to create your `.atKeys` file |
| **WiFi network** | 2.4 GHz (ESP32 does not support 5 GHz) |
| **npt client** | Install on your laptop: `dart pub global activate noports_core` or download from [noports releases](https://github.com/atsign-foundation/noports/releases) |

---

## Step-by-Step Setup

### 1. Clone the Repository

```bash
git clone https://github.com/cconstab/esp_sshnpd.git
cd esp_sshnpd/packages/NoPorts
```

### 2. Edit Your Configuration

Open `src/main.cpp` and update these five lines:

```cpp
const char *WIFI_SSID      = "YOUR_WIFI_SSID";      // Your WiFi network name
const char *WIFI_PASSWORD  = "YOUR_WIFI_PASSWORD";   // Your WiFi password
const char *DEVICE_ATSIGN  = "@your_device_atsign";  // The atSign for this ESP32
const char *DEVICE_NAME    = "esp32";                // A name for this device
const char *MANAGER_ATSIGN = "@your_manager_atsign"; // The atSign on your laptop
```

Also update the `permitopen` entries to match the hosts/ports you want to
tunnel to on your local network:

```cpp
config.permitopen[0] = { "192.168.1.100", 22 };   // SSH on a local machine
config.permitopen[1] = { "192.168.1.100", 80 };   // HTTP on a local machine
config.permitopen_count = 2;
```

> **Tip:** `permitopen` is a security allowlist — only these host:port
> combinations will be tunnelled. Add entries for every local service you want
> reachable remotely.

### 3. Prepare Your atKeys File

Your `.atKeys` file contains the cryptographic keys for your device atSign.

1. Locate your atKeys file (e.g. `@your_device_atsign_key.atKeys`)
2. Rename it to `atkeys.json`
3. Place it in the `data/` folder:
   ```
   packages/NoPorts/
   ├── data/
   │   └── atkeys.json    <-- your keys here
   ├── src/
   │   └── main.cpp
   └── platformio.ini
   ```

> **Security:** Never commit `atkeys.json` to version control.
> It is already listed in `.gitignore`.

### 4. Build the Firmware

```bash
pio run
```

Expected output:
```
RAM:   11.6%  (used 37896 bytes from 327680 bytes)
Flash: 60.3%  (used 789xxx bytes from 1310720 bytes)
```

### 5. Upload atKeys to the ESP32 Filesystem

```bash
pio run -t uploadfs
```

This writes `data/atkeys.json` to the ESP32's LittleFS partition.

### 6. Flash and Monitor

```bash
pio run -t upload && pio device monitor
```

You should see output like:
```
NoPorts - Loading keys from filesystem
......
WiFi connected: 192.168.1.42
Keys loaded from SPIFFS successfully
NoPorts daemon running!
```

### 7. Connect from Your Laptop

On the machine where your **manager atSign** is configured, run:

```bash
# Tunnel SSH through the ESP32
npt -f @your_manager_atsign \
    -t @your_device_atsign \
    -d esp32 \
    -h 192.168.1.100 -p 22 \
    -l 2222

# Then SSH to the tunnelled port
ssh user@localhost -p 2222
```

That's it — you're now SSH'ing through your ESP32 with end-to-end encryption,
no open ports, and no VPN.

---

## Project Structure

```
packages/NoPorts/
├── platformio.ini      # Build configuration
├── data/
│   └── atkeys.json     # Your atSign keys (not committed to git)
├── src/
│   └── main.cpp        # Daemon entry point — edit this
├── include/            # (optional) project-local headers
└── test/               # (optional) unit tests
```

### platformio.ini Explained

```ini
[env:esp32dev]
platform = espressif32
board = esp32dev
framework = arduino
board_build.filesystem = littlefs      # Filesystem for atkeys.json
monitor_speed = 115200
build_flags =
  -DARDUINO_LOOP_STACK_SIZE=32768      # Larger loop stack for crypto ops
lib_extra_dirs =
  ../../lib                            # Local NoPorts library
lib_deps =
  atsign-foundation/at_client          # atSDK for ESP32 (external repo)
  NoPorts                              # Pulls in NoPorts daemon
```

The `lib_extra_dirs` path points to the local NoPorts library.
`at_client` is fetched from the [at_client_arduino](https://github.com/atsign-foundation/at_client_arduino)
repository via the PlatformIO registry.

---

## Configuration Reference

### WiFi

| Variable | Description |
|---|---|
| `WIFI_SSID` | Your 2.4 GHz WiFi network name |
| `WIFI_PASSWORD` | Your WiFi password |

### atSign Configuration

| Variable | Description |
|---|---|
| `DEVICE_ATSIGN` | The atSign registered to this ESP32 device |
| `DEVICE_NAME` | A human-readable device name (used by `npt -d`) |
| `MANAGER_ATSIGN` | The atSign allowed to open tunnels through this device |

### permitopen (Tunnel Allowlist)

Each entry specifies a `{host, port}` pair on your local network that can be
tunnelled:

```cpp
config.permitopen[0] = { "192.168.1.100", 22 };    // SSH
config.permitopen[1] = { "192.168.1.100", 80 };    // HTTP
config.permitopen[2] = { "192.168.1.200", 3000 };  // Node.js app
config.permitopen_count = 3;                         // Must match!
```

Maximum 255 entries. If `permitopen_count` is 0, no tunnels will be allowed.

---

## How It Works

```
Your Laptop                     Cloud                         Your Network
──────────                      ─────                         ────────────
                                                          ┌──────────────┐
npt client ──TLS──→ atProtocol ──notify──→ ESP32 daemon   │ Local server │
     │                                        │           │ 192.168.x.x  │
     │               ┌─────┐                  │           │   :22, :80   │
     └──TLS──────→   │SRVD │  ←──TLS──────────┘           └──────┬───────┘
                     │     │                                      │
                     └──┬──┘        ESP32 ←──TCP──────────────────┘
                        │
              AES-256-CTR E2EE tunnel
```

1. The ESP32 daemon monitors the atProtocol cloud for tunnel requests
2. When `npt` sends a request, the daemon verifies the RSA signature and
   checks that the sender is in `manager_list`
3. Both the client and daemon connect outbound to **SRVD** (socket rendezvous)
4. SRVD pairs the two connections — no inbound ports needed on either side
5. A **twin-key AES-256-CTR** encrypted tunnel carries data between the
   `npt` client and the local TCP service (e.g. SSH)

---

## Troubleshooting

### WiFi won't connect
- ESP32 only supports **2.4 GHz** WiFi — check your SSID
- Verify the password has no trailing whitespace
- Move the ESP32 closer to your access point

### "ERROR: Failed to load atkeys from SPIFFS!"
- Run `pio run -t uploadfs` to upload your `data/atkeys.json`
- Ensure the file is valid JSON (not a renamed binary)
- Check that `board_build.filesystem = littlefs` is in `platformio.ini`

### "NoPorts failed" at startup
- Check serial output for the specific error message
- Verify your device atSign is activated and the keys match
- Ensure `root.atsign.org:64` is reachable from your network
- Try setting `atlogger_set_logging_level(ATLOGGER_LOGGING_LEVEL_DEBUG)` for
  more detail

### npt can't connect
- Verify `MANAGER_ATSIGN` matches the atSign you're using with `npt -f`
- Check `DEVICE_NAME` matches the `npt -d` argument
- Confirm the host:port in `permitopen` is correct and reachable from the ESP32
- Make sure the ESP32 is running and connected to WiFi

### ESP32 crashes or runs out of memory
- Monitor free heap with `ESP.getFreeHeap()` in your loop
- The daemon uses ~40 KB RAM at idle, plus ~8 KB per active tunnel
- Reduce concurrent tunnels if needed
- Don't run other memory-heavy tasks alongside the daemon

### RSA operations are slow
- RSA-2048 sign/verify takes 1-2 seconds on ESP32 — this is normal
- Tunnel establishment includes an RSA verification step, so there's a
  brief delay before the tunnel becomes usable

---

## Common PlatformIO Commands

| Command | Description |
|---|---|
| `pio run` | Build firmware |
| `pio run -t upload` | Flash firmware to ESP32 |
| `pio run -t uploadfs` | Upload `data/` to LittleFS |
| `pio device monitor` | Open serial monitor (115200 baud) |
| `pio run -t upload && pio device monitor` | Flash and monitor in one step |
| `pio run -t clean` | Clean build artifacts |

---

## Security Notes

- **atKeys are secrets** — treat `atkeys.json` like a private SSH key.
  Never commit it to git.
- **Tunnel targets are restricted** — only host:port pairs listed in
  `permitopen` can be tunnelled. Keep this list minimal.
- **Manager allowlist** — only atSigns in `manager_list` can request tunnels.
  Add up to 16.
- **Flash encryption** — for production deployments, enable
  [ESP32 flash encryption](https://docs.espressif.com/projects/esp-idf/en/latest/esp32/security/flash-encryption.html)
  to protect stored keys from physical extraction.
- **Key rotation** — if you suspect your atKeys have been compromised,
  re-onboard the atSign using `at_activate` or the `at_authenticate` example.

---

## Related

- [NoPorts library reference](../../lib/NoPorts/README.md) — API docs, architecture, examples
- [at_client_arduino](https://github.com/atsign-foundation/at_client_arduino) — atSDK for ESP32 (external repo)
- [Top-level README](../../README.md) — Repository overview
- [NoPorts project](https://github.com/atsign-foundation/noports) — Upstream project
- [atSign](https://atsign.com) — Get free atSigns

---

## License

BSD-3-Clause — see the upstream
[noports](https://github.com/atsign-foundation/noports) project.
