#!/bin/bash

# This script is for running e2e tests locally (e.g. development host), and will
# - Set up binaries
# - Start all required daemons
# - Run all required client tests
# - Stop daemons
# - Report test outcomes
#
# By contrast, the e2e tests from github action will
# - Set up binaries on the 'daemon' host
#   - Start all required daemons on the 'daemon' host
# - Set up binaries on the 'client' host
#   - Run all required client tests on the 'client' host
# - Stop daemons on the 'daemon' host
# - Report test outcomes

function usageAndExit {
  echo "Usage:"
  echo "  $scriptName @client_atsign @daemon_atsign @socket_rendezvous_atsign \\"
  echo "     [-r <atDirectory (aka root) host>] \\"
  echo "     [-t <space-separated list of test scripts to run from the e2e_all/scripts/tests/ subdirectory>] \\"
  echo "     [-s <daemon versions>] - defaults to $defaultDaemonVersions\\"
  echo "     [-c <client versions>] - defaults to $defaultClientVersions \\"
  echo "     [-u <remote username>] - defaults to the local username \\"
  echo "     [-w <daemon start wait time> - how long to wait for daemons to start up - defaults to 30 seconds] \\"
  echo "     [-n (Do not recompile binaries for current commit. Default is to always recompile.)]"
  echo ""
  echo "Notes:"
  echo "  <atDirectory host> defaults to root.atsign.org"
  echo "  If test script names are not supplied then all tests in e2e_all/scripts/tests will be executed"
  echo "  For a quick sanity check, use '-t noop' which will run a 'noop' test which does nothing except pass"
  echo "  Daemon / client versions are supplied as multiple <type>:<version> pairs, separated by spaces"
  echo ""
  echo "Usage examples:"
  echo "    $scriptName -s 'd:4.0.5 d:current' -c 'd:current' -t 'test1.sh test2.sh test3.sh'"
  echo "  So when we extend these tests for the C daemons then we could have, e.g."
  echo "    $scriptName -s 'd:4.0.5 d:5.1.0 c:5.1.0' -c 'd:4.0.5 d:current' -t 'test4.sh'"
  echo ""
  exit 1
}

# disable ssh-agent for these tests
export SSH_AUTH_SOCK=""

atDirectoryHost=root.atsign.org
atDirectoryPort=64
testsToRun="all"

defaultDaemonVersions="d:4.0.5 d:5.0.2 d:current"

# Client Versions
# Don't re-add 5.0.x until we've implemented the required
# `expect` magic to allow the 5.x clients to run even though there is not
# a real terminal attached.
# To see what I mean - run sshnp 5.0.2 with piped input - for example
# sshnoports % sshnp -f @atsign_1 -t @atsign_2 -h @rv_atsign -u username -d devicename -i /path/to/identityFile <<< 'echo hello'
#  Unhandled exception:
#  StdinException: Error getting terminal line mode, OS Error: Inappropriate ioctl for device, errno = 25
#  #0      Stdin.lineMode (dart:io-patch/stdio_patch.dart:116)
#  #1      main (file:///Users/runner/work/noports/noports/packages/dart/sshnoports/bin/sshnp.dart:38)
#  #2      _delayEntrypointInvocation.<anonymous closure> (dart:isolate-patch/isolate_patch.dart:295)
#  #3      _RawReceivePort._handleMessage (dart:isolate-patch/isolate_patch.dart:184)
#
# i.e. basically doesn't work in scripting environments
#
# version 5.1.0+ does work in scripting environments
#
defaultClientVersions="d:4.0.5 d:current"

daemonVersions=$defaultDaemonVersions
clientVersions=$defaultClientVersions

unset testScriptsDir
unset testRootDir
unset testRuntimeDir
recompile="true"

scriptName=$(basename -- "$0")
cd "$(dirname -- "$0")" || exit 1
testScriptsDir=$(pwd)
export testScriptsDir

source "$testScriptsDir/common/common_functions.include.sh"

if ! command -v timeout &> /dev/null
then
    logErrorAndExit "'timeout' command could not be found. If on MacOS, brew install coreutils"
fi


unset clientAtSign
unset daemonAtSign
unset srvAtSign

