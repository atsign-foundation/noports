#!/bin/bash

if [ -z "$testScriptsDir" ]; then
  echo -e "    ${RED}check_env: testScriptsDir is not set${NC}" && exit 1
fi

source "$testScriptsDir/common/common_functions.include.sh"
source "$testScriptsDir/common/check_env.include.sh" || exit $?

runAllDockerDaemons() {
  dockerfilesDir="$(dirname "$0")/../../dockerfiles"
  cd "$dockerfilesDir"/../../..

  logFilesToCheck=()
  for typeAndVersion in $daemonVersions; do
    # typeAndVersion is a string like "d:4.0.5" or "c:current"
    type=$(echo "$typeAndVersion" | cut -d: -f1)
    version=$(echo "$typeAndVersion" | cut -d: -f2)

    if [[ $(versionIsAtLeast "$typeAndVersion" "d:5.3.0") == "true" ]]; then
      apkamApp=$(getApkamAppName)
      apkamDev=$(getApkamDeviceName "daemon" "$commitId")
      # keysFile=$(getApkamKeysFile "$daemonAtSign" "$apkamApp" "$apkamDev") # OLD

      # the keys file is in the docker daemon
      # e.g. /atsign/.atsign/keys/@12alpaca.e2e_all.client_2064e58.atKeys
      keysFile="/atsign/.atsign/keys/$daemonAtSign.$apkamApp.$apkamDev".atKeys # NEW
      extraFlags="-k $keysFile"
    else
      extraFlags=""
    fi

    # Run with `-s` and `-u` flags (container 1)
    deviceName1=$(getDeviceNameWithFlags "$commitId" "$typeAndVersion")
    logFile1="${outputDir}/daemons/${deviceName1}.log"
    containerName1="e2e_all-$deviceName1"
    echo "Starting daemon version $typeAndVersion with the -u and -s flags"  >> "$logFile1"
    runDockerDaemon "$type" "$version" "$deviceName1" "$clientAtSign" "$daemonAtSign" "$extraFlags -s -u"
    sudo docker logs -f "$containerName1" >> "$logFile1" 2>&1 &

    # Run without `-s` and `u` flags (container 2)
    deviceName2=$(getDeviceNameNoFlags "$commitId" "$typeAndVersion")
    logFile2="${outputDir}/daemons/${deviceName2}.log"
    containerName2="e2e_all-$deviceName2"
    echo "Starting daemon version $typeAndVersion with neither the -u nor -s flags" >> "$logFile2"
    runDockerDaemon "$type" "$version" "$deviceName2" "$clientAtSign" "$daemonAtSign" "$extraFlags"
    sudo docker logs -f "$containerName2" >> "$logFile2" 2>&1 &

    logFilesToCheck+=("$logFile1")
    logFilesToCheck+=("$logFile2")
  done

  # Wait for all daemons to start
  for logFile in "${logFilesToCheck[@]}"; do
    logInfo "Waiting for Docker daemon with logFile \"$logFile\" to start..."
    waitUntilDockerDaemonStarted "$logFile" 60
  done
}

outputDir=$(getOutputDir)
mkdir -p "${outputDir}/daemons"

runAllDockerDaemons
