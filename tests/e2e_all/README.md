# End-to-end test matrix

## Goals

- Easily run locally
- Rebuild only when necessary
- Easily run from GitHub actions

## Approach

- Run daemons (latest release aka LR, branch) on cicd VM
- Run branch's socket rendezvous on cicd VM
- Test
    - not testing legacy daemon
    - LR cli clients (openssh and dart) VS both daemons VS both SR, LR features
      only
    - branch's cli clients (openssh and dart) VS both daemons VS both SR, LR
      features only
    - branch's cli clients (openssh and dart) VS branch daemons VS branch SR,
      all features

## NoPorts Daemons

- Versions: 3_2_0, 4_0_4, git_$BRANCH (BRANCH=`git rev-parse --short HEAD`)
- Pull existing release binaries from the release downloads if not already
  present
- $VERSION WITH "-u" and "-s" flags, set DEVICE = npe2e_${VERSION}_with_flags
- $VERSION WITHOUT "-u" and "-s" flags, set DEVICE = npe2e_${VERSION}_no_flags

## Running the daemons (npd and rvd)

- Set up
    - Ensure $HOME/np_e2e_test/$VERSION exist for each version
    - If not downloaded, download released binaries which we want to test into
      $VERSION/bin
    - on cicd VM, switch git branch to $BRANCH, and git pull
    - stop npe2e_$BRANCH_with_flags and _no_flags if they are running
    - Build all binaries from local branch, put into git_$BRANCH/bin
- Start the daemons
    - go through the directories
    - check if npe2e_${VERSION} is running if version is not 'branch'
    - if not running
        - start npe2e_${VERSION}_with_flags if it is not running
        - start npe2e_${VERSION}_no_flags if it is not running
    - start npe2e_$BRANCH_with_flags and _no_flags
- Start the branch SR
    - stop existing process sshrvd_$BRANCH if it is running
    - build the sshrvd binary as sshrvd_$BRANCH
    - start sshrvd_$BRANCH -a @rvd --ip hostname -v

## Daemon scripts
- set up to build branch binaries - CICD VM ONLY
    - git checkout $BRANCH, git pull
- Create dirs (both local and cicd vm)
- Download released binaries (both) - need to specify platform
  - For our purposes we only care about linux-x64 for cicd vm, and 
    macos-arm64 or windows-x64 for laptops
  - Download to $HOME/np_e2e_test/$VERSION/bin
    from https://github.com/atsign-foundation/noports/releases/download/v$version/sshnp-$platform.zip
- Stop $BRANCH daemon and SR (both)
- dart pub get in packages/dart/sshnoports (both)
- build BRANCH binaries (both)
  - compile into $HOME/np_e2e_test/$VERSION/bin
- Start older daemons if not running (both)
- Start branch daemon (both)
- Start branch SR (both)

All of the above can be wrapped into a single script with a flag for "are we 
cicd or not"

Let's make it two scripts, one of which NEVER CHANGES so that a git pull 
doesn't bork it, and is just a wrapper for the second one

## Running the tests (i.e. the clients)
- Run the set-up scripts
  - GitHub action - ssh to cicd vm and run the script for $BRANCH 
  - Local - just run the script for $BRANCH
- Run all the client tests sequentially from a single file, echo the 
  pass/fail status to output file
- When complete, cat the output file
- Tests fail if there is any failure in the output file or if the output
  file length is shorter or longer than expected
