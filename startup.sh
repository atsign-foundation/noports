#!/bin/bash
ssh-keygen -A
# echo "ListenAddress 127.0.0.1" >> /etc/ssh/sshd_config
# echo "PasswordAuthentication no" >> /etc/ssh/sshd_config
/usr/sbin/sshd -D -o "ListenAddress 127.0.0.1" -o "PasswordAuthentication no"  &
while true
do
sudo -u atsign /usr/local/at/sshnpd $*
sleep 3
done