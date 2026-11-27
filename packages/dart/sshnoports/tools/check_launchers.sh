#!/bin/bash
# Checks that each launcher NAME in DIR does what "DIR/atsc NAME" does: the
# same stdout and stderr, byte for byte, not both empty, and the same exit
# code, for --help and, for npt, for an option no program has.
# Usage: check_launchers.sh DIR EXT NAME...
set -u
if [ "$#" -lt 3 ]; then
  echo "usage: $0 DIR EXT NAME..." >&2
  exit 2
fi
dir=$1
ext=$2
shift 2
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
checked=0
failures=0

# Runs "DIR/NAME ARGS..." and "DIR/atsc NAME ARGS...", and reports whether
# they print the same and exit with the same code, which must be EXPECTED:
# "zero" or "nonzero".
compare() {
  local expected=$1 name=$2
  shift 2
  "$dir/$name$ext" "$@" >"$work/launcher.out" 2>"$work/launcher.err"
  local launcher=$?
  "$dir/atsc$ext" "$name" "$@" >"$work/atsc.out" 2>"$work/atsc.err"
  local atsc=$?
  checked=$((checked + 1))
  local verdict=same
  if ! cmp -s "$work/launcher.out" "$work/atsc.out" ||
    ! cmp -s "$work/launcher.err" "$work/atsc.err" ||
    { [ ! -s "$work/atsc.out" ] && [ ! -s "$work/atsc.err" ]; } ||
    [ "$launcher" -ne "$atsc" ] ||
    { [ "$expected" = zero ] && [ "$atsc" -ne 0 ]; } ||
    { [ "$expected" = nonzero ] && [ "$atsc" -eq 0 ]; }; then
    verdict=DIFFERENT
    failures=$((failures + 1))
  fi
  echo "$verdict: $name $* exits $launcher, atsc $name $* exits $atsc" \
    "($(wc -c <"$work/atsc.out" | tr -d ' ') bytes out," \
    "$(wc -c <"$work/atsc.err" | tr -d ' ') bytes err)"
  if [ "$verdict" = DIFFERENT ]; then
    diff "$work/launcher.out" "$work/atsc.out"
    diff "$work/launcher.err" "$work/atsc.err"
  fi
}

for name in "$@"; do
  compare zero "$name" --help
  if [ "$name" = npt ]; then
    compare nonzero npt --no-such-option
  fi
done

echo "checked $checked, $failures different"
[ "$checked" -gt 0 ] && [ "$failures" -eq 0 ]
