#!/bin/bash

# This script is used to package the macOS arm64 binaries for sshnoports.
# It first builds the binaries using dart compile, then copies the templates
# and LICENSE file to the output directory.
# Then it calls the notarize-macos.sh script to notarize the binaries

FULL_PATH_TO_SCRIPT="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIRECTORY="$(dirname "$FULL_PATH_TO_SCRIPT")"
ROOT_DIRECTORY="$SCRIPT_DIRECTORY/.."
SRC_DIR="$ROOT_DIRECTORY/packages/sshnoports"

if [ "$#" -ne 0 ]; then
  echo "Usage: $0"
  exit 1
fi

if [ "$(uname)" != "Darwin" ]; then
  echo "This script is only for macOS";
  exit 1;
fi

if [ "$(uname -m)" != "arm64" ]; then
  echo "This script can only be run on an Apple Silicon device";
  exit 1;
fi

if [ -n "$FLUTTER_ROOT" ]; then
  DART="$FLUTTER_ROOT/bin/dart"
else
  DART=$(which dart)
fi

restore_backup_and_exit() {
  mv "$SRC_DIR/pubspec_overrides.back.yaml" "$SRC_DIR/pubspec_overrides.yaml"
  exit "$1"
}

mv "$SRC_DIR/pubspec_overrides.yaml" "$SRC_DIR/pubspec_overrides.back.yaml"
eval "$DART pub get -C $SRC_DIR" || restore_backup_and_exit 1

OUTPUT_DIR_PATH="$ROOT_DIRECTORY/build/macos-arm64"
OUTPUT_DIR="$OUTPUT_DIR_PATH/sshnp"

rm -r "$OUTPUT_DIR_PATH"
mkdir -p "$OUTPUT_DIR/debug"

eval "$DART compile exe -o $OUTPUT_DIR/sshnpd $SRC_DIR/bin/sshnpd.dart"
eval "$DART compile exe -o $OUTPUT_DIR/sshnp $SRC_DIR/bin/sshnp.dart"
eval "$DART compile exe -o $OUTPUT_DIR/sshrvd $SRC_DIR/bin/sshrvd.dart"
eval "$DART compile exe -o $OUTPUT_DIR/sshrv $SRC_DIR/bin/sshrv.dart"
eval "$DART compile exe -o $OUTPUT_DIR/at_activate $SRC_DIR/bin/activate_cli.dart"
eval "$DART compile exe -o $OUTPUT_DIR/debug/sshrvd -D ENABLE_SNOOP=true $SRC_DIR/bin/sshrvd.dart"

cp -r "$SRC_DIR/bundles/core"/* "$OUTPUT_DIR/";
cp -r "$SRC_DIR/bundles/shell"/* "$OUTPUT_DIR/";
cp "$SRC_DIR"/LICENSE "$OUTPUT_DIR/";

"$SCRIPT_DIRECTORY/notarize-macos.sh" "$OUTPUT_DIR_PATH" sshnp-macos-arm64

restore_backup_and_exit 0
