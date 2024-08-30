#!/bin/bash

# N.B. this file must not depend on any external environment variables that are set in various places by the end2end
# test suite. When running under GNU parallels, the environment is empty, thus every single variable in this file must
# either be explicitly set in the parallels command with `--env` or passed to this script as part of the argument list

script_dir="$(dirname -- "$(readlink -f -- "$0")")"
source "$script_dir/common_functions.include.sh"

clientVersion="$1"
daemonVersion="$2"
testToRun="$3"
timeoutDuration="$4"

baseFileName="$(getBaseFileName $testToRun $daemonVersion $clientVersion)"
daemonLogFragmentName="$(getDaemonLogFragmentName $testToRun $daemonVersion $clientVersion)"
stdoutFileName="${baseFileName}.out"
stderrFileName="${baseFileName}.err"
singleTestOutputLog="$(getSingleTestOutputLogName $testToRun $daemonVersion $clientVersion)"
singleTestResultLog="$(getSingleTestResultLogName $testToRun $daemonVersion $clientVersion)"

touch $singleTestOutputLog

pdv=$(getVersionDescription "$daemonVersion")
pcv=$(getVersionDescription "$clientVersion")
what="${BOLD}Running test: ${BBLUE}${testToRun}${NC} ${BOLD}Client: ${BBLUE}${pcv}${NC} ${BOLD}Daemon: ${BBLUE}${pdv}${NC}"
logInfo "$what" | tee -a "$singleTestOutputLog"

exitStatus=1
maxAttempts=5
if [[ $(uname -s) == "Darwin" ]]; then
  maxAttempts=2
fi
attempts=0

while ((exitStatus != 0 && exitStatus != 50 && attempts < maxAttempts)); do
  rm -f "$daemonLogFragmentName"
  touch "$daemonLogFragmentName"
  if ((attempts > 0)); then
    logWarning "    Exit status was $exitStatus; will retry in 3 seconds"
    sleep 3
  fi

  # Execute the test script
  timeout --foreground "$timeoutDuration" "$testScriptsDir/tests/$testToRun" "$daemonVersion" "$clientVersion" \
    >"$stdoutFileName" 2>"$stderrFileName"

  exitStatus=$?
  if ((exitStatus != 0 && exitStatus != 50)); then
    # shellcheck disable=SC2129
    if isGithubActions; then
      echo "::group::See logs" >>"$singleTestOutputLog"
    fi

    echo "    test execution's stdout: " >>"$singleTestOutputLog" 2>&1
    sed 's/^/        /' "$stdoutFileName" >>"$singleTestOutputLog" 2>&1

    echo "    test execution's stderr: " >>"$singleTestOutputLog" 2>&1
    sed 's/^/        /' "$stderrFileName" >>"$singleTestOutputLog" 2>&1

    echo "    daemon log fragment: " >>"$singleTestOutputLog" 2>&1
    sed 's/^/        /' "$daemonLogFragmentName" >>"$singleTestOutputLog" 2>&1

    if isGithubActions; then
      echo "::endgroup::" >>"$singleTestOutputLog"
    fi

    echo
    echo >>"$singleTestOutputLog" 2>&1
  fi

  attempts=$((attempts + 1))
done

if ((exitStatus != 0 && exitStatus != 50 && attempts == maxAttempts)); then
  logError "    Failed after $maxAttempts attempts" >>"$singleTestOutputLog" 2>&1
fi

if ((exitStatus == 0)); then
  # Exit code 0, but did the output contain the magic 'TEST PASSED' words?
  if ! grep -q "TEST PASSED" "$stdoutFileName"; then
    exitStatus=51
  fi
fi

echo "$exitStatus" >"$singleTestResultLog"
