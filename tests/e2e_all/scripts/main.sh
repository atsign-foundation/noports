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
  echo "  $scriptName @client_atsign @daemon_atsign @relay_atsign @relay_latest_atsign @policy_atsign @policy_latest_atsign @events_atsign \\"
  echo "     [-r <atDirectory (aka root) host>] \\"
  echo "     [-t <space-separated list of test scripts to run from the e2e_all/scripts/tests/ subdirectory>] \\"
  echo "     [-s <daemon versions>] - defaults to $defaultDaemonVersions\\"
  echo "     [-c <client versions>] - defaults to $defaultClientVersions \\"
  echo "     [-w <daemon start wait time> - how long to wait for daemons to start up - defaults to 30 seconds] \\"
  echo "     [-n (Do not recompile binaries for current commit. Default is to always recompile.)]"
  echo "     [-p (Enable test parallelization) ]"
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

# defaultDaemonVersions="c:current"
defaultDaemonVersions="d:current c:current d:5.9.4 d:5.11.2 d:5.13.0"
defaultClientVersions="d:current d:5.9.4 d:5.11.2 d:5.13.0"

daemonVersions=$defaultDaemonVersions
clientVersions=$defaultClientVersions

unset testScriptsDir
unset testRootDir
unset testRuntimeDir

# Parallelization was designed for use with "GNU parallel 20210822"
allowParallelization="false"

recompile="true"

scriptName=$(basename -- "$0")
cd "$(dirname -- "$0")" || exit 1
testScriptsDir=$(pwd)
export testScriptsDir

export recompile
source "$testScriptsDir/common/common_functions.include.sh"

if ! command -v timeout &>/dev/null; then
  logErrorAndExit "'timeout' command could not be found. If on MacOS, brew install coreutils"
fi

unset clientAtSign
unset daemonAtSign
unset srvAtSign
unset srvLatestAtSign
unset policyAtSign
unset policyLatestAtSign
unset eventsAtSign

if (($# < 3)); then
  usageAndExit
fi

clientAtSign="$1"
if test "${clientAtSign:0:1}" != "@"; then
  logErrorAndReport "invalid clientAtSign $clientAtSign"
  usageAndExit
fi
shift

daemonAtSign="$1"
if test "${daemonAtSign:0:1}" != "@"; then
  logErrorAndReport "invalid daemonAtSign $daemonAtSign"
  usageAndExit
fi
shift

srvAtSign="$1"
if test "${srvAtSign:0:1}" != "@"; then
  logErrorAndReport "invalid srvAtSign $srvAtSign"
  usageAndExit
fi
shift

srvLatestAtSign="$1"
if test "${srvLatestAtSign:0:1}" != "@"; then
  logErrorAndReport "invalid srvLatestAtSign $srvLatestAtSign"
  usageAndExit
fi
shift

policyAtSign="$1"
if test "${policyAtSign:0:1}" != "@"; then
  logErrorAndReport "invalid policyAtSign $policyAtSign"
  usageAndExit
fi
shift

policyLatestAtSign="$1"
if test "${policyLatestAtSign:0:1}" != "@"; then
  logErrorAndReport "invalid policyLatestAtSign $policyLatestAtSign"
  usageAndExit
fi
shift

eventsAtSign="$1"
if test "${eventsAtSign:0:1}" != "@"; then
  logErrorAndReport "invalid eventsAtSign $eventsAtSign"
  usageAndExit
fi
shift

export clientAtSign daemonAtSign srvAtSign srvLatestAtSign policyAtSign policyLatestAtSign eventsAtSign

commitId="$(git rev-parse --short HEAD)"
export commitId

identityFilename="$HOME/.ssh/e2e_all.${commitId}"

daemonStartWait=20

while getopts r:t:s:c:u:w:pn opt; do
  case $opt in
  r) atDirectoryHost=$OPTARG ;;
  t) testsToRun=$OPTARG ;;
  s) daemonVersions=$OPTARG ;;
  c) clientVersions=$OPTARG ;;
  w) daemonStartWait=$OPTARG ;;
  p) allowParallelization="true" ;;
  n) recompile="false" ;;
  *) usageAndExit ;;
  esac
done

if test "$testsToRun" = "all"; then
  # shellcheck disable=SC2010
  testsToRun=$(ls -1 "$testScriptsDir/tests" | grep -v "^noop$" | grep -v "^shared$")
  logInfo "Will run all tests: $(tr "\n" ";" <<<"$testsToRun")"
fi

export atDirectoryHost
export atDirectoryPort
export testsToRun
export daemonVersions
export clientVersions
export remoteUsername="atsign"
export identityFilename
export daemonStartWait
export allowParallelization
timeoutDuration=30 # time out for each test
export timeoutDuration
export recompile

