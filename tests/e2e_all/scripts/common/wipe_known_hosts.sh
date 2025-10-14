#!/bin/bash

if [ -z "$testScriptsDir" ]; then
  echo -e "    ${RED}check_env: testScriptsDir is not set${NC}" && exit 1
fi

source "$testScriptsDir/common/common_functions.include.sh"
source "$testScriptsDir/common/check_env.include.sh" || exit $?

knownHostsFile="$HOME/.ssh/known_hosts"
echo "" >"$knownHostsFile" # Empty the known_hosts file

if [[ "$(uname)" == "Darwin" ]]; then
    sudo sh -c 'echo "" > /var/root/.ssh/known_hosts'
fi
