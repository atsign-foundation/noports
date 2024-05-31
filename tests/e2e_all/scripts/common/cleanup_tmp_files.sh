#!/bin/bash

if [ -z "$testScriptsDir" ] ; then
  echo -e "    ${RED}check_env: testScriptsDir is not set${NC}" && exit 1
fi

source "$testScriptsDir/common/common_functions.include.sh"
source "$testScriptsDir/common/check_env.include.sh" || exit $?

silent="false"
if [[ "$1" == "-s" ]]; then silent="true"; fi

localLogInfo() {
  if [[ "$silent" == "true" ]]; then return; fi
  logInfo "$1"
}

safeRemoveDir() {
  dirToRemove="$1"
  if grep -q "e2e_all/runtime" <<< "$dirToRemove" || grep -q "e2e_all/${commitId}" <<< "$dirToRemove"
  then
    localLogInfo "rm -rf ${dirToRemove:fubar}"
    rm -rf "${dirToRemove:fubar}"
  fi
}
echo
localLogInfo ""
localLogInfo "NOT Cleaning up output files for this run"

# safeRemoveDir "$(getOutputDir)"
