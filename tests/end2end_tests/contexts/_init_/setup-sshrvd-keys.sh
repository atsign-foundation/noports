#!/bin/bash

# this script copies the keys from ~/.atsign/keys to ../srvd/keys
# example usage: ./setup-srvd-keys.sh @alice

srvd=$1

cp ~/.atsign/keys/"$srvd"_key.atKeys ../srvd/.atsign/keys/"$srvd"_key.atKeys # copy keys to the mounted folder

if [[ ! -f ../srvd/.atsign/keys/${srvd}_key.atKeys ]];
then
    echo "Could not copy ${srvd}_key.atKeys to ../srvd/.atsign/keys/${srvd}_key.atKeys"
    exit 1
fi