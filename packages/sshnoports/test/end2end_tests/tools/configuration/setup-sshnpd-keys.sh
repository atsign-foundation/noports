#!/bin/bash

sshnpd=$1

cp ~/.atsign/keys/${sshnpd}_key.atKeys ../../contexts/sshnpd/keys/${sshnpd}_key.atKeys

if [[ ! -f ../../contexts/sshnpd/keys/${sshnpd}_key.atKeys ]];
then
    echo "Could not copy ${sshnpd}_key.atKeys to ../../contexts/sshnpd/keys/${sshnpd}_key.atKeys"
    exit 1
fi