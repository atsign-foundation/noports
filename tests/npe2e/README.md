# npe2e

End-to-end tests for NoPorts. The harness compiles the current binaries, builds
daemon Docker images (Dart and C, `current` plus a few released versions),
enrols APKAM keys for the client and daemon atSigns, starts each daemon in its
own container, then runs the client (`npt` / `sshnp`) on the host against those
containerised daemons through a relay (`srvd`).

In CI these run against the public atDirectory (`root.atsign.org`). This README
covers running them **locally against a local atStack** — the usual reason being
to test an atServer that has not been released to production yet.

There are three test packs, each with its own entrypoint under `bin/`:

| Pack | Entrypoint |
| --- | --- |
| core | `bin/core_tests.dart` |
| relay | `bin/relay_tests.dart` |
| policy | `bin/policy_tests.dart` |

The examples below use the core pack; the others take the same arguments.

## Prerequisites

- Docker (Docker Desktop on macOS).
- The Dart SDK.
- `expect`, `ssh-keygen`, `git`, `chmod`, `sh` on `PATH` (the harness checks
  these on startup).
- Run `melos bootstrap` from the repo root at least once. The harness compiles
  `current` binaries directly via `dart compile exe`; it does not run
  `dart pub get` for you, so without bootstrapping first, package resolution
  fails.

## Running against a local atStack

### 1. Point the test domain at your machine

Add the domain your local atStack uses to `/etc/hosts`, mapped to loopback:

```
127.0.0.1 vip.ve.atsign.zone
```

Your host processes now resolve `vip.ve.atsign.zone` to your local atStack. The
containerised daemons are handled separately — see step 4.

### 2. Start your local atStack

Bring up your atDirectory and the atServers for the client, daemon and relay
atSigns, all on the domain from step 1. The atDirectory must listen on port 64,
and the atServers and atDirectory must bind `0.0.0.0` (not `127.0.0.1` only), or
the containers won't be able to reach them (see step 4).

### 3. The Docker build context (`.dockerignore`)

The daemon images build with the repo root as their context. The repo-root
`.dockerignore` keeps `melos`-managed `pubspec_overrides.yaml` files out of that
context: those pin dependencies to host-absolute paths that don't exist inside
the container, so without this the in-container `dart pub get` fails. The file
is committed and is a no-op on a clean CI checkout (the overrides are
gitignored), so there's nothing to do here — just don't delete it.

### 4. Container-to-host networking (automatic)

A container can't inherit your `/etc/hosts`, and `127.0.0.1` inside a container
is the container itself, not your host. So the harness reads your `/etc/hosts`
and, for every `127.0.0.1 *.atsign.zone` entry, injects
`--add-host <name>:host-gateway` into each daemon container. `host-gateway` is
Docker's route back to the host, so the containerised daemons resolve the test
domains to your machine. This is automatic; there are no flags for it. It is
scoped to `*.atsign.zone` names, so unrelated `/etc/hosts` entries and
deliberate black-holes such as `127.1.1.1 unreachable.atsign.zone` are left
alone.

### 5. Start the relay (`srvd`)

The tests need a rendezvous relay running as the relay atSign. Two things
matter for a local run:

- **Advertise a host-resolvable name.** Use `-i vip.ve.atsign.zone`, not
  `-i 127.0.0.1`. `srvd` binds its rendezvous ports to `0.0.0.0` and only
  *advertises* the `-i` value to clients, so the name just has to resolve to
  your host on both sides — the host client resolves it via `/etc/hosts`, the
  container daemon resolves it via the injected `--add-host` from step 4. With
  `-i 127.0.0.1` the container would dial its own loopback and time out.
- **Drop `--443` for local runs.** It needs a privileged port (so `sudo`), and
  the packs don't require it.

```
srvd -a @relay -i vip.ve.atsign.zone -v --root-domain vip.ve.atsign.zone
```

Wait for `monitor started` in its output before running the pack.

### 6. Run the pack

```
dart run tests/npe2e/bin/core_tests.dart \
  --client-atsign @client \
  --daemon-atsign @service \
  --relay-atsign @relay \
  --root-domain vip.ve.atsign.zone \
  --base-directory npe2e_core_tests \
  --batch-size 5
```

## Re-running on the same commit

`--test-run-id` defaults to the short git commit hash, so re-runs on the same
commit reuse `<base-directory>/<testRunId>/` and the daemon container names
(which embed the testRunId). Two bits of state carry over between runs on the
same commit:

- `at_activate enroll` fails if the APKAM keys already exist in the run
  directory, so delete it:

  ```
  rm -rf npe2e_core_tests/<testRunId>
  ```

- the daemon containers aren't removed when the harness exits, so the next run
  hits a `container name ... already in use` conflict. Remove them first:

  ```
  docker rm -f $(docker ps -aq --filter name=npe2e) 2>/dev/null
  ```

Either clear both, or pass a fresh `--test-run-id`.

## Arguments

