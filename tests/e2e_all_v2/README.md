# e2e_all_v2

## Usage

```bash
dart run bin/main.dart \
    --client-atsign "@npe2e_client" \
    --daemon-atsign "@npe2e_daemon" \
    --relay-atsign "@npe2e_relay" \
    --policy-atsign "@npe2e_policy" \
    --events-atsign "@npe2e_events" \
    --root-domain "root.atsign.wtf:64"

dart run bin/main.dart \
    --client-atsign "@client_jttest" \
    --daemon-atsign "@device_jttest" \
    --relay-atsign "@rv_am" \
    --policy-atsign "@policy_jttest" \
    --events-atsign "@events_jttest" \
```

notes:
- --root-domain|--root-server

## Requirements

- I should be able to run `dart test` on a single test
- Let `dart test --concurrency=1` be able to decide how it runs in parallel
- Versions are determined in the test itself.

## Happy Path

1. Developer runs `dart run bin/main.dart`
2. Tear down (if old existing session running)
3. Set up
  a. Build and start up necessary Docker containers (client, daemons, policy, events)
  b. Check docker readiness
4. Execute tests
  a. Execute commands in container
  b. Validate logs in container
5. Tear down

Modules:
- buildOrPullDockerContainer
- executeInContainer

## Notes

- Goal here is to explicitly define each individual tests. As it is, we define a list of versions
- and if we want to do something specifically (such as add policy, relay, events into our tests),
- that is difficult with the way the harness works in e2e_all.

## Next steps if i have time

Runs a web app on localhost, allows me to enter input parameters (auto detects keys), then 
I get a good overview of the things happening

- Docker images being pulled, built, in parallel
- What tests are being ran
- Dropdowns of each test and their logs
- Management of existing binaries, docker images, and caches that I can clear
- View logs of previous test runs

```bash
dart run bin/web.dart
```
