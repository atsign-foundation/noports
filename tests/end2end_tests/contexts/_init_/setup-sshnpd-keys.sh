#!/bin/bash

# this script copies the keys from ~/.atsign/keys to ../sshnpd/keys
# example usage: ./setup-sshnpd-keys.sh @alice

sshnpd=$1

cp ~/.atsign/keys/"$sshnpd"_key.atKeys ../sshnpd/.atsign/keys/"$sshnpd"_key.atKeys

if [[ ! -f ../sshnpd/.atsign/keys/${sshnpd}_key.atKeys ]];
then
    echo "Could not copy ${sshnpd}_key.atKeys to ../sshnpd/.atsign/keys/${sshnpd}_key.atKeys"
    exit 1
fi