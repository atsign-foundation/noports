#!/bin/bash

if [ -z "$testScriptsDir" ] ; then
  echo -e "    ${RED}check_env: testScriptsDir is not set${NC}" && exit 1
fi

source "$testScriptsDir/common/common_functions.include.sh"
source "$testScriptsDir/common/check_env.include.sh" || exit $?

for pid in $(pgrep -f "sshnpd.*${commitId}")
do
  echo "Killing $(ps -ef | grep " $pid " | grep -v grep)"
  kill "$pid"
done

for pid in $(pgrep -f "tests/e2e_all/(runtime|releases)/.*/.* ")
do
  processInfo=$(ps -ef | grep " $pid " | grep -v grep)
  # Allow the srv's to exit in their own time
  if ! grep -q "srv " <<< "$processInfo";
  then
    echo "Killing $processInfo"
    kill "$pid"
  fi
done

for pid in $(pgrep -f "tail .*/tmp/e2e_all/.*/daemons")
do
  processInfo=$(ps -ef | grep " $pid " | grep -v grep)
  echo "Killing $processInfo"
  kill "$pid"
done