| Argument | Default | Notes |
| --- | --- | --- |
| `--client-atsign` | (required) | Client atSign used in tests |
| `--daemon-atsign` | (required) | Daemon atSign used in tests |
| `--relay-atsign` | (required) | Relay atSign used in tests |
| `--root-domain` | `root.atsign.org:64` | atDirectory host:port; set to your local domain |
| `--base-directory` | `npe2e_core_tests` | Where run artefacts (binaries, keys, logs) are written |
| `--client-versions` | `d:v5.9.4,d:v5.11.2,d:v5.13.0,d:current` | Comma-separated `language:version` |
| `--daemon-versions` | `d:v5.9.4,d:v5.11.2,d:v5.13.0,d:current,c:current` | Comma-separated `language:version` |
| `--batch-size` | `4` | Tests run concurrently per batch |
| `--max-retries` | `3` | Retries for a failing test |
| `--test-timeout-seconds` | `300` | Per-test timeout before fail/retry |
| `--test-run-id` | short git hash | Overrides the run directory name |
| `--verbose` | `false` | Unmutes the at_client SDK logger (`AtSignLogger` at `INFO` instead of `SEVERE`). Stage narration and failure detail are always on. Currently wired for `policy_tests` only. |

## Reading a failed policy_tests run

Start at the bottom of stdout. Each failed test prints a block naming the stage
it died at, what it expected, the command to reproduce it, and the logs to read:

```
Failed Tests:
  ✗ npp_test (client: d:current, daemon: d:current, policy: d:current)
      tag:        9a67193a_npp_dc_dc
      stage:      03_allowed
      reason:     npt did not behave as expected on any of 3 attempts: expected
                  exit 0 for --remote-port 22, last exit was 1
      detail:     attempt 1/3: exit 1 in 3210ms → unexpected
                  attempt 2/3: exit 124 (TIMED OUT) in 45002ms → unexpected
                  attempt 3/3: exit 1 in 2980ms → unexpected
      reproduce:  .../npt -f @client -t @daemon -d 9a67193a_npp_dc_dc ...
      logs:       .../logs/npp_test/clients/..._03_allowed_npt_stdout.log
                  .../logs/npp_test/daemons/..._03_allowed_stdout.log
      transcript: .../logs/npe2e_policy_transcript.log
```

**The transcript** — `<base-directory>/<testRunId>/logs/npe2e_policy_transcript.log`
— is the harness's own narration: every stage it entered, every policy rule it
wrote, the observed `permitOpen` set after each write, every npt command and
attempt outcome. It is written to disk as well as stdout because CI archives only
the logs directory; stdout is not in the uploaded artifact. It is truncated at the
start of each run.

**The tag** (`9a67193a_npp_dc_dc`) is the device name, and it is also embedded in
the daemon container name and in the per-stage log filenames. Every transcript
line carries one, which is how you attribute interleaved output when
`--batch-size` is greater than 1:

```
grep 9a67193a_npp_dc_dc npe2e_policy_tests/<testRunId>/logs/npe2e_policy_transcript.log
```

Log layout under `<base-directory>/<testRunId>/logs/`:

| Path | Contents |
| --- | --- |
| `npe2e_policy_transcript.log` | Harness narration for the whole run, tagged per test |
| `daemons/`, `npp/`, `npp_atserver/` | Full-lifetime container logs, one pair per container |
| `<testName>/clients/` | npt stdout/stderr, one pair per stage attempt |
| `<testName>/daemons/`, `<testName>/policies/` | Container log slices covering a single stage attempt |

Notes when interpreting a failure:

- `exit 124` means npt was killed after 45s without exiting. That is always a
  failure, never a policy denial, even at a stage that expects npt to fail.
- `stage: test timeout` means the harness gave up from the outside after
  `--test-timeout-seconds` × `--max-retries`, so there is no stage-level detail —
  read the transcript for the last step reached. A timed-out attempt is not
  cancelled, so its containers may still have been running when the retry began.
- A `WARN` line from `teardown:` means rules or a container were left behind, which
  is the usual cause of the *next* test failing its `after initial teardown` check.

## Troubleshooting

- **`error from sender: lstat ... permission denied` during an image build.** A
  path in the repo has no read/traverse permission and is leaking into the build
  context. The `.dockerignore` trims the context to source; make sure any scratch
  in your working tree is readable (a directory needs its execute bit to be
  traversed).
- **`Unable to authenticate ... Connection refused ... :64` in a daemon log.**
  The container can't reach your atDirectory. Check the `/etc/hosts` entry is a
  `*.atsign.zone` name, that your atDirectory is up on port 64, and that it binds
  `0.0.0.0` rather than `127.0.0.1` only.
- **`Connection timeout to srvd @relay service`.** `srvd` isn't running or isn't
  reachable from the containers. Confirm it's up and started with
  `-i vip.ve.atsign.zone` (not `-i 127.0.0.1`).
- **`Failed to compile current binary for at_activate: ... Couldn't resolve the
  package 'at_onboarding_cli'`.** `dart pub get` hasn't been run for
  `packages/dart/sshnoports` (no `.dart_tool/package_config.json`). Run
  `melos bootstrap` from the repo root.
