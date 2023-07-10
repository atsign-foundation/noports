#!/bin/bash

sshnp=$1

cp ~/.atsign/keys/${sshnp}_key.atKeys ../../contexts/sshnp/keys/${sshnp}_key.atKeys

if [[ ! -f ../../contexts/sshnp/keys/${sshnp}_key.atKeys ]];
then
    echo "Could not copy ${sshnp}_key.atKeys to ../../contexts/sshnp/keys/${sshnp}_key.atKeys"
    exit 1
fi