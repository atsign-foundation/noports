#!/bin/bash

# this script copies the template sshrvd entrypoint to ../sshrvd/entrypoint.sh
# then also replaces the @sshrvdatsign with the provided argument (e.g. @alice)
# example usage: ./setup-sshrvd-entrypoint.sh @alice

sshrvd=$1 # e.g. @alice

cp ../../entrypoints/sshrvd_entrypoint.sh ../sshrvd/entrypoint.sh # copy template to the mounted folder

prefix="sed -i"

# if on MacOS
if [[ $(uname) == "Darwin" ]];
then
    prefix="$prefix ''"
fi

eval "$prefix" "s/@sshrvdatsign/${sshrvd}/g" ../sshrvd/entrypoint.sh