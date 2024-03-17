# End-to-end tests, iteration 2[^1]

## Goals

- Easy to run locally
- Easy to run from GitHub actions
- Easy to configure matrix of daemons and clients
- Support individual tests asserting what their version requirements are
- Easy to run one test, several tests, or all tests

## To run

  ```
  # Show usage, all flags and options
  tests/e2e_all/scripts/main.sh

  # Dry run to verify that the test rig machinery works
  tests/e2e_all/scripts/main.sh @foo @bar @baz -t noop

  # Run all tests, prod atSigns
  tests/e2e_all/scripts/main.sh @clientAtSign @daemonAtSign @srvdAtSign

  # Run all tests, with local atDirectory and atServers
  tests/e2e_all/scripts/main.sh @alice @bob @chuck -r vip.ve.atsign.zone
    -w 3
```

## How it works

Note: All script names are relative
to `/path/to/repoRoot/tests/e2e_all/scripts/`

- Parses args
- Runs `common/setup_binaries.sh` which iterates though $daemonVersions and
  $clientVersions and for each one
    - If version is not 'current' (i.e. the current git branch) and not already
      downloaded, downloads from the appropriate NoPorts repo release assets to
      `/path/to/repoRoot/tests/e2e_all/releases`
    - If version is 'current', builds binaries for the current branch in
      `/path/to/repoRoot/tests/e2e_all/runtime/`
        - If the '-n' flag is set then binaries will not be rebuilt (but will be
          built if they are not present)
- Runs `common/start_daemons.sh` which iterates through $daemonVersions and,
  for each one
    - Sets the deviceName - for example
        - for daemon version `d:4.0.5` the deviceName for the daemon without
          the `-s -u` flags will be `${shortCommitId}d405` and for the
          daemon with those flags will be `${shortCommitId}d405`
        - for daemon version `d:current` the deviceNames will be
          `${shortCommitId}dc` and `${shortCommitId}dcf` respectively.
    - Runs the daemon
      with `-a @daemonAtSign -m @clientAtSign -d {$deviceName} -v`
- Generates an ssh keypair for use during the tests
    - All tests other than `tests/minus_s_flag` use that keypair, and
      use the device names with 'f' suffixed
    - `tests/minus_s_flag` tests the current branch's client and daemon to
      ensure that the `-s` flag works. As part of doing this, it generates
      another new keypair
- Runs `common/run_tests.sh` which
    - iterates through each combination of test script, daemon version and
      client version and
        - runs that test script for that daemon version and client version
        - checks exit status == zero AND 'TEST PASSED' appears in the test
          script's output
    - logs progress as it goes
    - outputs a summary report at the end
- Runs `common/stop_daemons.sh`
- Runs `common/cleanup_tmp_files.sh`
    - the `/tmp/e2e_all/${shortCommitId}` directory is removed. (All daemon,
      client and test script output files were written to there.)

## How the GitHub workflow works

- The workflow file is `/path/to/repoRoot/.github/workflows/e2e_all.yaml`
- It gets the appropriate commitId and places it in $SHA
- ssh's to the CICD host (using repo secrets `NOPORTS_CICD_HOST` and
  `NOPORTS_CICD_SSH_KEY`) and runs
    ```
    cd noports

    echo "Running git fetch"
    git fetch

    echo "Running git checkout -f $SHA"
    git checkout -f "$SHA"

    echo "Running tests"
    tests/e2e_all/scripts/main.sh @atSign1 @atSign2 @rv_am
    ```
- Note: `checkout -f` is used because before binaries are compiled, the
  script executes `dart pub get` which frequently will update the
  pubspec.lock file and so the next time the job runs we want to just discard
  that change - therefore, we force checkout.
- Requirements for the CICD host
    1. git is installed
    2. dart / flutter sdk is installed
    3. Clone of this repo is at ~/noports
    4. noports and noports.pub files in ~/.ssh directory
    5. noports.pub is in the ~/.ssh/authorized_keys file
    6. atKeys files for `@atSign1` and `@atSign2` are in ~/.atsign/keys

## TODOs

- TODO: Add section to this doc showing how to run local atServers

[^1]: Shout-out and endless thanks to @JeremyTubongbanua who built the first
iteration of the NoPorts e2e test rig
