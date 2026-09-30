#include "web_server.h"
#include "nvsconfig.h"
#include <LittleFS.h>
#include <Arduino.h>
#include <esp_random.h>
#ifdef NOPORTS_POE_P4
#include <ETH.h>
#include "led.h"
#endif

extern "C" {
#include "atauth.h"
}

// ─── Singletons ───────────────────────────────────────────────────────────
static WebServer   *_srv = nullptr;
static NoPortsDaemon  *_daemon  = nullptr;
static bool           *_running = nullptr;
static DaemonStats    *_stats   = nullptr;
static EnrollStatus   *_enroll  = nullptr;
static void          (*_restart_cb)() = nullptr;

static uint32_t _start_ms       = 0;    // set at web_server_begin() time
static bool     _restart_pending = false; // set by settings POST, cleared by loop()
static bool     _localhost_only  = false; // mirrors NVS_KEY_WEB_LOCAL; set at bind time

static void _rebind(bool local);  // forward declaration — defined near web_server_begin()
static void _send_page(const String &title, const String &body);  // forward decls used by auth guard
static void _send_json(int code, const String &json);

// ═══ Authentication ════════════════════════════════════════════════════════
// The web UI gates every route (except the login page itself) behind an admin
// PIN. On success the server issues a random session token, delivered as a
// HttpOnly, SameSite=Strict cookie; SameSite=Strict means the cookie is never
// sent on cross-site requests, which is the primary CSRF defense. Host- and
// Origin-header checks add defense in depth (anti DNS-rebinding / anti-CSRF).

#define SESSION_TTL_MS     (60UL * 60UL * 1000UL)  // 1 hour
#define SESSION_MAX        4                        // concurrent sessions
#define PIN_GEN_LEN        8                        // digits in the auto-generated initial PIN
#define PIN_MIN_LEN        6                        // shortest user-chosen PIN
#define PIN_MAX_LEN        63                       // longest user-chosen PIN (fits NVS + buffer)
#define LOGIN_MAX_FAILS    5                        // before lockout
#define LOGIN_LOCKOUT_MS   (60UL * 1000UL)         // lockout window

struct Session { char token[33]; uint32_t expires_ms; };
static Session _sessions[SESSION_MAX];
static char    _web_pin[PIN_MAX_LEN + 1] = {0};
static uint8_t  _web_pin_len    = 0;
static bool     _pin_must_change = false;  // true until the operator sets their own PIN
static uint8_t  _login_fails    = 0;
static uint32_t _lockout_until  = 0;

// Constant-time compare over n bytes — avoids leaking the PIN via response timing.
static bool _ct_equal(const char *a, const char *b, size_t n) {
  uint8_t diff = 0;
  for (size_t i = 0; i < n; i++) diff |= (uint8_t)a[i] ^ (uint8_t)b[i];
  return diff == 0;
}

// Load the admin PIN from NVS. On first boot (no stored PIN) generate a random
// 8-digit initial PIN and flag it must-change; the operator is forced to set
// their own PIN at first login. The initial PIN is printed to serial so a
// headless operator can retrieve it during USB flashing — but once the operator
// has set their own PIN we do NOT print it, to avoid leaking their credential.
static void _load_or_create_pin() {
  String pin = nvs_load(NVS_KEY_WEB_PIN);
  if (pin.length() >= PIN_MIN_LEN && pin.length() <= PIN_MAX_LEN) {
    strlcpy(_web_pin, pin.c_str(), sizeof(_web_pin));
  } else {
    for (int i = 0; i < PIN_GEN_LEN; i++) _web_pin[i] = '0' + (esp_random() % 10);
    _web_pin[PIN_GEN_LEN] = '\0';
    nvs_save(NVS_KEY_WEB_PIN, _web_pin);
    nvs_save(NVS_KEY_WEB_PIN_SET, "0");  // mark as still the device-issued initial PIN
  }
  _web_pin_len = strlen(_web_pin);
  _pin_must_change = (nvs_load(NVS_KEY_WEB_PIN_SET) != "1");

  if (_pin_must_change) {
    Serial.println("[web] ─────────────────────────────────────────");
    Serial.printf ("[web]  Web UI initial PIN: %s\n", _web_pin);
    Serial.println("[web]  Log in with this, then set your own PIN.");
    Serial.println("[web] ─────────────────────────────────────────");
  } else {
    Serial.println("[web] Web UI protected by admin PIN (operator-set).");
  }
}

static void _new_token(char *out /* [33] */) {
  static const char hex[] = "0123456789abcdef";
  for (int i = 0; i < 32; i++) out[i] = hex[esp_random() & 0x0F];
  out[32] = '\0';
}

// Read the np_sess cookie and return true if it names a live session.
static bool _authed() {
  if (!_srv->hasHeader("Cookie")) return false;
  String cookie = _srv->header("Cookie");
  int p = cookie.indexOf("np_sess=");
  if (p < 0) return false;
  p += 8;
  int e = cookie.indexOf(';', p);
  String tok = (e < 0) ? cookie.substring(p) : cookie.substring(p, e);
  tok.trim();
  if (tok.length() != 32) return false;
  uint32_t now = millis();
  for (int i = 0; i < SESSION_MAX; i++) {
    if (_sessions[i].token[0] && _ct_equal(_sessions[i].token, tok.c_str(), 32)) {
      if ((int32_t)(now - _sessions[i].expires_ms) >= 0) { _sessions[i].token[0] = '\0'; return false; }
      _sessions[i].expires_ms = now + SESSION_TTL_MS;  // sliding expiry
      return true;
    }
  }
  return false;
}

// Compare a header host[:port] against this device's legitimate names. Blocks
// DNS-rebinding: an attacker page carries its own domain in Host/Origin, which
// will not match the device IP / mDNS name / loopback.
static bool _host_allowed(const String &raw) {
  if (raw.isEmpty()) return true;  // some clients omit it; cookie+SameSite still gate
  String h = raw;
  int scheme = h.indexOf("://");     // strip scheme if this came from Origin
  if (scheme >= 0) h = h.substring(scheme + 3);
  int colon = h.indexOf(':');        // strip :port
  if (colon >= 0) h = h.substring(0, colon);
  h.toLowerCase();
  if (h == "localhost" || h == "127.0.0.1") return true;
  if (h == "noports-poe.local") return true;
#ifdef NOPORTS_POE_P4
  if (h == ETH.localIP().toString()) return true;
#endif
#ifdef NOPORTS_TEST_WIFI_AP
  if (h == WiFi.softAPIP().toString()) return true;
#endif
  return false;
}

// Access guard invoked by every protected route. Order: Host allowlist (all
// requests) → Origin/Referer check (state-changing methods) → session check.
// Returns false and sends the appropriate response if access is denied.
static bool _guard(bool require_auth) {
  if (!_host_allowed(_srv->hostHeader())) {
    _srv->send(403, "text/plain", "Forbidden");
    return false;
  }
  if (_srv->method() != HTTP_GET) {
    // Prefer Origin; fall back to Referer. If neither is present the
    // SameSite=Strict session cookie is the CSRF backstop, so allow.
    String origin = _srv->hasHeader("Origin")  ? _srv->header("Origin")  : "";
    String ref    = _srv->hasHeader("Referer") ? _srv->header("Referer") : "";
    String check  = origin.length() ? origin : ref;
    if (check.length() && !_host_allowed(check)) {
      _send_json(403, "{\"ok\":false,\"error\":\"Bad origin\"}");
      return false;
    }
  }
  if (require_auth && !_authed()) {
    if (_srv->uri().startsWith("/api/")) {
      _send_json(401, "{\"ok\":false,\"error\":\"Authentication required\"}");
    } else {
      _srv->sendHeader("Location", "/login");
      _srv->send(302, "text/plain", "");
    }
    return false;
  }
  // Forced PIN change: while the device still has its initial PIN, an
  // authenticated operator may only reach the change-PIN surface (and log out).
  // Everything else is funnelled to /change-pin.
  if (require_auth && _pin_must_change) {
    String uri = _srv->uri();
    if (uri != "/change-pin" && uri != "/api/change-pin" && uri != "/api/logout") {
      if (uri.startsWith("/api/")) {
        _send_json(403, "{\"ok\":false,\"error\":\"Set a new PIN first\",\"must_change\":true}");
      } else {
        _srv->sendHeader("Location", "/change-pin");
        _srv->send(302, "text/plain", "");
      }
      return false;
    }
  }
  return true;
}

