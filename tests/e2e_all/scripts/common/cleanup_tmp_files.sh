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

# Remove public keys which this test run generated from $HOME/.ssh/authorized_keys
echo "Authorized_keys before cleanup:"
cat "$HOME/.ssh/authorized_keys"

pattern=$(awk '{print $2}' < "$HOME/.ssh/${commitId}.pub")
echo "Key is [$pattern]"
if [[ "$pattern" == "" ]]; then
  echo "No key, nothing to remove"
else
  # Note: Not using sed -i because BSD and Linux have different syntax, so this is more readable
  mv "$HOME/.ssh/authorized_keys" "$HOME/.ssh/authorized_keys.before"
  grep -v "$pattern" < "$HOME/.ssh/authorized_keys.before" > "$HOME/.ssh/authorized_keys"
  chmod go-rwx "$HOME/.ssh/authorized_keys"
fi

echo "Authorized_keys after cleanup:"
cat "$HOME/.ssh/authorized_keys"
