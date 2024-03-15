#!/bin/bash

# Do a git fetch, then checkout a specific commit ID

scriptName=$(basename -- "$0")
cd "$(dirname -- "$0")" || exit 1

function usage {
  echo "Usage: $scriptName -c <git short commit id>"
  exit 1
}

unset commitId

while getopts c: opt; do
  case $opt in
    c) commitId=$OPTARG ;;
    *) usage ;;
  esac
done

if [ -z "$commitId" ] ; then
  usage
fi

echo "Running git fetch"
git fetch # update the repo

echo "Checking out commitId $commitId"
git checkout "$commitId"
