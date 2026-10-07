# 6.16.0

- build: depends on the at_client_sdk release candidates: at_client
  3.15.0-rc3, at_auth 4.0.0-rc3, at_lookup 3.7.0-rc3, at_cli_commons
  3.1.2-rc2 and at_onboarding_cli 2.0.0-rc3, plus at_commons 5.18.0 and
  at_utils 3.4.1
- build: requires socket_connector 2.6.1, so `Srvd.stop()` and `Npt.close()`
  also end the connections already open through their tunnels
- **BREAKING CHANGE** refactor: `signAndWrapAndJsonEncode` is async,
  `SshnpParams.sessionKP` is an `RsaKeyPair`, and `Activate` takes an
  `ActivateFlows` rather than an `AtOnboardingService`
- **BREAKING CHANGE** feat: `SrvdParams` requires `relayAuthDetectWindowMs`
  and `signingKeyCheckSecs`, and `ClientParams` implementations must add
  `relayAuthModeExplicit`
- **BREAKING CHANGE** feat: `Sshnpd.stop()` and `Srvd.stop()` shut down
  what `init()` and `run()` started, so implementations must add `stop()`
- **BREAKING CHANGE** feat: `RelayAuthenticatorESCR` requires `signingAlgo`
- feat: ESCR relay authentication works for an enrollment that holds signing
  keys of its own or authenticates with ML-DSA-65, which srvd now verifies
  as well as RSA-2048
- feat: srvd checks every 5 minutes (by default) whether either side's
  enrollment has been revoked, superseded, deleted or expired, and ends the
  session if so, for each side that authenticated with ESCR
- feat: srvd works out each side's relay-auth mode (ESCR or legacy) for
  itself, so the client and the daemon can each use the strongest one they
  support. New `srvd --relay-auth-detect-window-ms` option (default 500).
- feat: `relayAuthMode` now defaults to ESCR, used wherever the relay and the
  daemon support it. Against an older relay both sides stay on legacy, so
  daemons that predate ESCR keep working. An explicit `--relay-auth-mode escr`
  forces ESCR wherever it can, and is refused up front when it can't (an
  older relay with a daemon that predates ESCR). The full matrix is in
  `docs/reference/relay-auth-modes.md`.
- feat: `escrSigningKeyPair`, the key and algorithm ESCR relay auth signs
  with, and `loadEnvelopeSigningKey`, which reads the envelope signing key up
  front
- refactor: `verifyEnvelopeSignature` accepts only rsa2048 signatures from
  2048-bit keys, which is what every NoPorts release sends, and so do the
  relay verifiers when they verify RSA
- refactor: moved off at_chops's deprecated compatibility API. Nothing
  changes on the wire, and released versions can still exchange session
  keys with this one
- fix: the two-port relay path issues a fresh ESCR challenge for every
  connection, so a captured response can't be replayed onto a later
  connection in the same session.
- fix: sshnpd refuses a session request whose session id isn't a UUID, and
  `SshnpSessionRequest` and `NptSessionRequest` throw an `ArgumentError` for
  one. New `isValidSessionId` makes the same check
- fix: `LocalSshKeyUtil.deauthorizePublicKey` no longer removes other
  `authorized_keys` lines that happen to contain the session id
- fix: srvd accepts an ESCR-authenticated socket only when it is signed by
  the atSign of the side it claims
- fix: `srvd --manager` accepts session requests only from the manager
  itself
- fix: a long-running srvd no longer keeps a receive port open for every
  session it has relayed
- fix: sshnpd no longer leaves a session's ephemeral key in
  `authorized_keys`, or drops a new session's key, when sessions start and
  end at the same moment
- fix: `Npt.close()` closes the tunnel an inline npt opened, which used to
  keep accepting connections and then threw a `StateError` when it ended
- fix: sshnpd authorizes a direct ssh session's ephemeral key under the
  `homeDirectory` it was given, rather than always under `$HOME`

# 6.15.0

- feat: srv/srvd now carry tunnel traffic through at_chops's OpenSSL-backed
  AES-CTR cipher via FFI, using hardware acceleration (AES-NI on x86,
  ARMv8 Crypto Extensions on arm64) when libcrypto is available, falling
  back to the pure-Dart cipher otherwise

