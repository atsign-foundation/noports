#!/bin/bash

# This script copies the atKeys files from the ~/.atsign/keys directory to the testRuntimeDir/keys directory

if [ -z "$testScriptsDir" ] ; then
  echo -e "    ${RED}check_env: testScriptsDir is not set${NC}" && exit 1
fi

source "$testScriptsDir/common/common_functions.include.sh"
source "$testScriptsDir/common/check_env.include.sh" || exit $?

testAtKeysDir=$testRuntimeDir/keys
export testAtKeysDir

mkdir -p $testAtKeysDir

daemonAtKeysFile="$HOME/.atsign/keys/"$daemonAtSign"_key.atKeys" 
clientAtKeysFile="$HOME/.atsign/keys/"$clientAtSign"_key.atKeys"

cp $daemonAtKeysFile $testAtKeysDir
logInfo "Copied $daemonAtKeysFile to $testAtKeysDir"

cp $clientAtKeysFile $testAtKeysDir
logInfo "Copied $clientAtKeysFile to $testAtKeysDir"
