#!/bin/bash

if [ -z "$testScriptsDir" ] ; then
  echo -e "    ${RED}check_env: testScriptsDir is not set${NC}" && exit 1
fi

source "$testScriptsDir/common/common_functions.include.sh"
source "$testScriptsDir/common/check_env.include.sh" || exit $?

logInfo ""
logInfo "  start_daemons starting"

outputDir=$(getOutputDir)
mkdir -p "${outputDir}/daemons"

# For each daemonVersion
# Start two daemons for each typeAndVersion
# 1) with the -u and -s flags set
# 2) with neither of those flags set
for typeAndVersion in $daemonVersions
do
  logInfo "    Starting daemons for commitId $commitId and version $typeAndVersion"

  deviceName=$(getNoFlagsDeviceNameForCommitIDTypeAndVersion "$commitId" "$typeAndVersion" )
  logInfo "    Got deviceName $deviceName"

  pathToBinaries=$(getPathToBinariesForTypeAndVersion "$typeAndVersion")

  cBinary="$pathToBinaries/sshnpd"
  fRoot="--root-domain $atDirectoryHost"
  fAtSigns="-m $clientAtSign -a $daemonAtSign"

  logInfo "      Starting daemon version $typeAndVersion with neither the -u nor -s flags"
  commandLine="$cBinary $fRoot $fAtSigns -d ${deviceName} --storage-path ${outputDir}/daemons/${deviceName}.storage -v"
  echo "        --> $commandLine  >& ${outputDir}/daemons/${deviceName}.out 2> ${outputDir}/daemons/${deviceName}.err &"
  $commandLine > "${outputDir}/daemons/${deviceName}.out" 2> "${outputDir}/daemons/${deviceName}.err" &
  sleep 0.2
  echo
done
