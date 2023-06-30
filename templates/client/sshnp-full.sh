#!/bin/bash
#v2.0.0
BINARY_NAME="sshnp";
FROM="$CLIENT_ATSIGN";
TO="$DEVICE_MANAGER_ATSIGN";
HOST="$DEFAULT_HOST_ATSIGN";
PUBLIC_KEY="$SSHNP_PUBLIC_KEY";

usage() {
  "$HOME/.local/bin/$BINARY_NAME" --help | grep -v -e "(mandatory)" -v -e "FormatException";
  echo "Note: previously device name was a positional argument, please specify it with -d."
}

if [ "$#" -eq 0 ]; then
  usage;
  exit 1;
fi

if [ "$1" = "--help" ]; then
  usage;
  exit 0;
fi

"$HOME/.local/bin/$BINARY_NAME" -f "$FROM" -t "$TO" -h "$HOST" -s "$PUBLIC_KEY" "$@";