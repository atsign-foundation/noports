/**
 * @file ui_calibrate.cpp
 * @brief 3-point touch calibration screen implementation
 *
 * Presents three crosshair targets. User taps each one.
 * After all three, calibration is computed, applied, and saved to NVS.
 */

#include "ui_calibrate.h"
#include "ui_common.h"
#include <esp32_smartdisplay.h>
#include <Preferences.h>

// ---------------------------------------------------------------------------
// NVS keys for calibration data
// ---------------------------------------------------------------------------
#define NVS_KEY_CAL_VALID  "cal_valid"
#define NVS_KEY_CAL_AX     "cal_ax"
#define NVS_KEY_CAL_BX     "cal_bx"
#define NVS_KEY_CAL_DX     "cal_dx"
#define NVS_KEY_CAL_AY     "cal_ay"
#define NVS_KEY_CAL_BY     "cal_by"
#define NVS_KEY_CAL_DY     "cal_dy"

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------
static lv_obj_t *_scr         = nullptr;
static lv_obj_t *_crosshair   = nullptr;
static lv_obj_t *_instruction = nullptr;

static int _step = 0;  // 0, 1, 2 = three calibration points
static lv_point_t _screen_pts[3];
static lv_point_t _touch_pts[3];
static void (*_on_done_cb)()  = nullptr;

// Calibration target positions (10% inset from edges)
static void _get_target(int step, int32_t *x, int32_t *y) {
  switch (step) {
    case 0: *x = SCREEN_WIDTH * 10 / 100;  *y = SCREEN_HEIGHT * 10 / 100; break;  // top-left
    case 1: *x = SCREEN_WIDTH * 90 / 100;  *y = SCREEN_HEIGHT * 50 / 100; break;  // center-right
    case 2: *x = SCREEN_WIDTH * 50 / 100;  *y = SCREEN_HEIGHT * 90 / 100; break;  // bottom-center
    default: *x = SCREEN_WIDTH / 2;        *y = SCREEN_HEIGHT / 2;        break;
  }
}

// ---------------------------------------------------------------------------
// Draw crosshair at position
// ---------------------------------------------------------------------------
static void _draw_crosshair(int32_t cx, int32_t cy) {
  if (_crosshair) lv_obj_del(_crosshair);

  _crosshair = lv_obj_create(_scr);
  lv_obj_remove_style_all(_crosshair);
  lv_obj_set_size(_crosshair, SCREEN_WIDTH, SCREEN_HEIGHT);
  lv_obj_set_pos(_crosshair, 0, 0);
  lv_obj_set_style_bg_opa(_crosshair, LV_OPA_TRANSP, 0);
  lv_obj_clear_flag(_crosshair, LV_OBJ_FLAG_CLICKABLE);

  // Horizontal line
  lv_obj_t *h = lv_obj_create(_crosshair);
  lv_obj_remove_style_all(h);
  lv_obj_set_size(h, 20, 2);
  lv_obj_set_pos(h, cx - 10, cy - 1);
  lv_obj_set_style_bg_color(h, COLOR_ACCENT, 0);
  lv_obj_set_style_bg_opa(h, LV_OPA_COVER, 0);
  lv_obj_clear_flag(h, LV_OBJ_FLAG_CLICKABLE);

  // Vertical line
  lv_obj_t *v = lv_obj_create(_crosshair);
  lv_obj_remove_style_all(v);
  lv_obj_set_size(v, 2, 20);
  lv_obj_set_pos(v, cx - 1, cy - 10);
  lv_obj_set_style_bg_color(v, COLOR_ACCENT, 0);
  lv_obj_set_style_bg_opa(v, LV_OPA_COVER, 0);
  lv_obj_clear_flag(v, LV_OBJ_FLAG_CLICKABLE);

  // Center dot
  lv_obj_t *dot = lv_obj_create(_crosshair);
  lv_obj_remove_style_all(dot);
  lv_obj_set_size(dot, 6, 6);
  lv_obj_set_pos(dot, cx - 3, cy - 3);
  lv_obj_set_style_bg_color(dot, COLOR_PRIMARY, 0);
  lv_obj_set_style_bg_opa(dot, LV_OPA_COVER, 0);
  lv_obj_set_style_radius(dot, LV_RADIUS_CIRCLE, 0);
  lv_obj_clear_flag(dot, LV_OBJ_FLAG_CLICKABLE);
}

// ---------------------------------------------------------------------------
// Show step
// ---------------------------------------------------------------------------
static void _show_step() {
  int32_t tx, ty;
  _get_target(_step, &tx, &ty);
  _screen_pts[_step].x = tx;
  _screen_pts[_step].y = ty;

  _draw_crosshair(tx, ty);

  char buf[64];
  snprintf(buf, sizeof(buf), "Tap the crosshair (%d/3)", _step + 1);
  lv_label_set_text(_instruction, buf);
}

