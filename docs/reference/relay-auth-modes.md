# Relay authentication modes

How a NoPorts client and daemon authenticate to the relay (`srvd`), using
**ESCR** (Encrypted Signed Challenge-Response, the strong mode) or **legacy**
(`payload`, the original mode), and how the relay decides which mode each
connection uses.

> Reference for `RelayAuthMode`, `SrvdSessionParams.sideAMode` and
> `sideBMode`, `SrvdChannel.effectiveRelayAuthMode`,
> `SrvdChannel.daemonRelayAuthMode`, `SrvdChannel.checkDaemonAnswer`,
> `SrvdChannel.escrRequestedButUnreconcilable` and
> `SshnpdChannel.knownRelayAuthSupport`. It describes behaviour, not a
> protocol spec.

## Actors and the two "sides"

Every session opens two connections into the relay:

- **Side A** — the **client** (`sshnp` / `npt` / NoPorts Desktop). A current
  client can always do ESCR, so its ESCR capability is a given.
- **Side B** — the **daemon** (`sshnpd`). Older daemons cannot do ESCR; the
  client learns whether this one can from the daemon ping
  (`DaemonFeature.supportsRamEscr`), and from v5.18.3 also from its record of
  the daemon's last ping response (see
  [How a client from v5.18.3 names each side's mode](#how-a-client-from-v5183-names-each-sides-mode)).

Each side authenticates independently, and the relay authenticates each
incoming socket on its own. A legacy socket sends its signed envelope (a line
starting with `{`) as soon as it connects and reads nothing; an ESCR socket
sends nothing until the relay sends it a challenge.

## How the current relay decides

The relay decides each side's mode from what the client told it, and never
from how long a socket stays silent.

**A request that names both sides.** When `request_ports` carries
`relayAuthModes: {"sideA": "escr" | "payload", "sideB": "escr" | "payload"}`,
the relay applies it as given, and ignores the request's `relayAuthMode` and
any auth-modes notification for the session. Its response then carries
`appliedRelayAuthModes: true`. Clients from v5.18.3 send `relayAuthModes` in
every request.

**Otherwise the request's `relayAuthMode` and `relayAuthAesKey` decide:**

| `relayAuthMode` | `relayAuthAesKey` | Side A | Side B | Sent by |
|---|---|---|---|---|
| `payload`, or absent | absent | legacy | legacy | every client before v5.18.0 by default, and v5.18.0 to v5.18.2 with `--relay-auth-mode payload` |
| `escr` | present | ESCR | ESCR | clients from v5.10.0 to v5.18.2 with `--relay-auth-mode escr`, and on port 443 |
| `payload` | present | ESCR | left to the client | clients v5.18.0 to v5.18.2 by default |

**A side left to the client.** Each side B socket waits, and is sent nothing,
until one of these happens:

- the client's auth-modes notification (`{sessionId, rvdNonce, sideA,
  sideB}`) names side B's mode. The relay accepts it only from the session's
  requester, carrying the `rvdNonce` this relay instance answered with, and
  reads only `sideB`. Every side B socket still waiting takes that mode, and
  every later one is given it as it connects. An ESCR socket is challenged at
  once;
- the socket's first byte is `{`: it is legacy at once, whatever the client
  later says.

Any other first byte is refused. A socket nobody speaks for is closed at the
relay's authentication limit (30 seconds), having been sent nothing. A socket
keeps the mode it has once it has one.

**A side with a known mode refuses the other.** A legacy envelope on an ESCR
side is refused, and a legacy side is never challenged. Each ESCR socket gets
a challenge of its own.

**Requests refused before any port is allocated**, with a NACK saying why when
the request accepts one (`multipleAcksOk`):

- `relayAuthModes` that is not a map, does not name both `sideA` and
  `sideB`, or names a mode other than `escr` or `payload`;
- a side that authenticates by ESCR (named by `relayAuthModes`, or by
  `relayAuthMode: escr`) with no `relayAuthAesKey`.

**The response** says `autoDetectsRelayAuth: true` for every session, because
clients v5.18.0 to v5.18.2 send their auth-modes notification only when it
does.

**Port 443** (`--only-port 443`) multiplexes both sides on one port and is
ESCR-only: the relay refuses a 443 request unless both sides authenticate and
the modes it applies to them are ESCR. A 443 request whose `relayAuthModes`
names legacy for either side is refused.

`srvd --relay-auth-detect-window-ms` is still accepted, so that existing
command lines keep working, and has no effect.

## Older relays

- **v5.18.0 to v5.18.2** advertise `autoDetectsRelayAuth: true` and decide by
  timing whenever a side's mode is not known when its socket connects: a
  leading `{` is legacy, and silence for the detection window
  (`--relay-auth-detect-window-ms`, 500 ms by default) is ESCR, when the relay
  sends a challenge. The client's auth-modes notification sets a side's mode
  ahead of that. A legacy socket whose first bytes arrive after the window is
  challenged, and does not authenticate. These relays ignore
  `relayAuthModes`, so a client from v5.18.3 is served as a v5.18.0 client
  is, and sends them its auth-modes notification.
- **Before v5.18.0** the relay does not advertise `autoDetectsRelayAuth`, and
  applies **one session-wide mode to both sockets**: the request's
  `relayAuthMode`. The two sides cannot differ, and the auth-modes
  notification is ignored.

## Client capability

The `relayAuthMode` request field, `--relay-auth-mode` and ESCR relay auth
first appear in **v5.10.0** (a pre-release, 2025-06-11); **v5.11.2**
(2025-07-04) is the first full release with them. A client before v5.10.0
sends no `relayAuthMode`, which the relay reads as `payload`, so both of its
sides are legacy.

From v5.10.0 to v5.17.x the default is `payload`, and the client sends a
`relayAuthAesKey` only for `--relay-auth-mode escr`, when it also requires the
daemon to advertise ESCR. Only clients from v5.18.0 send `payload` with a key.

From v5.18.3 every request also names both sides' modes in `relayAuthModes`.

## How a client from v5.18.3 names each side's mode

`npt`, `sshnp` and NoPorts Desktop name both sides' modes in `request_ports`,
so they need the daemon's ESCR support before they ask the relay for ports.
`npt` and NoPorts Desktop send the daemon a ping on every session, and so
does `sshnp` whenever the session needs a daemon feature: the device
authenticating to the relay or the relay traffic being encrypted, both on by
default, or the ssh public key being sent. The client takes the daemon's ESCR
support, in this order, from:

1. the live ping answer this process last had from that daemon device, kept
   in memory for the life of the process, by client Atsign, daemon Atsign and
   device together. The client uses it at once, and reads the record
   alongside only to decide whether to rewrite it;
2. its own record of the daemon device's last ping response, a self record
   on the client's atServer;
3. the live ping, which it then waits for before asking the relay. With no
   ping response the session fails with the ping timeout, and the relay is
   never asked.

An `sshnp` session that needs no daemon feature sends no ping and waits for
none: the first two steps decide, the daemon is taken not to support ESCR
when neither has an answer, and the client writes no record.

A ping answer counts only when it comes from the daemon Atsign under that
device's own key, `heartbeat.<device>.sshnp@<daemon>`, matched in full.

**The record** is `cached.ping.<daemon Atsign, without @>.<device>.sshnp`,
owned by the client Atsign, with a 30-day ttl. Its value is
`{"storedAt", "supportsRamEscr", "publicSigningKeyUri"}` and nothing else. The
client reads and writes it on the atServer, not in local storage, and waits
at most 5 seconds for either. After a live ping it writes the record when
there is none, when `supportsRamEscr` or `publicSigningKeyUri` changed, when
the record is more than 7 days old, or when its `storedAt` is more than 5
minutes ahead of the client's clock, and never when the read failed. A
record that cannot be read or decoded counts as absent; a write that fails is
logged, and the session carries on.

**The request** names `relayAuthModes` for that answer as a relay that
authenticates each side by its own mode applies them: side A as the client's
own mode, side B as the daemon's. It
still names `relayAuthMode` and `relayAuthAesKey` as before, for a relay that
does not read `relayAuthModes`, and its `preFetch` holds the daemon's
`publicSigningKeyUri` from that answer.

**When the relay applied them** (`appliedRelayAuthModes: true`), each side
uses the mode the request named: the client authenticates its own socket by
side A's, tells the daemon side B's, and sends no auth-modes notification.
The live ping can still contradict the answer the request was built from.
When the daemon authenticates to the relay, `checkDaemonAnswer` ends the
attempt if the request named ESCR for side B and the live ping gives legacy,
or, under an explicit `--relay-auth-mode`, if the two give side B different
modes. A daemon that does not authenticate to the relay uses no side B mode,
so its answer ends nothing. The client first corrects the
record, then fails the attempt before the daemon is asked for anything,
saying the daemon's relay auth support changed since it was last seen. The
relay releases the abandoned session's ports at its 30-second limit. The
next attempt in the same process takes the live answer from memory, even if
the record could not be rewritten: `npt --keep-alive` and NoPorts Desktop
retry with it, and a one-shot `npt` or `sshnp` is rerun. A record that says
legacy for a daemon that now does ESCR, under the default mode, does not end
the attempt: the session runs with legacy on side B, and the record is
corrected.

**When the relay did not apply them**, the client acts as a v5.18.0 client
does: each side's mode comes from the response's `autoDetectsRelayAuth` and
the live ping, and the client sends its
auth-modes notification when the relay auto-detects. A contradicted record
ends no attempt here; the record is corrected.

## What a v5.18 client controls

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
daemonSupportsEscr`, told to the daemon as `req.relayAuthMode` and to the
relay in the auth-modes notification), and for `request_ports` (`autoDetect =
false, peerSupportsEscr = true`). The client sends a `relayAuthAesKey`
whenever its preference is `escr`, so by default its `request_ports` says
`payload` with a key.

From v5.18.3, `request_ports` also names `relayAuthModes`: both sides
evaluated with `autoDetect = true`, side B with the daemon's support taken as
[described above](#how-a-client-from-v5183-names-each-sides-mode). A relay
that applied them uses them as named, whatever its `autoDetectsRelayAuth`
says.

`E` = ESCR, `L` = legacy.

## Matrix A — current relay

For a client from v5.18.3, "Daemon ESCR" is the answer the request was built
from; when the live ping contradicts it, see
[How a client from v5.18.3 names each side's mode](#how-a-client-from-v5183-names-each-sides-mode).

| Client | Preference | Daemon ESCR | `request_ports` | Side A | Side B | Outcome |
|---|---|---|---|---|---|---|
| v5.18.3+ | escr (default) | yes | `relayAuthModes` E, E | E | E | Both ESCR. ✓ |
| v5.18.3+ | escr (default) | **no** | `relayAuthModes` E, L | E | L | Client ESCR, daemon legacy. ✓ |
| v5.18.3+ | escr (explicit) | yes | `relayAuthModes` E, E | E | E | Both ESCR. ✓ |
| v5.18.3+ | escr (explicit) | **no** | `relayAuthModes` E, L | E | L | Client ESCR, daemon legacy. ✓ |
| v5.18.3+ | payload | any | `relayAuthModes` L, L | L | L | Both legacy. ✓ |
| v5.18.3+ | **443** | yes | `relayAuthModes` E, E | E | E | Both ESCR. ✓ |
| v5.18.3+ | **443** | **no** | `relayAuthModes` E, E | — | — | **Rejected** by the client before the daemon is asked: 443 is ESCR-only. |
| v5.18.0 to v5.18.2 | escr (default) | yes | payload + key | E | E, from the client's notification | Both ESCR. If the notification never arrives, the daemon's socket is closed at the 30-second limit and the session fails. |
| v5.18.0 to v5.18.2 | escr (default) | **no** | payload + key | E | L, from its leading `{` | Client ESCR, daemon legacy. ✓ |
| v5.18.0 to v5.18.2 | escr (explicit) | yes | escr + key | E | E | Both ESCR. ✓ |
| v5.18.0 to v5.18.2 | escr (explicit) | **no** | escr + key | E | **refused** | **Fails at connect**: the relay applies ESCR to both sides and refuses the daemon's legacy envelope. |
| v5.18.0 to v5.18.2 | payload | any | payload | L | L | Both legacy. ✓ |
| v5.18.0 to v5.18.2 | **443** | yes | escr + key | E | E | Both ESCR. ✓ |
| v5.18.0 to v5.18.2 | **443** | **no** | — | — | — | **Rejected up front** by the client: 443 is ESCR-only. |
| v5.10.0 to v5.17.x | payload (default) | any | payload | L | L | Both legacy. ✓ |
| v5.10.0 to v5.17.x | escr (explicit) | yes | escr + key | E | E | Both ESCR. ✓ |
| v5.10.0 to v5.17.x | escr (explicit) | **no** | — | — | — | **Rejected up front** by the client, which requires the daemon to advertise ESCR. |
| before v5.10.0 | — (legacy only) | any | no `relayAuthMode` | L | L | Both legacy. ✓ |

## Matrix B — relays before v5.18.0

This relay applies the single `request_ports` mode to **both** sockets and
ignores the auth-modes notification, so the two sides cannot differ.

| Client | Preference | Explicit | Daemon ESCR | request_ports (both) | Side A | Side B | Outcome |
|---|---|---|---|---|---|---|---|
| v5.18+ | escr | no | any | L | L | L | Both legacy (ESCR not used; safe). ✓ |
| v5.18+ | escr | **yes** | yes | E | E | E | Both ESCR — explicit forces it. ✓ |
| v5.18+ | escr | **yes** | **no** | E | (E) | (L) | **Rejected up front** — cannot reconcile (see below). |
| v5.18+ | payload | any | any | L | L | L | Both legacy. ✓ |
| v5.18+ | **443** | — | yes | E | E | E | 443 ESCR-only. ✓ |
| v5.18+ | **443** | — | **no** | — | — | — | **Rejected up front** — 443 is ESCR-only. |
| before v5.18.0 | — | — | any | as sent | | | As in Matrix A: the relay applies the one mode the request names to both sides. |

## Walkthroughs

A client from v5.18.3 asks the relay for ports once it knows what the daemon
last said it supports: from memory, from its record, or from the live ping it
waited for. It names both sides' modes, and the current relay applies them.

### The current relay, a v5.18.3 client, the daemon can't do ESCR → client uses ESCR, daemon uses legacy

1. The client's record says this daemon **cannot** do ESCR. Its request names
   ESCR for side A and legacy for side B in `relayAuthModes`.
2. The relay applies them, and says so in its response.
3. The client authenticates its own connection by ESCR and tells the daemon
   to use legacy. It sends the relay no auth-modes notification.
4. The daemon connects and sends its signed envelope at once, and the relay
   accepts it as legacy.

With no record, the client waits for the daemon's ping response before step
1, and writes the record from it.

### The current relay, a v5.18.3 client, the daemon has stopped doing ESCR → that attempt fails, the next one works

1. The client's record says the daemon **can** do ESCR, so its request names
   ESCR for both sides, and the relay applies them.
2. The daemon's live ping response says it no longer can.
3. The client rewrites the record, and fails the attempt before it asks the
   daemon for anything, saying the daemon's relay auth support changed since
   it was last seen. The relay releases the ports it allocated at its
   30-second limit.
4. The next attempt names legacy for the daemon's side, from the live answer
   the client keeps in memory, or from the rewritten record in a new process.

The same happens under `--relay-auth-mode escr` when the daemon's support
changed either way. Under the default mode, a record that says legacy for a
daemon that now does ESCR ends nothing: that session runs with legacy on the
daemon's side, and the record is corrected.

The walkthroughs below describe clients v5.18.0 to v5.18.2, and every client
with an older relay. Such a client's opening request to the relay goes out
**before** it has heard back from the daemon about whether the daemon can do
ESCR, and before it knows which relay it has. That request names one mode in
`relayAuthMode`, and a v5.18 client includes a `relayAuthAesKey` whenever it
prefers ESCR. A relay before v5.18.0 applies the named mode to both
connections; the current relay reads the pair from a client v5.18.0 to
v5.18.2: by default `payload` with a key, which it takes as "my own
connection is ESCR, and I will tell you the daemon's".

### The current relay, a v5.18.0 to v5.18.2 client prefers ESCR, the daemon can't → client uses ESCR, daemon uses legacy

1. The client prefers ESCR (the default). Its opening request names `payload`
   and carries a key.
2. The relay challenges the client's connection as soon as it connects, and
   holds the daemon's side until it hears more.
3. The client hears back from the daemon: this daemon **cannot** do ESCR, so it
   tells the daemon to use legacy, and tells the relay the daemon's connection
   is legacy.
4. The daemon connects and sends its signed envelope at once. The relay
   accepts it as legacy, whether or not the client's notification has arrived
   yet.

### The current relay, a v5.18.0 to v5.18.2 client prefers ESCR, the daemon can → both use ESCR

1. As above, the opening request names `payload` with a key, and the client's
   connection is challenged at once.
2. The client hears back from the daemon: it **can** do ESCR. It tells the
   daemon to use ESCR, and tells the relay the daemon's connection is ESCR.
3. The daemon connects and waits to be challenged. The relay challenges it once
   the client's notification has arrived, or as it connects if the
   notification came first.

The client's notification is what releases the daemon's connection here. If it
never reaches the relay, the relay closes the daemon's connection at its
30-second limit, having sent it nothing, and the session fails.

### The current relay, a v5.18.0 to v5.18.2 client insisted on ESCR, the daemon can't → fails at connect

1. The opening request names **ESCR** with a key, so the current relay applies
   ESCR to both connections.
2. The client hears back from the daemon: it **cannot** do ESCR. The relay
   advertises `autoDetectsRelayAuth`, so the client goes on, tells the daemon
   to use legacy, and tells the relay so; the relay ignores that, because the
   request named the mode.
3. The daemon's legacy envelope is refused, and the session fails.

Retry without `--relay-auth-mode escr`, or upgrade the daemon. A client from
v5.18.3 names legacy for the daemon's side instead, and the session runs.

### An older relay, the client prefers ESCR but didn't insist → both use legacy

1. The client prefers ESCR, but the user didn't explicitly ask for it. The
   opening request names **legacy**.
2. The relay's reply shows it is a relay before v5.18.0: it runs the whole
   session on one mode and ignores any follow-up.
3. Such a relay can't run one connection on ESCR and the other on legacy, and
   the client wasn't told to insist on ESCR — so the client just uses the safe
   mode it already named: **legacy on both connections**.
4. Both connections authenticate with legacy, and the relay accepts.

ESCR isn't attempted here, even if this daemon could do it. The default stance
is "only use ESCR where the whole path clearly supports it", and an older relay
can't give that assurance before the session starts.

### An older relay, the user insisted on ESCR, the daemon can do ESCR → both use ESCR

1. The user explicitly asked for ESCR, so the client is being insistent. Its
   opening request names **ESCR**, which commits the whole session to it.
2. The relay is older, so it will run both connections on ESCR.
3. The client hears back from the daemon: it **can** do ESCR.
4. Both connections authenticate with ESCR, and the relay accepts.

### An older relay, the user insisted on ESCR, the daemon can't → refused before connecting

1. Because the user insisted on ESCR, the opening request named ESCR, so this
   older relay will require ESCR on **both** connections.
2. The client hears back from the daemon: it **cannot** do ESCR.
3. The client already committed the whole session to ESCR, this older relay
   ignores any follow-up, and the daemon can't do ESCR — so the daemon's
   connection would be turned away part-way through connecting.
4. Rather than let that happen, the client stops right away with a clear error.

### Asking for port 443 with a daemon that can't do ESCR → refused before connecting (any relay)

1. Asking for port 443 puts both connections through a single shared port, and
   that shared-port path only ever uses ESCR — on every relay, new or old. So
   ESCR is required on both connections no matter what.
2. The client hears back from the daemon: it **cannot** do ESCR.
3. The single-port path has no legacy fallback, so the client stops up front
   rather than let the daemon fail to authenticate part-way through
   connecting.

## Rejected up front

`SrvdChannel.escrRequestedButUnreconcilable` is true — and the client aborts
`initialize()` with a clear error — when the daemon **authenticates to the
relay** (`authenticateDeviceToRvd`) and **cannot do ESCR**, yet ESCR is
unavoidable on the daemon's socket, i.e. **either**:

- **443** — the single-port path is ESCR-only on every relay, so a non-ESCR
  daemon can never use it; **or**
- **explicit ESCR through a relay that does not advertise
  `autoDetectsRelayAuth`** — the relay forces one mode on both sockets and
  ignores the auth-modes notification.

Explicit ESCR with a non-ESCR daemon through the current relay is not caught
here: a client from v5.18.3 names legacy for the daemon's side, and a client
v5.18.0 to v5.18.2 fails at connect (see Matrix A).

> The tables assume the daemon authenticates to the relay
> (`authenticateDeviceToRvd`, the default). With `--no-authenticate-device-to-rvd`
> the daemon does no relay auth at all, so its ESCR capability is moot and
> nothing is rejected (side A still authenticates as shown; side B does not
> authenticate).

## Key properties

- **The relay never decides from a clock.** Each side's mode comes from the
  request, from the client's auth-modes notification, or from a legacy
  socket's leading `{`.
- **A client from v5.18.3 names both sides' modes** before either socket
  connects, from the daemon's last known answer, and fails an attempt whose
  answer the live ping contradicts in a way that matters before the daemon is
  asked for anything.
- **Progressive by default.** Without an explicit flag, ESCR is used only where
  the whole path supports it; against a relay before v5.18.0 both sides stay on
  legacy, so daemons (and clients) that predate ESCR keep working.
- **Explicit ESCR forces ESCR.** Against a daemon that cannot do it, it is
  refused up front on 443 and on a relay before v5.18.0. On the current relay
  a client from v5.18.3 gives the daemon's side legacy, and a client v5.18.0
  to v5.18.2 fails at connect.
- **443 is ESCR-only** on every relay version.
- **`payload`** always yields legacy on both sides.
- **Only an ESCR side is re-checked for revocation.** srvd ends a session
  once the enrollment an ESCR side signed with is revoked, superseded,
  deleted or expires (`--signing-key-check-secs`, every 5 minutes by
  default). The sessions srvd reports to a collector Atsign are re-checked
  every 3 seconds as well (`--reported-signing-key-check-secs`), so such a
  session ends within 10 seconds while its atServer answers promptly. A
  legacy side signs with its Atsign's shared key, which names no enrollment,
  so the relay can't tell when that side's enrollment goes.
