# Code Review: `st/best_rv_patch` vs `trunk`

**Date:** 2026-04-08  
**Branch:** `st/best_rv_patch`

---

## Status of Prior Issues

| # | Original Issue | Status |
|---|---------------|--------|
| 1 | Sentinel `-1` as "not initialized" in `_lowestAverageLatency` | Resolved — using `double.infinity` |
| 2 | Useful log lines removed from `getBestRv` | Resolved |
| 3 | Redundant `atClient` param in `_getIpAddress` | Resolved |
| 4 | `rvIpMap` accumulates across calls | Resolved — `RelaySelector` is instantiated per call in `create_sshnp.dart`, so the map is always fresh |
| 5 | Two loggers for one class | Resolved |
| 6 | Magic string `'standard_relays'` | Resolved — JSON envelope documented in `_fetchStandardRelays` |
| 7 | `channel = null` no-op | **Open** |
| 8 | `logger.shout` for normal progress | Resolved |
| 9 | Duplicate comma-split logic in two files | Resolved — consolidated in `create_sshnp.dart` |
| 10 | `SshnpParams` workaround in `npt.dart` | Resolved — `npt` no longer calls `RelaySelector` directly |
| 11 | Silent early return in `_handleLatencyCheckRequest` | Resolved — now logs a warning |
| 12 | No top-level timeout on `selectBestRelay` | **Open** |
| 13 | `jsonDecode` on malformed value throws uncaught `FormatException` | Resolved — specific catch with warning and early return |
| 14 | Null notification value silently produces empty latency map | Resolved — now throws `FormatException` |
| 15 | Latency subscription not scoped by sessionId | Resolved — daemon responds `sharedWith = notification.from`, so atprotocol routing scopes it to the requesting client |

---

## Open Issues

### 7. `channel = null` no-op (`relay_selector.dart:88`)

```dart
channel = null; // Dart has GC, this does nothing
```

Remove it.

### 12. No top-level timeout on `selectBestRelay`

The pre-connection phase chains three sequential waits:

| Step | Timeout |
|------|---------|
| `_requestRelayIpAddress` per RV (parallel) | 10s |
| `RelayLatencyChecker.measureLatencies` client-side (sequential per RV) | 5s × N |
| `fetchDeviceRelayLatencies` daemon-side | 60s |

Worst case is over 1 minute before the user sees an error. `selectBestRelay` needs a configurable top-level timeout, especially for UI callers.

---

## New Issues

### 16. `npt` has no relay auto-selection path

`create_sshnp.dart` handles best-RV selection for sshnp connections, but `npt.dart` passes `srvdAtSign` directly through to `NptParams` without calling `RelaySelector`. If a user provides an empty or comma-separated `--srvd` for an npt connection, no relay selection happens. This is likely a missing feature.

---

## Summary

| # | File | Severity | Category |
|---|------|----------|----------|
| 7 | `relay_selector.dart:88` | Trivial | Remove no-op `channel = null` |
| 12 | `relay_selector.dart` | High | UX: no top-level timeout, worst-case >1 min |
| 13 | `sshnpd_impl.dart:627` | Medium | Resolved — specific `FormatException` catch with warning |
| 15 | `sshnpd_channel.dart:338` | Medium | Resolved — atprotocol routing via `sharedWith` scopes responses to the requesting client |
| 16 | `npt.dart` | Medium | Missing feature: npt has no relay auto-selection |
| 17 | `sshnpd_channel.dart:333` | Trivial | Resolved — now documents `FormatException` |