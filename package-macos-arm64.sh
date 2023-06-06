#!/bin/bash

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

eval "$DART pub upgrade"

OUTPUT_DIR_PATH="build/macos-arm64"
OUTPUT_DIR="$OUTPUT_DIR_PATH/sshnp"

rm -r "$OUTPUT_DIR" build/sshnp-macos-arm64.tgz
mkdir -p "$OUTPUT_DIR"

eval "$DART compile exe -o $OUTPUT_DIR/sshnpd bin/sshnpd.dart"
eval "$DART compile exe -o $OUTPUT_DIR/sshnp bin/sshnp.dart"
eval "$DART compile exe -o $OUTPUT_DIR/sshrvd bin/sshrvd.dart"
eval "$DART compile exe -o $OUTPUT_DIR/sshrv bin/sshrv.dart"
eval "$DART compile exe -o $OUTPUT_DIR/at_activate bin/activate_cli.dart"

cp -r templates $OUTPUT_DIR/templates;
cp scripts/* "$OUTPUT_DIR/";

tar czf build/sshnp-macos-arm64.tgz -C "$OUTPUT_DIR_PATH" sshnp