// ─── Common page chrome ───────────────────────────────────────────────────
// CSS is deliberately compact (fits ~1.5 KB) so pages render fast over 100 Mbps Ethernet.

static const char CSS[] =
  "*{box-sizing:border-box;margin:0;padding:0}"
  "body{font-family:system-ui,sans-serif;background:#0E1117;color:#e0e0e0;min-height:100vh}"
  ".nav{background:#181C24;padding:12px 16px;border-bottom:1px solid #2a3042;"
        "display:flex;align-items:center;gap:12px}"
  ".logo{color:#F06000;font-weight:700;font-size:1.1em}"
  ".nav a{color:#8B9BB4;text-decoration:none;padding:5px 10px;border-radius:4px;font-size:.85em}"
  ".nav a:hover{background:#252d3d}"
  ".ctr{max-width:640px;margin:20px auto;padding:0 16px}"
  ".card{background:#181C24;border:1px solid #2a3042;border-radius:8px;"
         "padding:16px;margin-bottom:14px}"
  ".card h2{color:#F06000;font-size:.8em;text-transform:uppercase;letter-spacing:.1em;"
             "margin-bottom:12px;padding-bottom:8px;border-bottom:1px solid #2a3042}"
  ".row{display:flex;justify-content:space-between;align-items:center;"
        "padding:7px 0;border-bottom:1px solid #1a2032}"
  ".row:last-child{border-bottom:0}"
  ".lbl{color:#8B9BB4;font-size:.82em}"
  ".val{font-weight:500;font-size:.9em}"
  ".badge{padding:2px 10px;border-radius:20px;font-size:.72em;font-weight:700}"
  ".ok{background:#18A06025;color:#18A060;border:1px solid #18A06060}"
  ".err{background:#E8404025;color:#E84040;border:1px solid #E8404060}"
  ".dim{background:#2a304225;color:#8B9BB4;border:1px solid #2a304260}"
  "label{display:block;color:#8B9BB4;font-size:.82em;margin-top:14px;margin-bottom:4px}"
  "input,textarea,select{width:100%;padding:8px 10px;background:#0E1117;"
                          "border:1px solid #2a3042;border-radius:5px;color:#e0e0e0;font-size:.9em}"
  "input:focus,textarea:focus,select:focus{outline:none;border-color:#F06000}"
  "textarea{resize:vertical;min-height:72px;font-family:monospace;font-size:.82em}"
  ".btn{display:inline-flex;align-items:center;padding:8px 18px;border-radius:5px;"
        "border:0;cursor:pointer;font-size:.88em;font-weight:600;text-decoration:none;"
        "transition:opacity .15s}"
  ".pr{background:#F06000;color:#fff}"
  ".sc{background:#252d3d;color:#e0e0e0}"
  ".dr{background:#E84040;color:#fff}"
  ".btn:hover{opacity:.82}"
  ".btns{display:flex;gap:8px;margin-top:16px;flex-wrap:wrap}"
  ".msg{padding:10px 12px;border-radius:5px;font-size:.85em;margin-top:12px}"
  ".msg.ok{background:#18A06020;color:#18A060;border:1px solid #18A06040}"
  ".msg.err{background:#E8404020;color:#E84040;border:1px solid #E8404040}"
  ".msg.inf{background:#F0600020;color:#F06000;border:1px solid #F0600040}"
  ".hide{display:none}"
  ".hint{color:#8B9BB4;font-size:.75em;margin-top:3px}"
  "h1{color:#F06000;font-size:1.1em;margin-bottom:4px}"
  ".sub{color:#8B9BB4;font-size:.82em;margin-bottom:16px}";

// Stream a full page: header + CSS + nav + body + footer
static void _send_page(const String &title, const String &body) {
  String page;
  page.reserve(4096);
  page  = "<!DOCTYPE html><html><head><meta charset=UTF-8>";
  page += "<meta name=viewport content='width=device-width,initial-scale=1'>";
  page += "<title>NoPorts PoE &#8212; "; page += title; page += "</title>";
  page += "<style>"; page += CSS; page += "</style></head><body>";
  page += "<nav class=nav><span class=logo>NoPorts PoE</span>";
  page += "<a href='/'>Dashboard</a><a href='/settings'>Settings</a>";
  page += "<a href='/config'>Config</a>";
  page += "<a href='/change-pin'>PIN</a>";
  page += "<a href='#' style='margin-left:auto' onclick=\"fetch('/api/logout',{method:'POST'})"
          ".then(()=>location.href='/login');return false\">Sign Out</a></nav>";
  page += "<div class=ctr>"; page += body; page += "</div></body></html>";
  _srv->send(200, "text/html; charset=utf-8", page);
}

static void _send_json(int code, const String &json) {
  _srv->send(code, "application/json", json);
}

// ─── Dashboard (/  +  /api/status) ───────────────────────────────────────

static void _handle_status() {
  char upbuf[24];
  nvs_format_uptime(millis() - _start_ms, upbuf, sizeof(upbuf));

  const char *state_str = "stopped";
  if (_running && *_running && _daemon) {
    switch (_stats->state) {
      case DAEMON_MONITORING:   state_str = "running";  break;
      case DAEMON_AUTHENTICATING: state_str = "auth";   break;
      case DAEMON_INITIALIZING: state_str = "init";     break;
      case DAEMON_ERROR:        state_str = "error";    break;
      default: break;
    }
  }

  String ip;
#ifdef NOPORTS_TEST_WIFI_AP
  ip = WiFi.softAPIP().toString();
#elif defined(NOPORTS_POE_P4)
  ip = ETH.localIP().toString();
#else
  ip = "0.0.0.0";
#endif

  String j;
  j.reserve(512);
  j  = "{\"state\":\""; j += state_str;
  j += "\",\"atsign\":\"";  j += nvs_load(NVS_KEY_ATSIGN);
  j += "\",\"device\":\"";  j += nvs_load(NVS_KEY_DEVICE);
  j += "\",\"version\":\"" POE_APP_VERSION "\"";
  j += ",\"uptime\":\"";    j += upbuf;
  j += "\",\"uptime_s\":";  j += (millis() - _start_ms) / 1000;
  j += ",\"tunnels\":";     j += (_stats ? _stats->total_tunnels : 0);
  j += ",\"pings\":";       j += (_stats ? _stats->total_pings   : 0);
  j += ",\"bytes_in\":";    j += (_stats ? _stats->bytes_in      : 0);
  j += ",\"bytes_out\":";   j += (_stats ? _stats->bytes_out     : 0);
  j += ",\"relay_cpu\":";   j += (_stats ? _stats->relay_cpu     : 0);
  j += ",\"active_relays\":"; j += (_stats ? _stats->active_relays : 0);
  j += ",\"pcb_count\":";   j += (_stats ? _stats->pcb_count     : 0);
  j += ",\"pcb_max\":";     j += (_stats ? _stats->pcb_max       : 5);
  j += ",\"configured\":";  j += nvs_is_configured() ? "true" : "false";
  j += ",\"enrolled\":";    j += LittleFS.exists(ATKEYS_PATH) ? "true" : "false";
  j += ",\"ip\":\"";        j += ip; j += "\"}";
  _send_json(200, j);
}

