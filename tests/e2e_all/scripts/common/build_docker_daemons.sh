#!/bin/bash

if [ -z "$testScriptsDir" ]; then
  echo -e "    ${RED}check_env: testScriptsDir is not set${NC}" && exit 1
fi

source "$testScriptsDir/common/common_functions.include.sh"
source "$testScriptsDir/common/check_env.include.sh" || exit $?


dockerfilesDir="$(dirname "$0")/../../dockerfiles"
cd "$dockerfilesDir"/../../.. # go to root of the repo

pullBaseRuntime() {
  logInfo "Pulling base runtime image"
  imageName="atsigncompany/noports_e2e_all_base_runtime:latest"
  sudo docker pull $imageName --quiet
  if [ $? -ne 0 ]; then
    logError "Failed to pull base runtime image $imageName"
    return 1
  fi
  logInfo "Successfully pulled base runtime image $imageName"
  return 0
}

buildBaseRuntime() {
  logInfo "Building Dockerfile.base.runtime"
  sudo docker build \
    -f $dockerfilesDir/Dockerfile.base.runtime \
    -t atsigncompany/noports_e2e_all_base_runtime:latest \
    --quiet \
    .
}

buildAllDockerDaemons() {
  logInfo "Building all docker daemons for $daemonVersions"
  if [ "${allowParallelization}" = "true" ]; then
    buildDockerDaemonPids=()
    for typeAndVersion in $daemonVersions; do
      # typeAndVersion is a string like "d:4.0.5" or "c:current"
      type=$(echo "$typeAndVersion" | cut -d: -f1)
      version=$(echo "$typeAndVersion" | cut -d: -f2)
      logInfo "Building docker daemon for type $type and version $version"

      buildDockerDaemon "$type" "$version" &
      pid=$!
      buildDockerDaemonPids+=($pid)
    done
    for pid in "${buildDockerDaemonPids[@]}"; do
      wait $pid
    done
  else
    for typeAndVersion in $daemonVersions; do
      # typeAndVersion is a string like "d:4.0.5" or "c:current"
      type=$(echo "$typeAndVersion" | cut -d: -f1)
      version=$(echo "$typeAndVersion" | cut -d: -f2)
      logInfo "Building docker daemon for type $type and version $version"
      buildDockerDaemon "$type" "$version"
    done
  fi
}

if ! pullBaseRuntime; then
  logInfo "Pulling base runtime failed, building it locally"
  buildBaseRuntime
fi
buildAllDockerDaemons
