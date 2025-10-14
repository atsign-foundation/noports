#!/usr/bin/env bash
# This script can be run via cron for example to keep srvd upto date
set -e
# Edit these values for the Relay being deployed
BASE_IMAGE="atsigncompany/srvd:latest"
REGISTRY="docker.io"
ATSIGN="@changeme"
IP="1.2.3.4"
ATKEYS_LOCATION="<DIRECTORY>/.atsign/keys"
######
IMAGE="$REGISTRY/$BASE_IMAGE"
CID=$(docker ps  --no-trunc | grep $IMAGE | awk '{print $1}')

   docker pull $IMAGE
    if test -z "$CID"
        then
        docker run -d --restart always  -v $ATKEYS_LOCATION:/atsign/.atsign/keys  --network host $IMAGE  -a $ATSIGN -i $IP
    fi

    for im in $CID
    do
        LATEST=`docker inspect --format "{{.Id}}" $IMAGE`
        RUNNING=`docker inspect --format "{{.Image}}" $im`
        NAME=`docker inspect --format '{{.Name}}' $im | sed "s/\///g"`
        echo "Latest :" $LATEST
        echo "Running:" $RUNNING
        if [ "$RUNNING" != "$LATEST" ];then
            echo "upgrading $NAME"
            docker stop  $NAME
            docker rm -f $NAME
            docker run -d --restart always -v $ATKEYS_LOCATION:/atsign/.atsign/keys  --network host $IMAGE  -a $ATSIGN -i $IP
        else
            echo "$NAME up to date"
        fi
    done