static void _handle_dashboard() {
  String b;
  b.reserve(2048);

  String atsign  = nvs_load(NVS_KEY_ATSIGN);
  String device  = nvs_load(NVS_KEY_DEVICE);
  bool enrolled  = LittleFS.exists(ATKEYS_PATH);
  bool configured = nvs_is_configured();

  if (!configured || !enrolled) {
    b  = "<div class=card>";
    b += "<h1>Welcome to NoPorts PoE</h1>";
    b += "<p class=sub>Connect your device to the atSign network.</p>";
    b += "<div class=btns><a class='btn pr' href='/setup'>Set Up Device</a></div>";
    b += "</div>";
    return _send_page("Setup", b);
  }

  b  = "<div class=card>";
  b += "<h2>Device</h2>";
  b += "<div class=row><span class=lbl>atSign</span><span class=val id=at>";
  b += atsign; b += "</span></div>";
  b += "<div class=row><span class=lbl>Device</span><span class=val>";
  b += device; b += "</span></div>";
  b += "<div class=row><span class=lbl>IP</span><span class=val id=ip></span></div>";
  b += "<div class=row><span class=lbl>Uptime</span><span class=val id=up></span></div>";
  b += "<div class=row><span class=lbl>Version</span><span class=val>" POE_APP_VERSION "</span></div>";
  b += "</div>";

  b += "<div class=card><h2>Daemon</h2>";
  b += "<div class=row><span class=lbl>State</span>"
       "<span class=val><span class='badge dim' id=state>&#8230;</span></span></div>";
  b += "<div class=row><span class=lbl>Tunnels (total)</span><span class=val id=tun>&#8230;</span></div>";
  b += "<div class=row><span class=lbl>Pings (total)</span><span class=val id=ping>&#8230;</span></div>";
  b += "<div class=row><span class=lbl>Active relays</span><span class=val id=rel>&#8230;</span></div>";
  b += "<div class=row><span class=lbl>Throughput &#8595;</span><span class=val id=tin>&#8230;</span></div>";
  b += "<div class=row><span class=lbl>Throughput &#8593;</span><span class=val id=tout>&#8230;</span></div>";
  b += "<div class=row><span class=lbl>Relay CPU</span><span class=val id=cpu>&#8230;</span></div>";
  b += "</div>";

  b += "<div class=btns>";
  b += "<a class='btn sc' href='/settings'>Rules</a>";
  b += "<a class='btn sc' href='/config'>Config</a>";
#ifdef NOPORTS_POE_P4
  b += "<button class='btn sc' id=idbtn onclick=identify()>Identify</button>";
#endif
  b += "<button class='btn dr' onclick=\"if(confirm('Reset device?'))fetch('/api/reset',{method:'POST'})"
       ".then(()=>location.reload())\">Reset</button>";
  b += "</div>";

  // Auto-refresh JS
  b += "<script>"
       "function fmt(n){if(n<1024)return n+'B';if(n<1048576)return(n/1024).toFixed(1)+'KB';"
       "return(n/1048576).toFixed(2)+'MB'}"
       "function upd(){fetch('/api/status').then(r=>r.json()).then(d=>{"
       "var s=document.getElementById('state');"
       "s.textContent=d.state||'?';"
       "s.className='badge '+(d.state==='running'?'ok':d.state==='error'?'err':'dim');"
       "document.getElementById('up').textContent=d.uptime||'';"
       "document.getElementById('ip').textContent=d.ip||'';"
       "document.getElementById('tun').textContent=d.tunnels||0;"
       "document.getElementById('ping').textContent=d.pings||0;"
       "document.getElementById('rel').textContent=(d.active_relays||0)+'/'+(d.pcb_max||5);"
       "document.getElementById('tin').textContent=fmt(d.bytes_in||0)+'/s';"
       "document.getElementById('tout').textContent=fmt(d.bytes_out||0)+'/s';"
       "document.getElementById('cpu').textContent=(d.relay_cpu||0)+'%';"
       "}).catch(()=>{})}"
       "upd();setInterval(upd,5000);"
#ifdef NOPORTS_POE_P4
       "var _idTimer=null;"
       "function identify(){"
       "var btn=document.getElementById('idbtn');"
       "fetch('/api/identify',{method:'POST'}).then(r=>r.json()).then(d=>{"
       "if(!d.ok)return;"
       "var secs=d.seconds;"
       "btn.disabled=true;"
       "if(_idTimer)clearInterval(_idTimer);"
       "_idTimer=setInterval(function(){"
       "secs--;btn.textContent='Identify ('+secs+'s)';"
       "if(secs<=0){clearInterval(_idTimer);btn.disabled=false;btn.textContent='Identify';}"
       "},1000);"
       "})}"
#endif
       "</script>";

  _send_page("Dashboard", b);
}

// ─── First-run setup (/setup  +  /api/setup) ─────────────────────────────

static void _handle_setup_get() {
  String b;
  b.reserve(2048);
  b  = "<div class=card>";
  b += "<h1>Device Setup</h1>";
  b += "<p class=sub>Enter your atSign credentials to enrol this device on the NoPorts network.</p>";
  b += "<label>atSign <span style='color:#E84040'>*</span>";
  b += "<input id=at name=at placeholder='@mydevice' autocomplete=off></label>";
  b += "<label>Device name <span style='color:#E84040'>*</span>";
  b += "<input id=dev name=dev placeholder='esp32_poe' autocomplete=off></label>";
  b += "<label>Manager atSign(s) <span style='color:#E84040'>*</span>";
  b += "<input id=mgrs placeholder='@manager1,@manager2'></label>";
  b += "<p class=hint>Comma-separated list of atSigns allowed to open tunnels.</p>";
  b += "<label>PermitOpen rules <span style='color:#E84040'>*</span>";
  b += "<input id=po placeholder='localhost:22,localhost:2222'></label>";
  b += "<p class=hint>host:port pairs this device will relay. Use *:0 to allow all.</p>";
  b += "<label>Root server<input id=root placeholder='root.atsign.org' value='";
  b += nvs_load(NVS_KEY_ROOT); b += "'></label>";
  b += "<p class=hint>Leave blank for root.atsign.org. Optional :port (default 64). "
       "On 443-only networks use a reverse proxy with the proxy: prefix, "
       "e.g. proxy:proxy0001.atsign.org:443 &mdash; skips the atDirectory entirely.</p>";
  b += "<div id=msg></div>";
  b += "<div class=btns><button class='btn pr' onclick=save()>Save &amp; Enrol</button></div>";
  b += "</div>";

  b += "<script>"
       "function save(){"
       "var at=document.getElementById('at').value.trim(),"
       "dev=document.getElementById('dev').value.trim(),"
       "mgrs=document.getElementById('mgrs').value.trim(),"
       "po=document.getElementById('po').value.trim(),"
       "root=document.getElementById('root').value.trim();"
       "if(!at||!dev||!mgrs||!po){"
       "document.getElementById('msg').innerHTML='<div class=\"msg err\">All fields marked * are required.</div>';"
       "return;}"
       "fetch('/api/setup',{method:'POST',"
       "headers:{'Content-Type':'application/json'},"
       "body:JSON.stringify({at:at,device:dev,managers:mgrs,permitopen:po,root:root})})"
       ".then(r=>r.json()).then(d=>{"
       "if(d.ok)location.href='/enroll';"
       "else document.getElementById('msg').innerHTML='<div class=\"msg err\">'+d.error+'</div>';"
       "}).catch(e=>{"
       "document.getElementById('msg').innerHTML='<div class=\"msg err\">'+e+'</div>';"
       "});}"
       "</script>";

  _send_page("Setup", b);
}

