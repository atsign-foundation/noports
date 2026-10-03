# Relay authentication modes

How a NoPorts client and daemon decide, per session, whether to authenticate to
the relay (`srvd`) using **ESCR** (Encrypted Signed Challenge-Response, the
strong mode) or **legacy** (`payload`, the original mode), and what the relay
does in each case.

> Reference for the `noports_core` relay auto-detect work
> (`RelayAuthMode`, `SrvdChannel.effectiveRelayAuthMode`,
> `SrvdChannel.escrRequestedButUnreconcilable`). It describes behaviour, not a
> protocol spec.

## Actors and the two "sides"

Every session opens two connections into the relay:

- **Side A** — the **client** (`sshnp` / `npt` / NoPorts Desktop). A current
  client can always do ESCR, so its ESCR capability is a given.
- **Side B** — the **daemon** (`sshnpd`). Older daemons cannot do ESCR; the
  client learns whether this one can from the daemon ping
  (`DaemonFeature.supportsRamEscr`).

Each side authenticates independently, and the relay authenticates each incoming
socket on its own.

## What the relay does with the mode

- **Auto-detecting relay** (current `srvd`; advertises `autoDetectsRelayAuth:
  true`) — detects each socket's mode *per connection* by timing (a legacy peer
  sends a `{…}` line immediately; an ESCR peer stays silent until challenged),
  so the two sides may differ. The client may also send a **definitive
  auth-modes notification** — a hint `{sideA, sideB}` — so the relay skips the
  detection window.
- **Older relay** (does not advertise auto-detect) — applies **one session-wide
  mode to *both* sockets**: the `relayAuthMode` field of the client's
  `request_ports` notification. The two sides cannot differ, and the hint is
  ignored.
- **443 single-port path** (`--only-port 443`) — multiplexes both sides on one
  port and is **ESCR-only on every relay version**. Selecting 443 requires ESCR
  end-to-end (the daemon must support it).

## Client capability

ESCR relay auth was introduced in **NoPorts v5.11.2 (2025-07-04)**. A client
older than that authenticates to the relay only with **legacy**, never requests
ESCR, and sends no auth-modes hint — so for an **older client** side A is always
legacy and `request_ports` declares legacy. The tables assume a current
(≥ v5.11.2) client except where an "older client" row is shown.

## What the (current) client controls

| Input | Source | Meaning |
|---|---|---|
| `relayAuthMode` preference | `--relay-auth-mode` / config / API (default `escr`) | Preferred mode |
| `relayAuthModeExplicit` | whether the user actually set it | Treat as **prescriptive** rather than a soft default |
| `only443` | `--only-port 443` | Forces the ESCR-only single-port path |
| `authenticateDeviceToRvd` | flag | Whether the daemon authenticates to the relay at all |

`effectiveRelayAuthMode(preference, autoDetect, peerSupportsEscr, only443,
prescribed)`:

```
if only443:        return escr             # 443 is ESCR-only everywhere
if prescribed:     return payload if (preference==escr and not peerSupportsEscr) else preference
if not autoDetect: return payload          # older relay applies ONE mode to both -> safe legacy
return escr if (preference==escr and peerSupportsEscr) else payload
```

Evaluated for side A (`peerSupportsEscr = true`), side B (`peerSupportsEscr =
daemonSupportsEscr`, told to the daemon as `req.relayAuthMode`), and for
`request_ports` (`autoDetect = false, peerSupportsEscr = true`).

`E` = ESCR, `L` = legacy.

## Matrix A — latest, auto-detecting relay

The relay reconciles each socket independently, so **explicit vs default ESCR
makes no difference here** (the daemon side degrades to legacy either way and
the relay/hint reconcile it). No session is ever rejected.

