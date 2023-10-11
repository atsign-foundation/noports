#!/bin/bash

if [ "$(uname)" != "Darwin" ]; then
  echo "This script is only for macOS";
  exit 1;
fi

if [ $# -ne 2 ];  then
  echo "Usage: $0 <working directory> <output filename>"
  echo "Example: $0 build/macos-x64 sshnp-macos-x64"
  echo
  echo "<working directory> is the parent directory of the 'sshnp' directory"
  echo "All assets must be contained in <working directory>/sshnp"
  echo
  echo "<output filename> is the name of the output file without the extension"
  echo "The output file will be a zip file with the path <working directory>/<output filename>.zip"
  exit 1
fi

FULL_PATH_TO_SCRIPT="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIRECTORY="$(dirname "$FULL_PATH_TO_SCRIPT")"

WORKING_DIR=$1
OUTPUT_FILE=$2


if [ -z "$WORKING_DIR" ]; then
  echo "Usage: $0 <working directory>"
  exit 1
fi

# Get the environment variables
set -o allexport
# Disable SC1091 because we don't want to pass the env file as an argument to this script
# we instead assume that it is in the same directory as this script
# shellcheck disable=SC1091
source "$SCRIPT_DIRECTORY"/macos-signing.env
set +o allexport

if [ -z "$SIGNING_IDENTITY" ]; then
  echo "You must set either SIGNING_IDENTITY in macos-signing.env"
  exit 1
fi

if [ -z "$KEYCHAIN_PROFILE" ] && [[ -z "$APPLE_ID" || -z "$TEAM_ID" || -z "$PASSWORD" ]]; then
  echo "You must set either KEYCHAIN_PROFILE or APPLE_ID, TEAM_ID, and PASSWORD in macos-signing.env"
  exit 1
fi

# Sign the binaries
codesign \
  --timestamp \
  --prefix \
  --identifier \
  --entitlements "$SCRIPT_DIRECTORY"/templates/entitlements.plist \
  --options=runtime \
  -s "$SIGNING_IDENTITY" \
  -v \
  "$WORKING_DIR"/sshnp/{ssh*,at_activate};

echo Verifying signatures:
codesign -vvv --deep --strict "$WORKING_DIR"/sshnp/{ssh*,at_activate};

# Zip the signed binaries
ditto -c -k --keepParent "$WORKING_DIR"/sshnp "$WORKING_DIR/$OUTPUT_FILE".zip


# Submit the zip for notarization
if [ -n "$KEYCHAIN_PROFILE" ]; then
  xcrun notarytool submit "$WORKING_DIR/$OUTPUT_FILE".zip\
  --keychain-profile "$KEYCHAIN_PROFILE" \
  --wait
else
  xcrun notarytool submit "$WORKING_DIR/$OUTPUT_FILE".zip \
  --apple-id "$APPLE_ID" \
  --team-id "$TEAM_ID" \
  --password "$PASSWORD" \
  --wait
fi
