#!/bin/bash

if [ -z "$testScriptsDir" ]; then
  echo -e "    ${RED}check_env: testScriptsDir is not set${NC}" && exit 1
fi

source "$testScriptsDir/common/common_functions.include.sh"
source "$testScriptsDir/common/check_env.include.sh" || exit $?

logInfo ""
logInfo "  setup_binaries starting"

# We expect the current git branch's commitId to be what the commitId variable was passed as
currentCommitId="$(git rev-parse --short HEAD)"
if ! [ "$currentCommitId" = "$commitId" ]; then
  logErrorAndExit "Current local commitId is $currentCommitId but commitId variable is $commitId"
  exit 1
fi

cd "$testRuntimeDir" || exit 1

mkdir -p "$testRuntimeDir"/binaries

operatingSystem=$(uname -s)
# This script supports Linux and Ubuntu
if [ "$operatingSystem" = "Linux" ]; then
  logInfo "    Operating system is linux"
  OS="linux"
  EXT="tgz"
elif [ "$operatingSystem" = "Darwin" ]; then
  logInfo "    Operating system is macos"
  OS="macos"
  EXT="zip"
else
  logErrorAndExit "This script doesn't know how to download binaries for this operating system ($operatingSystem)"
  exit 1
fi

case "$(uname -m)" in
  aarch64 | arm64)
    ARCH="arm64"
    ;;
  x86_64 | amd64)
    ARCH="x64"
    ;;
  armv7l | arm)
    ARCH="NotHandled"
    ;;
  riscv64)
    ARCH="NotHandled"
    ;;
  *) ARCH="NotHandled" ;;
esac

if [ "$ARCH" = "NotHandled" ]; then
  logErrorAndExit "This script doesn't know how to download binaries for this platform ($(uname -m)"
  exit 1
fi

logInfo "    Architecture is $ARCH"

logInfo "    Exporting OS ($OS) ARCH ($ARCH) and EXT ($EXT)"
export OS ARCH EXT

allVersions="$daemonVersions $clientVersions"
uniqueVersions=$(for ver in $allVersions; do echo "$ver"; done | sort -u | tr "\n" " ")

# Binaries for named versions will not be re-downloaded but will be linked
for typeAndVersion in $uniqueVersions; do
  IFS=: read -r type version <<<"$typeAndVersion"
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
done
