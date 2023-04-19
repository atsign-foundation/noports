#!/bin/bash
ssh-keygen -A
dhclient
/usr/sbin/sshd -D -o "ListenAddress 127.0.0.1" -o "PasswordAuthentication no"  &
while true
do
sudo -u atsign /usr/local/at/sshnpd $*
sleep 3
done