/**
 * BasicDaemon.ino
 *
 * Minimal example of running a NoPorts daemon on an ESP32.
 *
 * This sketch:
 *   1. Connects to WiFi
 *   2. Configures the NoPorts daemon with your atSign, device name, and keys
 *   3. Starts listening for NPT tunnel requests
 *   4. Relays incoming connections to a local TCP service (e.g., a web server
 *      running on port 80)
 *
 * Prerequisites:
 *   - ESP32 board with WiFi
 *   - An activated atSign with .atKeys file
 *   - A manager atSign (the atSign you'll connect FROM)
 *
 * IMPORTANT: Replace the placeholder values below with your own:
 *   - WiFi credentials
 *   - atSign
 *   - Manager atSign
 *   - Decrypted atKeys (see README.md for how to extract these)
 */

#include <WiFi.h>
#include <NoPorts.h>

// ============================================================================
// Configuration - REPLACE THESE VALUES
// ============================================================================

// WiFi credentials
const char *WIFI_SSID     = "YOUR_WIFI_SSID";
const char *WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";

// Your device's atSign (the atSign registered for THIS device)
const char *DEVICE_ATSIGN = "@your_device_atsign";

// Device name (appears in noports client device list)
const char *DEVICE_NAME   = "esp32";

// Manager atSign (the atSign you connect FROM, e.g., your laptop's atSign)
const char *MANAGER_ATSIGN = "@your_manager_atsign";

// ============================================================================
// !! SECURITY WARNING — READ BEFORE PASTING KEYS BELOW !!
// ----------------------------------------------------------------------------
// The values below are your atSign's DECRYPTED private keys. Anyone who obtains
// them can fully impersonate this device on the atProtocol network.
//
//   * NEVER commit this file with real keys. Committing to a public repo is the
//     single most common way IoT keys leak. Keep it out of version control.
//   * Hardcoded keys are baked into the firmware binary in the CLEAR and are
//     recoverable from flash with `esptool.py read_flash` unless you enable
//     ESP32 flash encryption. Do not ship production images this way.
//   * For anything beyond quick local testing, prefer loading keys from a file
//     at runtime (see the LoadKeysFromSPIFFS example) and enable flash
//     encryption — see README.md.
// ============================================================================

// Decrypted atKeys - paste your base64-encoded keys here.
// See README.md section "Extracting Keys" for instructions.
const char *PKAM_PUBLIC_KEY  = "PASTE_YOUR_PKAM_PUBLIC_KEY_BASE64_HERE";
const char *PKAM_PRIVATE_KEY = "PASTE_YOUR_PKAM_PRIVATE_KEY_BASE64_HERE";
const char *ENC_PUBLIC_KEY   = "PASTE_YOUR_ENCRYPT_PUBLIC_KEY_BASE64_HERE";
const char *ENC_PRIVATE_KEY  = "PASTE_YOUR_ENCRYPT_PRIVATE_KEY_BASE64_HERE";
const char *SELF_ENC_KEY     = "PASTE_YOUR_SELF_ENCRYPTION_KEY_BASE64_HERE";

// ============================================================================
// Global objects
// ============================================================================

NoPortsDaemon daemon;

// ============================================================================
// Callbacks (optional)
// ============================================================================

void onTunnelOpen(const char *host, uint16_t port, const char *session_id) {
  Serial.printf("[CALLBACK] Tunnel opened: %s:%d (session: %s)\n", host, port, session_id);
}

void onTunnelClose(const char *session_id) {
  Serial.printf("[CALLBACK] Tunnel closed: %s\n", session_id);
}

void onPing(const char *from) {
  Serial.printf("[CALLBACK] Ping from: %s\n", from);
}

// ============================================================================
// Setup
// ============================================================================

void setup() {
  Serial.begin(115200);
  delay(1000);

  Serial.println("=================================");
  Serial.println("  NoPorts ESP32 Daemon");
  Serial.println("=================================");

  // Connect to WiFi
  Serial.printf("Connecting to WiFi: %s", WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.printf("\nConnected! IP: %s\n", WiFi.localIP().toString().c_str());

  // Configure the daemon
  NoPortsConfig config;
  noports_config_init(&config);

  config.atsign       = DEVICE_ATSIGN;
  config.device_name  = DEVICE_NAME;
  config.verbose      = true;  // set to false for less Serial output

  // Set the manager (the atSign that can request tunnels)
  config.manager_list[0] = MANAGER_ATSIGN;
  config.manager_count   = 1;

  // Set keys
  noports_keys_set(&config,
    PKAM_PUBLIC_KEY,
    PKAM_PRIVATE_KEY,
    ENC_PUBLIC_KEY,
    ENC_PRIVATE_KEY,
    SELF_ENC_KEY
  );

  // Permit tunneling to a local web server on port 80
  // Add more entries for other services
  config.permitopen[0] = { "localhost", 80 };
  config.permitopen[1] = { "127.0.0.1", 80 };
  config.permitopen_count = 2;

  // Set callbacks (optional)
  config.on_tunnel_open  = onTunnelOpen;
  config.on_tunnel_close = onTunnelClose;
  config.on_ping         = onPing;

  // Start the daemon
  Serial.println("Starting NoPorts daemon...");
  if (!daemon.begin(config)) {
    Serial.printf("ERROR: Failed to start daemon: %s\n", daemon.getLastError());
    Serial.println("Halting.");
    while (true) { delay(1000); }
  }

  Serial.println("NoPorts daemon is running!");
  Serial.printf("Device: %s, atSign: %s\n", DEVICE_NAME, DEVICE_ATSIGN);
  Serial.println("Waiting for tunnel requests...");
}

// ============================================================================
// Loop
// ============================================================================

void loop() {
  // Process NoPorts notifications (non-blocking)
  daemon.loop();

  // Optionally print status every 30 seconds
  static unsigned long lastStatus = 0;
  if (millis() - lastStatus > 30000) {
    lastStatus = millis();
    Serial.printf("[STATUS] Active relays: %d, WiFi: %s, Heap free: %d bytes\n",
                  daemon.getActiveRelayCount(),
                  WiFi.isConnected() ? "connected" : "disconnected",
                  ESP.getFreeHeap());
  }

  // Small delay to be friendly to the RTOS scheduler
  delay(10);
}