static void _handle_setup_post() {
  if (!_srv->hasArg("plain")) { return _send_json(400, "{\"ok\":false,\"error\":\"No body\"}"); }
  String body = _srv->arg("plain");

  // Minimal JSON parse (no cJSON dependency in web layer)
  auto extract = [&](const char *key) -> String {
    String k = "\""; k += key; k += "\":\"";
    int p = body.indexOf(k);
    if (p < 0) return "";
    p += k.length();
    int e = body.indexOf('"', p);
    return e < 0 ? "" : body.substring(p, e);
  };

  String at   = extract("at");
  String dev  = extract("device");
  String mgrs = extract("managers");
  String po   = extract("permitopen");
  String root = extract("root");

  if (at.isEmpty() || dev.isEmpty() || mgrs.isEmpty() || po.isEmpty()) {
    return _send_json(400, "{\"ok\":false,\"error\":\"Missing fields\"}");
  }

  nvs_save(NVS_KEY_ATSIGN,    at.c_str());
  nvs_save(NVS_KEY_DEVICE,    dev.c_str());
  nvs_save(NVS_KEY_MANAGERS,  mgrs.c_str());
  nvs_save(NVS_KEY_MANAGER,   mgrs.c_str());  // legacy key
  nvs_save(NVS_KEY_PERMITOPEN, po.c_str());
  nvs_save(NVS_KEY_ROOT,      root.c_str());   // "" → root.atsign.org
  nvs_save(NVS_KEY_RULES_MODE, "0");           // managers mode

  Serial.printf("[web] Setup saved: %s / %s\n", at.c_str(), dev.c_str());
  _send_json(200, "{\"ok\":true}");
}

// ─── Enrollment (/enroll  +  /api/enroll  +  /api/enroll-status) ─────────

static const char *DEFAULT_ROOT_SPEC = "root.atsign.org";
static const char *ENROLL_APP_NAME  = "noports";
static const char *ENROLL_NS        = "sshnp:rw,sshrvd:rw";

static void _handle_enroll_get() {
  String atsign = nvs_load(NVS_KEY_ATSIGN);
  String b;
  b.reserve(2048);
  b  = "<div class=card>";
  b += "<h1>Enrol Device</h1>";
  b += "<p class=sub>Open your atSign app, tap the device &rarr; OTP button, and enter the code below.</p>";
  b += "<div class=row><span class=lbl>atSign</span><span class=val>"; b += atsign; b += "</span></div>";
  b += "<label>One-Time Passcode (OTP) <span style='color:#E84040'>*</span>";
  b += "<input id=otp placeholder='abc123' autocomplete=off maxlength=30></label>";
  b += "<div id=msg></div><div id=prog class=hide>";
  b += "<div class='msg inf' id=ptext>Connecting&#8230;</div>";
  b += "<p style='color:#8B9BB4;font-size:.8em;margin-top:8px'>"
       "Approval may take up to 5 minutes &mdash; waiting for your atSign app.</p>";
  b += "</div>";
  b += "<div class=btns id=btn_row>";
  b += "<button class='btn pr' id=enroll_btn onclick=doEnroll()>Enrol</button>";
  b += "</div></div>";

  b += "<script>"
       "var polling=false;"
       "function doEnroll(){"
       "var otp=document.getElementById('otp').value.trim();"
       "if(!otp){document.getElementById('msg').innerHTML='<div class=\"msg err\">Enter OTP.</div>';return;}"
       "document.getElementById('enroll_btn').disabled=true;"
       "document.getElementById('prog').classList.remove('hide');"
       "document.getElementById('msg').innerHTML='';"
       "fetch('/api/enroll',{method:'POST',"
       "headers:{'Content-Type':'application/json'},"
       "body:JSON.stringify({otp:otp})})"
       ".then(r=>r.json()).then(d=>{"
       "if(d.ok){polling=true;poll();}"
       "else{document.getElementById('msg').innerHTML='<div class=\"msg err\">'+d.error+'</div>';}"
       "}).catch(e=>{"
       "document.getElementById('msg').innerHTML='<div class=\"msg err\">'+e+'</div>';"
       "});}"
       "function poll(){"
       "if(!polling)return;"
       "fetch('/api/enroll-status').then(r=>r.json()).then(d=>{"
       "document.getElementById('ptext').textContent=d.message||'...';"
       "if(d.state==='ok'){polling=false;location.href='/';}"
       "else if(d.state==='fail'){"
       "polling=false;"
       "document.getElementById('prog').classList.add('hide');"
       "document.getElementById('enroll_btn').disabled=false;"
       "document.getElementById('msg').innerHTML='<div class=\"msg err\">'+d.message+'</div>';}"
       "else setTimeout(poll,2000);"
       "}).catch(()=>setTimeout(poll,3000));}"
       "</script>";

  _send_page("Enrol", b);
}

struct EnrollTaskArgs {
  char          atsign[64];
  char          device[64];
  char          otp[32];
  char          root[128];  // root server spec, e.g. "proxy:proxy0001.atsign.org:443"
  EnrollStatus *enroll;  // pointer back to shared status struct
};

static void _enroll_task(void *param) {
  EnrollTaskArgs *a = (EnrollTaskArgs *)param;
  EnrollStatus   *e = a->enroll;

  Serial.printf("[enroll] atsign=%s device=%s root=%s\n", a->atsign, a->device, a->root);

  if (!LittleFS.begin(true)) {
    strlcpy(e->message, "LittleFS mount failed", sizeof(e->message));
    e->phase = ENROLL_FAIL;
    free(a); vTaskDelete(nullptr); return;
  }
  if (LittleFS.exists(ATKEYS_PATH)) LittleFS.remove(ATKEYS_PATH);

  int ret = atauth_enroll_command(
    a->atsign, a->root, ATKEYS_PATH_VFS,
    a->otp, ENROLL_APP_NAME, a->device, ENROLL_NS, nullptr
  );

  if (ret == 0) {
    nvs_set_configured(true);
    strlcpy(e->message, "Enrolled successfully!", sizeof(e->message));
    e->phase = ENROLL_OK;
    Serial.println("[enroll] SUCCESS");
  } else {
    char msg[64];
    snprintf(msg, sizeof(msg), "Enrollment failed (err=%d)", ret);
    strlcpy(e->message, msg, sizeof(e->message));
    e->phase = ENROLL_FAIL;
    Serial.printf("[enroll] FAILED err=%d\n", ret);
  }
  free(a);
  vTaskDelete(nullptr);
}

static void _handle_enroll_post() {
  if (!_srv->hasArg("plain")) return _send_json(400, "{\"ok\":false,\"error\":\"No body\"}");

  String body = _srv->arg("plain");
  auto extract = [&](const char *key) -> String {
    String k = "\""; k += key; k += "\":\"";
    int p = body.indexOf(k);
    if (p < 0) return "";
    p += k.length();
    int e = body.indexOf('"', p);
    return e < 0 ? "" : body.substring(p, e);
  };

  String otp = extract("otp");
  if (otp.isEmpty()) return _send_json(400, "{\"ok\":false,\"error\":\"No OTP\"}");
  if (_enroll->phase != ENROLL_IDLE) return _send_json(409, "{\"ok\":false,\"error\":\"Already enrolled or running\"}");

  _enroll->phase = ENROLL_RUNNING;
  _enroll->started_ms = millis();
  strlcpy(_enroll->message, "Connecting to atServer...", sizeof(_enroll->message));

  EnrollTaskArgs *args = (EnrollTaskArgs *)malloc(sizeof(EnrollTaskArgs));
  if (!args) {
    _enroll->phase = ENROLL_FAIL;
    strlcpy(_enroll->message, "Out of memory", sizeof(_enroll->message));
    return _send_json(500, "{\"ok\":false,\"error\":\"OOM\"}");
  }

  strlcpy(args->atsign, nvs_load(NVS_KEY_ATSIGN).c_str(), sizeof(args->atsign));
  strlcpy(args->device, nvs_load(NVS_KEY_DEVICE).c_str(),  sizeof(args->device));
  strlcpy(args->otp,    otp.c_str(),                        sizeof(args->otp));
  String root = nvs_load(NVS_KEY_ROOT);
  strlcpy(args->root, root.length() ? root.c_str() : DEFAULT_ROOT_SPEC, sizeof(args->root));
  args->enroll = _enroll;

  xTaskCreatePinnedToCore(_enroll_task, "enroll", 32768, args, 5, nullptr, 1);
  _send_json(200, "{\"ok\":true}");
}

