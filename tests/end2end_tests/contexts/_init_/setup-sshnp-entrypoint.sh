#!/bin/bash

# this script copies the template sshnp entrypoint to ../sshnp/entrypoint.sh
# then also replaces the device name, sshnp atSign, sshnpd atSign, and srvd atSign with the provided arguments
# example usage: ./setup-sshnp-entrypoint.sh e2e @alice @alice @alice

device=$1 # e.g. e2e
sshnp=$2 # e.g. @alice
sshnpd=$3 # e.g. @alice
srvd=$4 # e.g. @alice
template_name=$5 # e.g. sshnp_entrypoint.sh
args="$6" # e.g. "arg1 arg2 arg3"

cp ../../entrypoints/"$template_name" ../sshnp/entrypoint.sh # copy template to the mounted folder

prefix="sed -i"

# if on MacOS
if [[ $(uname) == "Darwin" ]];
then
    prefix="$prefix ''"
fi

eval "$prefix" "s/@sshnpatsign/${sshnp}/g" ../sshnp/entrypoint.sh
eval "$prefix" "s/@sshnpdatsign/${sshnpd}/g" ../sshnp/entrypoint.sh
eval "$prefix" "s/@srvdatsign/${srvd}/g" ../sshnp/entrypoint.sh
eval "$prefix" "s/deviceName/${device}/g" ../sshnp/entrypoint.sh

# Don't use eval for this one, because it will try to evaluate the args stored in $args
if [[ $(uname) == "Darwin" ]];
then
    sed -i '' "s|args|$args|g" ../sshnp/entrypoint.sh
else
    sed -i "s|args|$args|g" ../sshnp/entrypoint.sh
fi