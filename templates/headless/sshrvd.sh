#!/bin/bash
# allow machine to bring up network
sleep 10
USER=$(whoami) 
export USER
while true
do
# -a = atSign
# -i = FQDN/IP
~/.local/bin/sshrvd -a "$1" -i "$2"
sleep 10
done