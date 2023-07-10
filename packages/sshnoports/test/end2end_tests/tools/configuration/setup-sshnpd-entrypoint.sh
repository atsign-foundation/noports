#!/bin/bash

device=$1 # e.g. e2e
sshnp=$2 # e.g. @alice
sshnpd=$3 # e.g. @alice

cp ../../templates/sshnpd_entrypoint.sh ../../contexts/sshnpd/entrypoint.sh

prefix="sed -i"

# if on MacOS
if [[ $(uname) == "Darwin" ]];
then
    prefix="$prefix ''"
fi

eval $prefix "s/@sshnpatsign/${sshnp}/g" ../../contexts/sshnpd/entrypoint.sh
eval $prefix "s/@sshnpdatsign/${sshnpd}/g" ../../contexts/sshnpd/entrypoint.sh
eval $prefix "s/deviceName/${device}/g" ../../contexts/sshnpd/entrypoint.sh
