#!/bin/bash
#v1.0.0
BINARY_NAME="sshnp";
FROM="$CLIENT_ATSIGN";
TO="$DEVICE_MANAGER_ATSIGN";
HOST="$DEFAULT_HOST_ATSIGN";
PUBLIC_KEY="$SSHNP_PUBLIC_KEY";

usage() {
  echo "Usage: sshnp$DEVICE_MANAGER_ATSIGN [-h <host>] <device name>";
}

parse_args() {
  while [ $# -gt 0 ]; do
    case "$1" in
    -h|--host)
      if [ $# -lt 0 ]; then
        echo "Missing argument for $1";
        exit 1;
      fi
      HOST="$2"
      shift 2
      ;;
    *)
      SSHNP_DEVICE="$1"
      shift
      ;;
    esac
    shift
  done
  if [ -z "$SSHNP_DEVICE" ]; then
    echo "No device specified";
    usage;
    exit 1;
  fi
}

parse_args "$@";
# -f = client atSign ("from")
# -t = device atSign ("to")
# -h = host rendezvous server atSign (SRS)
# -d = device name
eval "$HOME/.local/bin/$BINARY_NAME -f $FROM -t $TO -h $HOST -d $SSHNP_DEVICE" -s "$PUBLIC_KEY";