#!/usr/bin/env bash
# Fails unless NPT_DISABLE_REGISTRAR_TLS_VERIFICATION is set by no tracked file
# and read once, behind kDebugMode, and the registrar client's callback, gated
# on it, is the only certificate callback in non-test Dart.
set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

define=NPT_DISABLE_REGISTRAR_TLS_VERIFICATION
declaring=packages/dart/npt_flutter/lib/features/onboarding/util/activate_util.dart
allowed=(
  "$declaring"
  packages/dart/npt_flutter/test/features/onboarding/util/activate_util_tls_test.dart
  packages/dart/npt_flutter/README.md
  .github/composite/verify_tls_verification/check.sh
)
failed=0

fail() {
  echo "::error file=$1${2:+,line=$2}::$3"
  failed=1
}

naming=$(git grep -l -F "$define") || [ $? -eq 1 ]
while IFS= read -r file; do
  [ -n "$file" ] || continue
  case " ${allowed[*]} " in
    *" $file "*) ;;
    *) fail "$file" "" "$file names $define, which only a debug build run by hand may set" ;;
  esac
done <<<"$naming"

declaration=$(perl -0777 -ne "print \$& if /^const disableRegistrarTlsVerification =\s*kDebugMode &&\s*bool\.fromEnvironment\(\s*(['\"])$define\1,?\s*\);/m" "$declaring")
reads=$(perl -0777 -ne "print scalar(() = /['\"]$define['\"]/g)" "$declaring")
if [ -z "$declaration" ] || [ "$reads" != 1 ]; then
  fail "$declaring" "" "$define must be read once, as disableRegistrarTlsVerification = kDebugMode && bool.fromEnvironment('$define')"
fi

pubspecs=$(git ls-files -- '*pubspec.yaml')
excludes=(':(exclude)tests')
while IFS= read -r pubspec; do
  root=$(dirname "$pubspec")
  [ "$root" = . ] && root= || root="$root/"
  excludes+=(":(exclude)${root}test" ":(exclude)${root}integration_test")
done <<<"$pubspecs"
case " ${excludes[*]} " in
  *" :(exclude)packages/dart/npt_flutter/test "*) ;;
  *) fail "$declaring" "" "found no package test directories to leave out" ;;
esac

callbacks=$(git grep -n -E 'badCertificateCallback|onBadCertificate' -- '*.dart' "${excludes[@]}") || [ $? -eq 1 ]
declaring_callbacks=0
while IFS= read -r hit; do
  [ -n "$hit" ] || continue
  file=${hit%%:*}
  rest=${hit#*:}
  line=${rest%%:*}
  if [ "$file" = "$declaring" ]; then
    declaring_callbacks=$((declaring_callbacks + 1))
  else
    fail "$file" "$line" "only $declaring may set a certificate callback, gated on disableRegistrarTlsVerification"
  fi
done <<<"$callbacks"
gated=$(perl -0777 -ne 'print $& if /disableRegistrarTlsVerification\s*\?\s*\(\s*HttpClient\(\)\s*\.\.badCertificateCallback\s*=/' "$declaring")
if [ "$declaring_callbacks" -gt 1 ] || { [ "$declaring_callbacks" -eq 1 ] && [ -z "$gated" ]; }; then
  fail "$declaring" "" "$declaring may set one certificate callback, gated on disableRegistrarTlsVerification"
fi

if [ "$failed" -eq 0 ]; then
  echo "$define is read once, behind kDebugMode:"
  echo "$declaration"
  echo "The only certificate callback in non-test Dart is gated on it:"
  echo "$gated"
fi
exit "$failed"
