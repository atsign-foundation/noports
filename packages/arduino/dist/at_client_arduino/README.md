# at_client — atSDK for Arduino/ESP32

ESP32 port of the [at_c SDK](https://github.com/atsign-foundation/at_c),
providing everything needed to build atProtocol applications on Arduino.

## What's Included

| Component | Description |
|---|---|
| **atclient** | PKAM/CRAM authentication, put/get/delete for self, public, and shared keys, scan, heartbeat |
| **monitor** | Long-lived TLS connection for real-time notifications |
| **notify** | Send notifications to other atSigns |
| **atchops** | AES-256 (CBC, CTR), RSA-2048, SHA-256/512, base64, HMAC via ESP-IDF mbedTLS |
| **atauth** | Onboard (activate with CRAM key) and enroll (additional app/device with OTP) |
| **atlogger** | Logging routed to `Serial.print` on Arduino |
| **cJSON** | JSON parsing |

## Usage

```cpp
#include <atsdk.h>
```

The umbrella header `atsdk.h` includes all components. See the examples for
complete sketches.

## Examples

| Example | Description |
|---|---|
| **BasicPKAMAuth** | WiFi → load atkeys from LittleFS → PKAM authenticate → put/get self key → heartbeat loop |
| **at_authenticate** | Create new atKeys — MODE 1: onboard with CRAM key, MODE 2: enroll with OTP |
| **PutGetKeys** | CRUD for all three key types (self, public, shared) → scan → delete |
| **MonitorNotifications** | Dual-connection (worker + monitor), send + receive notifications, auto-reconnect |
| **SendNotification** | Send notifications with different types, priorities, and periodic sensor data |

## Installation

### Arduino IDE

1. Download the latest release `.zip` from the [Releases](https://github.com/atsign-foundation/at_client_arduino/releases) page.
2. In Arduino IDE: **Sketch → Include Library → Add .ZIP Library…** and select the downloaded file.

Alternatively, search for **at_client** in the **Library Manager** (**Tools → Manage Libraries…**).

### PlatformIO

Add to your `platformio.ini`:

```ini
lib_deps =
  atsign-foundation/at_client
```

Or clone this repo locally and reference it directly:

```ini
lib_extra_dirs = /path/to/at_client_arduino
lib_deps = at_client
```

## Quick Start — Authenticate & Put/Get

```cpp
#include <WiFi.h>
#include <LittleFS.h>
#include <atsdk.h>

void setup() {
  Serial.begin(115200);
  WiFi.begin("MyWiFi", "MyPassword");
  while (WiFi.status() != WL_CONNECTED) delay(500);

  atsdk_arduino_setup();
  LittleFS.begin(true);

  // Load keys from filesystem
  atclient_atkeys atkeys;
  atclient_atkeys_init(&atkeys);
  atclient_atkeys_file kf;
  atclient_atkeys_file_init(&kf);
  atclient_atkeys_file_from_path(&kf, "/atkeys.json");
  atclient_atkeys_populate_from_atkeys_file(&atkeys, &kf);
  atclient_atkeys_file_free(&kf);

  // Authenticate
  atclient client;
  atclient_init(&client);
  atclient_authenticate_options opts;
  atclient_authenticate_options_init(&opts);
  atclient_pkam_authenticate(&client, "@myatsign", &atkeys, &opts, NULL);
  atclient_authenticate_options_free(&opts);

  // Put a self key
  atclient_atkey key;
  atclient_atkey_init(&key);
  atclient_atkey_create_self_key(&key, "greeting", "@myatsign", NULL);
  atclient_put_self_key(&client, &key, "Hello from ESP32!", NULL, NULL);

  // Get it back
  char *value = NULL;
  atclient_get_self_key(&client, &key, &value, NULL);
  Serial.printf("Got: %s\n", value);
  free(value);
  atclient_atkey_free(&key);
}

void loop() {
  delay(10000);
}
```

## API Overview

### Authentication

| Function | Description |
|---|---|
| `atclient_pkam_authenticate()` | Authenticate with PKAM (standard) |
| `atclient_cram_authenticate()` | Authenticate with CRAM (one-time, for onboarding) |
| `atauth_onboard_command()` | Activate a new atSign with CRAM key |
| `atauth_enroll_command()` | Enroll an additional app/device with OTP |

### Key Operations

| Function | Description |
|---|---|
| `atclient_put_self_key()` | Store a self-encrypted key |
| `atclient_get_self_key()` | Retrieve a self-encrypted key |
| `atclient_put_public_key()` | Store a public key (visible to all) |
| `atclient_get_public_key()` | Retrieve a public key |
| `atclient_put_shared_key()` | Store a shared key (encrypted for a specific atSign) |
| `atclient_get_shared_key()` | Retrieve a shared key |
| `atclient_delete()` | Delete a key |
| `atclient_get_atkeys()` | Scan/list keys matching a regex |

### Monitor & Notifications

| Function | Description |
|---|---|
| `atclient_monitor_init()` | Initialize a monitor connection |
| `atclient_monitor_pkam_authenticate()` | Authenticate the monitor connection |
| `atclient_monitor_start()` | Start monitoring with a regex filter |
| `atclient_monitor_read()` | Read one notification (blocks up to timeout) |
| `atclient_notify()` | Send a notification to another atSign |

### Utilities

| Function | Description |
|---|---|
| `atclient_send_heartbeat()` | Send a heartbeat to keep the connection alive |
| `atclient_is_connected()` | Check if the connection is alive |
| `atclient_monitor_is_connected()` | Check if the monitor connection is alive |

## Platform

- **ESP32 only** — ESP8266 lacks sufficient RAM
- Requires Arduino framework with ESP-IDF mbedTLS

## Source

Ported from [at_c](https://github.com/atsign-foundation/at_c) with ESP32
adaptations (`sleep()` → `delay()`, `access()` → `stat()`, C++ compatibility).

## License

BSD-3-Clause
