#!/usr/bin/env python3
"""
NoPorts PoE — HTTP endpoint test harness
==========================================
Run against a device flashed with the test_esp32 build:

    # 1. Flash: pio run -e test_esp32 --target upload
    # 2. Connect laptop to "NoPorts-Test" Wi-Fi AP (password: noports123)
    # 3. python test_http.py                        # default 192.168.4.1
    # 4. python test_http.py --host 10.0.0.42       # production IP

Also works against the production (esp32p4) build on a local network:
    python test_http.py --host noports-poe.local

Exit code 0 = all tests passed, non-zero = failures.
"""

import argparse
import json
import sys
import time
import urllib.request
import urllib.error
from typing import Any, Dict, List, Tuple

# ─── Test infrastructure ──────────────────────────────────────────────────

PASS = "\033[32mPASS\033[0m"
FAIL = "\033[31mFAIL\033[0m"
SKIP = "\033[33mSKIP\033[0m"

results: List[Tuple[str, bool, str]] = []


def check(name: str, ok: bool, detail: str = "") -> bool:
    tag = PASS if ok else FAIL
    msg = f"  [{tag}] {name}"
    if detail:
        msg += f"  ({detail})"
    print(msg)
    results.append((name, ok, detail))
    return ok


def get(url: str, timeout: int = 10) -> Tuple[int, bytes, str]:
    """Return (status, body_bytes, content_type)."""
    try:
        with urllib.request.urlopen(url, timeout=timeout) as r:
            return r.status, r.read(), r.headers.get("Content-Type", "")
    except urllib.error.HTTPError as e:
        return e.code, e.read(), ""
    except Exception as e:
        return 0, str(e).encode(), ""


def post(url: str, body: Dict[str, Any], timeout: int = 10) -> Tuple[int, bytes]:
    data = json.dumps(body).encode()
    req  = urllib.request.Request(url, data=data,
                                  headers={"Content-Type": "application/json"},
                                  method="POST")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return r.status, r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()
    except Exception as e:
        return 0, str(e).encode()


# ─── Individual tests ─────────────────────────────────────────────────────

def test_dashboard(base: str) -> None:
    print("\n── Dashboard")
    code, body, ct = get(f"{base}/")
    check("GET / returns 200",           code == 200, f"got {code}")
    check("GET / is HTML",               "text/html" in ct, ct)
    check("GET / contains 'NoPorts'",    b"NoPorts" in body)


def test_status_api(base: str) -> Dict[str, Any]:
    print("\n── /api/status")
    code, body, ct = get(f"{base}/api/status")
    ok_code = check("GET /api/status returns 200", code == 200, f"got {code}")
    ok_json = check("GET /api/status is JSON", "application/json" in ct, ct)

    d: Dict[str, Any] = {}
    if ok_code and ok_json:
        try:
            d = json.loads(body)
        except json.JSONDecodeError as e:
            check("JSON parses cleanly", False, str(e))
            return d

    required = ["state", "atsign", "device", "version", "uptime_s",
                "tunnels", "pings", "bytes_in", "bytes_out",
                "relay_cpu", "active_relays", "configured", "enrolled", "ip"]
    for field in required:
        check(f"  field '{field}' present", field in d, f"keys={list(d.keys())}")

    check("state is a string",      isinstance(d.get("state"), str))
    check("uptime_s is non-negative", isinstance(d.get("uptime_s"), (int, float)) and d.get("uptime_s", -1) >= 0)
    check("version present",          bool(d.get("version")))
    return d


def test_setup_page(base: str) -> None:
    print("\n── /setup page")
    code, body, ct = get(f"{base}/setup")
    check("GET /setup returns 200",  code == 200, f"got {code}")
    check("GET /setup is HTML",      "text/html" in ct, ct)
    check("Contains atSign field",   b"atSign" in body or b"atsign" in body.lower())
    check("Contains OTP hint",       b"enrol" in body.lower() or b"enroll" in body.lower() or b"otp" in body.lower())


def test_enroll_page(base: str) -> None:
    print("\n── /enroll page")
    code, body, ct = get(f"{base}/enroll")
    check("GET /enroll returns 200", code == 200, f"got {code}")
    check("GET /enroll is HTML",     "text/html" in ct, ct)
    check("Contains OTP field",      b"otp" in body.lower() or b"passcode" in body.lower())


def test_settings_page(base: str) -> None:
    print("\n── /settings page")
    code, body, ct = get(f"{base}/settings")
    check("GET /settings returns 200", code == 200, f"got {code}")
    check("Contains manager field",   b"manager" in body.lower() or b"Manager" in body)
    check("Contains permitopen",      b"permitopen" in body.lower() or b"PermitOpen" in body)


def test_config_page(base: str) -> None:
    print("\n── /config page")
    code, body, ct = get(f"{base}/config")
    check("GET /config returns 200", code == 200, f"got {code}")
    check("Contains keepalive",      b"keep" in body.lower() or b"keepalive" in body.lower())
    check("Contains relay",          b"relay" in body.lower())


