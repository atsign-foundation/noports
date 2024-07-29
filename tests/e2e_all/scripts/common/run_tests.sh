#!/bin/bash

if [ -z "$testScriptsDir" ]; then
  echo -e "    ${RED}check_env: testScriptsDir is not set${NC}" && exit 1
fi

source "$testScriptsDir/common/common_functions.include.sh"
source "$testScriptsDir/common/check_env.include.sh" || exit $?

mkdir -p /tmp/e2e_all

reportFile=$(getReportFile)
rm -f "$reportFile"

passed=0
failed=0
ignored=0
total=0

# shellcheck disable=SC2129
echo "###########################################################" >>"$reportFile"
echo "### NoPorts e2e test run starting at $(iso8601Date)" >>"$reportFile"
echo "### " >>"$reportFile"
echo "### " >>"$reportFile"

outputDir=$(getOutputDir)
mkdir -p "${outputDir}/clients"
mkdir -p "${outputDir}/tests"

numDaemons=$(wc -w <<<"$daemonVersions")
numClients=$(wc -w <<<"$clientVersions")
numTestScripts=$(wc -w <<<"$testsToRun")
totalNumTests=$((numDaemons * numClients * numTestScripts))

run_test() {
  local clientVersion="$1"
  local daemonVersion="$2"
  local testToRun="$3"

  pdv=$(getVersionDescription "$daemonVersion")
  pcv=$(getVersionDescription "$clientVersion")
  what="Test $((total + 1)) of $totalNumTests | ${BOLD}Test script: ${BBLUE}${testToRun}${NC} ${BOLD}Client: ${BBLUE}${pcv}${NC} ${BOLD}Daemon: ${BBLUE}${pdv}${NC}"
  echo
  logInfoAndReport "$what"

  baseFileName="$(getBaseFileName $testToRun $daemonVersion $clientVersion)"
  daemonLogFragmentName="$(getDaemonLogFragmentName $testToRun $daemonVersion $clientVersion)"
  stdoutFileName="${baseFileName}.out"
  stderrFileName="${baseFileName}.err"

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
    log "    Running test script ... "

    # Execute the test script
    timeout --foreground "$timeoutDuration" "$testScriptsDir/tests/$testToRun" "$daemonVersion" "$clientVersion" \
      >"$stdoutFileName" 2>"$stderrFileName"

    exitStatus=$?
    if ((exitStatus != 0 && exitStatus != 50)); then
      # shellcheck disable=SC2129
      echo "    test execution's stdout: " | tee -a "$reportFile"
      sed 's/^/        /' "$stdoutFileName" | tee -a "$reportFile"

      echo "    test execution's stderr: " | tee -a "$reportFile"
      sed 's/^/        /' "$stderrFileName" | tee -a "$reportFile"

      echo "    daemon log fragment: " | tee -a "$reportFile"
      sed 's/^/        /' "$daemonLogFragmentName" | tee -a "$reportFile"

      echo
      echo >>"$reportFile"
    fi

    attempts=$((attempts + 1))
  done

  if ((exitStatus != 0 && exitStatus != 50 && attempts == maxAttempts)); then
    logError "    Failed after $maxAttempts attempts                                                            "
  fi

  total=$((total + 1))
  if ((exitStatus == 0)); then
    # Exit code 0, but did the output contain the magic 'TEST PASSED' words?
    if ! grep -q "TEST PASSED" "$stdoutFileName"; then
      exitStatus=51
    fi
  fi

  additionalInfo=""
  testResult="WAT"

  case $exitStatus in
    0) # test passed
      testResult="PASSED"
      passed=$((passed + 1))
      ;;
    50) # special exit code, indicates the test was deliberately ignored
      testResult="N/A"
      additionalInfo="(not applicable)"
      ignored=$((ignored + 1))
      ;;
    51) # special exit code, indicates the exit code was 0 but there was no 'TEST PASSED' output
      testResult="FAILED"
      additionalInfo="(test exit status was 0, but no 'TEST PASSED' in test output)"
      failed=$((failed + 1))
      ;;
    124) # timeout returns 124 if the command timed out
      testResult="FAILED"
      additionalInfo="(timed out after $timeoutDuration seconds)"
      failed=$((failed + 1))
      ;;
    *) # any other non-zero exit code is a failure
      testResult="FAILED"
      failed=$((failed + 1))
      ;;
  esac
  case $testResult in
    FAILED) logColour=$RED ;;
    "N/A") logColour=$BLUE ;;
    PASSED) logColour=$GREEN ;;
    *) logErrorAndExit "Unexpected testResult $testResult" ;;
  esac

  case $testResult in
    FAILED)
      logInfoAndReport "    ${logColour}Test ${testResult}${NC} : exit code $exitStatus $additionalInfo"
      ;;
    "N/A")
      logInfoAndReport "    ${logColour}Test ${testResult}${NC}"
      ;;
    PASSED)
      logInfoAndReport "    ${logColour}Test ${testResult}${NC}"
      ;;
  esac
  echo >>"$reportFile"
}

run_tests_for_daemon() {
  local daemonVersion = "$1"
  for testToRun in $testsToRun; do
    for clientVersion in $clientVersions; do
      run_test $clientVersion $daemonVersion $testToRun
      if [[ "$testResult" == "FAILED" ]]; then
        break
      fi
    done
    if [[ "$testResult" == "FAILED" ]]; then
      break
    fi
  done
}

if command -v parallel >/dev/null 2>&1; then
  parallel run_tests_for_daemon -- $daemonVersions
else
  logWarning "Unable to find GNU parallel, running tests linearly"
  for testToRun in $testsToRun; do
    for daemonVersion in $daemonVersions; do
      for clientVersion in $clientVersions; do
        run_test $clientVersion $daemonVersion $testToRun
        if [[ "$testResult" == "FAILED" ]]; then
          break
        fi
      done
      if [[ "$testResult" == "FAILED" ]]; then
        break
      fi
    done
    if [[ "$testResult" == "FAILED" ]]; then
      break
    fi
  done

fi
# shellcheck disable=SC2129

echo "### " >>"$reportFile"
echo "### " >>"$reportFile"
echo "### NoPorts e2e test run complete at $(iso8601Date)" >>"$reportFile"
echo "### " >>"$reportFile"
if ((failed == 0)); then
  colour=$GREEN
else
  colour=$RED
fi
actuallyExecuted=$((total - ignored))
echo -e "### Of a possible $total, $ignored were not applicable (usually version constraints)" >>"$reportFile"
echo -e "${colour}### Executed: $actuallyExecuted  Passed: $passed  Failed: $failed${NC}" >>"$reportFile"
echo "###########################################################" >>"$reportFile"

exit $failed
