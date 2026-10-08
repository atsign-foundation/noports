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

if [[ $allowParallelization == "true" ]]; then
  # 1. Run the 001_minus_s_flag test in parallel for all client and daemon versions
  listOfPids=()
  for clientVersion in $clientVersions; do
    for daemonVersion in $daemonVersions; do
      "$testScriptsDir/common/run_single_test.sh" $clientVersion $daemonVersion '001_minus_s_flag' $timeoutDuration
    done &
    pid=$!
    listOfPids+=($pid)
    sleep 0.2
  done
  # Wait for all the 001_minus_s_flag tests to finish
  for pid in "${listOfPids[@]}"; do
    wait $pid
    if [ $? -ne 0 ]; then
      logErrorAndReport "001_minus_s_flag test failed with pid $pid, exiting because the rest of the tests depend on it"
      exit 1
    fi
  done

  # 2. Run the rest of the tests in parallel for all client and daemon versions
  for clientVersion in $clientVersions; do
    listOfPids=()
    for testToRun in $testsToRun; do
      for daemonVersion in $daemonVersions; do
        if [ "$testToRun" == "001_minus_s_flag" ]; then
          # Skip this test because it was already run above
          continue
        fi
        "$testScriptsDir/common/run_single_test.sh" $clientVersion $daemonVersion $testToRun $timeoutDuration
      done &
      pid=$!
      listOfPids+=($pid)
      sleep 0.2
    done
    # Wait for all the tests to finish
    for pid in "${listOfPids[@]}"; do
      wait $pid
    done
  done
else
  # The old way of running e2e tests - no parallelization
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