static void _handle_enroll_status() {
  String j = "{\"state\":\"";
  switch (_enroll->phase) {
    case ENROLL_RUNNING: j += "running"; break;
    case ENROLL_OK:      j += "ok";      break;
    case ENROLL_FAIL:    j += "fail";    break;
    default:             j += "idle";    break;
  }
  j += "\",\"message\":\""; j += _enroll->message;
  j += "\",\"elapsed_s\":"; j += (millis() - _enroll->started_ms) / 1000;
  j += "}";
  _send_json(200, j);
}

// ─── Settings (/settings  +  /api/settings) ──────────────────────────────

static void _handle_settings_get() {
  String mode    = nvs_load(NVS_KEY_RULES_MODE);
  String mgrs    = nvs_load(NVS_KEY_MANAGERS);
  if (mgrs.isEmpty()) mgrs = nvs_load(NVS_KEY_MANAGER);
  String po      = nvs_load(NVS_KEY_PERMITOPEN);
  String pol_at  = nvs_load(NVS_KEY_POLICY_AT);
  String root    = nvs_load(NVS_KEY_ROOT);

  String b;
  b.reserve(2048);
  b  = "<div class=card>";
  b += "<h1>Rules &amp; Managers</h1>";
  b += "<p class=sub>Control who can open tunnels through this device.</p>";

  b += "<label>Authorization mode";
  b += "<select id=mode onchange=modeChange()>";
  b += (mode == "1") ? "<option value=0>Managers list</option><option value=1 selected>Policy atSign</option>"
                     : "<option value=0 selected>Managers list</option><option value=1>Policy atSign</option>";
  b += "</select></label>";

  b += "<div id=mgr_block>";
  b += "<label>Manager atSign(s)<textarea id=mgrs rows=3>"; b += mgrs; b += "</textarea></label>";
  b += "<p class=hint>One per line or comma-separated. These atSigns can open tunnels.</p>";
  b += "<label>PermitOpen rules<textarea id=po rows=3>"; b += po; b += "</textarea></label>";
  b += "<p class=hint>host:port per line or comma-separated. Use *:0 to allow all.</p>";
  b += "</div>";

  b += "<div id=pol_block class=";
  b += (mode == "1") ? "''" : "hide";
  b += ">";
  b += "<label>Policy atSign<input id=pol_at placeholder='@mypolicysvc' value='"; b += pol_at; b += "'></label>";
  b += "<p class=hint>This atSign service handles authorization via RPC.</p>";
  b += "</div>";

  b += "<label>Root server<input id=root placeholder='root.atsign.org' value='"; b += root; b += "'></label>";
  b += "<p class=hint>Leave blank for root.atsign.org. Optional :port (default 64). "
       "On 443-only networks use a reverse proxy with the proxy: prefix, "
       "e.g. proxy:proxy0001.atsign.org:443 &mdash; skips the atDirectory entirely.</p>";

  b += "<div id=msg></div>";
  b += "<div class=btns>"
       "<button class='btn pr' onclick=save()>Save</button>"
       "<a class='btn sc' href='/'>Cancel</a></div>";
  b += "</div>";

  b += "<script>"
       "function modeChange(){"
       "var m=document.getElementById('mode').value;"
       "document.getElementById('mgr_block').className=m==='1'?'hide':'';"
       "document.getElementById('pol_block').className=m==='0'?'hide':'';}"
       "function save(){"
       "var mode=document.getElementById('mode').value,"
       "mgrs=document.getElementById('mgrs').value.replace(/\\n/g,','),"
       "po=document.getElementById('po').value.replace(/\\n/g,','),"
       "pol=document.getElementById('pol_at').value.trim(),"
       "root=document.getElementById('root').value.trim();"
       "if(mode==='0'){var m=mgrs.trim();if(!m||m.indexOf('@')<0){"
       "document.getElementById('msg').innerHTML='<div class=\"msg err\">At least one manager atSign (starting with @) is required</div>';return;}}"
       "fetch('/api/settings',{method:'POST',"
       "headers:{'Content-Type':'application/json'},"
       "body:JSON.stringify({mode:mode,managers:mgrs,permitopen:po,policy_at:pol,root:root})})"
       ".then(r=>r.json()).then(d=>{"
       "if(d.ok){"
       "document.getElementById('msg').innerHTML='<div class=\"msg ok\">Saved. Restarting daemon&#8230;</div>';"
       "setTimeout(()=>location.href='/',3000);}"
       "else{document.getElementById('msg').innerHTML='<div class=\"msg err\">'+d.error+'</div>';}"
       "});}"
       "</script>";

  _send_page("Settings", b);
}

static void _handle_settings_post() {
  if (!_srv->hasArg("plain")) return _send_json(400, "{\"ok\":false,\"error\":\"No body\"}");
  String body = _srv->arg("plain");

  auto extract = [&](const char *key) -> String {
    String k = "\""; k += key; k += "\":\"";
    int p = body.indexOf(k);
    if (p < 0) return "";
    p += k.length();
    int e = body.indexOf('"', p);
    return e < 0 ? "" : body.substring(p, e);
  };

  String mode = extract("mode");
  String mgrs = extract("managers");
  String po   = extract("permitopen");
  String pol  = extract("policy_at");
  String root = extract("root");

  if (mode != "1") {
    String m = mgrs; m.trim();
    if (m.isEmpty() || m.indexOf('@') < 0) {
      return _send_json(400, "{\"ok\":false,\"error\":\"At least one manager atSign (starting with @) is required\"}");
    }
  }

  nvs_save(NVS_KEY_RULES_MODE, mode.c_str());
  if (mode == "1") {
    nvs_save(NVS_KEY_POLICY_AT, pol.c_str());
  } else {
    nvs_save(NVS_KEY_MANAGERS,  mgrs.c_str());
    nvs_save(NVS_KEY_MANAGER,   mgrs.c_str());
    nvs_save(NVS_KEY_PERMITOPEN, po.c_str());
  }
  nvs_save(NVS_KEY_ROOT, root.c_str());  // "" → root.atsign.org

  Serial.println("[web] Settings saved — daemon restart deferred to loop()");
  _send_json(200, "{\"ok\":true}");
  _restart_pending = true;  // handled by loop() after this response is sent
}

// ─── Config (/config  +  /api/config) ────────────────────────────────────

