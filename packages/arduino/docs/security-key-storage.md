# Key storage and at-rest security

This note explains where an atArduino/NoPorts device keeps its secrets, what an
attacker with physical access to the hardware can recover, and how to mitigate
that. It applies to every firmware in this repo (NoPorts, NoPorts_PoE,
NoPorts_CYD) and to any sketch built on the `NoPorts` library.

## What is stored, and where

| Secret | Location | Encrypted at rest? |
| --- | --- | --- |
| atSign private keys (`atkeys.json` / `.atKeys`) | LittleFS `spiffs` partition | **No** (by default) |
| atSign / device name / managers / permitOpen / root | NVS (`Preferences`) | **No** (by default) |
| WiFi SSID + password | NVS (`Preferences`) | **No** (by default) |

The `.atKeys` format stores the **self-encryption key in the clear alongside**
the encrypted PKAM and encryption private keys, so the file as a whole is
equivalent to the plaintext identity: whoever holds it holds the atSign.

## Threat model

The relevant threat is an attacker with **physical or USB access** to the
device. With a few seconds of access they can run:

```
esptool.py read_flash 0 0x1000000 flash.bin
```

and then extract `atkeys.json` from the LittleFS image and the config
(including the WiFi password) from the NVS partition — all in cleartext. With
the atKeys they can impersonate the device's atSign on the NoPorts network,
including opening tunnels that the device is authorized to open.

This is **not** a remote/network risk. All NoPorts traffic is TLS to the
atProtocol infrastructure (certificate + hostname verified) and end-to-end
encrypted over the relay; the keys are not exposed over the wire. The exposure
is strictly local, to someone holding the physical device.

## Why software-only encryption does not fix this

Encrypting the flash contents from application code does not help on its own,
because the decryption key would itself have to live somewhere on the same
readable flash. Without a **hardware root of trust**, any key the firmware can
read at boot, an attacker who dumps the flash can also read.

On ESP32, ESP-IDF *NVS encryption* has the same dependency: it protects NVS with
XTS-AES keys held in a dedicated `nvs_keys` partition, and that partition is
only safe when **flash encryption** protects it. NVS encryption without flash
encryption does not defeat a flash dump, and in any case would not cover
`atkeys.json`, which lives on LittleFS rather than in NVS.

The only mechanism that actually protects secrets at rest on this hardware is
**flash encryption** (optionally with **secure boot**), which derives its key
from an eFuse that is not readable off-chip.

## Mitigations

### 1. Operational: keys are per-device and rotatable (primary mitigation)

Each device has its **own** atSign / enrollment; there is no shared secret. If a
device is lost, stolen, decommissioned, or sent for RMA, **revoke or rotate its
enrollment** from the managing atSign app so any keys recovered from its flash
become useless. This bounds the blast radius of a physical compromise to a
single device and only until its enrollment is revoked.

Practical guidance:

- Treat a physically compromised device as compromised: rotate/revoke its
  enrollment rather than trusting a wipe.
- Before resale or return, revoke the enrollment (a factory reset unlinks files
  but does not guarantee the key bytes are erased from flash).
- Scope each device narrowly with `permitOpen` so a compromised device grants
  the least access possible (see the per-package configuration docs).

### 2. Hardware: enable flash encryption for untrusted deployments

For devices deployed in physically untrusted locations, enable ESP32 **flash
encryption** (and consider **secure boot**). This encrypts both the LittleFS
partition holding `atkeys.json` and the NVS partition holding config/WiFi
credentials, so a flash dump yields only ciphertext.

This is **not enabled by default** in this repo because it is an irreversible,
per-chip eFuse commitment:

- Enabling flash encryption **burns eFuses** and cannot be undone on that chip.
- In **Release** mode the device will no longer accept plaintext firmware over
  UART, which can brick development boards mid-iteration.
- Use **Development** mode while testing (it keeps re-flashing possible and
  limits the encryption-key eFuse burns), and only move to Release mode for
  production units you do not need to re-flash over UART.

See Espressif's documentation for the exact procedure and trade-offs:

- Flash Encryption:
  <https://docs.espressif.com/projects/esp-idf/en/latest/esp32/security/flash-encryption.html>
- Secure Boot v2:
  <https://docs.espressif.com/projects/esp-idf/en/latest/esp32/security/secure-boot-v2.html>

At a high level, for a PlatformIO build you would add the relevant
`CONFIG_SECURE_FLASH_ENC_ENABLED`, `CONFIG_SECURE_FLASH_ENCRYPTION_MODE_*`, and
(optionally) `CONFIG_SECURE_BOOT` options to the package's `sdkconfig.defaults`,
then flash once over UART to perform the initial encryption. Validate the whole
flow on a sacrificial board first.

## Summary

- By default, atSign keys and WiFi credentials are recoverable from a device's
  flash by anyone with physical access. This is inherent to storing secrets on a
  microcontroller without a hardware root of trust.
- The primary, always-available mitigation is **operational**: keys are
  per-device and can be **rotated/revoked**, so a physically compromised device
  can be cut off from the network.
- For physically untrusted deployments, additionally enable **ESP32 flash
  encryption**, understanding the irreversible eFuse trade-offs above.
