#!/bin/bash

if [ -z "$testScriptsDir" ]; then
  echo -e "    ${RED}check_env: testScriptsDir is not set${NC}" && exit 1
fi

source "$testScriptsDir/common/common_functions.include.sh"
source "$testScriptsDir/common/check_env.include.sh" || exit $?

dockerfilesDir="$(dirname "$0")/../../dockerfiles"
cd "$dockerfilesDir"/../../.. # go to root of the repo

baseImageName=$(getBaseRuntimeImageName)

doesImageExist() {
  imageName="$1" # e.g. "atsigncompany/noports_e2e_all_base_runtime:latest"
  sudo docker image inspect "$imageName" > /dev/null 2>&1
  if [ $? -eq 0 ]; then
    echo "true"
  else
    echo "false"
  fi
}

pullBaseRuntimeImage() {
  logInfo "Pulling base runtime image"
  sudo docker pull $baseRuntimeImageName --quiet
  if [ $? -ne 0 ]; then
    logError "Failed to pull base runtime image $baseRuntimeImageName"
    return 1
  fi
  logInfo "Successfully pulled base runtime image $baseRuntimeImageName"
  return 0
}

buildBaseRuntimeImage() {
  logInfo "Building Dockerfile.base.runtime"
  sudo docker build \
    -f $dockerfilesDir/Dockerfile.base.runtime \
    -t $baseRuntimeImageName \
    --quiet \
    .
}

buildDockerDaemonsInParallel() {
  logInfo "Building all docker daemons for $daemonVersions in parallel"
  pids=()
  for typeAndVersion in $daemonVersions; do
    # typeAndVersion is a string like "d:4.0.5" or "c:current"
    type=$(echo "$typeAndVersion" | cut -d: -f1)
    version=$(echo "$typeAndVersion" | cut -d: -f2)

    imageName=$(getDockerDaemonImageName "$type" "$version")
    if [[ "$recompile" == "false" && "$(doesImageExist "$imageName")" == "true" ]]; then
      logInfo "You set recompile = $recompile and $imageName already exists, so skipping build for $typeAndVersion"
      continue
    fi

    logInfo "Building docker daemon for type $type and version $version"
    buildDockerDaemon "$type" "$version" &
    pid=$!
    buildDockerDaemonPids+=($pid)
  done
  for pid in "${buildDockerDaemonPids[@]}"; do
    wait $pid
  done
}

buildDockerDaemonsInSequence() {
  logInfo "Building all docker daemons for $daemonVersions sequentially"
  for typeAndVersion in $daemonVersions; do
    # typeAndVersion is a string like "d:4.0.5" or "c:current"
    type=$(echo "$typeAndVersion" | cut -d: -f1)
    version=$(echo "$typeAndVersion" | cut -d: -f2)
    imageName=$(getDockerDaemonImageName "$type" "$version")
    if [ "$(doesImageExist "$imageName")" = "true" ] && [ "$recompile" = "false" ]; then
      logInfo "You set recompile = $recompile (using -n) and $imageName already exists, so skipping build for $typeAndVersion"
      continue
    fi

    logInfo "Building docker daemon for type $type and version $version"
    buildDockerDaemon "$type" "$version"
  done
}

buildDockerPolicyInParallel() {
  logInfo "Building all docker policy images for $policyVersions in parallel"
  for typeAndVersion in $policyVersions; do # e.g. "d:current d:5.14.10"
    type=$(echo "typeAndVersion" | cut -d: -f1) # get the type e.g. "d"
    version=$(echo "$typeAndVersion" | cut -d: -f2) # "5.14.10"
    imageName=$(getDockerPolicyImageName "$type" "$version")
    if [ "$(doesImageExist "$imageName")" = "true" ] && [ "$recompile" = "false" ]; then
      logInfo "You set recompile = $recompile (using -n) and $imageName already exists, so skipping build for $typeAndVersion"
      continue
    fi
    logInfo "Building docker daemon for type $type and version $version"
    buildDockerPolicy "$type" "$version"
  done
}

buildDockerPolicyInSequence() {
  logInfo "Building all docker policy images for $policyVersions sequentially"
}

if [ "$(doesImageExist "$baseRuntimeImageName")" = "false" ]; then
  logInfo "Base runtime image not found, building it locally"
  buildBaseRuntimeImage
fi

if [ "${allowParallelization}" = "true" ]; then
  # build in parallel
  buildDockerDaemonsInParallel
  buildDockerPolicyInParallel
else
  # build sequentially
  buildDockerDaemonsInSequence
  buildDockerPolicyInSequence
fi
