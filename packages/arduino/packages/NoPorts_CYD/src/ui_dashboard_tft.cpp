/**
 * @file ui_dashboard_tft.cpp
 * @brief Dashboard screen implementation using TFT_eSPI
 */

#include "ui_dashboard_tft.h"
#include "ui_tft.h"
#include <Arduino.h>
#include <WiFi.h>

// ---------------------------------------------------------------------------
// Layout constants
// ---------------------------------------------------------------------------
#define HEADER_HEIGHT     30
#define HEADER_PADDING    3
#define STATS_ROW1_Y      (HEADER_PADDING + HEADER_HEIGHT + 3)
#define STATS_ROW2_Y      (STATS_ROW1_Y + 26)
#define LOG_TOP_Y         (STATS_ROW2_Y + 26)
#define LOG_HEIGHT        48
#define GRAPH_TOP_Y       (LOG_TOP_Y + LOG_HEIGHT + 3)
#define GRAPH_HEIGHT      54
#define BOTTOM_ROW_Y      (TFT_HEIGHT - 30)
#define SPACING           3

#define LOG_MAX_ENTRIES   3
#define LOG_ENTRY_HEIGHT  14

// Throughput graph
#define GRAPH_SAMPLES     40
#define GRAPH_PAD_L       38   // left padding for axis labels
#define GRAPH_PAD_R       4
#define GRAPH_PAD_T       12   // top padding for title
#define GRAPH_PAD_B       2

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
static uint32_t _boot_ms = 0;
static int _active_relays = 0;
static uint32_t _total_tunnels = 0;
static int _relay_tcp_count = 0;
static int _relay_pcb_max = 11;
static uint32_t _total_pings = 0;
static char _daemon_state[32] = "init";
static uint8_t _cpu_pct = 0;
static void (*_on_reset_cb)() = nullptr;
static void (*_on_settings_cb)() = nullptr;
static void (*_on_wifi_cb)() = nullptr;
static void (*_on_config_cb)() = nullptr;

// Log entries (ring buffer)
struct LogEntry {
  char text[EVENT_TEXT_LEN];
  uint16_t color;
  bool used;
};

static LogEntry _log_entries[LOG_MAX_ENTRIES];
static int _log_head = 0;

// Throughput graph ring buffer
static uint32_t _tp_in[GRAPH_SAMPLES];   // bytes received per sample period
static uint32_t _tp_out[GRAPH_SAMPLES];  // bytes sent per sample period
static int _tp_head = 0;
static uint32_t _prev_bytes_in = 0;
static uint32_t _prev_bytes_out = 0;

// WiFi / identity info
static String _atsign;
static String _device;

// Bottom row button layout — 6 uniform buttons with 4px gaps, sized to fill
// TFT_WIDTH: 49 px at 320 (6*49 + 5*4 + 2*3 = 320), 62 px at 400.
#define BTN_H         26
#define BTN_Y         (TFT_HEIGHT - BTN_H - 2)
#define BTN_GAP        4
#define BTN_MARGIN     3
#define BTN_W         ((TFT_WIDTH - 2 * BTN_MARGIN - 5 * BTN_GAP) / 6)
// Button x positions
#define LED_BTN_X     BTN_MARGIN
#define LCD_BTN_X     (BTN_MARGIN + 1*(BTN_W + BTN_GAP))
#define WIFI_BTN_X    (BTN_MARGIN + 2*(BTN_W + BTN_GAP))
#define CFG_BTN_X     (BTN_MARGIN + 3*(BTN_W + BTN_GAP))
#define RULES_BTN_X   (BTN_MARGIN + 4*(BTN_W + BTN_GAP))
#define RESET_BTN_X   (BTN_MARGIN + 5*(BTN_W + BTN_GAP))

// Confirm-reset state
static bool _reset_confirming = false;
static uint32_t _reset_confirm_ms = 0;
#define RESET_CONFIRM_TIMEOUT 3000  // 3 seconds to confirm

// LED toggle state
static bool _led_enabled = true;

// Screen-off (backlight off) state
// When true, backlight is off, all TFT drawing is suppressed.
// Any touch wakes the screen immediately.
static bool _screen_off        = false;
static bool _screen_wake_redraw = false;  // flag: do a full redraw on next update after wake

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

