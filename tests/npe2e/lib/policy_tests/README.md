# policy_tests

## Usage

```bash
dart run tests/npe2e/bin/policy_tests.dart \
    --client-atsign "@client_jttest" \
    --daemon-atsign "@device_jttest" \
    --relay-atsign "@rv_am" \
    --npp-atsign "@policy01_jttest" \
    --npp-atserver-atsign "@policy02_jttest" \
    --root-domain "root.atsign.org" \
    --base-directory "npe2e_policy" \
    --batch-size 2
```

## Diagnosing failures

On failure, the "Failed Tests:" summary at the end of the run prints a
`Reason:` line and `See:` pointers to the on-disk log files (docker
container logs, `npt` client stdout/stderr) relevant to that failure — no
need to guess file names under `<base-directory>/<test-run-id>/logs/`.

Pass `--verbose`/`-v` to also:

- raise `AtSignLogger`'s level from `SEVERE` to `INFO`, surfacing internal
  `NppClient`/`PolicyServiceWithAtClient`/onboarding SDK log output, and
- print full client/daemon/policy logs for every failed `npt` connection
  attempt, not just the last one before a test is marked failed.

## General Test Flow

0. Set up actors
   0a. Run `npp_atserver|npp -a <policy_atsign> -v`
   0b. Run `sshnpd -a <atsign> -p <policy_atsign> --permit-open "localhost:22"`
   0c. Tear down `npp_atserver|npp` rules

1. try a session with no rules in place for the client - verify denied
   1a. Run `npt`
   1b. Verify fail

2. try a session with rules in place for the client but not for the required
   port - verify denied
   2a. Place policy rules for @client, but for localhost:222
   2b. Run `npt --rp 22`
   2c. Verify failed because permitOpen is localhost:22 and the policy rule
       is for localhost:222 (wrong port)

3. try a session with rules in place for the client which cover the required
   port - verify permitted
   3a. Place policy rules for @client, but for localhost:22
   3b. Run `npt --rp 22`
   3c. Verify success because policy allows localhost:22 for @client, and
       sshnpd has permit open localhost:22

4. try a session where allowed by policy but restricted by daemon's permitOpen
   - verify denied
   4a. Place policy rules for @client, but for localhost:2233
   4b. Run `npt --rp 2233`
   4c. Verify fail because the policy rules are localhost:22, localhost:222,
       and lolcahost:2233, but permitOpen is only localhost:22 on sshnpd

5. Tear down `npp_atserver|npp` rules

regarding 2a, 3a, and 4a:

- depending on if we're running `npp_atserver` or `npp`, there is a different
  way of putting policy rules in place.
