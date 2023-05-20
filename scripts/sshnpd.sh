#!/bin/bash
export USER=`whoami` 
while true
do
~/sshnp/sshnpd -a <atSign> -m <atSign>  -u  -d <devicename> -v -s
# To use this script for sshrv comment out the above line and un comment/edit the line below
#~/sshnp/sshrvd -a <atSign> -i <FQDN/IP>
sleep 10
done