| Client | Preference | Daemon ESCR | Side A | Side B | Relay reconciles via | Outcome |
|---|---|---|---|---|---|---|
| current | escr (explicit or not) | yes | E | E | detect + hint `(E,E)` | Both ESCR. ✓ |
| current | escr (explicit or not) | **no** | E | **L** | detect + hint `(E,L)` | Client ESCR, daemon legacy. ✓ |
| current | payload | any | L | L | detect `(L,L)` | Both legacy. ✓ |
| current | **443** | yes | E | E | single ESCR-only port | Both ESCR. ✓ |
| current | **443** | **no** | — | — | — | **Rejected up front** — 443 is ESCR-only; the daemon can't do it. |
| **older** (<5.11.2) | — (legacy only) | any | L | L | detect `(L,L)` | Both legacy. ✓ |

## Matrix B — older, non-auto-detecting relay

This relay applies the single `request_ports` mode to **both** sockets and
ignores the hint, so the two sides cannot differ. (Transitional: production
relays are upgraded before a formal release, so in practice all sessions use
Matrix A.)

| Client | Preference | Explicit | Daemon ESCR | request_ports (both) | Side A | Side B | Outcome |
|---|---|---|---|---|---|---|---|
| current | escr | no | any | L | L | L | Both legacy (ESCR not used; safe). ✓ |
| current | escr | **yes** | yes | E | E | E | Both ESCR — explicit forces it. ✓ |
| current | escr | **yes** | **no** | E | (E) | (L) | **Rejected up front** — cannot reconcile (see below). |
| current | payload | any | any | L | L | L | Both legacy. ✓ |
| current | **443** | — | yes | E | E | E | 443 ESCR-only. ✓ |
| current | **443** | — | **no** | — | — | — | **Rejected up front** — 443 is ESCR-only. |
| **older** | — | — | any | L | L | L | Both legacy. ✓ |

## Walkthroughs

The rows worth tracing are the ones that are not simply "both ESCR" or "both
legacy". Two facts about timing shape all of them. First, the client's opening
request to the relay goes out **before** it has heard back from the daemon about
whether the daemon can do ESCR, and before it knows whether this relay can work
out each connection's mode on its own. Second, that opening request names a
single mode — but **that named mode is only ever used by an older relay**, which
runs the whole session on one mode; a newer relay that inspects each connection
itself ignores it. So read the mode in the opening request as "the fallback an
older relay would use", not "the mode the client will use".

### A newer relay, the client prefers ESCR, the daemon can't → client uses ESCR, daemon uses legacy

1. The client prefers ESCR (the default). Its opening request to the relay names
   **legacy** as the mode. It has to name something before it knows anything
   about the daemon or the relay, and legacy is the one mode every relay and
   every daemon understands, so naming it can never make matters worse.
2. The relay's reply shows it can work out each connection's mode on its own.
   That means the mode named in the opening request is never consulted here — the
   relay will judge the client's connection and the daemon's connection
   separately. The client's real choice of mode is made in step 4, not step 1.
3. The client hears back from the daemon: this daemon **cannot** do ESCR.
4. The client now chooses a mode for each connection on its own merits. Its own
   connection can always do ESCR, so it uses **ESCR**. The daemon can't, so the
   daemon's connection uses **legacy**.
5. The client sends the relay a short follow-up spelling this out — its own
   connection ESCR, the daemon's connection legacy — so the relay needn't spend
   time working it out.
6. The client's connection authenticates with ESCR and the daemon's with legacy,
   and the relay accepts both.

The client keeps the stronger mode on its own connection while the daemon quietly
falls back to legacy — with no waiting and no failure.

### An older relay, the client prefers ESCR but didn't insist → both use legacy

1. The client prefers ESCR, but the user didn't explicitly ask for it. The
   opening request names **legacy**.
2. The relay's reply shows it is an older relay: it can't judge connections on
   its own, so it runs the whole session on one mode and ignores any follow-up.
3. Such a relay can't run one connection on ESCR and the other on legacy, and the
   client wasn't told to insist on ESCR — so the client just uses the safe mode
   it already named: **legacy on both connections**.
