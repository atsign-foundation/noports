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
relayAtKeysFile="$HOME/.atsign/keys/"$srvAtSign"_key.atKeys"
policyLatestAtKeysFile="$HOME/.atsign/keys/"$policyLatestAtSign"_key.atKeys"
eventsAtKeysFile="$HOME/.atsign/keys/"$eventsAtSign"_key.atKeys"
singletonAtKeysFile="$HOME/.atsign/keys/"$singletonAtSign"_key.atKeys"

cp $daemonAtKeysFile $testAtKeysDir
logInfo "Copied $daemonAtKeysFile to $testAtKeysDir"

cp $clientAtKeysFile $testAtKeysDir
logInfo "Copied $clientAtKeysFile to $testAtKeysDir"

cp $relayAtKeysFile $testAtKeysDir
logInfo "Copied $relayAtKeysFile to $testAtKeysDir"

cp $policyLatestAtKeysFile $testAtKeysDir
logInfo "Copied $policyLatestAtKeysFile to $testAtKeysDir"

cp $eventsAtKeysFile $testAtKeysDir
logInfo "Copied $eventsAtKeysFile to $testAtKeysDir"

cp $singletonAtKeysFile $testAtKeysDir
logInfo "Copied $singletonAtKeysFile to $testAtKeysDir"
