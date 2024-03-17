#!/bin/bash

if [ -z "$testScriptsDir" ] ; then
  echo -e "    ${RED}check_env: testScriptsDir is not set${NC}" && exit 1
fi

source "$testScriptsDir/common/common_functions.include.sh"
source "$testScriptsDir/common/check_env.include.sh" || exit $?

for pid in $(pgrep -f "sshnpd.*${commitId}")
do
  kill "$pid"
done

for pid in $(pgrep -f "tests/e2e_all/runtime/.*/srv ")
do
  kill "$pid"
done

for pid in $(pgrep -f "tests/e2e_all/releases/.*/srv ")
do
  kill "$pid"
done