static void _add_log_entry(const char *text, uint16_t color) {
  LogEntry &entry = _log_entries[_log_head];
  strncpy(entry.text, text, EVENT_TEXT_LEN - 1);
  entry.text[EVENT_TEXT_LEN - 1] = '\0';
  entry.color = color;
  entry.used = true;
  _log_head = (_log_head + 1) % LOG_MAX_ENTRIES;
}

static void _draw_header() {
  TFT_eSPI &tft = ui_get_tft();
  int y = HEADER_PADDING;
  
  // Background card
  ui_draw_rounded_rect(HEADER_PADDING, y, TFT_WIDTH - 6, HEADER_HEIGHT, 5, COLOR_BG_CARD);
  
  // atSign (left)
  tft.setTextColor(COLOR_PRIMARY);
  tft.setTextDatum(ML_DATUM);
  tft.setTextSize(1);
  tft.drawString(_atsign.c_str(), HEADER_PADDING + 6, y + HEADER_HEIGHT / 2, 2);
  
  // Device name (center)
  tft.setTextColor(COLOR_TEXT_WHITE);
  tft.setTextDatum(MC_DATUM);
  tft.drawString(_device.c_str(), TFT_WIDTH / 2, y + HEADER_HEIGHT / 2, 2);
  
  // IP address (right)
  String ip = WiFi.localIP().toString();
  tft.setTextColor(COLOR_ACCENT);
  tft.setTextDatum(MR_DATUM);
  tft.drawString(ip.c_str(), TFT_WIDTH - HEADER_PADDING - 6, y + HEADER_HEIGHT / 2, 2);
}

static void _draw_stats_row1() {
  TFT_eSPI &tft = ui_get_tft();
  int y = STATS_ROW1_Y;
  
  // Card background drawn once in ui_dashboard_create() — clear only text zones
  char buf[40];
  
  // --- State indicator (left zone) ---
  tft.fillRect(HEADER_PADDING + 4, y + 2, 110, 18, COLOR_BG_CARD);
  uint16_t state_color = COLOR_TEXT_GREY;
  if (strcmp(_daemon_state, "running") == 0) state_color = COLOR_SUCCESS;
  else if (strcmp(_daemon_state, "auth") == 0) state_color = COLOR_ACCENT;
  else if (strcmp(_daemon_state, "error") == 0) state_color = COLOR_ERROR;
  tft.fillCircle(HEADER_PADDING + 12, y + 11, 4, state_color);
  snprintf(buf, sizeof(buf), "%s", _daemon_state);
  tft.setTextColor(COLOR_TEXT_WHITE, COLOR_BG_CARD);
  tft.setTextDatum(ML_DATUM);
  tft.setTextSize(1);
  tft.drawString(buf, HEADER_PADDING + 22, y + 11, 2);
  
  // --- Active relays (center zone) ---
  tft.fillRect(TFT_WIDTH / 2 - 45, y + 2, 90, 18, COLOR_BG_CARD);
  snprintf(buf, sizeof(buf), "Active: %d", _active_relays);
  tft.setTextColor(_active_relays > 0 ? COLOR_SUCCESS : COLOR_TEXT_GREY, COLOR_BG_CARD);
  tft.setTextDatum(MC_DATUM);
  tft.drawString(buf, TFT_WIDTH / 2, y + 11, 2);
  
  // --- Uptime (right zone) ---
  tft.fillRect(TFT_WIDTH - HEADER_PADDING - 80, y + 2, 76, 18, COLOR_BG_CARD);
  char uptime_str[20];
  ui_format_uptime(millis() - _boot_ms, uptime_str, sizeof(uptime_str));
  tft.setTextColor(COLOR_TEXT_GREY, COLOR_BG_CARD);
  tft.setTextDatum(MR_DATUM);
  tft.drawString(uptime_str, TFT_WIDTH - HEADER_PADDING - 6, y + 11, 2);
}

