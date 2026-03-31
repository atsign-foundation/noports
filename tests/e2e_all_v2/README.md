# e2e_all_v2

## Usage

```bash
dart run bin/main.dart \
    --client-atsign "@npe2e_client" \
    --daemon-atsign "@npe2e_daemon" \
    --relay-atsign "@npe2e_relay" \
    --policy-atsign "@npe2e_policy" \
    --events-atsign "@npe2e_events" \
    --root-domain "root.atsign.wtf:64" \
    --log-directory "logs"

docker stop $(docker ps -q) && dart run tests/e2e_all_v2/bin/main.dart \
    --client-atsign "@client_jttest" \
    --daemon-atsign "@device_jttest" \
    --relay-atsign "@rv_am" \
    --policy-atsign "@policy_jttest" \
    --events-atsign "@events_jttest" \
    --log-directory "logs"
```

notes:
- --root-domain|--root-server

## Requirements

- I should be able to run `dart test` on a single test
- Let `dart test --concurrency=1` be able to decide how it runs in parallel
- Versions are determined in the test itself.
- Assumed that host machine is running Docker and has a file system

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

## List of Tests

### 001_minus_s_flag

1. Generates a new ssh key
2.
    a. Run sshnp against a daemon without the `-s` flag with that new key
    b. Verify it fails
3.
    a. Run against a daemon with the `-s` flag
    b. Verify it succeeds

- Client: Dart (current) | Daemon: Dart (current)
- Client: Dart (current) | Daemon: C (current)
- Client: Dart (current) | Daemon: Dart v5.9.4
- Client: Dart (current) | Daemon: Dart v5.11.2
- Client: Dart (current) | Daemon: Dart v5.13.0

### minus_r_flag

1. Run sshnp with `--host` (expect to pass)
2. Run sshnp with `-h` invalid and `-r` valid (expect to pass)
3. Run sshnp with `-h` valid and `-r` invalid (expect to fail)

- Client: Dart (current) | Daemon: Dart (current)
- Client: Dart v5.9.4 | Daemon: Dart (current)
- Client: Dart v5.11.2 | Daemon: Dart (current)
- Client: Dart v5.13.0 | Daemon: Dart (current)
- Client: Dart (current) | Daemon: Dart v5.9.4
- Client: Dart (current) | Daemon: Dart v5.11.2
- Client: Dart (current) | Daemon: Dart v5.13.0

### minus_u_flag

1. Run sshnp without `-u <username>` talking to device daemon which does not have `-u` flag enabled (expect to fail)
2. Run sshnp without `-u <username>` talking to device daemon which does have `-u` flag enabled (expect to pass)

- Client: Dart (current) | Daemon: Dart (current)

### npt_to_port_22

1. Run npt to device daemon on port 22, then use ssh (expect to pass)

- Client: Dart (current) | Daemon: Dart (current)
- Client: Dart v5.9.4 | Daemon: Dart (current)
- Client: Dart v5.11.2 | Daemon: Dart (current)
- Client: Dart v5.13.0 | Daemon: Dart (current)
- Client: Dart (current) | Daemon: C (current)
- Client: Dart v5.9.4 | Daemon: C (current)
- Client: Dart v5.11.2 | Daemon: C (current)
- Client: Dart v5.13.0 | Daemon: C (current)
- Client: Dart (current) | Daemon: Dart v5.9.4
- Client: Dart (current) | Daemon: Dart v5.11.2
- Client: Dart (current) | Daemon: Dart v5.13.0

### npt_to_port_22_no_encrypt_traffic

1. Run npt with `--no-encrypt-rvd-traffic` then ssh (expect to pass)

- Client: Dart (current) | Daemon: Dart (current)

### v4_dart_inline

v4 protocol lacks advanced features; does not support:
- device authentication to relay
- end-to-end traffic encryption
- daemon feature detection/ping
- when a v5 cleint needs to talk to v4 daemon, client must `--no-ad` (disable device auth to rvd) `--no-et` (disable end-to-end encryption)

