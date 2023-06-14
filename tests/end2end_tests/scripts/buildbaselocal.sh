#!/bin/bash

# usage example:
# ```sh
# cd scripts
# sh buildbaseimage.sh -b trunk
# ```

TAGNAME="atsigncompany/sshnp_base"

# receive -b branch flag
# receive -c cache flag, -c to use --no-cache
while getopts b:c: flag
do
    case "${flag}" in
        b) branch=${OPTARG};;
        c) cache=${OPTARG};;
    esac
done

main() {
    if [ -z "$branch" ]
    then
        echo "branch is empty"
        exit 1
    fi

    echo "branch: $branch"

    build_base_image
}

build_base_image() {
    if [ -z "$cache" ]
    then
        echo "builing base image without cache"
        sudo docker build -t ${TAGNAME} -f ../base/Dockerfile --build-arg branch=$branch --no-cache ../base
    else
        echo "building base iamge with cache"
        sudo docker build -t ${TAGNAME} -f ../base/Dockerfile --build-arg branch=$branch ../base
    fi
}

main