static void _draw_stats_row2() {
  TFT_eSPI &tft = ui_get_tft();
  int y = STATS_ROW2_Y;
  
  // Card background drawn once in ui_dashboard_create() — clear only text zones
  char buf[40];
  
  // --- TCP socket count (left zone) ---
  tft.fillRect(HEADER_PADDING + 4, y + 2, 105, 18, COLOR_BG_CARD);
  snprintf(buf, sizeof(buf), "TCP: %d/%d", _relay_tcp_count, _relay_pcb_max);
  // warn at >85%, error at >90% of max
  int tcp_warn  = (_relay_pcb_max * 85) / 100;
  int tcp_error = (_relay_pcb_max * 90) / 100;
  uint16_t tcp_color = _relay_tcp_count > tcp_error ? COLOR_ERROR : (_relay_tcp_count > tcp_warn ? COLOR_ACCENT : COLOR_SUCCESS);
  tft.setTextColor(tcp_color, COLOR_BG_CARD);
  tft.setTextDatum(ML_DATUM);
  tft.setTextSize(1);
  tft.drawString(buf, HEADER_PADDING + 8, y + 11, 2);
  
  // --- CPU % (center zone) ---
  tft.fillRect(TFT_WIDTH / 2 - 45, y + 2, 90, 18, COLOR_BG_CARD);
  uint16_t cpu_color = COLOR_SUCCESS;  // green < 50%
  if (_cpu_pct >= 80) cpu_color = COLOR_ERROR;       // red >= 80%
  else if (_cpu_pct >= 50) cpu_color = COLOR_ACCENT;  // orange >= 50%
  snprintf(buf, sizeof(buf), "Relay: %d%%", _cpu_pct);
  tft.setTextColor(cpu_color, COLOR_BG_CARD);
  tft.setTextDatum(MC_DATUM);
  tft.drawString(buf, TFT_WIDTH / 2, y + 11, 2);
  
  // --- Heap (right zone) ---
  tft.fillRect(TFT_WIDTH - HEADER_PADDING - 80, y + 2, 76, 18, COLOR_BG_CARD);
  snprintf(buf, sizeof(buf), "Heap: %uK", ESP.getFreeHeap() / 1024);
  tft.setTextColor(COLOR_TEXT_GREY, COLOR_BG_CARD);
  tft.setTextDatum(MR_DATUM);
  tft.drawString(buf, TFT_WIDTH - HEADER_PADDING - 6, y + 11, 2);
}

static void _draw_log() {
  TFT_eSPI &tft = ui_get_tft();
  int y = LOG_TOP_Y;
  
  // Card background drawn once in create() — clear only the text content area
  tft.fillRect(HEADER_PADDING + 4, y + 3, TFT_WIDTH - 14, LOG_HEIGHT - 6, COLOR_BG_CARD);
  
  // Draw log entries (most recent first)
  tft.setTextDatum(TL_DATUM);
  tft.setTextSize(1);
  
  int entry_y = y + 4;
  int displayed = 0;
  
  for (int i = 0; i < LOG_MAX_ENTRIES && displayed < LOG_MAX_ENTRIES; i++) {
    int idx = (_log_head - 1 - i + LOG_MAX_ENTRIES) % LOG_MAX_ENTRIES;
    
    if (_log_entries[idx].used) {
      tft.setTextColor(_log_entries[idx].color, COLOR_BG_CARD);
      tft.drawString(_log_entries[idx].text, HEADER_PADDING + 8, entry_y, 2);
      entry_y += LOG_ENTRY_HEIGHT;
      displayed++;
      
      if (entry_y + LOG_ENTRY_HEIGHT > y + LOG_HEIGHT) break;
    }
  }
}

// Format bits per second with appropriate unit suffix
static void _format_bps(uint32_t bits, char *buf, size_t len) {
  if (bits >= 1000000)
    snprintf(buf, len, "%.1fM", bits / 1000000.0f);
  else if (bits >= 1000)
    snprintf(buf, len, "%.0fK", bits / 1000.0f);
  else
    snprintf(buf, len, "%lu", (unsigned long)bits);
}