if (( $# < 3 )); then
  usageAndExit
fi

clientAtSign="$1"
if test "${clientAtSign:0:1}" != "@"; then
  logError "invalid clientAtSign $clientAtSign"
  usageAndExit
fi
daemonAtSign="$2"
if test "${daemonAtSign:0:1}" != "@"; then
  logError "invalid daemonAtSign $daemonAtSign"
  usageAndExit
fi
srvAtSign="$3"
if test "${srvAtSign:0:1}" != "@"; then
  logError "invalid srvAtSign $srvAtSign"
  usageAndExit
fi

export clientAtSign daemonAtSign srvAtSign
shift
shift
shift

commitId="$(git rev-parse --short HEAD)"
export commitId

remoteUsername=$(whoami)
identityFilename="$HOME/.ssh/e2e_all.${commitId}"

daemonStartWait=15
daemonStopWait=15

while getopts r:t:s:c:u:w:z:n opt; do
  case $opt in
    r) atDirectoryHost=$OPTARG ;;
    t) testsToRun=$OPTARG ;;
    s) daemonVersions=$OPTARG ;;
    c) clientVersions=$OPTARG ;;
    u) remoteUsername=$OPTARG ;;
    w) daemonStartWait=$OPTARG ;;
    z) daemonStopWait=$OPTARG ;;
    n) recompile="false" ;;
    *) usageAndExit ;;
  esac
done

if test "$testsToRun" = "all"; then
  # shellcheck disable=SC2010
  testsToRun=$(ls -1 "$testScriptsDir/tests" | grep -v "^noop$" | grep -v "^shared$")
  logInfo "Will run all tests: $testsToRun"
fi

export atDirectoryHost
export atDirectoryPort
export testsToRun
export daemonVersions
export clientVersions
export remoteUsername
export identityFilename
export daemonStartWait
timeoutDuration=20
export timeoutDuration

shift "$(( OPTIND - 1 ))"

# Script dir is <repo_root>/tests/e2e_all/scripts
cd "$testScriptsDir/../../.." || exit 1 # should now be in <repo_root>/
repoRootDir="$(pwd)"
export repoRootDir

# Runtime base working directory is <repo_root>/tests/e2e_all/runtime
# which is in .gitignore
cd "$testScriptsDir/.." || exit 1 # should now be in <repo_root>/tests/e2e_all
testRootDir="$(pwd)"
export testRootDir

cd "$testRootDir" || exit 1
mkdir -p runtime
cd runtime || exit 1 # should now be in <repo_root>/tests/e2e_all/runtime
mkdir -p "$commitId"
cd "$commitId" || exit 1 # should now be in <repo_root>/tests/e2e_all/runtime/$commitId
testRuntimeDir="$(pwd)"
export testRuntimeDir

"$testScriptsDir/common/cleanup_tmp_files.sh" -s

logInfo "  --> will execute setup_binaries, start_daemons and tests [$testsToRun] with "
logInfo "    testRootDir:      $testRootDir"
logInfo "    testRuntimeDir:   $testRuntimeDir"
logInfo "    testScriptsDir:   $testScriptsDir"
logInfo "    recompile:        $recompile"
logInfo "    atDirectoryHost:  $atDirectoryHost"
logInfo "    daemonVersions:   $daemonVersions"
logInfo "    clientVersions:   $clientVersions"
logInfo "    commitId:         $commitId"
logInfo "    testsToRun:       $testsToRun"

echo
logInfo "Calling setup_binaries.sh"
export recompile
"$testScriptsDir/common/setup_binaries.sh"
retCode=$?
if test "$retCode" != 0; then
  logError "Failed to set up binaries - exiting"
  exit $retCode
fi

echo
logInfo "Generating new ssh key"
generateNewSshKey

echo
logInfo "Backing up authorized_keys"
backupAuthorizedKeys

# Kill any daemons that might be running since last time, due to a Ctrl-C or whatever
echo
logInfo "Calling stop_daemons.sh"
"$testScriptsDir/common/stop_daemons.sh"

logInfo "Calling start_daemons.sh"
"$testScriptsDir/common/start_daemons.sh"
retCode=$?
if test "$retCode" != 0; then
  logError "Failed to start daemons; will not run tests"
  exit $retCode
else
  echo
  logInfo "Sleeping for $daemonStartWait seconds to allow daemons to start"
  sleep "$daemonStartWait"
  logInfo "Calling common/run_tests.sh"
  "$testScriptsDir/common/run_tests.sh"
  testExitStatus=$?
fi

logInfo "Calling common/stop_daemons.sh"
"$testScriptsDir/common/stop_daemons.sh"
retCode=$?
if test "$retCode" != 0; then
  logError "stop_daemons failed with exit status $retCode"
fi

echo
logInfo "Restoring authorized_keys from backup"
restoreAuthorizedKeys

reportFile=$(getReportFile)

logInfo ""
logInfo "Tests completed. Report follows. (Can also be found at ${reportFile}) : "
echo
cat "$reportFile"
logInfo ""
logInfo ""

echo
logInfo "Calling common/cleanup_tmp_files.sh"
"$testScriptsDir/common/cleanup_tmp_files.sh"
retCode=$?
if test "$retCode" != 0; then
  logError "cleanup_tmp_files failed with exit status $retCode"
fi

exit $testExitStatus
