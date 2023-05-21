#!/bin/bash
# allow machine to bring up network
sleep 10
export USER=`whoami` 
while true
do
~/sshnp/sshnpd -a <atSign> -m <atSign>  -u  -d <devicename> -v -s
sleep 10
done