static void _draw_graph() {
  TFT_eSPI &tft = ui_get_tft();
  int x0 = HEADER_PADDING;
  int y0 = GRAPH_TOP_Y;
  int w  = TFT_WIDTH - 6;
  int h  = GRAPH_HEIGHT;

  // Graph plotting area (inside card, below title)
  int gx = x0 + GRAPH_PAD_L;
  int gy = y0 + GRAPH_PAD_T;
  int gw = w - GRAPH_PAD_L - GRAPH_PAD_R;
  int gh = h - GRAPH_PAD_T - GRAPH_PAD_B;

  if (gw <= 0 || gh <= 0) return;

  // Find max value for scaling
  uint32_t max_val = 1;  // avoid /0
  for (int i = 0; i < GRAPH_SAMPLES; i++) {
    uint32_t combined = _tp_in[i] + _tp_out[i];
    if (combined > max_val) max_val = combined;
  }

  // --- Title / rate text (opaque text overwrites old, no fillRect needed) ---
  int last_idx = (_tp_head - 1 + GRAPH_SAMPLES) % GRAPH_SAMPLES;
  char tot_rx[10], tot_tx[10];
  // *2 for per-second (500ms sample), *8 for bits
  _format_bps(_tp_in[last_idx] * 2 * 8, tot_rx, sizeof(tot_rx));
  _format_bps(_tp_out[last_idx] * 2 * 8, tot_tx, sizeof(tot_tx));

  // Draw rx/tx labels in matching bar colors
  // Title (top-left)
  tft.setTextSize(1);
  tft.setTextDatum(TL_DATUM);
  tft.setTextColor(COLOR_TEXT_GREY, COLOR_BG_CARD);
  tft.drawString("bps", x0 + 6, y0 + 2, 1);

  // Rate values (right-aligned) — color-coded to match graph bars
  tft.setTextDatum(TR_DATUM);
  // Build string piece by piece to color each part
  int rx = x0 + w - 4;
  char tx_str[14], rx_str[14];
  snprintf(tx_str, sizeof(tx_str), "tx:%-5s", tot_tx);
  snprintf(rx_str, sizeof(rx_str), "rx:%-5s ", tot_rx);

  // Draw tx (orange = COLOR_PRIMARY) right-aligned
  tft.setTextColor(COLOR_PRIMARY, COLOR_BG_CARD);
  tft.drawString(tx_str, rx, y0 + 2, 1);
  int tx_w = tft.textWidth(tx_str, 1);

  // Draw rx (teal = COLOR_ACCENT) to the left of tx
  tft.setTextColor(COLOR_ACCENT, COLOR_BG_CARD);
  tft.drawString(rx_str, rx - tx_w, y0 + 2, 1);

  // --- Y-axis labels (clear only label column) ---
  tft.fillRect(x0 + 1, gy, GRAPH_PAD_L - 1, gh, COLOR_BG_CARD);
  char label[12];
  _format_bps(max_val * 8, label, sizeof(label));  // Y-axis in bits
  tft.setTextColor(COLOR_TEXT_GREY, COLOR_BG_CARD);
  tft.setTextDatum(MR_DATUM);
  tft.drawString(label, gx - 3, gy + 4, 1);
  tft.drawString("0", gx - 3, gy + gh - 2, 1);

  // --- Draw bars column-by-column (no bulk clear — each column is
  //     drawn atomically: background first, then bar, so no blank flash) ---
  int bar_w = gw / GRAPH_SAMPLES;
  if (bar_w < 1) bar_w = 1;
  int bar_gap = (bar_w > 2) ? 1 : 0;
  int draw_w = bar_w - bar_gap;  // pixel width of each drawn bar

  for (int i = 0; i < GRAPH_SAMPLES; i++) {
    int idx = (_tp_head + i) % GRAPH_SAMPLES;
    uint32_t val_in  = _tp_in[idx];
    uint32_t val_out = _tp_out[idx];

    int bx = gx + i * bar_w;
    if (bx + bar_w > gx + gw) break;  // don't draw past right edge

    if (val_in == 0 && val_out == 0) {
      // Empty column — paint background
      tft.fillRect(bx, gy, draw_w, gh, COLOR_BG_CARD);
      continue;
    }

    // Use uint64_t to prevent overflow on large throughput values
    int h_in  = (int)((uint64_t)val_in  * gh / max_val);
    int h_out = (int)((uint64_t)val_out * gh / max_val);

    // Clamp each individually, then combined
    if (h_in  > gh) h_in  = gh;
    if (h_out > gh) h_out = gh;
    if (h_in + h_out > gh) h_out = gh - h_in;
    if (h_in  < 0) h_in  = 0;
    if (h_out < 0) h_out = 0;

    int bar_total = h_in + h_out;
    int empty_h = gh - bar_total;

    // 1) Background above bars (clears any stale pixels)
    if (empty_h > 0) {
      tft.fillRect(bx, gy, draw_w, empty_h, COLOR_BG_CARD);
    }
    // 2) "out" bar (orange) stacked on top
    if (h_out > 0) {
      tft.fillRect(bx, gy + empty_h, draw_w, h_out, COLOR_PRIMARY);
    }
    // 3) "in" bar (teal) at bottom
    if (h_in > 0) {
      tft.fillRect(bx, gy + empty_h + h_out, draw_w, h_in, COLOR_ACCENT);
    }
  }

  // Fill any remaining pixels to the right of the last bar column
  int used_w = GRAPH_SAMPLES * bar_w;
  if (used_w < gw) {
    tft.fillRect(gx + used_w, gy, gw - used_w, gh, COLOR_BG_CARD);
  }
}

