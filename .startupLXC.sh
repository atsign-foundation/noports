#!/bin/bash
ssh-keygen -A
dhclient &
/usr/sbin/sshd -D -o "ListenAddress 127.0.0.1" -o "PasswordAuthentication no"  &
cd /app
sudo -u atsign dart --disable-analytics
sudo -u atsign dart pub get -C /app
while true
do
sudo -u atsign dart run /app/bin/sshnpd.dart $*
sleep 3
done