4. Both connections authenticate with legacy, and the relay accepts.

ESCR isn't attempted here, even if this daemon could do it. The default stance is
"only use ESCR where the whole path clearly supports it", and an older relay
can't give that assurance before the session starts.

### An older relay, the user insisted on ESCR, the daemon can do ESCR → both use ESCR

1. The user explicitly asked for ESCR, so the client is being insistent. Its
   opening request names **ESCR**, which commits the whole session to it.
2. The relay is older, so it will run both connections on ESCR.
3. The client hears back from the daemon: it **can** do ESCR.
4. Both connections authenticate with ESCR, and the relay accepts.

This is the one situation where explicitly asking for ESCR gets you something an
older relay wouldn't give you otherwise — ESCR the whole way — and it works only
because every part of the path happens to support it.

### An older relay, the user insisted on ESCR, the daemon can't → refused before connecting

1. Because the user insisted on ESCR, the opening request named ESCR, so this
   older relay will require ESCR on **both** connections.
2. The client hears back from the daemon: it **cannot** do ESCR.
3. The client is now stuck. It already committed the whole session to ESCR (that
   went out before it heard from the daemon), this older relay ignores any
   follow-up, and the daemon can't do ESCR — so the daemon's connection would be
   turned away by the relay part-way through connecting.
4. Rather than let that happen, the client stops right away with a clear error.

Quietly dropping just the daemon to legacy wouldn't help: that would create
exactly the "one connection on ESCR, the other on legacy" split this older relay
can't handle. What the user asked for and what the daemon can do simply can't
both be satisfied on this relay, so the client says so up front instead of
failing halfway through.

### Asking for port 443 with a daemon that can't do ESCR → refused before connecting (any relay)

1. Asking for port 443 puts both connections through a single shared port, and
   that shared-port path only ever uses ESCR — on every relay, new or old (there
   is no room in it for a legacy connection). So ESCR is required on both
   connections no matter what.
2. The client hears back from the daemon: it **cannot** do ESCR.
3. The single-port path has no legacy fallback, so the client stops up front
   rather than let the daemon fail to authenticate part-way through connecting.

## Rejected up front

`SrvdChannel.escrRequestedButUnreconcilable` is true — and the client aborts
`initialize()` with a clear error — when the daemon **authenticates to the
relay** (`authenticateDeviceToRvd`) and **cannot do ESCR**, yet ESCR is
unavoidable on the daemon's socket, i.e. **either**:

- **443** — the single-port path is ESCR-only end-to-end on every relay (even an
  auto-detecting one), so a non-ESCR daemon can never use it; **or**
- **explicit ESCR through a non-auto-detecting relay** — the relay forces one
  mode on both sockets and ignores the hint, so the daemon cannot legacy-degrade
  on its own.

These are rejected up front rather than failing mid-connect. Every other
explicit-ESCR case degrades gracefully: the client uses ESCR on its own side,
the daemon side falls back to legacy where needed, and an auto-detecting relay
reconciles per socket.

> The tables assume the daemon authenticates to the relay
> (`authenticateDeviceToRvd`, the default). With `--no-authenticate-device-to-rvd`
> the daemon does no relay auth at all, so its ESCR capability is moot and
> nothing is rejected (side A still authenticates as shown; side B does not
> authenticate).

## Key properties

- **Progressive by default.** Without an explicit flag, ESCR is used only where
  the whole path supports it; against an older relay both sides stay on legacy,
  so daemons (and clients) that predate ESCR keep working.
- **Explicit ESCR forces where it can, degrades where it can't, and hard-errors
  up front — never mid-connect — in the unreconcilable cases** (443 to a
  non-ESCR daemon, or explicit ESCR through a non-auto-detecting relay to a
  non-ESCR daemon).
- **443 is ESCR-only** on every relay version.
- **`payload`** always yields legacy on both sides.
