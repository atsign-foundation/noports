#pragma once
#include <Arduino.h>

// M5Stack Unit PoE-P4 RGB LED pins
#define LED_PIN_R  17
#define LED_PIN_G  15
#define LED_PIN_B  16

// PoE-P4 RGB LED is common-anode: pull LOW to illuminate, HIGH to extinguish.
#define LED_ON  LOW
#define LED_OFF HIGH

enum class LedMode : uint8_t {
  OFF       = 0,  // stealth — always dark
  HEARTBEAT = 1,  // minimal: one colour encodes overall health, brief pulse
  STATUS    = 2,  // colour encodes state, steady (blinks only on error/enroll)
  FULL      = 3,  // status + brief white flash on every tunnel event
};

enum class LedState : uint8_t {
  NO_NETWORK,    // Ethernet not connected or DHCP pending
  UNCONFIGURED,  // network OK but device not enrolled
  ENROLLING,     // OTP enrollment in progress
  RUNNING,       // daemon up and healthy
  ERROR,         // daemon not running after being configured
};

void led_init(LedMode mode);
void led_set_mode(LedMode mode);
LedMode led_get_mode();
void led_update(LedState state);
void led_on_tunnel_event();   // call from tunnel open/close; flashes white in FULL mode
void led_identify(uint32_t ms = 15000);  // start identify cycle; overrides all modes
bool led_identifying();       // true while identify is running
