# revocation_tests

Checks that revoking a client's enrollment ends the sessions it signed, and
only those.

The pack enrolls a device of the client atSign for each test, starts its own
daemon containers and its own `srvd` (both checking signing keys every 3
seconds), and revokes the enrollment with `at_activate revoke` while a session
is open.

## Test coverage

For each daemon version (`d:current` and `c:current` by default):

1. **The daemon ends a revoked client's session.** Two tunnels are opened to
   the same daemon with payload relay auth, so `srvd` does not watch them: one
   with the enrollment to be revoked, one with another enrollment. Each holds
   an ssh connection open. After the revocation, the revoked enrollment's
   held connection must close and its tunnel stop reaching sshd within
   `--withdrawn-within-seconds` (default 45). The daemon must log
   `has been withdrawn to r.__e`, and the other tunnel must still reach sshd.
2. **An unsigned request is refused under `--require-enrollment-signature`.**
   A released client that doesn't sign its requests
   (`--unsigned-client-version`, default `d:v5.17.0`) is refused, and npt
   prints the daemon's reason. The current client, which signs, is accepted.

And once:

3. **srvd ends a revoked client's ESCR session.** The same two tunnels, with
   ESCR relay auth, to a daemon whose own check is off
   (`--client-key-check-secs 0`), so `srvd` must be what ends the session and
   logs `has been withdrawn to r.__e`.

## Running locally

On an ephemeral environment (EE), with atSigns of the run's own:

```bash
echo '127.0.0.1 vip.ve.atsign.zone' | sudo tee -a /etc/hosts   # once
tests/tools/ee/setup_ee.sh ee_rev rvc_mine rvd_mine rvr_mine
dart run tests/npe2e/bin/revocation_tests.dart \
    --client-atsign @rvc_mine \
    --daemon-atsign @rvd_mine \
    --relay-atsign @rvr_mine \
    --root-domain vip.ve.atsign.zone:2500
tests/tools/ee/teardown_ee.sh ee_rev rvc_mine rvd_mine rvr_mine
```

`setup_ee.sh` takes its base port from `BASE_PORT` (2500 when unset), so to
run beside other rigs, lease one:
`~/.claude/bin/portlease run -- tests/tools/ee/setup_ee.sh ...`, then pass
`--root-domain vip.ve.atsign.zone:<base>`. It refuses a container name,
keyfile or port that is already taken rather than clearing it.

On the virtual environment (VE), after `tests/tools/ve/setup_ve.sh`, use
three of its demo atSigns and `--root-domain vip.ve.atsign.zone`. The client
atSign's keys must be able to enroll and revoke devices.

Run from the repo root, after `melos bootstrap`. The run's directory is
`npe2e_revocation_tests/<test-run-id>/`; its
`logs/npe2e_revocation_transcript.log` says what each test did and why it
passed or failed.

## CI

The `npe2e (revocation_tests)` job in `.github/workflows/e2e_all.yaml` starts
an EE (`atsigncompany/ephemeral:dev_env`) with fresh atSigns on every run, so
it needs no secrets and revokes nothing shared.
