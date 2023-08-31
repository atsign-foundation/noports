#!/bin/bash

# this script copies the keys from ~/.atsign/keys to ../sshrvd/keys
# example usage: ./setup-sshrvd-keys.sh @alice

sshrvd=$1

cp ~/.atsign/keys/"$sshrvd"_key.atKeys ../sshrvd/.atsign/keys/"$sshrvd"_key.atKeys # copy keys to the mounted folder

if [[ ! -f ../sshrvd/.atsign/keys/${sshrvd}_key.atKeys ]];
then
    echo "Could not copy ${sshrvd}_key.atKeys to ../sshrvd/.atsign/keys/${sshrvd}_key.atKeys"
    exit 1
fi