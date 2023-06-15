#!/bin/bash

# usage example:
# ```sh
# cd scripts
# sh buildbaseimage.sh -b trunk
# ```

IMAGE_TAG_NAME="atsigncompany/sshnp_test_base"
DEFAULT_BRANCH="trunk"

usage () {
    echo "usage: $0 [-h|--help] [--no-cache] [-b branch]"
}

parse_args() {
    nocache=0
    branch=$DEFAULT_BRANCH

    while [ $# -gt 0 ];
    do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            --no-cache)
                nocache=1
                shift 1
                ;;
            -b|--branch)
                branch=$2
                shift 2
                ;;
            *)
                echo "Unknown argument: $1"
                exit 1
                ;;
        esac
    done

}

build_base_image() {
    if [[ $nocache == 1 ]];
    then
        echo "[!] Building without cache"
        sudo docker build --no-cache -t $IMAGE_TAG_NAME -f ../base/Dockerfile ../base
    else
        sudo docker build -t $IMAGE_TAG_NAME -f ../base/Dockerfile ../base
    fi
}

main() {
    build_base_image
}

parse_args $@
main
