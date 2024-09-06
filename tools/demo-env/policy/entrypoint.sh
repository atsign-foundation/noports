#!/bin/sh

# Pull the key from the bootstrapper
cp /home/atsign/mount/"${ATSIGN}_key.atKeys" /home/atsign/.atsign/keys/

# Run the NoPorts Policy binary
/home/atsign/npp_atserver -a "${ATSIGN}" ${ARGS} &
/home/atsign/np_admin -a "${ATSIGN}" ${API_ARGS}

# Pause after a crash before restarting
sleep 5
