#!/bin/bash
# allow machine to bring up network
sleep 10
USER=$(whoami) 
export USER
while true
do
# $1 = client atSign
# $2 = device manager atSign
# $3 = device name
~/sshnp/sshnpd -a "$1" -m "$2"  -u  -d "$3" -v -s
sleep 10
done