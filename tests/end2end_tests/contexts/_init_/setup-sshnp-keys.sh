#!/bin/bash

# this script copies the keys from ~/.atsign/keys to ../sshnp/keys
# example usage: ./setup-sshnp-keys.sh @alice

sshnp=$1

cp ~/.atsign/keys/"$sshnp"_key.atKeys ../sshnp/.atsign/keys/"$sshnp"_key.atKeys

if [[ ! -f ../sshnp/.atsign/keys/${sshnp}_key.atKeys ]];
then
    echo "Could not copy ${sshnp}_key.atKeys to ../sshnp/.atsign/keys/${sshnp}_key.atKeys"
    exit 1
fi