static void _handle_config_get() {
  String ka  = nvs_load(NVS_KEY_WORKER_KEEPALIVE);
  String mrs = nvs_load(NVS_KEY_MAX_RELAYS);
  int ka_val  = ka.isEmpty()  ? 4 : constrain(ka.toInt(),  0, 15);
  int mrs_val = mrs.isEmpty() ? 5 : constrain(mrs.toInt(), 1, 8);
  bool wl = _localhost_only;

  String b;
  b.reserve(2048);
  b  = "<div class=card>";
  b += "<h1>Advanced Config</h1>";
  b += "<p class=sub>Tune performance parameters. Changes take effect immediately.</p>";

  b += "<label>Worker keep-alive (minutes, 0 = off)";
  b += "<input type=number id=ka min=0 max=15 value="; b += ka_val; b += "></label>";
  b += "<p class=hint>Heartbeat to keep atServer TLS session alive. 4 min recommended.</p>";

  b += "<label>Max concurrent relay sub-connections (1&#8211;8)";
  b += "<input type=number id=mrs min=1 max=8 value="; b += mrs_val; b += "></label>";
  b += "<p class=hint>Higher values allow more parallel SSH sessions per tunnel.</p>";

  b += "<label style='display:flex;align-items:center;gap:8px;margin-top:14px'>"
       "<input type=checkbox id=wl style='width:auto'";
  if (wl) b += " checked";
  b += "> Restrict web UI to localhost only (NoPorts access only)</label>";
  b += "<p class=hint style='color:#F06000'>&#9888; When enabled, this page is only reachable "
       "via a NoPorts tunnel &mdash; direct LAN access will return 403.</p>";

#ifdef NOPORTS_POE_P4
  {
    String lm = nvs_load(NVS_KEY_LED_MODE);
    int lm_val = lm.isEmpty() ? 2 : constrain(lm.toInt(), 0, 3);
    b += "<label>LED indicator";
    b += "<select id=led>";
    const char *opts[] = {"Off (Stealth)", "Heartbeat", "Status", "Full"};
    for (int i = 0; i < 4; i++) {
      b += "<option value="; b += i;
      if (i == lm_val) b += " selected";
      b += ">"; b += opts[i]; b += "</option>";
    }
    b += "</select></label>";
    b += "<p class=hint>"
         "Off: always dark. "
         "Heartbeat: single blink = OK, patterns for problems. "
         "Status: colour shows state (blue=no net, amber=unconfigured, green=running, red=error). "
         "Full: status + white flash on each tunnel.</p>";
  }
#endif

  b += "<div id=msg></div>";
  b += "<div class=btns>"
       "<button class='btn pr' onclick=save()>Save</button>"
       "<a class='btn sc' href='/'>Cancel</a></div>";
  b += "</div>";

  b += "<script>"
       "function save(){"
       "var ka=document.getElementById('ka').value,"
       "mrs=document.getElementById('mrs').value,"
       "wl=document.getElementById('wl').checked,"
       "led=document.getElementById('led')?document.getElementById('led').value:null;"
       "var body={keepalive:ka,max_relays:mrs,web_local:wl};"
       "if(led!==null)body.led_mode=led;"
       "fetch('/api/config',{method:'POST',"
       "headers:{'Content-Type':'application/json'},"
       "body:JSON.stringify(body)})"
       ".then(r=>r.json()).then(d=>{"
       "if(d.ok){"
       "document.getElementById('msg').innerHTML='<div class=\"msg ok\">Saved.</div>';"
       "setTimeout(()=>location.href='/',2000);}"
       "else document.getElementById('msg').innerHTML='<div class=\"msg err\">'+d.error+'</div>';"
       "});}"
       "</script>";

  _send_page("Config", b);
}

static void _handle_config_post() {
  if (!_srv->hasArg("plain")) return _send_json(400, "{\"ok\":false,\"error\":\"No body\"}");
  String body = _srv->arg("plain");

  auto extract = [&](const char *key) -> String {
    String k = "\""; k += key; k += "\":";
    int p = body.indexOf(k);
    if (p < 0) return "";
    p += k.length();
    // skip optional quote
    bool quoted = (body[p] == '"');
    if (quoted) p++;
    int e = p;
    while (e < (int)body.length() && body[e] != ',' && body[e] != '}' && body[e] != '"') e++;
    return body.substring(p, e);
  };

  String ka  = extract("keepalive");
  String mrs = extract("max_relays");
  String wl  = extract("web_local");
  String lm  = extract("led_mode");

  if (!ka.isEmpty())  nvs_save(NVS_KEY_WORKER_KEEPALIVE, ka.c_str());
  if (!mrs.isEmpty()) nvs_save(NVS_KEY_MAX_RELAYS, mrs.c_str());
  bool rebind_needed = false;
  bool new_local = _localhost_only;
  if (!wl.isEmpty()) {
    new_local = (wl == "true" || wl == "1");
    if (new_local != _localhost_only) {
      if (new_local && !(_running && *_running)) {
        return _send_json(400, "{\"ok\":false,\"error\":\"Cannot restrict to localhost: NoPorts daemon must be running first\"}");
      }
      nvs_save(NVS_KEY_WEB_LOCAL, new_local ? "1" : "0");
      rebind_needed = true;
    }
  }

  // Apply daemon tunables immediately
  if (_daemon && _running && *_running) {
    if (!ka.isEmpty()) {
      uint32_t ms = (uint32_t)constrain(ka.toInt(), 0, 15) * 60000UL;
      _daemon->setWorkerKeepaliveMs(ms);
    }
    if (!mrs.isEmpty()) {
      _daemon->setMaxRelays((uint8_t)constrain(mrs.toInt(), 1, 8));
    }
  }

#ifdef NOPORTS_POE_P4
  if (!lm.isEmpty()) {
    nvs_save(NVS_KEY_LED_MODE, lm.c_str());
    led_set_mode((LedMode)constrain(lm.toInt(), 0, 3));
  }
#endif

  Serial.printf("[web] Config saved: ka=%s mrs=%s web_local=%s led=%s\n",
                ka.c_str(), mrs.c_str(), wl.c_str(), lm.c_str());
  _send_json(200, "{\"ok\":true}");
  // Rebind AFTER the response is sent so the current request completes cleanly.
  if (rebind_needed) _rebind(new_local);
}

// ─── Identify (/api/identify) ─────────────────────────────────────────────

#ifdef NOPORTS_POE_P4
static void _handle_identify() {
  led_identify(15000);
  Serial.println("[web] Identify: 15 s LED cycle started");
  _send_json(200, "{\"ok\":true,\"seconds\":15}");
}
#endif

// ─── Factory reset (/api/reset) ───────────────────────────────────────────

static void _handle_reset() {
  Serial.println("[web] Factory reset requested");
  _send_json(200, "{\"ok\":true,\"message\":\"Rebooting...\"}");

  if (_running && *_running && _daemon) {
    _daemon->stop();
    *_running = false;
  }

  if (LittleFS.begin(false)) {
    if (LittleFS.exists(ATKEYS_PATH)) LittleFS.remove(ATKEYS_PATH);
  }

  nvs_save(NVS_KEY_ATSIGN,    "");
  nvs_save(NVS_KEY_DEVICE,    "");
  nvs_save(NVS_KEY_MANAGERS,  "");
  nvs_save(NVS_KEY_MANAGER,   "");
  nvs_save(NVS_KEY_PERMITOPEN,"");
  nvs_save(NVS_KEY_POLICY_AT, "");
  nvs_save(NVS_KEY_RULES_MODE,"");
  nvs_save(NVS_KEY_ROOT,      "");  // back to root.atsign.org
  nvs_set_configured(false);

  delay(500);
  ESP.restart();
}

// ─── Login / logout (/login  +  /api/login  +  /api/logout) ───────────────

static void _handle_login_get() {
  // Already logged in? Go straight to the dashboard.
  if (_authed()) { _srv->sendHeader("Location", "/"); _srv->send(302, "text/plain", ""); return; }

  String b;
  b.reserve(1024);
  b  = "<div class=card>";
  b += "<h1>Sign In</h1>";
  b += "<p class=sub>Enter the device admin PIN. On first use, log in with the "
       "initial PIN from the serial console &mdash; you'll then set your own.</p>";
  b += "<label>Admin PIN<input id=pin type=password autocomplete=off "
       "placeholder='PIN'></label>";
  b += "<div id=msg></div>";
  b += "<div class=btns><button class='btn pr' onclick=login()>Sign In</button></div>";
  b += "</div>";
  b += "<script>"
       "function login(){"
       "var pin=document.getElementById('pin').value.trim();"
       "if(!pin){document.getElementById('msg').innerHTML='<div class=\"msg err\">Enter the PIN.</div>';return;}"
       "fetch('/api/login',{method:'POST',headers:{'Content-Type':'application/json'},"
       "body:JSON.stringify({pin:pin})}).then(r=>r.json()).then(d=>{"
       "if(d.ok)location.href=d.must_change?'/change-pin':'/';"
       "else document.getElementById('msg').innerHTML='<div class=\"msg err\">'+(d.error||'Login failed')+'</div>';"
       "}).catch(e=>{document.getElementById('msg').innerHTML='<div class=\"msg err\">'+e+'</div>';});}"
       "document.addEventListener('keydown',function(e){if(e.key==='Enter')login();});"
       "</script>";

  // Minimal page (no nav — user is not authenticated yet).
  String page;
  page.reserve(2048);
  page  = "<!DOCTYPE html><html><head><meta charset=UTF-8>";
  page += "<meta name=viewport content='width=device-width,initial-scale=1'>";
  page += "<title>NoPorts PoE &#8212; Sign In</title>";
  page += "<style>"; page += CSS; page += "</style></head><body>";
  page += "<nav class=nav><span class=logo>NoPorts PoE</span></nav>";
  page += "<div class=ctr>"; page += b; page += "</div></body></html>";
  _srv->send(200, "text/html; charset=utf-8", page);
}