# 6.14.2

- fix: `WrappedSSHSocket.close()`/`destroy()` now tears down the
  `StreamController` feeding its AES-CTR encrypter, instead of only closing
  the underlying socket. The FFI-backed cipher only disposes on that
  controller's `onDone`/`onCancel`/`onError`, so the native
  `EVP_CIPHER_CTX` previously leaked until GC on a teardown that went
  through `close()`/`destroy()` rather than `sink.close()`.
- fix: srvd's daemon-multi control-channel path now disposes its AES-CTR
  cipher on connection close too, instead of leaking an `EVP_CIPHER_CTX`
  and its native buffers per connection

# 6.14.1

- fix: the relay auth stream wrappers (the srv-side relay authenticator and
  both srvd-side relay auth verifiers) now forward pause/resume from their
  `StreamController` to the socket subscription, so backpressure applied by
  the consumer of the wrapped stream reaches the socket and closes the TCP
  window instead of buffering without bound in the wrapper
- build: socket_connector bumped to ^2.6.0, which bounds in-process relay
  buffering with flush-gated backpressure (4 MiB high-water mark per
  direction), enables TCP keep-alive on relayed sockets, and fixes a race in
  2.5.0 where the backpressure flush could collide with a write and close a
  relay side mid-stream, or stall one direction for good

# 6.14.0

- fix: share event logging config once as cached key instead of on every
  heartbeat
- fix: daemon policy config logs downgraded from SHOUT to INFO to stop
  flooding Windows Event Viewer

# 6.13.0

