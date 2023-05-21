#!/bin/bash
# allow machine to bring up network
sleep 10
export USER=`whoami` 
while true
do
~/sshnp/sshrvd -a <atSign> -i <FQDN/IP>
sleep 10
done