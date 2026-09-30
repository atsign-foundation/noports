# at_Arduino_NoPorts

<!-- pyml disable-num-lines 4 md013,md033-->
<a href="https://atsign.com#gh-light-mode-only"><img width=250px src="https://atsign.com/wp-content/uploads/2022/05/atsign-logo-horizontal-color2022.svg#gh-light-mode-only" alt="The Atsign Foundation"></a><a href="https://atsign.com#gh-dark-mode-only"><img width=250px src="https://atsign.com/wp-content/uploads/2023/08/atsign-logo-horizontal-reverse2022-Color.svg#gh-dark-mode-only" alt="The Atsign Foundation"></a>

**An experimental repository bringing the [atProtocol](https://atsign.com) and [NoPorts](https://noports.com) to ESP32 microcontrollers.**

> **Status: Experimental** — This project is under active development and
> should be considered experimental. It *is* working on real hardware, but
> APIs, structure, and functionality may change without notice.

---

## What Is This?

at_Arduino_NoPorts is a collection of Arduino/PlatformIO libraries and
ready-to-flash packages that let ESP32 devices participate in the atProtocol
network. The headline application is **NoPorts on ESP32** — an encrypted TCP
relay daemon (`sshnpd`) that lets you SSH into machines on your local network
through* an ESP32, with **no open ports, no public IP, and no VPN**.

All tunnel traffic is **end-to-end encrypted** (AES-256-CTR) and
**RSA-2048 signed**.

---

## Supported Hardware

<!-- pyml disable-num-lines 5 md013-->
| Device | Chip | Connectivity | UI | Package |
|---|---|---|---|---|
| **CYD** (ESP32-2432S028R / v2) | ESP32 | WiFi | 2.8" touchscreen | `NoPorts_CYD` |
| **Freenove FNK0104** (CYD S3) | ESP32-S3 | WiFi | 2.8" touchscreen | `NoPorts_CYD` |
| **Elecrow CrowPanel Advance 7.0** | ESP32-S3 | WiFi | 7" 800x480 touchscreen | `NoPorts_CYD` |
| **M5Stack Unit PoE-P4** | ESP32-P4 | Fast Ethernet (10/100) + PoE | Web UI | `NoPorts_PoE` |

### CYD — Cheap Yellow Display

The
[ESP32-2432S028R](https://github.com/witnessmenow/ESP32-Cheap-Yellow-Display)
is an inexpensive (~$15) ESP32 board with a built-in 2.8" ILI9341 TFT
touchscreen. It provides a full onboard UI for WiFi setup, atSign enrollment,
and a live dashboard showing tunnel activity and system stats.

### M5Stack Unit PoE-P4

The [M5Stack Unit PoE-P4](https://docs.m5stack.com/en/unit/Unit_PoE-P4) is a
compact headless module powered by the ESP32-P4 (RISC-V, 360 MHz, 32 MB PSRAM).
It connects via **Fast Ethernet (10/100 Mbps)** using the onboard IP101GRI PHY,
and can be powered entirely over **PoE** (802.3af, up to 6 W) — no WiFi, no
USB power supply needed. Configuration and
monitoring are done through a built-in **web UI** accessible over the local
network. Designed for always-on, unattended deployment.

---

## Repository Structure

```txt
at_Arduino_NoPorts/
├── lib/                        # Reusable Arduino libraries
│   └── NoPorts/                # NoPorts daemon library (sshnpd for ESP32)
│
├── packages/                   # Ready-to-build PlatformIO projects
│   ├── NoPorts_CYD/            # NoPorts with touchscreen UI (CYD / ESP32-S3)
│   └── NoPorts_PoE/            # NoPorts headless daemon (M5Stack Unit PoE-P4)
│
└── web/                        # Browser-based firmware installer (docker compose)
```

> **Note:** The `at_client` Arduino library (atSDK for ESP32) lives in
> its own repository:
> [github.com/atsign-foundation/at_client_arduino](https://github.com/atsign-foundation/at_client_arduino)

### Libraries (`lib/`)

<!-- pyml disable-num-lines 4 md013-->
| Library | Description |
|---|---|
| **[NoPorts](lib/NoPorts/)** | NoPorts daemon (`sshnpd`) library — registers on the atProtocol network, accepts encrypted tunnel requests, and relays TCP traffic to local network services. |
| **[at_client](https://github.com/atsign-foundation/at_client_arduino)** *(external)* | Full ESP32 port of the [at_c SDK](https://github.com/atsign-foundation/at_c) — PKAM/CRAM auth, put/get/delete keys, monitor notifications, AES-256, RSA-2048, base64, and more. |

### Packages (`packages/`)

<!-- pyml disable-num-lines 4 md013-->
| Package | Target hardware | Description |
|---|---|---|
| **[NoPorts_CYD](packages/NoPorts_CYD/)** | ESP32-2432S028R, ESP32-S3 CYD variants, Elecrow CrowPanel Advance 7.0 | Touchscreen UI — WiFi setup, enrollment, live dashboard. |
| **[NoPorts_PoE](packages/NoPorts_PoE/)** | M5Stack Unit PoE-P4 (ESP32-P4) | Headless daemon with web UI. Connects over Fast Ethernet (10/100), powered by PoE. |

---

## Getting Started

### Prerequisites

- [PlatformIO](https://docs.platformio.org/en/latest/core/installation.html)
(CLI or VS Code extension)
- Two **atSigns** — one for the ESP32 (device) and one for your laptop
(manager). Get free atSigns at [atsign.com](https://atsign.com).

### CYD Quick Start

1. Clone the repo and open `packages/NoPorts_CYD` in PlatformIO.
2. Flash firmware — WiFi credentials and atSign enrollment are configured via
the touchscreen on first boot.
3. Requires a **2.4 GHz WiFi** network (ESP32 does not support 5 GHz).

### M5Stack Unit PoE-P4 Quick Start

1. Clone the repo and open `packages/NoPorts_PoE` in PlatformIO (uses the
[pioarduino](https://github.com/pioarduino/platform-espressif32) platform for
ESP32-P4 support).
2. Flash firmware via USB-C. **Note the web UI admin PIN** printed to the
serial console at boot (see below) — it is required to sign in to the config
UI.
3. Plug an Ethernet cable into the RJ45 port (PoE switch recommended — no
USB power needed).
4. Navigate to the device's IP address in a browser, sign in with the admin
PIN, and complete configuration.

#### Web UI admin PIN

The config web UI is protected by an admin PIN. On first boot the device
generates a random 8-digit **initial PIN** and prints it to the serial console.
You log in with that once, and are then **required to set your own PIN** before
you can use the UI.

To read the initial PIN, connect over USB-C and open the serial monitor:

```bash
pio device monitor -e esp32p4    # or: pio device monitor -b 115200
```

Look for this block in the boot log:

```log
[web] ─────────────────────────────────────────
[web]  Web UI initial PIN: 12345678
[web]  Log in with this, then set your own PIN.
[web] ─────────────────────────────────────────
```

Then browse to the device's IP address, sign in with the initial PIN, and set
your own PIN (6–63 characters) on the page that follows. After that:

- Sign in at the device IP with **your** PIN. A session lasts one hour.
- You can change the PIN any time from the **PIN** link in the top nav.

Notes:

- Once you've set your own PIN it is **never printed to serial** — only the
  temporary initial PIN is, and only until you replace it.
- The PIN persists across reboots and factory reset, so a headless/PoE-only
  device stays reachable.
- **Forgot your PIN?** Because your PIN is never printed, recovery requires
  physical access: erase it so a fresh initial PIN is generated — e.g.
  `pio run -e esp32p4 -t erase` then re-flash (this also clears other config),
  or clear the `web_pin` and `web_pin_ok` NVS keys with your own tooling. The
  device will then prompt for a new PIN at the next login.

### Browser-based Firmware Installer

A Docker-based web flasher lets you flash either device directly from a
browser (Chrome/Edge) over WebSerial — no local toolchain needed:

```bash
docker compose up --build
# Then open http://localhost:8081
```

The flasher binds to `127.0.0.1` only, so it's reachable from the machine
running it but not the local network — `localhost` is also the secure context
WebSerial requires. To flash from another machine, change the port bind in the
compose file and serve it over HTTPS.

Or use the hosted installer at [cyd.crushware.com](https://cyd.crushware.com).

---

## Current Capabilities

| Feature | CYD | PoE-P4 |
|---|---|---|
| atProtocol authentication (PKAM) | ✓ | ✓ |
| Monitor for notifications | ✓ | ✓ |
| Ping / heartbeat responses | ✓ | ✓ |
| NPT (network port tunneling) | ✓ | ✓ |
| AES-CTR end-to-end encryption | ✓ | ✓ |
| RSA-2048 signing / verification | ✓ | ✓ |
| Multi-session relay (up to 4 concurrent) | ✓ | ✓ |
| APKAM enrollment | Touchscreen | Web UI |
| Live dashboard | Touchscreen | Web UI |
| Connectivity | WiFi | Fast Ethernet (10/100) |
| PoE power | — | ✓ |
| Hardware watchdog + heap recovery | ✓ | ✓ |
| Auto-recovery on network loss / DHCP expiry | ✓ | ✓ |

### Known Limitations

- **No SSH server on-device** — tunnels to TCP services on the local network
- **RSA operations are slow** — envelope verification takes 1–2 seconds
- **Limited concurrent tunnels** — realistically 2–4 simultaneous connections
- **NoPorts_PoE requires pioarduino** — the official espressif32 PlatformIO
platform does not yet support ESP32-P4
- **Keys are not encrypted at rest by default** — atSign keys and WiFi
  credentials are recoverable from a flash dump by anyone with physical access
  unless ESP32 flash encryption is enabled. Keys are per-device and revocable;
  see [docs/security-key-storage.md](docs/security-key-storage.md) for the threat
  model and mitigations.

---

## Contributing

**PRs and collaborators are VERY welcome!**

This has been a spare-time / weekend project, coded with the help of
**AI Architect** — primarily **Claude** and local LLMs running via
**[Ollama](https://ollama.com)**. There is plenty of room to help — whether
it's testing on new hardware, improving the UI, writing docs, fixing bugs, or
adding features. If you're interested in the atProtocol, embedded systems, or
encrypted networking on microcontrollers, jump in!

Please read [CONTRIBUTING.md](CONTRIBUTING.md) before submitting a PR, and
note that this project follows our [Code of Conduct](code_of_conduct.md).

---

## License

This project is licensed under the [BSD 3-Clause License](LICENSE).

Copyright (c) 2022, The Atsign Foundation.

---

## Security

If you discover a security vulnerability, please see [SECURITY.md](SECURITY.md)
for responsible disclosure instructions.

For how the firmware stores atSign keys and WiFi credentials, what a physical
attacker can recover, and how to mitigate it (key rotation/revocation and ESP32
flash encryption), see [docs/security-key-storage.md](docs/security-key-storage.md).
