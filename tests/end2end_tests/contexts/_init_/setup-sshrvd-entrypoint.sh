#!/bin/bash

# this script copies the template sshrvd entrypoint to ../../contexts/sshrvd/entrypoint.sh
# then also replaces the @sshrvdatsign with the provided argument (e.g. @alice)
# example usage: ./setup-sshrvd-entrypoint.sh @alice

sshrvd=$1 # e.g. @alice

cp ../../templates/sshrvd_entrypoint.sh ../../contexts/sshrvd/entrypoint.sh

prefix="sed -i"

# if on MacOS
if [[ $(uname) == "Darwin" ]];
then
    prefix="$prefix ''"
fi

eval "$prefix" "s/@sshrvdatsign/${sshrvd}/g" ../../contexts/sshrvd/entrypoint.sh