- feat: added `binaryName` and `formatCliHelp` to utils, for generating
  help2man-friendly `--help` output (#2650)
- feat: added a `--version` flag to `NPAParams.parser`

# 6.12.2

- fix: close stdin in srv process, fixes fd leak

# 6.12.1

- fix: `RelaySelector.selectBestRelay` no longer hangs or throws when the
  daemon never responds to a `relay_latency_request` (e.g. pre-5.15.0
  daemons, which don't implement it). It now falls back to client-only
  latency selection after `deviceLatencyTimeout` (default 20s, down from an
  unbounded 60s+ wait). See #2752.

# 6.12.0

- feat: npp policy next iteration

# 6.11.0

- feat: remove persistent caching of public keys

# 6.10.4

- build(deps): take up at_client 3.10.0

# 6.10.3

- fix: In the RelayAuthVerifiers, catch in the same place all the exceptions
  which can be thrown during parsing and processing

# 6.10.2

- fix: Require authenticated connection when sshnpd is sending its periodic
  "am I alive" heartbeat. This forces issuing of a `from:` request, which in
  turn means that a connection via a proxy service is made successfully.
  Also, reduce frequency of this heartbeat from every 15 seconds to every 90
  seconds.

# 6.10.1

fix: remove late from `AtEventConfig? elc` in NPAImpl

# 6.10.0

- feat: enable redundancy support for Policy Services
- fix: ENABLE_SNOOP build environment variable was not being passed correctly in srvd

# 6.9.0

- feat: add support for config file to sshnpd
- feat: add support for password-protected atKeys to sshnp, npt, sshnpd, srvd
- fix: normalize atSign before constructing defaultAtKeysFilePath

# 6.8.1

- build(deps): at_client -> 3.8.0, at_cli_commons -> 3.0.0

# 6.8.0

- feat: Enable npt clients to choose which local IP address to bind to,
  supporting both ipv4 and ipv6, and defaulting to `localhost` on ipv4/ipv6
  as per the host's preference

# 6.7.0

- build(deps): Remove dependency on fork of args package. Output alias info
  explicitly via the option's or flag's help text.

# 6.6.1
- fix: better srvd exception handling

# 6.6.0
- feat: twin keys for control socket and data sockets
- fix: enable daemons and policy service to use the same atSign

# 6.5.0
- feat: New ESCR (Encrypted Signed Challenge-Response) relay socket
  authentication
- feat: Ability to have relay sessions where both sides are connecting to
  port 443
- feat: Ability to send heartbeats over the npt control socket to let network
  intermediaries know that it is active.
# 6.4.0
- feat: have srvd use ephemeral local storage for its AtClient by default
- feat: have srvd listen for PublicKeyChanged events
# 6.3.0
- feat: enable multiple instances of relays for load balancing and resilience
# 6.2.1
- fix: multiple enhancements for stability of `npt` under heavy concurrent load
# 6.2.0
- feat: allow hyphens in device name
# 6.1.1
- build[deps]: upgrade: \
  at_client to 3.2.2 | at_onboarding_cli to 1.6.4 | at_utils to 3.0.19 | at_commons to 5.0.0
# 6.1.0
- feat: npt: added 'keep-alive' flag, and an adjustable session timeout (#1110)
- fix: sshnpd: ensure required directories exist (#1139)
- feat: all: set a 1-minute ttln (notification time-to-live) (#1095)
- feat: sshnp: No double ssh when sockets are encrypted (#1090)
- feat: sshnpd: make daemon storage location map to its device name (#1080)
- feat: sshnpd: add more type validation for session requests (#1063)
- fix: sshnp: various arg parsing issues (#1047)
- feat: sshnpd: add '--sshpublickey-permissions' option (#1004)
- fix: sshnpd,sshnp,npt: better error message if srv binary can't be
  located (#988)

# 6.0.7
- feat: include allowed services in device ping
- chore: deprecate -h and --host in favor of -r and --srvd
- feat: allow --list-devices to work without requiring -t or -r

# 6.0.6
- feat: SrvImplDart: supply a logger to SocketConnector so that the Srv can
  control what happens with any log messages that SocketConnector emits

# 6.0.5
- fix: Strict validation of device name as alphanumeric snake case
- feat: Increase device name max length from 15 to 36

# 6.0.4
- build: upgrade at_chops dependency to ^2.0.0

# 6.0.3
- chore: downgrade at_commons dependency from ^4.0.1 to ^4.0.0
- chore: downgrade at_client dependency from ^3.0.75 to ^3.0.73
- chore: downgrade at_chops dependency from ^2.0.0 to ^1.0.7

# 6.0.2
- chore: Uptake at_commons ^4.0.1 (was ^3.0.56)
- fix: lint errors related to the new version of at_commons
- chore: make SrvImpl throw an SshnpError instead of an Exception

# 6.0.1
- fix: ensure that directories for key creation exist before trying to create them
- fix: ensure that temporary keys are deleted after use
- ci: add srv.exe to the release on Windows

# 6.0.0
- Added ability to authenticate to the socket rendezvous, and made this the
  default behaviour.
- Added ability to end-to-end encrypt all traffic via the socket rendezvous (
  SR), and made this the default behaviour. This provides a good general defense
  against compromise by man-in-the-middle attacks if the two ends are
  communicating via the SR. The encryption is implemented by exchanging a
  symmetric key via an ephemeral encryption keypair generated by the client
  for every session.
- Added ability to "ping" a daemon for info about it, including which
  features the daemon supports.
- By default, sshnp now immediately drops into a prompt for clients that don't
  support sshnp.canRunShell(). `-x` flag allows the ssh command to be output
  instead of executing ssh immediately.
- Renamed everything sshrvd and sshrv to srvd and srv respectively

# 5.0.4

- refactor: move the `findLocalPortIfRequired` function to `EphemeralPortBinder`, a mixin on `SshnpCore`
- fix: call `callFindLocalPortIfRequired` during the initialization of the unsigned sshnp client

# 5.0.3
- feat: Add `--storage-path` option to sshnpd to allow users to specify where
  it keeps any locally stored data

# 5.0.2

- fix: Add more supported ssh public key types to the send ssh public key filters for sshnpd.

# 5.0.1

- fix: Add more supported ssh public key types to the send ssh public key filters for sshnp.

# 5.0.0

- **BREAKING CHANGE** fix: changed `list-devices` arg from String option to boolean flag.

# 4.0.1

- fix(Pure Dart SSH client): send a keep alive to the server to prevent SSHAuthAbortError

# 4.0.0

- Initial release
