#!/bin/bash

# this script copies the template sshnp entrypoint to ../../contexts/sshnp/entrypoint.sh
# then also replaces the device name, sshnp atSign, sshnpd atSign, and sshrvd atSign with the provided arguments
# example usage: ./setup-sshnp-entrypoint.sh e2e @alice @alice @alice

device=$1 # e.g. e2e
sshnp=$2 # e.g. @alice
sshnpd=$3 # e.g. @alice
sshrvd=$4 # e.g. @alice
waitingTime=$5 # e.g. 30

cp ../../templates/sshnp_entrypoint.sh ../../contexts/sshnp/entrypoint.sh

prefix="sed -i"

# if on MacOS
if [[ $(uname) == "Darwin" ]];
then
    prefix="$prefix ''"
fi

eval $prefix "s/@sshnpatsign/${sshnp}/g" ../../contexts/sshnp/entrypoint.sh
eval $prefix "s/@sshnpdatsign/${sshnpd}/g" ../../contexts/sshnp/entrypoint.sh
eval $prefix "s/@sshrvdatsign/${sshrvd}/g" ../../contexts/sshnp/entrypoint.sh
eval $prefix "s/deviceName/${device}/g" ../../contexts/sshnp/entrypoint.sh
eval $prefix "s/WAITING_TIME/${waitingTime}/g" ../../contexts/sshnp/entrypoint.sh