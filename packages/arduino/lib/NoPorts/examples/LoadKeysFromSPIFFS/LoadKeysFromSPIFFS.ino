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
 *
 * !! SECURITY WARNING !!
 *   - atkeys.json contains your atSign's private keys (the self-encryption key
 *     sits next to the encrypted keys it protects, so the file == the identity).
 *     Keep it OUT of version control: do not commit the sketch's "data" folder.
 *     A stray `git add -A` after placing atkeys.json there publishes your keys.
 *     The repo .gitignore excludes *.atKeys / atkeys.json for this reason.
 *   - Keys on the filesystem are still readable from flash via
 *     `esptool.py read_flash` unless you enable ESP32 flash encryption. Enable
 *     it for production deployments.
 */

#include <WiFi.h>
#include <NoPorts.h>

const char *WIFI_SSID      = "YOUR_WIFI_SSID";
const char *WIFI_PASSWORD  = "YOUR_WIFI_PASSWORD";
const char *DEVICE_ATSIGN  = "@your_device_atsign";
const char *DEVICE_NAME    = "esp32_fs";
const char *MANAGER_ATSIGN = "@your_manager_atsign";

NoPortsDaemon daemon;

void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("NoPorts - Loading keys from filesystem");

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

  // Load keys from SPIFFS
  int res = noports_keys_load_from_file(&config, "/atkeys.json");
  if (res != 0) {
    Serial.println("ERROR: Failed to load atkeys from SPIFFS!");
    Serial.println("Make sure you've uploaded /atkeys.json to SPIFFS.");
    while (true) { delay(1000); }
  }
  Serial.println("Keys loaded from SPIFFS successfully");

  // Allow tunneling to local web server
  config.permitopen[0] = { "localhost", 80 };
  config.permitopen_count = 1;

  // Start daemon
  if (!daemon.begin(config)) {
    Serial.printf("NoPorts failed: %s\n", daemon.getLastError());
    while (true) { delay(1000); }
  }
  Serial.println("NoPorts daemon running!");

  // Note: noports_keys_free(&config) should be called if you want to
  // reclaim the memory used by the decrypted keys. But since the daemon
  // has already copied what it needs, it's safe to free here.
  noports_keys_free(&config);
}

void loop() {
  daemon.loop();
  delay(10);
}
