#!/bin/bash

if [ -z "$testScriptsDir" ] ; then
  echo -e "    ${RED}check_env: testScriptsDir is not set${NC}" && exit 1
fi

source "$testScriptsDir/common/common_functions.include.sh"
source "$testScriptsDir/common/check_env.include.sh" || exit $?

logInfo ""
logInfo "  run_tests starting"

NC='\033[0m'
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'

mkdir -p /tmp/e2e_all

reportFile=$(getReportFile)
rm -f "$reportFile"

passed=0
failed=0
ignored=0
total=0

# shellcheck disable=SC2129
echo "###########################################################" >> "$reportFile"
echo "### NoPorts e2e test run starting at $(iso8601Date)" >> "$reportFile"
echo "### " >> "$reportFile"
echo "### " >> "$reportFile"

if (( timeoutDuration == 0 )) ; then
  timeoutDuration=10
fi

outputDir=$(getOutputDir)
mkdir -p "${outputDir}/clients"

for testToRun in $testsToRun
do
  for daemonVersion in $daemonVersions
  do
    for clientVersion in $clientVersions
    do
      logInfo "Test ${testToRun} with client ${clientVersion} and daemon ${daemonVersion}"

      baseFileName="${outputDir}/clients/${testToRun}.daemon.${daemonVersion}.client.${clientVersion}"
      stdoutFileName="${baseFileName}.out"
      stderrFileName="${baseFileName}.err"

      what="tests/$testToRun for daemon [$daemonVersion] client [$clientVersion]"
      logInfo "    Executing $what > $stdoutFileName 2> $stderrFileName"

      # Execute the test script
      timeout "$timeoutDuration" "$testScriptsDir/tests/$testToRun" "$daemonVersion" "$clientVersion" \
        > "$stdoutFileName" 2> "$stderrFileName"

      #
      # Check exit status
      exitStatus=$?

      total=$((total+1))
      if (( exitStatus == 0 )); then
        # Exit code 0, but did the output contain the magic 'TEST PASSED' words?
        if ! grep "TEST PASSED" "$stdoutFileName"; then
          exitStatus=51
        fi
      fi

      additionalInfo=""
      testResult="WAT"

      case $exitStatus in
        0) # test passed
          testResult="PASSED"
          passed=$((passed+1))
          ;;
        50) # special exit code, indicates the test was deliberately ignored
          testResult="IGNORED"
          additionalInfo="(ignored)"
          ignored=$((ignored+1))
          ;;
        51) # special exit code, indicates the exit code was 0 but there was no 'TEST PASSED' output
          testResult="FAILED"
          additionalInfo="(test exit status was 0, but no 'TEST PASSED' in test output)"
          failed=$((failed+1))
          ;;
        124) # timeout returns 124 if the command timed out
          testResult="FAILED"
          additionalInfo="(timed out after $timeoutDuration seconds)"
          failed=$((failed+1))
          ;;
        *) # any other non-zero exit code is a failure
          testResult="FAILED"
          failed=$((failed+1))
          ;;
      esac
      case $testResult in
        FAILED) logColour=$RED ;;
        IGNORED) logColour=$BLUE ;;
        PASSED) logColour=$GREEN ;;
        *) logErrorAndExit "Unexpected testResult $testResult" ;;
      esac

      case $testResult in
        FAILED)
          echo "    test execution's stdout: "
          sed 's/^/        /' "$stdoutFileName"

          echo "    test execution's stderr: "
          sed 's/^/        /' "$stderrFileName"

          echo -e "    ${logColour}${testResult}${NC} : exit code $exitStatus $additionalInfo : $what" | tee -a "$reportFile"
          # shellcheck disable=SC2129
          echo "    test execution's stdout: " >> "$reportFile"
          sed 's/^/        /' "$stdoutFileName" >> "$reportFile"

          echo "    test execution's stderr: " >> "$reportFile"
          sed 's/^/        /' "$stderrFileName" >> "$reportFile"

          echo >> "$reportFile"
          ;;
        IGNORED)
          echo -e "$what | ${logColour}${testResult}${NC}" | tee -a "$reportFile"
          ;;
        PASSED)
          echo -e "$what | ${logColour}${testResult}${NC}" | tee -a "$reportFile"
          echo -e "$what | ssh output was: $(grep "TEST PASSED" "$stdoutFileName")" | tee -a "$reportFile"
          ;;
      esac
      echo >> "$reportFile"
      echo >> "$reportFile"
    done
  done
done
# shellcheck disable=SC2129

echo "### " >> "$reportFile"
echo "### " >> "$reportFile"
echo "### NoPorts e2e test run complete at $(iso8601Date)" >> "$reportFile"
echo "### " >> "$reportFile"
if (( failed == 0 )); then
  colour=$GREEN
else
  colour=$RED
fi
actuallyExecuted=$(( total - ignored ))
echo -e "### Of a possible $total, ignored $ignored and executed $actuallyExecuted tests" >> "$reportFile"
echo -e "${colour}### Passed: $passed Failed: $failed${NC}" >> "$reportFile"
echo "###########################################################" >> "$reportFile"

exit $failed
