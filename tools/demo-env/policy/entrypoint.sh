#!/bin/sh

# Pull the key from the bootstrapper
cp /home/atsign/mount/"${ATSIGN}_key.atKeys" /home/atsign/.atsign/keys/

# Run the NoPorts Policy binary
/home/atsign/npp -a "${ATSIGN}" ${ARGS} &
/home/atsign/admin_api -a "${ATSIGN}" ${API_ARGS}

# Pause after a crash before restarting
sleep 5