// ---------------------------------------------------------------------------
// Touch callback
// ---------------------------------------------------------------------------
static void _touch_cb(lv_event_t *e) {
  if (_step >= 3) return;

  lv_indev_t *indev = lv_indev_active();
  if (!indev) return;

  lv_point_t p;
  lv_indev_get_point(indev, &p);

  _touch_pts[_step].x = p.x;
  _touch_pts[_step].y = p.y;

  Serial.printf("[cal] Step %d: screen(%ld,%ld) touch(%ld,%ld)\n",
                _step, _screen_pts[_step].x, _screen_pts[_step].y,
                p.x, p.y);

  _step++;

  if (_step < 3) {
    _show_step();
  } else {
    // Compute and apply calibration
    touch_calibration_data = smartdisplay_compute_touch_calibration(
        _screen_pts, _touch_pts);

    Serial.printf("[cal] Calibration: aX=%.4f bX=%.4f dX=%.4f aY=%.4f bY=%.4f dY=%.4f\n",
                  touch_calibration_data.alphaX, touch_calibration_data.betaX,
                  touch_calibration_data.deltaX, touch_calibration_data.alphaY,
                  touch_calibration_data.betaY, touch_calibration_data.deltaY);

    // Save to NVS
    Preferences &prefs = ui_prefs();
    prefs.putBool(NVS_KEY_CAL_VALID, true);
    prefs.putFloat(NVS_KEY_CAL_AX, touch_calibration_data.alphaX);
    prefs.putFloat(NVS_KEY_CAL_BX, touch_calibration_data.betaX);
    prefs.putFloat(NVS_KEY_CAL_DX, touch_calibration_data.deltaX);
    prefs.putFloat(NVS_KEY_CAL_AY, touch_calibration_data.alphaY);
    prefs.putFloat(NVS_KEY_CAL_BY, touch_calibration_data.betaY);
    prefs.putFloat(NVS_KEY_CAL_DY, touch_calibration_data.deltaY);

    lv_label_set_text(_instruction, LV_SYMBOL_OK " Calibrated!");
    Serial.println("[cal] Calibration saved to NVS");

    // Brief delay then continue
    lv_timer_create([](lv_timer_t *t) {
      lv_timer_del(t);
      if (_on_done_cb) _on_done_cb();
    }, 800, nullptr);
  }
}

// ---------------------------------------------------------------------------
// Public: load calibration from NVS
// ---------------------------------------------------------------------------
bool ui_calibrate_load() {
  Preferences &prefs = ui_prefs();
  if (!prefs.getBool(NVS_KEY_CAL_VALID, false)) return false;

  touch_calibration_data.alphaX = prefs.getFloat(NVS_KEY_CAL_AX, 1.0f);
  touch_calibration_data.betaX  = prefs.getFloat(NVS_KEY_CAL_BX, 0.0f);
  touch_calibration_data.deltaX = prefs.getFloat(NVS_KEY_CAL_DX, 0.0f);
  touch_calibration_data.alphaY = prefs.getFloat(NVS_KEY_CAL_AY, 0.0f);
  touch_calibration_data.betaY  = prefs.getFloat(NVS_KEY_CAL_BY, 1.0f);
  touch_calibration_data.deltaY = prefs.getFloat(NVS_KEY_CAL_DY, 0.0f);
  touch_calibration_data.valid  = true;

  Serial.printf("[cal] Loaded calibration: aX=%.4f bX=%.4f dX=%.4f aY=%.4f bY=%.4f dY=%.4f\n",
                touch_calibration_data.alphaX, touch_calibration_data.betaX,
                touch_calibration_data.deltaX, touch_calibration_data.alphaY,
                touch_calibration_data.betaY, touch_calibration_data.deltaY);
  return true;
}

// ---------------------------------------------------------------------------
// Public: show calibration screen
// ---------------------------------------------------------------------------
void ui_calibrate_create(void (*on_done)()) {
  _on_done_cb = on_done;
  _step = 0;

  _scr = lv_obj_create(nullptr);
  lv_obj_set_style_bg_color(_scr, COLOR_BG_DARK, 0);
  lv_obj_add_flag(_scr, LV_OBJ_FLAG_CLICKABLE);

  // Instruction label
  _instruction = ui_create_label(_scr, "Tap the crosshair (1/3)",
                                 &lv_font_montserrat_16);
  lv_obj_set_style_text_color(_instruction, COLOR_TEXT_WHITE, 0);
  lv_obj_align(_instruction, LV_ALIGN_TOP_MID, 0, SCREEN_HEIGHT / 2 - 30);
  lv_obj_clear_flag(_instruction, LV_OBJ_FLAG_CLICKABLE);

  // Touch handler on the screen itself
  lv_obj_add_event_cb(_scr, _touch_cb, LV_EVENT_CLICKED, nullptr);

  lv_scr_load(_scr);
  _show_step();
}