1. Configuration:
    a. SSH client: dart (client `--ssh-client dart|openssh`)
    b. Protocol version: v4
    c. Connection mode: inline

- Client: Dart (current) | Daemon: Dart (current)
- Client: Dart v5.9.4 | Daemon: Dart (current)
- Client: Dart v5.11.2 | Daemon: Dart (current)
- Client: Dart v5.13.0 | Daemon: Dart (current)
- Client: Dart (current) | Daemon: Dart v5.9.4
- Client: Dart (current) | Daemon: Dart v5.11.2
- Client: Dart (current) | Daemon: Dart v5.13.0

### v4_openssh_print

1. Configuration:
    a. SSH Client: OpenSSH `--ssh-client openssh`
    b. Protocol Version: v4
    c. Connection Mode: print `-x`

- Client: Dart (current) | Daemon: Dart (current)
- Client: Dart v5.9.4 | Daemon: Dart (current)
- Client: Dart v5.11.2 | Daemon: Dart (current)
- Client: Dart v5.13.0 | Daemon: Dart (current)
- Client: Dart (current) | Daemon: Dart v5.9.4
- Client: Dart (current) | Daemon: Dart v5.11.2
- Client: Dart (current) | Daemon: Dart v5.13.0

### v5_dart_inline

1. Configuration:
    a. SSH Client: Dart `--ssh-client dart`
    b. Protocol Version: v5
    c. Connection mode: inline

- Client: Dart (current) | Daemon: Dart (current)
- Client: Dart v5.9.4 | Daemon: Dart (current)
- Client: Dart v5.11.2 | Daemon: Dart (current)
- Client: Dart v5.13.0 | Daemon: Dart (current)
- Client: Dart (current) | Daemon: C (current)
- Client: Dart v5.9.4 | Daemon: C (current)
- Client: Dart v5.11.2 | Daemon: C (current)
- Client: Dart v5.13.0 | Daemon: C (current)
- Client: Dart (current) | Daemon: Dart v5.9.4
- Client: Dart (current) | Daemon: Dart v5.11.2
- Client: Dart (current) | Daemon: Dart v5.13.0

### v5_openssh_inline

Configuration:
    a. SSH Client: `--ssh-client openssh`
    b. Protocol Version: v5
    c. Connection mode: `inline`

- Client: Dart (current) | Daemon: Dart (current)
- Client: Dart v5.9.4 | Daemon: Dart (current)
- Client: Dart v5.11.2 | Daemon: Dart (current)
- Client: Dart v5.13.0 | Daemon: Dart (current)
- Client: Dart (current) | Daemon: C (current)
- Client: Dart v5.9.4 | Daemon: C (current)
- Client: Dart v5.11.2 | Daemon: C (current)
- Client: Dart v5.13.0 | Daemon: C (current)
- Client: Dart (current) | Daemon: Dart v5.9.4
- Client: Dart (current) | Daemon: Dart v5.11.2
- Client: Dart (current) | Daemon: Dart v5.13.0

### v5_openssh_print

Configuration:
    a. SSH Client: `--ssh-cleint openssh`
    b. Protocol version: v5
    c. Connection mode: print `-x`

- Client: Dart (current) | Daemon: Dart (current)
- Client: Dart v5.9.4 | Daemon: Dart (current)
- Client: Dart v5.11.2 | Daemon: Dart (current)
- Client: Dart v5.13.0 | Daemon: Dart (current)
- Client: Dart (current) | Daemon: C (current)
- Client: Dart v5.9.4 | Daemon: C (current)
- Client: Dart v5.11.2 | Daemon: C (current)
- Client: Dart v5.13.0 | Daemon: C (current)
- Client: Dart (current) | Daemon: Dart v5.9.4
- Client: Dart (current) | Daemon: Dart v5.11.2
- Client: Dart (current) | Daemon: Dart v5.13.0
