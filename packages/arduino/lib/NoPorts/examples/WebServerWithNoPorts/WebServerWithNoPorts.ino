/**
 * WebServerWithNoPorts.ino
 *
 * Advanced example: Run a web server on the ESP32 and expose it
 * securely through NoPorts tunneling.
 *
 * No port-forwarding, no public IP, no firewall configuration needed.
 * Access your ESP32's web interface from anywhere using the noports client.
 *
 * Usage (from your laptop):
 *   npt -f @your_manager_atsign \
 *       -t @your_device_atsign \
 *       -d esp32_web \
 *       -rh localhost -rp 80 \
 *       -lp 8080
 *
 *   Then open http://localhost:8080 in your browser.
 */

#include <WiFi.h>
#include <WebServer.h>
#include <NoPorts.h>

// ============================================================================
// Configuration
// ============================================================================

const char *WIFI_SSID     = "YOUR_WIFI_SSID";
const char *WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";
const char *DEVICE_ATSIGN = "@your_device_atsign";
const char *DEVICE_NAME   = "esp32_web";
const char *MANAGER_ATSIGN = "@your_manager_atsign";

// ============================================================================
// !! SECURITY WARNING !! The values below are DECRYPTED atSign private keys —
// anyone who obtains them can fully impersonate this device. NEVER commit this
// file with real keys (public-repo commits are the #1 IoT key-leak vector), and
// note that hardcoded keys are baked into the firmware in the CLEAR and are
// recoverable via `esptool.py read_flash` unless ESP32 flash encryption is
// enabled. For anything beyond local testing, load keys from a file at runtime
// (see LoadKeysFromSPIFFS) and enable flash encryption. See README.md.
// ============================================================================

// Keys - see BasicDaemon example and README.md
const char *PKAM_PUBLIC_KEY  = "YOUR_KEY_HERE";
const char *PKAM_PRIVATE_KEY = "YOUR_KEY_HERE";
const char *ENC_PUBLIC_KEY   = "YOUR_KEY_HERE";
const char *ENC_PRIVATE_KEY  = "YOUR_KEY_HERE";
const char *SELF_ENC_KEY     = "YOUR_KEY_HERE";

// ============================================================================
// Objects
// ============================================================================

WebServer webServer(80);
NoPortsDaemon noportsDaemon;

// ============================================================================
// Web server handlers
// ============================================================================

void handleRoot() {
  String html = "<!DOCTYPE html><html><head>";
  html += "<title>ESP32 NoPorts Dashboard</title>";
  html += "<meta name='viewport' content='width=device-width, initial-scale=1'>";
  html += "<style>body{font-family:sans-serif;margin:2em;background:#f5f5f5;}";
  html += ".card{background:white;padding:1.5em;border-radius:8px;box-shadow:0 2px 4px rgba(0,0,0,0.1);margin:1em 0;}";
  html += "h1{color:#333;} .label{color:#666;font-size:0.9em;} .value{font-size:1.2em;font-weight:bold;}</style></head>";
  html += "<body><h1>ESP32 NoPorts Dashboard</h1>";

  html += "<div class='card'>";
  html += "<div class='label'>Free Heap</div>";
  html += "<div class='value'>" + String(ESP.getFreeHeap()) + " bytes</div></div>";

  html += "<div class='card'>";
  html += "<div class='label'>WiFi RSSI</div>";
  html += "<div class='value'>" + String(WiFi.RSSI()) + " dBm</div></div>";

  html += "<div class='card'>";
  html += "<div class='label'>Uptime</div>";
  html += "<div class='value'>" + String(millis() / 1000) + " seconds</div></div>";

  html += "<div class='card'>";
  html += "<div class='label'>Active Tunnels</div>";
  html += "<div class='value'>" + String(noportsDaemon.getActiveRelayCount()) + "</div></div>";

  html += "<div class='card'>";
  html += "<div class='label'>IP Address</div>";
  html += "<div class='value'>" + WiFi.localIP().toString() + "</div></div>";

  html += "<p style='color:#999;font-size:0.8em;'>Secured by NoPorts - no open ports required!</p>";
  html += "</body></html>";

  webServer.send(200, "text/html", html);
}

void handleApi() {
  String json = "{";
  json += "\"heap\":" + String(ESP.getFreeHeap()) + ",";
  json += "\"rssi\":" + String(WiFi.RSSI()) + ",";
  json += "\"uptime\":" + String(millis() / 1000) + ",";
  json += "\"tunnels\":" + String(noportsDaemon.getActiveRelayCount());
  json += "}";
  webServer.send(200, "application/json", json);
}

// ============================================================================
// Setup
// ============================================================================

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("ESP32 Web Server + NoPorts");

  // WiFi
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.printf("\nWiFi connected: %s\n", WiFi.localIP().toString().c_str());

  // Start web server (listening locally)
  webServer.on("/", handleRoot);
  webServer.on("/api", handleApi);
  webServer.begin();
  Serial.println("Web server started on port 80");

  // Configure NoPorts
  NoPortsConfig config;
  noports_config_init(&config);
  config.atsign       = DEVICE_ATSIGN;
  config.device_name  = DEVICE_NAME;
  config.manager_list[0] = MANAGER_ATSIGN;
  config.manager_count   = 1;

  noports_keys_set(&config, PKAM_PUBLIC_KEY, PKAM_PRIVATE_KEY,
                   ENC_PUBLIC_KEY, ENC_PRIVATE_KEY, SELF_ENC_KEY);

  // Only permit tunneling to our web server
  config.permitopen[0] = { "localhost", 80 };
  config.permitopen[1] = { "127.0.0.1", 80 };
  config.permitopen_count = 2;

  if (!noportsDaemon.begin(config)) {
    Serial.printf("NoPorts failed: %s\n", noportsDaemon.getLastError());
    // Web server still works locally, just no remote access
  } else {
    Serial.println("NoPorts daemon running - remote access enabled!");
  }
}

// ============================================================================
// Loop
// ============================================================================

void loop() {
  webServer.handleClient();   // handle local web requests
  noportsDaemon.loop();       // handle NoPorts tunnel requests
  delay(2);
}
