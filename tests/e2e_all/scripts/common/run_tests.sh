#!/bin/bash

if [ -z "$testScriptsDir" ]; then
  echo -e "    ${RED}check_env: testScriptsDir is not set${NC}" && exit 1
fi

source "$testScriptsDir/common/common_functions.include.sh"
source "$testScriptsDir/common/check_env.include.sh" || exit $?

mkdir -p /tmp/e2e_all

reportFile=$(getReportFile)
rm -f "$reportFile"

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

# N.B. any variable used by this function must be explicitly set when called from GNU parallel
run_tests_for_daemon() {
  local daemonVersion="$1"
  for testToRun in $testsToRun; do
    for clientVersion in $clientVersions; do
      "$testScriptsDir/common/run_single_test.sh" $clientVersion $daemonVersion $testToRun $timeoutDuration
    done
  done
}

if [ $allowParallelization == "true" ] && command -v env_parallel >/dev/null 2>&1; then
  logInfo "Found GNU parallel, running tests in parallel"
  export -f run_tests_for_daemon
  # Run a round of tests against each daemon in parallel
  parallel --jobs 5 \
    --timeout 3m \
    --env run_tests_for_daemon \
    "testScriptsDir='$testScriptsDir' && testsToRun='$testsToRun' && clientVersions='$clientVersions' && testScriptsDir='$testScriptsDir' && timeoutDuration='$timeoutDuration' && run_tests_for_daemon" \
    ::: $daemonVersions
else
  # The old way of running e2e tests - no parallelization
  if [ $allowParallelization == "true" ]; then
    logWarning "Unable to find GNU parallel, running tests serially :("
  fi
  for daemonVersion in $daemonVersions; do
    for testToRun in $testsToRun; do
      for clientVersion in $clientVersions; do
        "$testScriptsDir/common/run_single_test.sh" $clientVersion $daemonVersion $testToRun $timeoutDuration
      done
    done
  done
fi

passed=0
failed=0
ignored=0
total=0

# Aggregation of all the logs at the end serially so that the final report is in order
for daemonVersion in $daemonVersions; do
  for testToRun in $testsToRun; do
    for clientVersion in $clientVersions; do
      singleTestOutputLog="$(getSingleTestOutputLogName $testToRun $daemonVersion $clientVersion)"
      singleTestResultLog="$(getSingleTestResultLogName $testToRun $daemonVersion $clientVersion)"

      exitStatus=$(cat $singleTestResultLog | tr -d "\n")

      additionalInfo=""
      testResult="WAT"

      cat "$singleTestOutputLog" >>"$reportFile"

      case $exitStatus in
        0) # test passed
          testResult="PASSED"
          ;;
        50) # special exit code, indicates the test was deliberately ignored
          testResult="N/A"
          additionalInfo="(not applicable)"
          ;;
        51) # special exit code, indicates the exit code was 0 but there was no 'TEST PASSED' output
          testResult="FAILED"
          additionalInfo="(test exit status was 0, but no 'TEST PASSED' in test output)"
          ;;
        124) # timeout returns 124 if the command timed out
          testResult="FAILED"
          additionalInfo="(timed out after $timeoutDuration seconds)"
          ;;
        *) # any other non-zero exit code is a failure
          testResult="FAILED"
          ;;
      esac

      total=$((total + 1))
      case $testResult in
        FAILED)
          logColour=$RED
          failed=$((failed + 1))
          ;;
        "N/A")
          logColour=$BLUE
          ignored=$((ignored + 1))
          ;;
        PASSED)
          logColour=$GREEN
          passed=$((passed + 1))
          ;;
        *)
          logError "    Unexpected testResult $testResult" >>"$reportFile"
          failed=$((failed + 1))
          ;;
      esac

      case $testResult in
        FAILED)
          logError "    ${logColour}Test ${testResult}${NC} : exit code $exitStatus $additionalInfo" >>"$reportFile"
          ;;
        "N/A")
          logInfo "    ${logColour}Test ${testResult}${NC}" >>"$reportFile"
          ;;
        PASSED)
          logInfo "    ${logColour}Test ${testResult}${NC}" >>"$reportFile"
          ;;
      esac

    done
  done
done

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

if ((failed == 0)); then
  exit 0
else
  exit 1
fi
