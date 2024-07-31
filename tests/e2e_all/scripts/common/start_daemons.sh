#!/bin/bash

if [ -z "$testScriptsDir" ]; then
  echo -e "    ${RED}check_env: testScriptsDir is not set${NC}" && exit 1
fi

source "$testScriptsDir/common/common_functions.include.sh"
source "$testScriptsDir/common/check_env.include.sh" || exit $?

outputDir=$(getOutputDir)
mkdir -p "${outputDir}/daemons"

waitUntilStarted() {
  logInfo "Waiting for daemon $2 to start"
  # $1 is pid, $2 is deviceName, $3 is logFile, $4 is daemon version
  totalSleepTime=0

  while ! grep "Monitor .*monitor started" "$3"; do
    if ! ps -p "$1" >/dev/null; then
      logErrorAndReport "Daemon $2 has exited. Log file follows: "
      cat "$3"
      # Do something knowing the pid exists, i.e. the process with $PID is running
      exit 1
    fi
    sleep 1
    totalSleepTime=$((totalSleepTime + 1))
    if ((totalSleepTime > daemonStartWait)); then
      logErrorAndReport "Daemon $2 has failed to start. Log file follows: "
      cat "$3"
      exit 1
    fi
  done
}

# For each daemonVersion
# Start two daemons for each typeAndVersion
# 1) with the -u and -s flags set
# 2) with neither of those flags set
for typeAndVersion in $daemonVersions; do
  logInfo "    Starting daemons for commitId $commitId and version $typeAndVersion"

  pathToBinaries=$(getPathToBinariesForTypeAndVersion "$typeAndVersion")

  cBinary="$pathToBinaries/sshnpd"
  fRoot="--root-domain $atDirectoryHost"
  fAtSigns="-m $clientAtSign -a $daemonAtSign"
  extraFlags=""
  if [[ $(versionIsAtLeast "$typeAndVersion" "d:5.3.0") == "true" ]]; then
    apkamApp=$(getApkamAppName)
    apkamDev=$(getApkamDeviceName "daemon" "$commitId")
    keysFile=$(getApkamKeysFile "$daemonAtSign" "$apkamApp" "$apkamDev")
    extraFlags="-k $keysFile"
  fi

  deviceName=$(getDeviceNameNoFlags "$commitId" "$typeAndVersion")
  logFile="${outputDir}/daemons/${deviceName}.log"
  logInfo "      Starting daemon version $typeAndVersion with neither the -u nor -s flags"
  commandLine="$cBinary $fRoot $fAtSigns -d ${deviceName} --storage-path ${outputDir}/daemons/${deviceName}.storage -v $extraFlags"
  echo "        --> $commandLine  >& $logFile 2>&1 &"
  $commandLine >"$logFile" 2>&1 &

  waitUntilStarted $! "$deviceName" "$logFile"
  echo

  deviceName=$(getDeviceNameWithFlags "$commitId" "$typeAndVersion")
  logFile="${outputDir}/daemons/${deviceName}.log"
  logInfo "      Starting daemon version $typeAndVersion with the -u and -s flags"
  commandLine="$cBinary $fRoot $fAtSigns -d ${deviceName} --storage-path ${outputDir}/daemons/${deviceName}.storage -v -u -s $extraFlags"
  echo "        --> $commandLine  >& $logFile 2>&1 &"
  $commandLine >"$logFile" 2>&1 &
  waitUntilStarted $! "$deviceName" "$logFile"

  echo
  echo

done
