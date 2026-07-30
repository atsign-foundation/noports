# core_tests

## Usage

```bash
docker stop $(docker ps -q) 2>/dev/null
rm -rf npe2e_core/
dart run tests/npe2e/bin/core_tests.dart \
    --client-atsign "@client_jttest" \
    --daemon-atsign "@device_jttest" \
    --relay-atsign "@rv_am" \
    --base-directory "npe2e_core" \
    --root-domain "root.atsign.org" \
    --batch-size 3
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

`-r`/`--host`/`-h` precedence is a client-side-only feature, so (matching the
legacy e2e_all `minus_r_flag` test) this runs the FULL cross-product of every
Dart client (>= v5.2.0) against every Dart daemon. C daemons are skipped. With
the default versions:

- Client: Dart {current, v5.9.4, v5.11.2, v5.13.0}
  x Daemon: Dart {current, v5.9.4, v5.11.2, v5.13.0}

### minus_u_flag

1. Run sshnp without `-u <username>` talking to device daemon which does
   not have `-u` flag enabled (expect to fail)
2. Run sshnp without `-u <username>` talking to device daemon which does
   have `-u` flag enabled (expect to pass)

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
- when a v5 cleint needs to talk to v4 daemon, client must use `--no-ad`
  (disable device auth to rvd) and `--no-et` (disable end-to-end encryption)

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

## General Form of a Test

### Runner function

There's a core function called "run____Tests" that runs the group of tests
given:

```dart
List<Future<CoreTestResult>> run____Tests({
  // contains values like clientAtsign and daemonAtsign
  required final CoreTestsContext context,
  // list of client versions to run against
  required final List<NoPortsVersion> clientVersions,
  // list of daemon versions to run against
  required final List<NoPortsVersion> daemonVersions,
}) {
    // ...
}
```

This function returns `List<Future<CoreTestResult>>`, which is a list of
started tests that can be awaited using
`await Future.wait(run____Tests(...))`. This way, the caller has control and
flexibility over how to run the tests, in parallel, sequentially, etc.

### Test logger

Typically in this function, there's a `CoreTestLogger`.

The CoreTestLogger describes how to log the results of the test.

```dart
final CoreTestLogger testLogger = CoreTestLogger(
  // creates `clients/` and `daemons/` directories here
  logsDirectory: context.logsDirectory,
  testName: testName,
);
```

This testLogger will create a directory structure within
`context.logsDirectory` like this:

```text
logsDirectory/
    testName/
        clients/
            clientVersion1.log
            clientVersion2.log
            ...
        daemons/
            daemonVersion1.log
            daemonVersion2.log
            ...
```

### Version permutations

In the `run___Tests` function, there will be a private
`_generateVersionPermutations` that takes `clientVersions` and
`daemonVersions`, then creates related version permutations.

E.g.

```text
clientVersions: [current, v5.9.4, v5.11.2, v5.13.0]
daemonVersions: [current, v5.9.4, v5.11.2]
```

```dart
List<(NoPortsVersion, NoPortsVersion)> _generateVersionCombinations({
  required final List<NoPortsVersion> clientVersions,
  required final List<NoPortsVersion> daemonVersions,
}) {
  List<(NoPortsVersion, NoPortsVersion)> combinations = [];
  for(final clientVersion in clientVersions) {
    for(final daemonVersion in daemonVersions) {
      final bool isClientCurrent = clientVersion.version == 'current';
      final bool isDaemonCurrent = daemonVersion.version == 'current';
      // we only want to test against current clients/daemons
      if(!isClientCurrent && !isDaemonCurrent) {
        continue;
      }
      // this test requires the `-s` flag, which was added in v5.3.0
      if(versionIsAtLeast(
        clientVersion,
        NoPortsVersion(language: Language.dart, version: 'v5.3.0'),
      )) {
      }
      combinations.add((clientVersion, daemonVersion));
    }
  }
  return combinations;
}
```

Generates:

```text
(current, current)
(current, v5.9.4)
(current, v5.11.2)
(current, v5.13.0)
(v5.9.4, current)
(v5.11.2, current)
(v5.13.0, current)
```

### Common helpers

Commonly used functions and classes:

- `ProcessOutputCapture` and `startCommandWithCapture` -> starts a
  command and captures its output; output used in `printAllLogs`
- `LogFragment` and `dockerInstance.createLogFragment` -> captures logs of a
  Docker instance; output used in `printAllLogs`
- `getDeviceNameNoFlags` -> gets the device name for a given daemon version.
  Append this with `_f` to get the docker daemon with `-s -u` flags.

- `printTestStart` -> used at the beginning of `_run____Test` to print test start
- `printTestResult` -> for printing the result of a test in fail or pass
- `printAllLogs` -> print ProcessOutputCapture and LogFragment (typically client/daemon)

### Argument builders

If it's related to the test, we have `_buildNptArgs` or `_buildSshnpArgs` to
build a base set of `List<String> args` that will be used in functions.
