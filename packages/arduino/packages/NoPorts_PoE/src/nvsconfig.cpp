#include "nvsconfig.h"

static Preferences _prefs;
static bool _prefs_open = false;

Preferences& nvs_prefs() {
  if (!_prefs_open) {
    _prefs.begin(NVS_NAMESPACE, false);
    _prefs_open = true;
  }
  return _prefs;
}

String nvs_load(const char *key) {
  return nvs_prefs().getString(key, "");
}

void nvs_save(const char *key, const char *value) {
  nvs_prefs().putString(key, value);
}

bool nvs_is_configured() {
  return nvs_prefs().getBool(NVS_KEY_CONFIGURED, false);
}

void nvs_set_configured(bool val) {
  nvs_prefs().putBool(NVS_KEY_CONFIGURED, val);
}

bool nvs_rules_valid() {
  String mode = nvs_load(NVS_KEY_RULES_MODE);
  if (mode == "1") {
    return nvs_load(NVS_KEY_POLICY_AT).length() > 0;
  }
  String mgrs = nvs_load(NVS_KEY_MANAGERS);
  if (mgrs.length() == 0) mgrs = nvs_load(NVS_KEY_MANAGER);
  return mgrs.length() > 0 && nvs_load(NVS_KEY_PERMITOPEN).length() > 0;
}

int nvs_parse_csv(const String &input, String *out, int max_items) {
  int count = 0;
  int start = 0;
  for (int i = 0; i <= (int)input.length() && count < max_items; i++) {
    if (i == (int)input.length() || input[i] == ',') {
      String item = input.substring(start, i);
      item.trim();
      if (item.length() > 0) out[count++] = item;
      start = i + 1;
    }
  }
  return count;
}

void nvs_format_uptime(unsigned long ms, char *buf, size_t len) {
  unsigned long s = ms / 1000;
  unsigned long m = s / 60;
  unsigned long h = m / 60;
  s %= 60; m %= 60;
  if (h > 0)
    snprintf(buf, len, "%luh %02lum", h, m);
  else if (m > 0)
    snprintf(buf, len, "%lum %02lus", m, s);
  else
    snprintf(buf, len, "%lus", s);
}
