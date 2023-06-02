#!/bin/bash
BINARY="/usr/local/bin/sshnp";
# -f = client atSign ("from")
# -t = device manager atSign ("to")
# -h = host rendezvous server atSign (SRS)
# -d = device name
eval "$BINARY -f $1 -t $2 -h $3 -d $4";