#!/bin/bash

# this script copies the template entrypoint to ../sshnpd/entrypoint.sh
# then also replaces the @sshnpatsign, @sshnpdatsign and device name with the provided arguments
# example usage: ./setup-sshnpd-entrypoint.sh e2e @alice @alice

device=$1 # e.g. e2e
sshnp=$2 # e.g. @alice
sshnpd=$3 # e.g. @alice
template_name=$4 # e.g. sshnpd_entrypoint.sh

cp ../../entrypoints/"$template_name" ../sshnpd/entrypoint.sh

prefix="sed -i"

# if on MacOS
if [[ $(uname) == "Darwin" ]];
then
    prefix="$prefix ''"
fi

eval "$prefix" "s/@sshnpatsign/${sshnp}/g" ../sshnpd/entrypoint.sh
eval "$prefix" "s/@sshnpdatsign/${sshnpd}/g" ../sshnpd/entrypoint.sh
eval "$prefix" "s/deviceName/${device}/g" ../sshnpd/entrypoint.sh