static void _handle_login_post() {
  uint32_t now = millis();
  if (_lockout_until && (int32_t)(now - _lockout_until) < 0) {
    return _send_json(429, "{\"ok\":false,\"error\":\"Too many attempts — wait a minute\"}");
  }
  if (!_srv->hasArg("plain")) return _send_json(400, "{\"ok\":false,\"error\":\"No body\"}");
  String body = _srv->arg("plain");
  int p = body.indexOf("\"pin\":\"");
  String pin = "";
  if (p >= 0) { p += 7; int e = body.indexOf('"', p); if (e >= 0) pin = body.substring(p, e); }

  bool ok = (pin.length() == _web_pin_len) &&
            _ct_equal(pin.c_str(), _web_pin, _web_pin_len);
  if (!ok) {
    if (++_login_fails >= LOGIN_MAX_FAILS) {
      _lockout_until = now + LOGIN_LOCKOUT_MS;
      _login_fails   = 0;
      Serial.println("[web] Login lockout: too many failed PIN attempts");
    }
    return _send_json(401, "{\"ok\":false,\"error\":\"Invalid PIN\"}");
  }

  _login_fails   = 0;
  _lockout_until = 0;

  // Allocate a session slot (reuse an empty or the soonest-expiring one).
  int slot = 0;
  uint32_t soonest = 0xFFFFFFFF;
  for (int i = 0; i < SESSION_MAX; i++) {
    if (!_sessions[i].token[0]) { slot = i; break; }
    if (_sessions[i].expires_ms < soonest) { soonest = _sessions[i].expires_ms; slot = i; }
  }
  _new_token(_sessions[slot].token);
  _sessions[slot].expires_ms = now + SESSION_TTL_MS;

  String cookie = "np_sess=";
  cookie += _sessions[slot].token;
  cookie += "; Path=/; HttpOnly; SameSite=Strict; Max-Age=3600";
  _srv->sendHeader("Set-Cookie", cookie);
  Serial.println("[web] Admin login OK");
  // Signal the client to route to the change-PIN page while the device still
  // has its initial PIN.
  _send_json(200, _pin_must_change ? "{\"ok\":true,\"must_change\":true}"
                                   : "{\"ok\":true}");
}

static void _handle_logout() {
  // Invalidate the caller's session, if any.
  if (_srv->hasHeader("Cookie")) {
    String cookie = _srv->header("Cookie");
    int p = cookie.indexOf("np_sess=");
    if (p >= 0) {
      p += 8; int e = cookie.indexOf(';', p);
      String tok = (e < 0) ? cookie.substring(p) : cookie.substring(p, e);
      tok.trim();
      for (int i = 0; i < SESSION_MAX; i++)
        if (_sessions[i].token[0] && _ct_equal(_sessions[i].token, tok.c_str(), 32))
          _sessions[i].token[0] = '\0';
    }
  }
  _srv->sendHeader("Set-Cookie", "np_sess=; Path=/; HttpOnly; SameSite=Strict; Max-Age=0");
  _send_json(200, "{\"ok\":true}");
}

// ─── Change PIN (/change-pin  +  /api/change-pin) ─────────────────────────

// Copy the caller's np_sess token into out[33]; out[0]='\0' if none.
static void _caller_token(char *out /* [33] */) {
  out[0] = '\0';
  if (!_srv->hasHeader("Cookie")) return;
  String cookie = _srv->header("Cookie");
  int p = cookie.indexOf("np_sess=");
  if (p < 0) return;
  p += 8;
  int e = cookie.indexOf(';', p);
  String tok = (e < 0) ? cookie.substring(p) : cookie.substring(p, e);
  tok.trim();
  if (tok.length() == 32) strlcpy(out, tok.c_str(), 33);
}

static void _handle_change_pin_get() {
  String b;
  b.reserve(1536);
  b  = "<div class=card>";
  b += "<h1>Set Admin PIN</h1>";
  if (_pin_must_change) {
    b += "<p class=sub>This device is still using its initial PIN. Choose your own "
         "PIN to continue.</p>";
  } else {
    b += "<p class=sub>Change the PIN used to sign in to this web UI.</p>";
  }
  b += "<label>Current PIN<input id=cur type=password autocomplete=off></label>";
  b += "<label>New PIN<input id=np type=password autocomplete=new-password "
       "placeholder='6&#8211;63 characters'></label>";
  b += "<label>Confirm new PIN<input id=np2 type=password autocomplete=new-password></label>";
  b += "<div id=msg></div>";
  b += "<div class=btns><button class='btn pr' onclick=chg()>Save PIN</button>";
  if (!_pin_must_change) b += "<a class='btn sc' href='/'>Cancel</a>";
  b += "</div></div>";
  b += "<script>"
       "function chg(){"
       "var cur=document.getElementById('cur').value,"
       "np=document.getElementById('np').value,"
       "np2=document.getElementById('np2').value,"
       "m=document.getElementById('msg');"
       "if(!cur||!np){m.innerHTML='<div class=\"msg err\">All fields are required.</div>';return;}"
       "if(np!==np2){m.innerHTML='<div class=\"msg err\">New PINs do not match.</div>';return;}"
       "if(np.length<6){m.innerHTML='<div class=\"msg err\">New PIN must be at least 6 characters.</div>';return;}"
       "fetch('/api/change-pin',{method:'POST',headers:{'Content-Type':'application/json'},"
       "body:JSON.stringify({current:cur,pin:np})}).then(r=>r.json()).then(d=>{"
       "if(d.ok){m.innerHTML='<div class=\"msg ok\">PIN updated.</div>';setTimeout(()=>location.href='/',1200);}"
       "else m.innerHTML='<div class=\"msg err\">'+(d.error||'Failed')+'</div>';"
       "}).catch(e=>{m.innerHTML='<div class=\"msg err\">'+e+'</div>';});}"
       "</script>";

  // Standalone page during forced change (no nav to other sections yet).
  if (_pin_must_change) {
    String page;
    page.reserve(2560);
    page  = "<!DOCTYPE html><html><head><meta charset=UTF-8>";
    page += "<meta name=viewport content='width=device-width,initial-scale=1'>";
    page += "<title>NoPorts PoE &#8212; Set PIN</title>";
    page += "<style>"; page += CSS; page += "</style></head><body>";
    page += "<nav class=nav><span class=logo>NoPorts PoE</span>";
    page += "<a href='#' style='margin-left:auto' onclick=\"fetch('/api/logout',{method:'POST'})"
            ".then(()=>location.href='/login');return false\">Sign Out</a></nav>";
    page += "<div class=ctr>"; page += b; page += "</div></body></html>";
    return _srv->send(200, "text/html; charset=utf-8", page);
  }
  _send_page("Set PIN", b);
}

// Reject control chars and characters that would break the naive JSON parsing
// / NVS round-trip; allow the rest of printable ASCII so passphrases work.
static bool _pin_chars_ok(const String &s) {
  for (size_t i = 0; i < s.length(); i++) {
    char c = s[i];
    if (c < 0x20 || c == 0x7F) return false;   // control chars
    if (c == '"' || c == '\\') return false;    // break JSON body parsing
    if (c == ' ') return false;                 // avoid confusing trailing spaces
  }
  return true;
}

