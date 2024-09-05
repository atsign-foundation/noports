#!/bin/sh

# Pull the key from the bootstrapper
cp /home/atsign/mount/"${ATSIGN}_key.atKeys" /home/atsign/.atsign/keys/

HOST="$(hostname)"
echo Using host: $HOST

# Run the NoPorts agent
/home/atsign/srvd -a "$ATSIGN" -i "$HOST" $ARGS

# Pause after a crash before restarting
sleep 5
