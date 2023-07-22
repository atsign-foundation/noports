#!/bin/bash

# this script copies the keys from ~/.atsign/keys to ../../contexts/sshnp/keys
# example usage: ./setup-sshnp-keys.sh @alice

sshnp=$1

cp ~/.atsign/keys/${sshnp}_key.atKeys ../../contexts/sshnp/keys/${sshnp}_key.atKeys

if [[ ! -f ../../contexts/sshnp/keys/${sshnp}_key.atKeys ]];
then
    echo "Could not copy ${sshnp}_key.atKeys to ../../contexts/sshnp/keys/${sshnp}_key.atKeys"
    exit 1
fi