static void _draw_bottom_row() {
  TFT_eSPI &tft = ui_get_tft();

  // Clear bottom row area
  tft.fillRect(0, BTN_Y - 1, TFT_WIDTH, BTN_H + 3, COLOR_BG_DARK);

  // LED on/off toggle (left)
  uint16_t led_bg = _led_enabled ? COLOR_SUCCESS : COLOR_BG_CARD;
  ui_draw_rounded_rect(LED_BTN_X, BTN_Y, BTN_W, BTN_H, 4, led_bg);
  tft.setTextColor(_led_enabled ? 0x0000 : COLOR_TEXT_GREY);
  tft.setTextDatum(MC_DATUM);
  tft.setTextSize(1);
  tft.drawString("LED", LED_BTN_X + BTN_W / 2, BTN_Y + BTN_H / 2, 2);

  // LCD off button
  ui_draw_rounded_rect(LCD_BTN_X, BTN_Y, BTN_W, BTN_H, 4, COLOR_BUTTON_BG);
  tft.setTextColor(COLOR_TEXT_GREY);
  tft.setTextDatum(MC_DATUM);
  tft.drawString("LCD", LCD_BTN_X + BTN_W / 2, BTN_Y + BTN_H / 2, 2);

  // WiFi button (blue)
  ui_draw_rounded_rect(WIFI_BTN_X, BTN_Y, BTN_W, BTN_H, 4, COLOR_ACCENT);
  tft.setTextColor(COLOR_TEXT_WHITE);
  tft.setTextDatum(MC_DATUM);
  tft.drawString("WiFi", WIFI_BTN_X + BTN_W / 2, BTN_Y + BTN_H / 2, 2);

  // Settings/Config button
  ui_draw_rounded_rect(CFG_BTN_X, BTN_Y, BTN_W, BTN_H, 4, COLOR_BUTTON_BG);
  tft.setTextColor(COLOR_TEXT_WHITE);
  tft.setTextDatum(MC_DATUM);
  tft.drawString("Stngs", CFG_BTN_X + BTN_W / 2, BTN_Y + BTN_H / 2, 2);

  // Rules button
  ui_draw_rounded_rect(RULES_BTN_X, BTN_Y, BTN_W, BTN_H, 4, COLOR_BUTTON_BG);
  tft.setTextColor(COLOR_TEXT_WHITE);
  tft.setTextDatum(MC_DATUM);
  tft.drawString("Rules", RULES_BTN_X + BTN_W / 2, BTN_Y + BTN_H / 2, 2);

  // Reset button (far right, dark red — bright red when confirming)
  uint16_t reset_color = _reset_confirming ? COLOR_ERROR : 0x8000;
  ui_draw_rounded_rect(RESET_BTN_X, BTN_Y, BTN_W, BTN_H, 4, reset_color);
  tft.setTextColor(COLOR_TEXT_WHITE);
  tft.setTextDatum(MC_DATUM);
  tft.drawString(_reset_confirming ? "Sure?" : "Reset",
                 RESET_BTN_X + BTN_W / 2, BTN_Y + BTN_H / 2, 2);
}

