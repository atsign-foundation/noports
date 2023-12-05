#!/bin/bash

# This script is used to package the macOS x64 binaries for sshnoports.
# It first unpacks the prebuilt binaries, then it calls the notarize-macos.sh
# script to notarize the binaries

FULL_PATH_TO_SCRIPT="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIRECTORY="$(dirname "$FULL_PATH_TO_SCRIPT")"
ROOT_DIRECTORY="$SCRIPT_DIRECTORY/.."

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <tgz file>"
  exit 1
fi

if [ "$(uname)" != "Darwin" ]; then
  echo "This script is only for macOS";
  exit 1;
fi

TAR_FILE="$1"

OUTPUT_DIR_PATH="$ROOT_DIRECTORY/build/windows-x64"
OUTPUT_DIR="$OUTPUT_DIR_PATH/sshnp"

rm -r "$OUTPUT_DIR_PATH"
mkdir -p "$OUTPUT_DIR"
tar -xvf "$TAR_FILE" -C "$OUTPUT_DIR_PATH"

# Zip the signed binaries
ditto -c -k --keepParent "$OUTPUT_DIR_PATH"/sshnp "$OUTPUT_DIR_PATH/sshnp-windows-x64".zip