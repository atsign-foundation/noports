#!/bin/bash

device=$1 # e.g. e2e
sshnp=$2 # e.g. @alice
sshnpd=$3 # e.g. @alice
sshrvd=$4 # e.g. @alice
template_name=$5 # e.g. sshnp_entrypoint.sh
args=$6 # e.g. -v

cp ../../entrypoints/"$template_name" ../sshnp/entrypoint.sh # copy template to the mounted folder

prefix="sed -i"

# if on MacOS
if [[ $(uname) == "Darwin" ]];
then
    prefix="$prefix ''"
fi

eval "$prefix" "s/@sshnpatsign/${sshnp}/g" ../sshnp/entrypoint.sh
eval "$prefix" "s/@sshnpdatsign/${sshnpd}/g" ../sshnp/entrypoint.sh
eval "$prefix" "s/@sshrvdatsign/${sshrvd}/g" ../sshnp/entrypoint.sh
eval "$prefix" "s/deviceName/${device}/g" ../sshnp/entrypoint.sh
eval "$prefix" "s/args/${args}/g" ../sshnp/entrypoint.sh