def test_api_config_roundtrip(base: str) -> None:
    print("\n── /api/config POST round-trip")
    code, body = post(f"{base}/api/config", {"keepalive": "3", "max_relays": "2"})
    ok = check("POST /api/config returns 200", code == 200, f"got {code}")
    if ok:
        try:
            d = json.loads(body)
            check("Response has ok:true", d.get("ok") is True, str(d))
        except Exception as e:
            check("Response JSON valid", False, str(e))

    # Verify dashboard still works after config change
    code2, _, _ = get(f"{base}/")
    check("Dashboard still 200 after config", code2 == 200, f"got {code2}")


def test_api_settings_roundtrip(base: str) -> None:
    print("\n── /api/settings POST round-trip")
    code, body = post(f"{base}/api/settings", {
        "mode": "0",
        "managers": "@testmanager",
        "permitopen": "localhost:22",
        "policy_at": ""
    })
    ok = check("POST /api/settings returns 200", code == 200, f"got {code}")
    if ok:
        try:
            d = json.loads(body)
            check("Response has ok:true", d.get("ok") is True, str(d))
        except Exception as e:
            check("Response JSON valid", False, str(e))

    # Restart is deferred to loop(); poll until server responds (≤10 s)
    deadline = time.time() + 10
    code2 = 0
    while time.time() < deadline:
        code2, _, _ = get(f"{base}/", timeout=3)
        if code2 == 200:
            break
        time.sleep(0.5)
    check("Dashboard still 200 after settings", code2 == 200, f"got {code2}")


def test_setup_api_missing_fields(base: str) -> None:
    print("\n── /api/setup validation")
    code, body = post(f"{base}/api/setup", {"at": "@x"})  # missing fields
    check("POST /api/setup with missing fields returns 400", code == 400, f"got {code}")
    try:
        d = json.loads(body)
        check("Error response has ok:false", d.get("ok") is False, str(d))
    except Exception:
        pass


def test_enroll_api_no_body(base: str) -> None:
    print("\n── /api/enroll validation")
    # POST with no body — device should return 400
    req = urllib.request.Request(f"{base}/api/enroll", data=b"",
                                 headers={"Content-Type": "application/json"},
                                 method="POST")
    try:
        with urllib.request.urlopen(req, timeout=5) as r:
            code, body = r.status, r.read()
    except urllib.error.HTTPError as e:
        code, body = e.code, e.read()
    check("POST /api/enroll with empty body returns 400", code == 400, f"got {code}")


def test_enroll_status(base: str) -> None:
    print("\n── /api/enroll-status")
    code, body, ct = get(f"{base}/api/enroll-status")
    check("GET /api/enroll-status returns 200", code == 200, f"got {code}")
    try:
        d = json.loads(body)
        check("Has 'state' field",   "state" in d, str(d))
        check("Has 'message' field", "message" in d, str(d))
        check("State is valid",      d.get("state") in ("idle", "running", "ok", "fail"), str(d))
    except Exception as e:
        check("JSON parses cleanly", False, str(e))


def test_404(base: str) -> None:
    print("\n── 404 handling")
    code, _, _ = get(f"{base}/nonexistent-page-xyz")
    check("Unknown route returns 404", code == 404, f"got {code}")


def test_reset_requires_post(base: str) -> None:
    print("\n── /api/reset method guard")
    code, _, _ = get(f"{base}/api/reset")
    check("GET /api/reset returns 404 (POST only)", code == 404, f"got {code}")


# ─── Main ─────────────────────────────────────────────────────────────────

def main() -> int:
    parser = argparse.ArgumentParser(description="NoPorts PoE HTTP tests")
    parser.add_argument("--host", default="192.168.4.1",
                        help="Device IP or hostname (default: 192.168.4.1)")
    parser.add_argument("--port", type=int, default=80)
    parser.add_argument("--timeout", type=int, default=30,
                        help="Seconds to wait for first connection")
    args = parser.parse_args()

    base = f"http://{args.host}:{args.port}"
    print(f"NoPorts PoE HTTP tests  →  {base}\n")

    # Wait for device to be reachable
    print("Waiting for device...")
    deadline = time.time() + args.timeout
    while time.time() < deadline:
        code, _, _ = get(f"{base}/api/status", timeout=3)
        if code == 200:
            print("Device reachable.\n")
            break
        time.sleep(2)
    else:
        print(f"ERROR: Device at {base} not reachable after {args.timeout}s")
        return 1

    # Run all tests
    test_dashboard(base)
    status = test_status_api(base)
    test_setup_page(base)
    test_enroll_page(base)
    test_settings_page(base)
    test_config_page(base)
    test_api_config_roundtrip(base)
    test_api_settings_roundtrip(base)
    test_setup_api_missing_fields(base)
    test_enroll_api_no_body(base)
    test_enroll_status(base)
    test_404(base)
    test_reset_requires_post(base)

    # Summary
    passed = sum(1 for _, ok, _ in results if ok)
    failed = sum(1 for _, ok, _ in results if not ok)
    total  = len(results)
    print(f"\n{'─'*40}")
    print(f"  {passed}/{total} passed   {failed} failed")
    print(f"{'─'*40}")

    if failed:
        print("\nFailed tests:")
        for name, ok, detail in results:
            if not ok:
                print(f"  • {name}  {detail}")

    return 0 if failed == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
