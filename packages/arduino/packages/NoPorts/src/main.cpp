/**
 * LoadKeysFromSPIFFS.ino
 *
 * Example showing how to load atKeys from the ESP32 filesystem (SPIFFS/LittleFS)
 * instead of hardcoding them in the sketch.
 *
 * Steps to use:
 *   1. Upload your .atKeys file to the ESP32 SPIFFS partition as "/atkeys.json"
 *      (use the ESP32 Filesystem Uploader plugin or esptool)
 *   2. Flash this sketch
 *   3. The daemon will read and decrypt the keys at boot
 *
 * To upload files to SPIFFS:
 *   - Arduino IDE: Install "ESP32 Sketch Data Upload" plugin, put atkeys.json
 *     in the "data" folder of your sketch, then use Tools > ESP32 Sketch Data Upload
 *   - PlatformIO: Put atkeys.json in the "data" folder, run "pio run -t uploadfs"
 *   - esptool: Use espflash or similar tool
 */

#include <WiFi.h>
#include <NoPorts.h>

extern "C" {
  #include "atlogger/atlogger.h"
}

const char *WIFI_SSID      = "YOUR_WIFI_SSID";
const char *WIFI_PASSWORD  = "YOUR_WIFI_PASSWORD";
const char *DEVICE_ATSIGN  = "@your_device_atsign";
const char *DEVICE_NAME    = "esp32";
const char *MANAGER_ATSIGN = "@your_manager_atsign";

NoPortsDaemon npDaemon;

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("NoPorts - Loading keys from filesystem");

  // Enable atSDK internal logging so we can see connection errors
  atlogger_set_logging_level(ATLOGGER_LOGGING_LEVEL_INFO);

  // WiFi
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.printf("\nWiFi connected: %s\n", WiFi.localIP().toString().c_str());

  // Configure daemon
  NoPortsConfig config;
  noports_config_init(&config);
  config.atsign       = DEVICE_ATSIGN;
  config.device_name  = DEVICE_NAME;
  config.manager_list[0] = MANAGER_ATSIGN;
  config.manager_count   = 1;

  // Optional root server spec (default root.atsign.org:64). On networks
  // where only port 443 egress is allowed, use a protocol-aware reverse
  // proxy instead — no atDirectory lookup is made:
  //   config.root_domain = "proxy:proxy0001.atsign.org:443";

  // Load keys from SPIFFS
  int res = noports_keys_load_from_file(&config, "/atkeys.json");
  if (res != 0) {
    Serial.println("ERROR: Failed to load atkeys from SPIFFS!");
    Serial.println("Make sure you've uploaded /atkeys.json to SPIFFS.");
    while (true) { delay(1000); }
  }
  Serial.println("Keys loaded from SPIFFS successfully");

  // Allow tunneling to local web server
  config.permitopen[0] = { "192.168.1.149", 22 };
  config.permitopen[1] = { "192.168.1.149", 2200};
  config.permitopen_count = 2;

  // Start daemon
  if (!npDaemon.begin(config)) {
    Serial.printf("NoPorts failed: %s\n", npDaemon.getLastError());
    while (true) { delay(1000); }
  }
  Serial.println("NoPorts daemon running!");

  // Note: noports_keys_free(&config) should be called if you want to
  // reclaim the memory used by the decrypted keys. But since the daemon
  // has already copied what it needs, it's safe to free here.
  noports_keys_free(&config);
}

void loop() {
  npDaemon.loop();

  // The sketch is the daemon's supervisor (the Linux sshnpd relies on
  // systemd Restart=always for this).  If the daemon stops on its own —
  // internal error, or the testing shutdown notification — reboot to
  // recover; this bare example has no other recovery path.
  if (!npDaemon.isRunning()) {
    Serial.println("NoPorts daemon stopped — rebooting in 5 s");
    delay(5000);
    ESP.restart();
  }

  delay(10);
}