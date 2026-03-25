# e2e_all_v2

## Usage

```bash
dart run bin/main.dart \
    --client-atsign "@npe2e_client" \
    --daemon-atsign "@npe2e_daemon" \
    --relay-atsign "@npe2e_relay" \
    --relay-latest-atsign "@npe2e_relay_latest" \
    --policy-atsign "@npe2e_policy" \
    --policy-latest-atsign "@npe2e_policy_latest" \
    --events-atsign "@npe2e_events" \
    --root-domain "root.atsign.wtf:64"
```

notes:
- --root-domain|--root-server

## Requirements

- I should be able to run `dart test` on a single test
- Let `dart test --concurrency=1` be able to decide how it runs in parallel
- Versions are determined in the test itself.

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