shift "$((OPTIND - 1))"

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

logInfo "  --> will execute setup_binaries, start_daemons and run_tests with "
logInfo "    clientAtSign:       $clientAtSign"
logInfo "    daemonAtSign:       $daemonAtSign"
logInfo "    relayAtSign:        $srvAtSign"
logInfo "    relayLatestAtSign:  $srvLatestAtSign"
logInfo "    policyAtSign:       $policyAtSign"
logInfo "    policyLatestAtSign: $policyLatestAtSign"
logInfo "    eventsAtSign:       $eventsAtSign"
logInfo "    testRootDir:        $testRootDir"
logInfo "    testRuntimeDir:     $testRuntimeDir"
logInfo "    testScriptsDir:     $testScriptsDir"
logInfo "    recompile:          $recompile"
logInfo "    parallelization:    $allowParallelization"
logInfo "    atDirectoryHost:    $atDirectoryHost"
logInfo "    daemonVersions:     $daemonVersions"
logInfo "    clientVersions:     $clientVersions"
logInfo "    commitId:           $commitId"
logInfo "    testsToRun:         $(tr "\n" ";" <<<"$testsToRun")"

echo
logInfo "Calling common/build_docker_daemons.sh"
if [ "${allowParallelization}" = "true" ]; then
  # shellcheck disable=SC2016
  "$testScriptsDir/common/build_docker_daemons.sh" &
  buildDockerDaemonPidParallel=$!
else
  "$testScriptsDir/common/build_docker_daemons.sh"
fi

echo
logInfo "Calling common/setup_binaries.sh"
if [ "${allowParallelization}" = "true" ]; then
  "$testScriptsDir/common/setup_binaries.sh" &
  setupBinariesPidParallel=$!
else
  "$testScriptsDir/common/setup_binaries.sh"
fi

echo
logInfo "Calling common/setup_atkeys.sh"
"$testScriptsDir/common/setup_atkeys.sh"

echo
logInfo "Generating new ssh key"
generateNewSshKey

echo
logInfo "Backing up authorized_keys"
backUpAuthorizedKeysFile

echo
logInfo "Backing up known_hosts file"
backUpKnownHostsFile

# Kill any daemons that might be running since last time, due to a Ctrl-C or whatever
echo
logInfo "Calling common/stop_daemons.sh"
"$testScriptsDir/common/stop_daemons.sh"

if [ "${allowParallelization}" = "true" ]; then
  logInfo "Waiting for setup_binaries.sh to finish"
  wait "$setupBinariesPidParallel"
  retCode=$?
  if [ "$retCode" -ne 0 ]; then
    logErrorAndReport "setup_binaries.sh failed with exit code $retCode"
    exit $retCode
  fi
  logInfo "setup_binaries.sh finished with exit code $?"
fi

echo
logInfo "Calling common/apkam_setup.sh"
"$testScriptsDir/common/apkam_setup.sh"

if [ "${allowParallelization}" = "true" ]; then
  logInfo "Waiting for build_docker_daemons.sh to finish"
  wait "$buildDockerDaemonPidParallel"
  retCode=$?
  if [ "$retCode" -ne 0 ]; then
    logErrorAndReport "build_docker_daemons.sh failed with exit code $retCode"
    exit $retCode
  fi
  logInfo "build_docker_daemons.sh finished with exit code $?"
fi

logInfo "Calling common/start_daemons.sh"
"$testScriptsDir/common/start_daemons.sh"
retCode=$?
if test "$retCode" != 0; then
  logErrorAndReport "Failed to start daemons; will not run tests"
  logInfo "Calling stop_daemons.sh"
  "$testScriptsDir/common/stop_daemons.sh"
  exit $retCode
else
  logInfo "Calling common/run_tests.sh"
  "$testScriptsDir/common/run_tests.sh"
  testExitStatus=$?
fi


logInfo "Calling common/stop_daemons.sh"
"$testScriptsDir/common/stop_daemons.sh"
retCode=$?
if test "$retCode" != 0; then
  logErrorAndReport "stop_daemons failed with exit status $retCode"
fi

echo
logInfo "Restoring authorized_keys from backup"
restoreAuthorizedKeysFile

echo
logInfo "Restoring known_hosts file from backup"
restoreKnownHostsFile

logInfo "Removing $identityFilename and $identityFilename.pub"
rm -f "${identityFilename}" "${identityFilename}.pub"

reportFile=$(getReportFile)

logInfo ""
logInfo "Tests completed. Report follows. (Can also be found at ${reportFile}) : "
echo
cat "$reportFile"
logInfo ""
logInfo ""

exit $testExitStatus
