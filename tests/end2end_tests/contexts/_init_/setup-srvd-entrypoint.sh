#!/bin/bash

# this script copies the template srvd entrypoint to ../srvd/entrypoint.sh
# then also replaces the @srvdatsign with the provided argument (e.g. @alice)
# example usage: ./setup-srvd-entrypoint.sh @alice

srvd=$1 # e.g. @alice
template_name=$2 # e.g. "srvd_entrypoint.sh"

cp ../../entrypoints/"$template_name" ../srvd/entrypoint.sh # copy template to the mounted folder

prefix="sed -i"

# if on MacOS
if [[ $(uname) == "Darwin" ]];
then
    prefix="$prefix ''"
fi

eval "$prefix" "s/@srvdatsign/${srvd}/g" ../srvd/entrypoint.sh