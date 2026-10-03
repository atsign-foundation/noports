#include "led.h"

static LedMode   _mode             = LedMode::OFF;
static uint32_t  _flash_until_ms   = 0;  // non-zero = show white until this time (FULL mode)
static uint32_t  _identify_until_ms = 0; // non-zero = identify cycle running

// Cached output — _set() only touches GPIO when a channel actually changes.
static int8_t _cur_r = -1, _cur_g = -1, _cur_b = -1;  // -1 = uninitialised

// ─── Primitives ───────────────────────────────────────────────────────────────

static void _set(bool r, bool g, bool b) {
  if ((int8_t)r != _cur_r) { digitalWrite(LED_PIN_R, r ? LED_ON : LED_OFF); _cur_r = r; }
  if ((int8_t)g != _cur_g) { digitalWrite(LED_PIN_G, g ? LED_ON : LED_OFF); _cur_g = g; }
  if ((int8_t)b != _cur_b) { digitalWrite(LED_PIN_B, b ? LED_ON : LED_OFF); _cur_b = b; }
}

static void _off() { _set(false, false, false); }

// True during the ON phase of a square-wave blink.
static bool _blink(uint32_t period_ms, uint32_t duty_ms = 0) {
  if (!duty_ms) duty_ms = period_ms / 2;
  return (millis() % period_ms) < duty_ms;
}

// ─── Public API ───────────────────────────────────────────────────────────────

void led_init(LedMode mode) {
  pinMode(LED_PIN_R, OUTPUT);
  pinMode(LED_PIN_G, OUTPUT);
  pinMode(LED_PIN_B, OUTPUT);
  _off();
  _mode = mode;
}

void led_set_mode(LedMode mode) {
  _mode = mode;
  if (mode == LedMode::OFF) _off();
}

LedMode led_get_mode() { return _mode; }

// Called from tunnel open/close callbacks — sets a short white-flash timer.
void led_on_tunnel_event() {
  if (_mode == LedMode::FULL) _flash_until_ms = millis() + 250;
}

void led_identify(uint32_t ms) {
  _identify_until_ms = millis() + ms;
}

bool led_identifying() {
  return _identify_until_ms && millis() < _identify_until_ms;
}

void led_update(LedState state) {
  // Throttle to 20 Hz — blink patterns need no finer resolution than 50 ms,
  // and this keeps GPIO writes well under 60 per second total.
  static uint32_t _last_ms = 0;
  uint32_t now = millis();
  if (now - _last_ms < 50) return;
  _last_ms = now;

  // Identify overrides everything including stealth — it's a deliberate user action.
  if (_identify_until_ms) {
    if (now < _identify_until_ms) {
      // Cycle R→G→B every 100 ms (full cycle 300 ms) — unmistakable.
      switch ((now / 100) % 3) {
        case 0: _set(true,  false, false); break;  // red
        case 1: _set(false, true,  false); break;  // green
        case 2: _set(false, false, true);  break;  // blue
      }
      return;
    }
    _identify_until_ms = 0;
    // Force output cache reset so normal mode repaints correctly after identify.
    _cur_r = _cur_g = _cur_b = -1;
  }

  if (_mode == LedMode::OFF) { _off(); return; }

  // FULL mode: white flash on tunnel activity overrides the state colour.
  if (_mode == LedMode::FULL && _flash_until_ms) {
    if (now < _flash_until_ms) { _set(true, true, true); return; }
    _flash_until_ms = 0;
  }

  switch (state) {

    case LedState::NO_NETWORK:
      // Blue — blinks in HEARTBEAT, steady in STATUS/FULL
      (_mode == LedMode::HEARTBEAT)
        ? (_blink(1000) ? _set(false, false, true) : _off())
        : _set(false, false, true);
      break;

    case LedState::UNCONFIGURED:
      // Amber (R+G) — slow blink in HEARTBEAT, steady in STATUS/FULL
      (_mode == LedMode::HEARTBEAT)
        ? (_blink(2000) ? _set(true, true, false) : _off())
        : _set(true, true, false);
      break;

    case LedState::ENROLLING:
      // Cyan (G+B) — fast blink in all modes so it looks "busy"
      _blink(400) ? _set(false, true, true) : _off();
      break;

    case LedState::RUNNING:
      // Green — single heartbeat pulse in HEARTBEAT, steady in STATUS/FULL
      (_mode == LedMode::HEARTBEAT)
        ? (_blink(5000, 120) ? _set(false, true, false) : _off())
        : _set(false, true, false);
      break;

    case LedState::ERROR:
      // Red — fast blink in all modes
      _blink(300) ? _set(true, false, false) : _off();
      break;
  }
}
