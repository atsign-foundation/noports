#!/bin/bash
export USER=`whoami` 
while true
do
~/sshnp/sshrvd -a <atSign> -i <FQDN/IP>
sleep 10
done