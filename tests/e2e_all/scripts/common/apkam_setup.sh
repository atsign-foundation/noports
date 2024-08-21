#!/bin/bash

if [ -z "$testScriptsDir" ]; then
  echo -e "    ${RED}check_env: testScriptsDir is not set${NC}" && exit 1
fi

source "$testScriptsDir/common/common_functions.include.sh"
source "$testScriptsDir/common/check_env.include.sh" || exit $?

logInfo ""
logInfo "  apkam_setup starting"

# We expect the current git branch's commitId to be what the commitId variable was passed as
currentCommitId="$(git rev-parse --short HEAD)"
if ! [ "$currentCommitId" = "$commitId" ]; then
  logErrorAndExit "Current local commitId is $currentCommitId but commitId variable is $commitId"
  exit 1
fi

cd "$testRuntimeDir" || exit 1

enroll() {
  if (($# != 2)); then
    # shellcheck disable=SC2016
    logErrorAndExit 'enroll() requires 3 arguments. enroll $atSign <client|daemon>'
  fi
  atSign=$1
  which=$2
  authBinary="$(getDartCompilationOutputDir)/activate_cli"

  mkdir -p "$(getApkamKeysDir)"

  logInfo "Generating OTP for $atSign"
  # generate an OTP
  otp=$($authBinary otp -a "$atSign" -r "$atDirectoryHost") || return $?

  apkamApp=$(getApkamAppName)
  apkamDev=$(getApkamDeviceName "$which" "$commitId")
  keysFileName=$(getApkamKeysFile "$atSign" "$apkamApp" "$apkamDev")

  rm -f "$keysFileName"

  logInfo "Denying any pending enrollment requests for $atSign with apkamAppName $apkamApp and apkamDeviceName $apkamDev"
  $authBinary deny -r "$atDirectoryHost" -a "$atSign" --arx "$apkamApp" --drx "$apkamDev" || return $?

  logInfo "Revoking any approved enrollment requests for $atSign with apkamAppName $apkamApp and apkamDeviceName $apkamDev"
  $authBinary revoke -r "$atDirectoryHost" -a "$atSign" --arx "$apkamApp" --drx "$apkamDev" || return $?

  # submit enrollment request in background
  logInfo "Submitting enrollment request for $atSign with apkamAppName $apkamApp and apkamDeviceName $apkamDev"
  $authBinary enroll -r "$atDirectoryHost" -a "$atSign" \
    --app "$apkamApp" \
    --device "$apkamDev" \
    --namespaces "sshnp:rw,sshrvd:rw" \
    --keys "$keysFileName" \
    --passcode "$otp" 1>/dev/null 2>/dev/null &

  # sleep 5 seconds
  logInfo "Waiting for enrollment request to have been submitted"
  sleep 5

  # approve the enrollment
  logInfo "Approving enrollment request for $atSign with apkamAppName $apkamApp and apkamDeviceName $apkamDev"
  $authBinary approve -a "$atSign" -r "$atDirectoryHost" --drx "$apkamDev" || return $?

  # wait for the enroll process to complete
  logInfo "Waiting for enrollment to complete"
  wait

  # verify atKeys file created
  if test -f "$keysFileName"; then
    logInfo "keys file HAS been created at $keysFileName"
    return 0
  else
    logErrorAndReport "keys file has NOT been created at $keysFileName"
    return 1
  fi
}

logInfo
logInfo "Doing APKAM enrollment for $clientAtSign client"
enroll "$clientAtSign" client || exit 1

logInfo
logInfo "Doing APKAM enrollment for $daemonAtSign daemon"
enroll "$daemonAtSign" daemon || exit 1

logInfo
logInfo "apkam_setup.sh complete"

exit 0
