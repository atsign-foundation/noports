#!/bin/bash

if [ -z "$testScriptsDir" ] ; then
  echo -e "    ${RED}check_env: testScriptsDir is not set${NC}" && exit 1
fi

source "$testScriptsDir/common/common_functions.include.sh"
source "$testScriptsDir/common/check_env.include.sh" || exit $?

logInfo ""
logInfo "  stop_daemons starting"

for pid in $(pgrep -f "sshnpd.*${commitId}")
do
  logInfo "    killing $pid ($(ps -ef | grep " $pid "))"
  kill "$pid"
done
