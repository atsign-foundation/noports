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
echo
localLogInfo ""
localLogInfo "Cleaning up"

outputDir=$(getOutputDir)
localLogInfo "rm -rf ${outputDir}"
rm -rf "${outputDir}"
