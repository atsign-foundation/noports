# NoPorts CYD

## Overview

NoPorts daemon with touchscreen UI for the **CYD (Cheap Yellow Display)** ESP32-2432S028R board.

### Features

- 🌐 **WiFi Configuration** - Scan and connect to networks with on-screen keyboard
- 🔐 **APKAM Enrollment** - Secure device enrollment with atProtocol
- 📊 **Real-time Dashboard** - Monitor tunnels, pings, throughput (bps), and CPU usage
- 🔀 **Multi-Session Relay** - Up to 5 concurrent TCP sessions per NPT connection
- 🔒 **Per-Session Encryption** - Independent AES-CTR keys for each sub-connection
- 🛡️ **ESCR Authentication** - Encrypted Signed Challenge-Response relay auth (`npt --ram escr`)
- 💡 **RGB LED Status** - Color-coded states (green=connected, amber=relay active, red=error)
- 💾 **Persistent Storage** - WiFi credentials and keys saved to NVS/LittleFS
- 🎯 **Touch Interface** - Flicker-free touchscreen UI optimized for 320x240 display

### Hardware Support

- **ESP32-2432S028R** (CYD) - standard version with micro-USB
- **ESP32-2432S028Rv2** (CYD2USB) - newer version with micro-USB + USB-C
- **Freenove FNK0104** (ESP32-S3, 2.8" IPS, FT6336U capacitive touch) -
  `cyd2usb_s3`
- **Elecrow CrowPanel Advance 7.0-HMI** (ESP32-S3-N16R8, 7" 800x480 IPS, GT911
  capacitive touch, CH340K UART) - `crowpanel_adv7`. The UI is drawn on a
  400x240 PSRAM canvas and shown at 2x, filling the panel. Backlight and touch
  reset are I2C commands to the board's companion MCU, not GPIOs; boards older
  than V1.3 need `-DCROWPANEL_ADVANCE_REV=120` (V1.2) and V1.0 is not
  supported.

## Memory Optimization

This project uses **TFT_eSPI** instead of LVGL for maximum memory efficiency:

| Component | Memory Usage |
|-----------|--------------|
| GUI Framework | 5-10 KB (vs 32-48 KB LVGL) |
| Stack Size | 16 KB (vs 32 KB) |
| **Free Heap** | **~150-180 KB** |

See [MIGRATION.md](MIGRATION.md) for full details on the memory optimization work.

## Building

### Prerequisites

- PlatformIO CLI or PlatformIO IDE
- NoPorts library (in `../../lib/NoPorts`)

### Compile and Upload

```bash
# For standard CYD (micro-USB)
pio run -e cyd -t upload

# For CYD2USB (micro-USB + USB-C)
pio run -e cyd2usb -t upload

# For Freenove FNK0104 (ESP32-S3, native USB)
pio run -e cyd2usb_s3 -t upload

# For Elecrow CrowPanel Advance 7.0 (ESP32-S3, CH340K UART — needs the WCH
# CH34x driver on macOS; the port appears as /dev/cu.wchusbserial*)
pio run -e crowpanel_adv7 -t upload
```

### Serial Monitor

```bash
pio device monitor -b 115200
```

## First Run

1. **Touch calibration** (if needed) - follow on-screen instructions
2. **WiFi Setup** - scan for networks, select SSID, enter password
3. **Enrollment** - enter atSign, device name, OTP, and manager atSign
4. **Dashboard** - view live tunnel/ping events and system status

## Project Structure

```
├── src/
│   ├── main.cpp              # Main application entry point
│   ├── ui_tft.cpp            # Core UI framework (TFT_eSPI)
│   ├── ui_dashboard_tft.cpp  # Dashboard screen (throughput, CPU, relay stats)
│   ├── ui_wifi_tft.cpp       # WiFi configuration screen
│   ├── ui_enroll_tft.cpp     # Enrollment screen
│   └── old_lvgl/             # Backup of previous LVGL implementation
├── include/
│   └── User_Setup.h          # TFT_eSPI hardware configuration
├── platformio.ini            # Build configuration
├── partitions.csv            # Flash partitions
└── MIGRATION.md              # Migration & optimization documentation
```

### NoPorts Library (../../lib/NoPorts/)

```
├── src/
│   ├── noports_daemon.cpp    # NPT request handling, auth, relay orchestration
│   ├── noports_relay.cpp     # TCP relay engine (single + multi-session)
│   └── noports/
│       ├── noports_daemon.h  # Daemon class, NOPORTS_MAX_RELAYS=5/6
│       ├── noports_relay.h   # Relay struct, config, sub-connection types
│       └── noports_config.h  # Timeout and buffer configuration
```

## Configuration

### Display & Touch

Display and touch settings are configured in [include/User_Setup.h](include/User_Setup.h).

If touch calibration is off, adjust these values in `ui_tft.h`:

```cpp
#define TOUCH_MIN_X 200
#define TOUCH_MAX_X 3700
#define TOUCH_MIN_Y 200
#define TOUCH_MAX_Y 3700
```

### Partitions

Custom partition table in `partitions.csv` allocates:
- 1.4 MB for app
- 320 KB for LittleFS (atkeys.json storage)

## Troubleshooting

### Display Issues
- Check SPI connections
- Verify `User_Setup.h` pin definitions
- Reduce `SPI_FREQUENCY` if display is unstable

### Touch Issues
- Run touch calibration
- Adjust `TOUCH_MIN/MAX` values
- Check IRQ pin (GPIO 36) connection

### CrowPanel Advance 7.0 stays black
- The serial log will still look healthy: the panel scans regardless of the
  backlight. Check the board revision on the back silkscreen and build with
  the matching `-DCROWPANEL_ADVANCE_REV` (130 for V1.3+, 120 for V1.2).
- `[crow] nothing at 0x30` means a V1.0 board (PCA9557 expander), unsupported.
- `[crow] no GT911 at 0x5D or 0x14` means the touch reset did not take; power
  cycle the board rather than just resetting it.

### CrowPanel Advance 7.0 shows an occasional torn frame
- The panel scans its framebuffer out of PSRAM, and WiFi/TLS bursts can starve
  that DMA for one frame. The env ships `-DCROWPANEL_PCLK_HZ=14000000`
  (~34 Hz refresh) instead of Elecrow's 16 MHz for exactly this reason. Lower
  it further if it persists; raise it back toward 16000000 if you see flicker.

### Memory Issues
Monitor free heap in serial output:
```
Free heap: XXXXX bytes
```

Should remain >100 KB during operation. If lower:
- Check for memory leaks
- Reduce buffer sizes
- Disable debug logging

### WiFi Connection Fails
- Verify SSID/password
- Check signal strength
- Ensure 2.4 GHz network (ESP32 doesn't support 5 GHz)

### Enrollment Fails
- Verify OTP is valid (not expired)
- Check manager atSign is correct
- Ensure internet connectivity
- Verify system time is synced (NTP)

## API Integration

The project integrates with:

- **NoPorts Library** - SSH and TCP tunnel management
- **atProtocol** - End-to-end encrypted communication
- **APKAM** - Application-level access control

## Development

### Adding New Screens

1. Create header/source files (e.g., `ui_settings_tft.h/cpp`)
2. Add screen enum to `main.cpp`
3. Implement create/update/handle_touch functions
4. Add screen transition logic

### Customizing UI

Colors are defined in `ui_tft.h`:
```cpp
#define COLOR_PRIMARY     0xF300  // Orange
#define COLOR_ACCENT      0x05F3  // Teal
#define COLOR_SUCCESS     0x2E65  // Green
```

Convert colors using: `RGB565 = (R >> 3) << 11 | (G >> 2) << 5 | (B >> 3)`

## Relay Architecture

### Multi-Session Relay

The ESP32 NoPorts relay supports multiple concurrent TCP sessions per NPT connection,
matching the Dart sshnpd `multi: true` protocol:

1. **Control Channel** - Single encrypted connection to the SRVD relay server
2. **Sub-Connections** - Each `connect:` message from the control channel spawns a new
   SRVD data connection + local service connection pair
3. **Per-Session Keys** - Each sub-connection gets independent AES-CTR encryption keys
   derived from the `connect:` message payload
4. **Concurrent Bridging** - All active sub-connections are polled and bridged in parallel

```
Client ──► SRVD ◄── Control Channel ──► ESP32
             │                            │
             ├── Sub 0: SRVD ◄──────────► local:22
             ├── Sub 1: SRVD ◄──────────► local:22
             ├── Sub 2: SRVD ◄──────────► local:22
             └── Sub 3: SRVD ◄──────────► local:22
```

**Limits**: `MAX_RELAY_SUBS = 4` concurrent sessions per NPT connection,
`NOPORTS_MAX_RELAYS = 4` concurrent NPT connections. Constrained by ESP32 lwIP
TCP PCB limit (default 10 sockets).

## Security

The atSign keys written during enrollment (`atkeys.json` on LittleFS) and the
WiFi credentials and config stored in NVS are **not encrypted at rest** by
default, so anyone with physical/USB access to the board can recover them from a
flash dump. Because each device has its own revocable enrollment, the primary
mitigation is to **rotate/revoke** a lost or decommissioned device's enrollment;
for physically untrusted deployments, additionally enable ESP32 flash
encryption. See [docs/security-key-storage.md](../../docs/security-key-storage.md)
for the threat model and mitigations.

## Performance

- **Frame Rate**: 60 FPS (flicker-free partial updates)
- **Touch Latency**: <50ms
- **RAM Usage**: ~17% (56 KB / 328 KB)
- **Flash Usage**: ~36% (901 KB / 2.5 MB)
- **Relay Throughput**: Real-time bps display with color-coded RX (cyan) / TX (green)
- **CPU Monitoring**: Per-core usage displayed on dashboard

## License

See root [LICENSE](../../LICENSE) file.

## Support

For issues specific to the CYD package, please open an issue on GitHub.

---

**Last Updated**: July 2025  
**Tested Platform**: ESP32-2432S028R (CYD), ESP32-2432S028Rv2 (CYD2USB)  
**Framework**: TFT_eSPI (memory-optimized)