static void _handle_change_pin_post() {
  uint32_t now = millis();
  if (_lockout_until && (int32_t)(now - _lockout_until) < 0) {
    return _send_json(429, "{\"ok\":false,\"error\":\"Too many attempts — wait a minute\"}");
  }
  if (!_srv->hasArg("plain")) return _send_json(400, "{\"ok\":false,\"error\":\"No body\"}");
  String body = _srv->arg("plain");
  auto extract = [&](const char *key) -> String {
    String k = "\""; k += key; k += "\":\"";
    int p = body.indexOf(k);
    if (p < 0) return "";
    p += k.length();
    int e = body.indexOf('"', p);
    return e < 0 ? "" : body.substring(p, e);
  };
  String current = extract("current");
  String newpin  = extract("pin");

  // Verify the current PIN (constant-time), rate-limited like login.
  bool cur_ok = (current.length() == _web_pin_len) &&
                _ct_equal(current.c_str(), _web_pin, _web_pin_len);
  if (!cur_ok) {
    if (++_login_fails >= LOGIN_MAX_FAILS) {
      _lockout_until = now + LOGIN_LOCKOUT_MS;
      _login_fails   = 0;
    }
    return _send_json(401, "{\"ok\":false,\"error\":\"Current PIN is incorrect\"}");
  }
  _login_fails = 0;

  if (newpin.length() < PIN_MIN_LEN || newpin.length() > PIN_MAX_LEN) {
    return _send_json(400, "{\"ok\":false,\"error\":\"New PIN must be 6-63 characters\"}");
  }
  if (!_pin_chars_ok(newpin)) {
    return _send_json(400, "{\"ok\":false,\"error\":\"New PIN contains invalid characters\"}");
  }
  if (newpin.length() == _web_pin_len && _ct_equal(newpin.c_str(), _web_pin, _web_pin_len)) {
    return _send_json(400, "{\"ok\":false,\"error\":\"New PIN must differ from the current one\"}");
  }

  // Persist and activate the new PIN.
  strlcpy(_web_pin, newpin.c_str(), sizeof(_web_pin));
  _web_pin_len = strlen(_web_pin);
  nvs_save(NVS_KEY_WEB_PIN, _web_pin);
  nvs_save(NVS_KEY_WEB_PIN_SET, "1");
  _pin_must_change = false;

  // Invalidate every other session; keep the caller signed in.
  char keep[33]; _caller_token(keep);
  for (int i = 0; i < SESSION_MAX; i++) {
    if (_sessions[i].token[0] && !(keep[0] && _ct_equal(_sessions[i].token, keep, 32)))
      _sessions[i].token[0] = '\0';
  }

  Serial.println("[web] Admin PIN changed by operator");
  _send_json(200, "{\"ok\":true}");
}

// ─── 404 ──────────────────────────────────────────────────────────────────

static void _handle_not_found() {
  _srv->send(404, "text/plain", "Not found");
}

// ─── Internal helpers ─────────────────────────────────────────────────────

// Register a route behind the access guard. `auth` = false for the login
// endpoints (still Host/Origin-checked, but reachable without a session).
static void _guarded(const char *uri, HTTPMethod method, void (*handler)(), bool auth) {
  _srv->on(uri, method, [handler, auth]() {
    if (!_guard(auth)) return;   // sends 401/403/redirect on denial
    handler();
  });
}

static void _register_routes() {
  // Headers the guard/auth logic needs (Arduino WebServer ignores others).
  static const char *WANT_HEADERS[] = {"Cookie", "Origin", "Referer"};
  _srv->collectHeaders(WANT_HEADERS, sizeof(WANT_HEADERS) / sizeof(WANT_HEADERS[0]));

  // Unauthenticated (login surface only).
  _guarded("/login",              HTTP_GET,  _handle_login_get,     false);
  _guarded("/api/login",          HTTP_POST, _handle_login_post,    false);
  _guarded("/api/logout",         HTTP_POST, _handle_logout,        false);

  // Change-PIN surface — requires a session; reachable during forced change.
  _guarded("/change-pin",         HTTP_GET,  _handle_change_pin_get,  true);
  _guarded("/api/change-pin",     HTTP_POST, _handle_change_pin_post, true);

  // Everything else requires a valid session.
  _guarded("/",                   HTTP_GET,  _handle_dashboard,     true);
  _guarded("/setup",              HTTP_GET,  _handle_setup_get,     true);
  _guarded("/enroll",             HTTP_GET,  _handle_enroll_get,    true);
  _guarded("/settings",           HTTP_GET,  _handle_settings_get,  true);
  _guarded("/config",             HTTP_GET,  _handle_config_get,    true);
  _guarded("/api/status",         HTTP_GET,  _handle_status,        true);
  _guarded("/api/enroll-status",  HTTP_GET,  _handle_enroll_status, true);
  _guarded("/api/setup",          HTTP_POST, _handle_setup_post,    true);
  _guarded("/api/enroll",         HTTP_POST, _handle_enroll_post,   true);
  _guarded("/api/settings",       HTTP_POST, _handle_settings_post, true);
  _guarded("/api/config",         HTTP_POST, _handle_config_post,   true);
  _guarded("/api/reset",          HTTP_POST, _handle_reset,         true);
#ifdef NOPORTS_POE_P4
  _guarded("/api/identify",       HTTP_POST, _handle_identify,      true);
#endif
  _srv->onNotFound(_handle_not_found);
}

// Stop, destroy and recreate the server socket bound to the right address,
// then re-register all routes and start listening.
static void _rebind(bool local) {
  if (_srv) {
    _srv->stop();
    delete _srv;
    _srv = nullptr;
  }
  _localhost_only = local;
  IPAddress addr = local ? IPAddress(127, 0, 0, 1) : IPAddress(0, 0, 0, 0);
  _srv = new WebServer(addr, 80);
  _register_routes();
  _srv->begin();
  Serial.printf("[web] Rebound to %s:80\n", local ? "127.0.0.1" : "0.0.0.0");
}

// ─── Public ───────────────────────────────────────────────────────────────

void web_server_begin(NoPortsDaemon *daemon,
                      bool          *running,
                      DaemonStats   *stats,
                      EnrollStatus  *enroll,
                      void        (*restart_cb)()) {
  _daemon     = daemon;
  _running    = running;
  _stats      = stats;
  _enroll     = enroll;
  _restart_cb = restart_cb;
  _start_ms   = millis();

  _enroll->phase      = ENROLL_IDLE;
  _enroll->message[0] = '\0';

  for (int i = 0; i < SESSION_MAX; i++) _sessions[i].token[0] = '\0';
  _load_or_create_pin();

  _localhost_only = (nvs_load(NVS_KEY_WEB_LOCAL) == "1");
  // Safety: localhost-only with no daemon configured = permanent lockout. Fall back.
  if (_localhost_only && !nvs_is_configured()) {
    _localhost_only = false;
    Serial.println("[web] web_local=1 but not configured — binding to 0.0.0.0 for safety");
  }
  IPAddress addr = _localhost_only ? IPAddress(127, 0, 0, 1) : IPAddress(0, 0, 0, 0);
  _srv = new WebServer(addr, 80);
  _register_routes();
  _srv->begin();
  Serial.printf("[web] HTTP server started on %s:80\n",
                _localhost_only ? "127.0.0.1" : "0.0.0.0");
}

void web_server_handle() {
  _srv->handleClient();
}

bool web_server_restart_pending() {
  return _restart_pending;
}

void web_server_clear_restart() {
  _restart_pending = false;
}

String web_server_ip() {
#ifdef NOPORTS_TEST_WIFI_AP
  return WiFi.softAPIP().toString();
#elif defined(NOPORTS_POE_P4)
  return ETH.localIP().toString();
#else
  return "0.0.0.0";
#endif
}

bool web_server_is_local() {
  return _localhost_only;
}
