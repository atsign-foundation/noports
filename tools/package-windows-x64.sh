#!/bin/bash

# This script is used to package the windows x64 binaries for sshnoports.
# It first unpacks the tgz archive of binaries, then it repacks them as a .zip
# This script requires that you do this packaging on a mac, since it is expected
# that you do it while notarizing the macos binaries to save time

# This script expects the path to the tgz archive as an argument

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