// Version label drawn in the gap between the graph and the button row.
static void _draw_version_badge() {
  TFT_eSPI &tft = ui_get_tft();
  tft.setTextColor(COLOR_TEXT_GREY);
  tft.setTextDatum(MC_DATUM);
  tft.setTextSize(1);
  // Vertically centred between graph bottom (GRAPH_TOP_Y+GRAPH_HEIGHT) and BTN_Y
  tft.drawString("v" CYD_APP_VERSION, TFT_WIDTH / 2,
                 GRAPH_TOP_Y + GRAPH_HEIGHT + (BTN_Y - GRAPH_TOP_Y - GRAPH_HEIGHT) / 2, 1);
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

void ui_dashboard_create(void (*on_reset)(), void (*on_settings)(), void (*on_wifi)(), void (*on_config)()) {
  _boot_ms = millis();
  _on_reset_cb = on_reset;
  _on_settings_cb = on_settings;
  _on_wifi_cb = on_wifi;
  _on_config_cb = on_config;
  _reset_confirming = false;
  _screen_off = false;
  _screen_wake_redraw = false;
  ui_set_backlight(true);  // ensure backlight is on when dashboard is created
  
  // Load atSign and device info
  _atsign = ui_load_string(NVS_KEY_ATSIGN);
  _device = ui_load_string(NVS_KEY_DEVICE);
  
  // Clear log
  memset(_log_entries, 0, sizeof(_log_entries));
  _log_head = 0;

  // Clear throughput history
  memset(_tp_in, 0, sizeof(_tp_in));
  memset(_tp_out, 0, sizeof(_tp_out));
  _tp_head = 0;
  _prev_bytes_in = 0;
  _prev_bytes_out = 0;

  // Initial log entry
  _add_log_entry("Dashboard started", COLOR_SUCCESS);
  
  // Draw initial screen
  TFT_eSPI &tft = ui_get_tft();
  tft.fillScreen(COLOR_BG_DARK);
  
  _draw_header();
  
  // Pre-draw card backgrounds for dynamic sections (only done once;
  // update functions clear only small text zones to avoid flicker)
  ui_draw_rounded_rect(HEADER_PADDING, STATS_ROW1_Y, TFT_WIDTH - 6, 22, 4, COLOR_BG_CARD);
  ui_draw_rounded_rect(HEADER_PADDING, STATS_ROW2_Y, TFT_WIDTH - 6, 22, 4, COLOR_BG_CARD);
  ui_draw_rounded_rect(HEADER_PADDING, LOG_TOP_Y, TFT_WIDTH - 6, LOG_HEIGHT, 5, COLOR_BG_CARD);
  ui_draw_rounded_rect(HEADER_PADDING, GRAPH_TOP_Y, TFT_WIDTH - 6, GRAPH_HEIGHT, 5, COLOR_BG_CARD);
  
  _draw_stats_row1();
  _draw_stats_row2();
  _draw_log();
  _draw_graph();
  _draw_bottom_row();
  _draw_version_badge();

  Serial.println("[ui_dashboard] Created");
}

void ui_dashboard_update(int active_relays, const char *daemon_state,
                         uint32_t total_tunnels, uint32_t total_pings,
                         uint32_t bytes_in, uint32_t bytes_out,
                         uint8_t cpu_pct, int relay_tcp_count,
                         int relay_pcb_max) {
  // — — — screen-off early exit — — —
  // Still drain the event queue so log entries aren't lost, but skip
  // all TFT writes to save SPI bandwidth / CPU while backlight is off.
  if (_screen_off) {
    UiEvent evt;
    while (ui_event_pop(&evt)) {
      uint16_t c = COLOR_TEXT_WHITE;
      if (evt.type == UI_EVT_TUNNEL_OPEN)  c = COLOR_SUCCESS;
      else if (evt.type == UI_EVT_TUNNEL_CLOSE) c = COLOR_TEXT_GREY;
      else if (evt.type == UI_EVT_PING)    c = COLOR_ACCENT;
      else if (evt.type == UI_EVT_ERROR)   c = COLOR_ERROR;
      _add_log_entry(evt.text, c);
    }
    // LED updates still run (relay status LED should still reflect state)
    if (_led_enabled) {
      uint32_t delta_in  = bytes_in  - _prev_bytes_in;
      uint32_t delta_out = bytes_out - _prev_bytes_out;
      _prev_bytes_in  = bytes_in;
      _prev_bytes_out = bytes_out;
      if (delta_in + delta_out > 0)    ui_set_led(false, true, false);
      else if (active_relays > 0)      ui_set_led(true, true, false);
      else {
        ui_led_breathe_start(false, true, true);  // cyan breathe — standby
      }
    }
    return;
  }

  // If just woken up, do a full redraw to clear stale content
  if (_screen_wake_redraw) {
    _screen_wake_redraw = false;
    TFT_eSPI &tft = ui_get_tft();
    tft.fillScreen(COLOR_BG_DARK);
    _draw_header();
    ui_draw_rounded_rect(HEADER_PADDING, STATS_ROW1_Y, TFT_WIDTH - 6, 22, 4, COLOR_BG_CARD);
    ui_draw_rounded_rect(HEADER_PADDING, STATS_ROW2_Y, TFT_WIDTH - 6, 22, 4, COLOR_BG_CARD);
    ui_draw_rounded_rect(HEADER_PADDING, LOG_TOP_Y,    TFT_WIDTH - 6, LOG_HEIGHT, 5, COLOR_BG_CARD);
    ui_draw_rounded_rect(HEADER_PADDING, GRAPH_TOP_Y,  TFT_WIDTH - 6, GRAPH_HEIGHT, 5, COLOR_BG_CARD);
    _draw_log();
    _draw_graph();
    _draw_bottom_row();
    _draw_version_badge();
  }

  _cpu_pct = cpu_pct;
  // Update state (only redraw if changed)
  bool stats_changed = false;
  
  if (_active_relays != active_relays) {
    _active_relays = active_relays;
    stats_changed = true;
  }
  
  if (strcmp(_daemon_state, daemon_state) != 0) {
    strncpy(_daemon_state, daemon_state, sizeof(_daemon_state) - 1);
    _daemon_state[sizeof(_daemon_state) - 1] = '\0';
    stats_changed = true;
  }
  
  if (_total_tunnels != total_tunnels || _total_pings != total_pings) {
    _total_tunnels = total_tunnels;
    _total_pings = total_pings;
    stats_changed = true;
  }

  if (_relay_tcp_count != relay_tcp_count || _relay_pcb_max != relay_pcb_max) {
    _relay_tcp_count = relay_tcp_count;
    _relay_pcb_max    = relay_pcb_max;
    stats_changed = true;
  }

  // Record throughput sample (delta since last update)
  uint32_t delta_in  = bytes_in  - _prev_bytes_in;
  uint32_t delta_out = bytes_out - _prev_bytes_out;
  _prev_bytes_in  = bytes_in;
  _prev_bytes_out = bytes_out;

  _tp_in[_tp_head]  = delta_in;
  _tp_out[_tp_head] = delta_out;
  _tp_head = (_tp_head + 1) % GRAPH_SAMPLES;

  // LED activity: green = data flowing, blue = relay connected, cyan = daemon ready, off = stopped
  if (_led_enabled) {
    if (delta_in + delta_out > 0) {
      ui_set_led(false, true, false);   // green — data flowing
    } else if (active_relays > 0) {
      ui_set_led(true, true, false);    // amber — relay connected, idle
    } else {
      // Daemon running but no relays — breathe cyan (Apple sleep indicator style)
      ui_led_breathe_start(false, true, true);
    }
  }
  
  // Check reset confirmation timeout
  if (_reset_confirming && (millis() - _reset_confirm_ms > RESET_CONFIRM_TIMEOUT)) {
    _reset_confirming = false;
    _draw_bottom_row();
  }
  
  // Process event queue
  UiEvent evt;
  bool log_changed = false;
  
  while (ui_event_pop(&evt)) {
    switch (evt.type) {
      case UI_EVT_TUNNEL_OPEN:
        _add_log_entry(evt.text, COLOR_SUCCESS);
        log_changed = true;
        break;
        
      case UI_EVT_TUNNEL_CLOSE:
        _add_log_entry(evt.text, COLOR_TEXT_GREY);
        log_changed = true;
        break;
        
      case UI_EVT_PING:
        _add_log_entry(evt.text, COLOR_ACCENT);
        log_changed = true;
        break;
        
      case UI_EVT_DAEMON_STATE:
        _add_log_entry(evt.text, COLOR_TEXT_WHITE);
        log_changed = true;
        break;
        
      case UI_EVT_ERROR:
        _add_log_entry(evt.text, COLOR_ERROR);
        log_changed = true;
        break;
        
      default:
        break;
    }
  }
  
  // Always redraw stats (uptime/heap change constantly)
  _draw_stats_row1();
  _draw_stats_row2();
  _draw_graph();
  
  if (log_changed) {
    _draw_log();
  }
}

bool ui_dashboard_handle_touch(int16_t tx, int16_t ty) {
  // Wake screen if backlight is off — consume this touch, don't act on it
  if (_screen_off) {
    _screen_off = false;
    _screen_wake_redraw = true;
    ui_set_backlight(true);
    Serial.println("[ui_dashboard] Screen woken by touch");
    return true;
  }

  // Extend touch targets upward by BTN_PAD so buttons at screen edge are easier to hit
  #define BTN_PAD 10
  int touch_top = BTN_Y - BTN_PAD;

  // Only process bottom row if touch is roughly in the button strip
  if (ty >= touch_top) {
    // Check LED toggle button
    if (ui_touch_in_rect(tx, ty, LED_BTN_X, touch_top, BTN_W, BTN_H + BTN_PAD)) {
      _led_enabled = !_led_enabled;
      if (!_led_enabled) {
        ui_set_led(false, false, false);  // turn off immediately
      }
      _draw_bottom_row();
      Serial.printf("[ui_dashboard] LED %s\n", _led_enabled ? "ON" : "OFF");
      return true;
    }

    // Check LCD off button
    if (ui_touch_in_rect(tx, ty, LCD_BTN_X, touch_top, BTN_W, BTN_H + BTN_PAD)) {
      Serial.println("[ui_dashboard] LCD off");
      _screen_off = true;
      ui_set_backlight(false);
      return true;
    }

    // Check WiFi button
    if (ui_touch_in_rect(tx, ty, WIFI_BTN_X, touch_top, BTN_W, BTN_H + BTN_PAD)) {
      Serial.println("[ui_dashboard] WiFi pressed");
      if (_on_wifi_cb) {
        _on_wifi_cb();
      }
      return true;
    }

    // Check Settings/Config button
    if (ui_touch_in_rect(tx, ty, CFG_BTN_X, touch_top, BTN_W, BTN_H + BTN_PAD)) {
      Serial.println("[ui_dashboard] Config pressed");
      if (_on_config_cb) {
        _on_config_cb();
      }
      return true;
    }

    // Check Rules button
    if (ui_touch_in_rect(tx, ty, RULES_BTN_X, touch_top, BTN_W, BTN_H + BTN_PAD)) {
      Serial.println("[ui_dashboard] Rules pressed");
      if (_on_settings_cb) {
        _on_settings_cb();
      }
      return true;
    }

    // Check Reset button
    if (ui_touch_in_rect(tx, ty, RESET_BTN_X, touch_top, BTN_W, BTN_H + BTN_PAD)) {
      if (_reset_confirming) {
        Serial.println("[ui_dashboard] Reset confirmed!");
        if (_on_reset_cb) {
          _on_reset_cb();
        }
      } else {
        _reset_confirming = true;
        _reset_confirm_ms = millis();
        _draw_bottom_row();
        Serial.println("[ui_dashboard] Reset requested - tap again to confirm");
      }
      return true;
    }
  }

  // If tapping elsewhere while confirming, cancel the confirmation
  if (_reset_confirming) {
    _reset_confirming = false;
    _draw_bottom_row();
    return true;
  }
  
  return false;
}
