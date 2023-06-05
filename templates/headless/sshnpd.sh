#!/bin/bash
#v1.0.0
# allow machine to bring up network
sleep 10
USER=$(whoami)
export USER
while true
do
# -a = client atSign
# -m = device manager atSign
# -d = device name
$HOME/.local/bin/sshnpd -a "$1" -m "$2"  -u  -d "$3" -v -s
sleep 10
done