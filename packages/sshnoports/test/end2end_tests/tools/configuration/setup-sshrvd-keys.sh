#!/bin/bash

# this script copies the keys from ~/.atsign/keys to ../../contexts/sshrvd/keys
# example usage: ./setup-sshrvd-keys.sh @alice

sshrvd=$1

cp ~/.atsign/keys/${sshrvd}_key.atKeys ../../contexts/sshrvd/keys/${sshrvd}_key.atKeys

if [[ ! -f ../../contexts/sshrvd/keys/${sshrvd}_key.atKeys ]];
then
    echo "Could not copy ${sshrvd}_key.atKeys to ../../contexts/sshrvd/keys/${sshrvd}_key.atKeys"
    exit 1
fi