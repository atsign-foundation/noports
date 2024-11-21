NC='\033[0m'
BOLD='\033[1m'
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
BBLUE='\033[1;34m'

authKeysFile="$HOME/.ssh/authorized_keys"

### BEGIN GENERAL ###

getApkamAppName() {
  echo "e2e_all"
}

getApkamDeviceName() {
  if (($# != 2)); then
    # shellcheck disable=SC2016
    logErrorAndExit 'getApkamDeviceName requires 2 arguments: <client|daemon> $commitId'
  fi
  which="$1"
  commitId="$2"
  echo "${which}_${commitId}"
}

getApkamKeysDir() {
  echo "$testRuntimeDir"/apkam
}

getApkamKeysFile() {
  if (($# != 3)); then
    # shellcheck disable=SC2016
    logErrorAndExit 'getApkamKeysFile requires 3 arguments: $atSign $apkamAppName $apkamDeviceName'
  fi
  keysDir=$(getApkamKeysDir)
  atSign="$1"
  apkamApp="$2"
  apkamDev="$3"
  echo "$keysDir"/"$atSign"."$apkamApp"."$apkamDev".atKeys
}

getBaseSshnpCommand() {
  if (($# != 1)); then
    logErrorAndExit "getBaseSshnpCommand requires 1 argument (clientBinaryPath)"
  fi
  clientBinaryPath="$1"
  l1="$clientBinaryPath/sshnp -f $clientAtSign -d $deviceName -i $identityFilename"
  if [ "$(versionIsLessThan "$daemonVersion" "d:5.2.0")" ]; then
    l2=" -t $daemonAtSign -h $srvAtSign -u $remoteUsername"
  else
    l2=" -t $daemonAtSign -r $srvAtSign -u $remoteUsername"
  fi
  l3=" --root-domain $atDirectoryHost"
  echo "$l1" "$l2" "$l3"
}

getBaseNptCommand() {
  if (($# < 1 || $# > 2)); then
      logErrorAndExit "getBaseNptCommand requires 1 mandatory argument (clientBinaryPath) and optionally a second argument (encryptRvdTraffic)"
  fi
  clientBinaryPath="$1"
  l1="$clientBinaryPath/npt -f $clientAtSign -d $deviceName"
  l2=" -t $daemonAtSign -r $srvAtSign"
  l3=" --root-domain $atDirectoryHost"
  if [ -z "$2" ]; then
    echo "$l1" "$l2" "$l3"
  else
    echo "$l1" "$l2" "$l3" "$2"
  fi
}

getTestSshCommand() {
  testSshCommand="$1"

  # shellcheck disable=SC2016
  remoteCommand='echo `date` `whoami` `hostname` TEST PASSED'
  testSshCommand="${testSshCommand} $remoteCommand"
  # shellcheck disable=SC2086
  echo $testSshCommand
}

backupAuthorizedKeys() {
  authKeysFileBackup="$authKeysFile.before.commit.${commitId}"
  rm -f "$authKeysFileBackup"
  cp -p "$authKeysFile" "$authKeysFileBackup"
}

restoreAuthorizedKeys() {
  authKeysFileBackup="$authKeysFile.before.commit.${commitId}"
  if test -f "$authKeysFileBackup"; then
    rm -f "$authKeysFile"
    mv "$authKeysFileBackup" "$authKeysFile"
  fi
}

generateNewSshKey() {
  mkdir -p "$HOME/.ssh"
  chmod go-rwx "$HOME/.ssh"
  touch "$authKeysFile"
  chmod go-rwx "$authKeysFile"

  logInfo "Generating test ssh keypair"
  ssh-keygen -t ed25519 -q -N '' -f "${identityFilename}" -C "$commitId" <<<y >/dev/null 2>&1
}

getOutputDir() {
  echo "/tmp/e2e_all/${commitId}"
}
getReportFile() {
  echo "/tmp/e2e_all/${commitId}.test.report"
}

getDeviceNameNoFlags() {
  if (($# != 2)); then
    logErrorAndReport "getDeviceNameNoFlags expects two parameters; $# were supplied"
    exit 1
  fi
  commitId="$1"
  typeAndVersion="$2"
  IFS=: read -r type version <<<"$typeAndVersion"
  versionForDeviceName=$(echo "$version" | tr -d ".")
  if test "$versionForDeviceName" = "current"; then
    versionForDeviceName="c"
  fi
  echo "${commitId}${type}${versionForDeviceName}"
}

getDeviceNameWithFlags() {
  if (($# != 2)); then
    logErrorAndReport "getDeviceNameFlags expects two parameters; $# were supplied"
    exit 1
  fi
  # shellcheck disable=SC2086
  echo "$(getDeviceNameNoFlags $1 $2)f"
}

# Calling this "OS" unsets the environment variable of the same name thus it is named "cachedOS" to avoid side effects
cachedOS=""
iso8601Date() {
  if test "$cachedOS" == ""; then
    cachedOS=$(uname -s)
  fi
  if test "$cachedOS" == "Darwin"; then
    # no milliseconds in Darwin
    date +"%Y-%m-%d %H:%M:%S"
  else
    date +"%Y-%m-%d %H:%M:%S.%3N"
  fi
}

log() {
  echo -e "$(iso8601Date) | $1"
}

logInfo() {
  log "$1"
}

logGreenInfo() {
  log "${GREEN}INFO :${NC} $1"
}

logError() {
  log "${RED}ERROR:${NC} $1"
}

logWarning() {
  echo -e "$(iso8601Date) |     ${ORANGE}WARN :${NC} $1"
}

logInfoAndReport() {
  logInfo "$1" | tee -a "$(getReportFile)"
}

logErrorAndReport() {
  logError "$1" | tee -a "$(getReportFile)"
}

logErrorAndExit() {
  logErrorAndReport "$1"
  exit 1
}

crLog() {
  echo -e "\r$(iso8601Date) | $1"
}

getBaseFileName() {
  # expected input: $testToRun $daemonVersion $clientVersion
  printf "$(getOutputDir)/clients/${1}.daemon.${2}.client.${3}"
}

getDaemonLogFragmentName() {
  # expected input: $testToRun $daemonVersion $clientVersion
  printf "$(getBaseFileName $1 $2 $3).daemonLogFragment.log"
}

getSingleTestOutputLogName() {
  printf "$(getBaseFileName $1 $2 $3).testOutput.log"
}

getSingleTestResultLogName() {
  printf "$(getBaseFileName $1 $2 $3).testResult.log"
}

getVersionDescription() {
  if (($# != 1)); then logErrorAndExit "getVersionDescription requires 1 parameter"; fi
  IFS=: read -r type version <<<"$1"
  case $type in
    d) desc="Dart " ;;
    c) desc="C" ;;
    *) desc="$type (?) " ;;
  esac
  case $version in
    current) desc="${desc} (branch)" ;;
    *) desc="${desc} v${version}" ;;
  esac
  echo "$desc"
}
versionIsLessThan() {
  actualTypeAndVersion="$1"
  typeAndVersionList="$2"
  IFS=: read -r aType aVersion <<<"$actualTypeAndVersion"

  IFS=. read -r aMaj aMin aPat <<<"$aVersion"

  for rtv in $typeAndVersionList; do
    IFS=: read -r rType rVersion <<<"$rtv"
    if [[ "$aType" == "$rType" ]]; then
      if [[ "$aVersion" == "current" ]]; then
        # actual version 'current' is never less than anything
        echo "false"
        return
      fi

      IFS=. read -r rMaj rMin rPat <<<"$rVersion"
      if ((aMaj < rMaj)); then
        echo "true"
        return
      fi
      if ((aMaj > rMaj)); then
        echo "false"
        return
      fi

      # major versions are the same - compare minor versions
      if ((aMin < rMin)); then
        echo "true"
        return
      fi
      if ((aMin > rMin)); then
        echo "false"
        return
      fi

      # minor versions are the same - compare patch versions
      if ((aPat < rPat)); then
        echo "true"
        return
      else
        echo "false"
        return
      fi
    fi
  done

  # If we didn't return during the loop above, then we return false
  echo "false"
}

versionIsAtLeast() {
  # Given actual of "type_1:5.0.2" and required of "type_1:4.0.5 type_2:4.0.1
  # We find the 'type_1:' entry in the required list
  #   return FALSE if there is no 'type_1:' entry
  #   return FALSE if the actual version is >= the required version
  #   return TRUE if not
  actualTypeAndVersion="$1"
  typeAndVersionList="$2"
  IFS=: read -r aType aVersion <<<"$actualTypeAndVersion"

  IFS=. read -r aMaj aMin aPat <<<"$aVersion"

  # for required in required list
  for rtv in $typeAndVersionList; do
    IFS=: read -r rType rVersion <<<"$rtv"
    if [[ "$aType" == "$rType" ]]; then
      if [[ "$aVersion" == "current" ]]; then
        # actual version 'current' is always at least what is required
        echo "true"
        return
      fi

      IFS=. read -r rMaj rMin rPat <<<"$rVersion"
      if ((aMaj < rMaj)); then # not at required major version
        echo "false"
        return
      fi
      if ((aMaj > rMaj)); then # beyond the required major version
        echo "true"
        return
      fi

      # major versions are the same - compare minor versions
      if ((aMin < rMin)); then # not at required minor version
        echo "false"
        return
      fi
      if ((aMin > rMin)); then
        echo "true"
        return
      fi

      # minor versions are the same - compare patch versions
      if ((aPat < rPat)); then # not at required patch version
        echo "false"
        return
      else
        echo "true"
        return
      fi
    fi
  done

  # If we didn't return during the loop above, then we return false
  echo "false"
}

# if test isLessThan "$daemonVersion" "d:5.0.0"; then

getPathToBinariesForTypeAndVersion() {
  if (($# != 1)); then
    logErrorAndReport "getPathToBinariesForTypeAndVersion expects one parameter, but was supplied $#"
    exit 1
  fi
  typeAndVersion="$1"
  IFS=: read -r type version <<<"$typeAndVersion"

  case "$version" in
    current)
      case "$type" in
        d) # dart
          getDartCompilationOutputDir
          ;;
        c)
          getCCompilationOutputDir
          ;;
        *)
          logErrorAndExit "Don't know how to getPathToBinariesForTypeAndVersion for $typeAndVersion"
          ;;
      esac
      ;;
    *)
      case "$type" in
        d) # dart
          getDartReleaseBinDirForVersion "$version"
          ;;
        # c);; # Not supported yet (soon)
        *)
          logErrorAndExit "Don't know how to getPathToBinariesForTypeAndVersion for $typeAndVersion"
          ;;
      esac
      ;;
  esac
}

### END OF GENERAL ###
### BEGIN DART ###

getDartCompilationOutputDir() {
  echo "$testRuntimeDir/binaries/dart.branch"
}

getDartReleaseDirForVersion() {
  version="$1"
  echo "$testRootDir/releases/dart.$version"
}

getDartReleaseBinDirForVersion() {
  version="$1"
  echo "$testRootDir/releases/dart.$version/sshnp"
}

setupDartVersion() {
  version="$1"

  if test "$version" = "current"; then
    buildCurrentDartBinaries || exit $?
  else
    downloadDartBinaries "$version" || exit $?
  fi
}

buildCurrentDartBinaries() {
  compileVerbosity=error

  logInfo "    Compiling Dart binaries for current git commitId $commitId"

  binaryOutputDir=$(getDartCompilationOutputDir)
  mkdir -p "$binaryOutputDir"

  if [ "$recompile" = "true" ]; then
    cd "$binaryOutputDir" || exit 1
    rm -f activate_cli srv sshnpd srvd sshnp npt
  fi

  binarySourceDir="$repoRootDir/packages/dart/sshnoports"
  if ! [ -d "$binarySourceDir" ]; then
    logErrorAndExit "Directory $binarySourceDir does not exist. Has package structure changed? "
    exit 1
  fi
  cd "$binarySourceDir" || exit 1

  logInfo "    dart pub get"
  dart pub get || exit 1

  if [ -f "$binaryOutputDir/activate_cli" ]; then
    logInfo "        $binaryOutputDir/activate_cli has already been compiled"
  else
    logInfo "        Compiling activate_cli"
    dart compile exe --verbosity "$compileVerbosity" bin/activate_cli.dart -o "$binaryOutputDir/activate_cli"
  fi

  if [ -f "$binaryOutputDir/srv" ]; then
    logInfo "        $binaryOutputDir/srv has already been compiled"
  else
    logInfo "        Compiling srv"
    dart compile exe --verbosity "$compileVerbosity" bin/srv.dart -o "$binaryOutputDir/srv"
  fi

  if [ -f "$binaryOutputDir/sshnpd" ]; then
    logInfo "        $binaryOutputDir/sshnpd has already been compiled"
  else
    logInfo "        Compiling sshnpd"
    dart compile exe --verbosity "$compileVerbosity" bin/sshnpd.dart -o "$binaryOutputDir/sshnpd"
  fi

  if [ -f "$binaryOutputDir/srvd" ]; then
    logInfo "        $binaryOutputDir/srvd has already been compiled"
  else
    logInfo "        Compiling srvd"
    dart compile exe --verbosity "$compileVerbosity" bin/srvd.dart -o "$binaryOutputDir/srvd"
  fi

  if [ -f "$binaryOutputDir/sshnp" ]; then
    logInfo "        $binaryOutputDir/sshnp has already been compiled"
  else
    logInfo "        Compiling sshnp"
    dart compile exe --verbosity "$compileVerbosity" bin/sshnp.dart -o "$binaryOutputDir/sshnp"
  fi

  if [ -f "$binaryOutputDir/npt" ]; then
    logInfo "        $binaryOutputDir/npt has already been compiled"
  else
    logInfo "        Compiling npt"
    dart compile exe --verbosity "$compileVerbosity" bin/npt.dart -o "$binaryOutputDir/npt"
  fi

  cp "$testScriptsDir/srv.sh" "$binaryOutputDir/srv.sh"
}

downloadDartBinaries() {
  version="$1"

  versionBinDir=$(getDartReleaseDirForVersion "$version")
  mkdir -p "$versionBinDir"
  # https://github.com/atsign-foundation/noports/releases/download/v4.0.5/sshnp-macos-arm64.zip
  # https://github.com/atsign-foundation/noports/releases/download/v4.0.5/sshnp-linux-x64.tgz

  #   Check if $versionBinDir contains the zip
  #   If it contains the zip, check that the binaries have been unzipped
  #   If binaries have not been unzipped, unzip them
  downloadZipName="sshnp-$OS-$ARCH.$EXT"
  logInfo "    Getting binaries for Dart release $version"

  if [ -f "$versionBinDir/$downloadZipName" ]; then
    logInfo "        $versionBinDir/$downloadZipName has already been downloaded"
  else
    baseUrl="https://github.com/atsign-foundation/noports/releases/download"
    downloadUrl="$baseUrl/v$version/$downloadZipName"
    logInfo "        Downloading $downloadUrl to $versionBinDir/$downloadZipName"
    curl -f -s -L -X GET "$downloadUrl" -o "$versionBinDir/$downloadZipName"
    retCode=$?
    if test "$retCode" != 0; then
      logErrorAndExit "Failed to download $downloadUrl with curl exit status $retCode"
    fi
  fi

  # Unzip if not already unzipped
  if ! [ -d "$versionBinDir/sshnp" ]; then
    case "$EXT" in
      zip)
        unzip -qo "$versionBinDir/$downloadZipName" -d "$versionBinDir"
        ;;
      tgz | tar.gz)
        tar -zxf "$versionBinDir/$downloadZipName" -C "$versionBinDir"
        ;;
    esac
  fi

  #   Symbolic link the releases/$version/binaries into this commit's runtime/binaries directory
  rm -f "${testRuntimeDir}/binaries/dart.${version}"
  ln -s "$versionBinDir/sshnp" "${testRuntimeDir}/binaries/dart.${version}"
}

### END DART ###
### BEGIN C ###

getCCompilationOutputDir() {
  echo "$testRuntimeDir/binaries/c.branch"
}

setupCVersion() {
  version="$1"

  if test "$version" = "current"; then
    buildCurrentCBinaries || exit $?
  else
    logErrorAndExit "Versions other than 'current' are unimplemented for C"
    # downloadDartBinaries "$version" || exit $?
  fi
}

buildCurrentCBinaries() {
  compileVerbosity=error

  logInfo "    Compiling C binaries for current git commitId $commitId"

  binaryOutputDir=$(getCCompilationOutputDir)
  mkdir -p "$binaryOutputDir"

  if [ "$recompile" = "true" ]; then
    cd "$binaryOutputDir" || exit 1
    rm -f activate_cli srv sshnpd srvd sshnp npt
  fi

  binarySourceDir="$repoRootDir/packages/c"
  if ! [ -d "$binarySourceDir" ]; then
    logErrorAndExit "Directory $binarySourceDir does not exist. Has package structure changed? "
  fi
  cd "$binarySourceDir" || exit 1

  if ! command -v cmake 2>/dev/null; then
    logErrorAndExit "cmake is required to build c:current binaries"
  fi

  # We shouldn't need this binary for any e2e tests right now, but leaving this here in case we do
  # if [ -f "$binaryOutputDir/srv" ]; then
  #   logInfo "        $binaryOutputDir/srv has already been compiled"
  # else
  #   logInfo "        Compiling srv"
  #   local base_dir="./srv"
  #   local build_dir="$base_dir/build"
  #   cmake -B $build_dir -S $base_dir
  #   cmake --build $build_dir
  #   cp $build_dir/srv "$binaryOutputDir/"
  # fi

  if [ -f "$binaryOutputDir/sshnpd" ]; then
    logInfo "        $binaryOutputDir/sshnpd has already been compiled"
  else
    logInfo "        Compiling sshnpd"
    local base_dir="./sshnpd"
    local build_dir="$base_dir/build"
    mkdir -p "$build_dir"
    cmake -B $build_dir -S $base_dir -DCMAKE_C_COMPILER=gcc -DCMAKE_C_FLAGS="-Wall -Wextra -Werror-implicit-function-declaration" -DBUILD_TESTS=off
    cmake --build $build_dir
    if [ $? -ne 0 ]; then
      logErrorAndExit "cmake build failed"
    fi
    cp $build_dir/sshnpd "$binaryOutputDir/"
  fi

  cp "$testScriptsDir/srv.sh" "$binaryOutputDir/srv.sh"
}

### END C ###

setup_type_and_version() {
  IFS=: read -r type version <<<"$1"
  case "$type" in
    d) # dart
      setupDartVersion "$version" || logErrorAndExit "Failed to set up binaries for dart version [$version]"
      ;;
    c) # c
      setupCVersion "$version" || logErrorAndExit "Failed to set up binaries for c version [$version]"
      ;;
    *)
      logErrorAndExit "This script doesn't know where to find NoPorts daemon binary for [$typeAndVersion]"
      exit 1
      ;;
  esac
}
