#!/bin/bash

if [ -n "$FLUTTER_ROOT" ]; then
  DART="$FLUTTER_ROOT/bin/dart"
else
  DART=$(which dart)
fi

eval "$DART pub upgrade"

rm -r build/sshnp build/sshnp-macos-arm64.tgz
mkdir -p build/sshnp

eval "$DART compile exe -o build/sshnp/sshnpd bin/sshnpd.dart"
eval "$DART compile exe -o build/sshnp/sshnp bin/sshnp.dart"
eval "$DART compile exe -o build/sshnp/sshrvd bin/sshrvd.dart"
eval "$DART compile exe -o build/sshnp/sshrv bin/sshrv.dart"
eval "$DART compile exe -o build/sshnp/at_activate bin/activate_cli.dart"

cp -r templates build/sshnp/templates;
cp scripts/* build/sshnp/;

tar czf build/sshnp-macos-arm64.tgz -C build sshnp
