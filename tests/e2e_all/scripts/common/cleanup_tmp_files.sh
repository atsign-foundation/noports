#!/bin/bash

if [ -z "$testScriptsDir" ] ; then
  echo -e "    ${RED}check_env: testScriptsDir is not set${NC}" && exit 1
fi

source "$testScriptsDir/common/common_functions.include.sh"
source "$testScriptsDir/common/check_env.include.sh" || exit $?

echo
logInfo ""
logInfo "Cleaning up"

logInfo "rm -rf /tmp/e2e_all/${commitId}/daemons"
rm -rf "/tmp/e2e_all/${commitId}/daemons"

logInfo "rm -rf /tmp/e2e_all/${commitId}/clients"
rm -rf "/tmp/e2e_all/${commitId}/clients"

logInfo "rmdir /tmp/e2e_all/${commitId}"
rmdir "/tmp/e2e_all/${commitId}"
