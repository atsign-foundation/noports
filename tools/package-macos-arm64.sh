#!/bin/bash

FULL_PATH_TO_SCRIPT="$(realpath "${BASH_SOURCE[0]}")"
SCRIPT_DIRECTORY="$(dirname "$FULL_PATH_TO_SCRIPT")"
ROOT_DIRECTORY="$SCRIPT_DIRECTORY/.."
SRC_DIR="$ROOT_DIRECTORY/packages/sshnoports"

if [ "$(uname)" != "Darwin" ]; then
  echo "This script is only for macOS";
  exit 1;
fi

if [ "$(uname -m)" != "arm64" ]; then
  echo "This script is only for Apple Silicon";
  exit 1;
fi

if [ -n "$FLUTTER_ROOT" ]; then
  DART="$FLUTTER_ROOT/bin/dart"
else
  DART=$(which dart)
fi

eval "$DART pub get -C $SRC_DIR"

OUTPUT_DIR_PATH="$ROOT_DIRECTORY/build/macos-arm64"
OUTPUT_DIR="$OUTPUT_DIR_PATH/sshnp"

rm -r "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

eval "$DART compile exe -o $OUTPUT_DIR/sshnpd $SRC_DIR/bin/sshnpd.dart"
eval "$DART compile exe -o $OUTPUT_DIR/sshnp $SRC_DIR/bin/sshnp.dart"
eval "$DART compile exe -o $OUTPUT_DIR/sshrvd $SRC_DIR/bin/sshrvd.dart"
eval "$DART compile exe -o $OUTPUT_DIR/sshrv $SRC_DIR/bin/sshrv.dart"
eval "$DART compile exe -o $OUTPUT_DIR/at_activate $SRC_DIR/bin/activate_cli.dart"

cp -r "$SRC_DIR/templates" "$OUTPUT_DIR/templates";
cp "$SRC_DIR"/scripts/* "$OUTPUT_DIR/";
