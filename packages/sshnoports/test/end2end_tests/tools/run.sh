#!/bin/bash

# Spin up an interactive container with a specific version of ssh no ports

usage() {
    echo "usage: $0"
    echo "  -h|--help"
    echo "  -t|--tag <sshnp/sshnpd/sshrvd> (required)"
    echo "  ONE OF THE FOLLOWING (required)"
    echo "  -l|--local"
    echo "  -b|--branch <branch/commitid>"
    echo "  -r|--release <release>"
    echo "  --blank"
    echo ""
    echo "  example: $0 -t sshnp -b trunk"
    echo "  example: $0 -t sshnpd -l"
    echo "  example: $0 -t sshrvd -r 3.3.0"
}

parse_args() {

    if [[ $# -eq 0 ]];
    then
        usage
        exit 1
    fi

    while [[ $# -gt 0 ]];
    do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -t|--type)
                tag=$2
                shift 2
                ;;
            -l|--local)
                local=true
                shift 1
                ;;
            -b|--branch)
                branch=$2
                shift 2
                ;;
            -r|--release)
                release=$2
                shift 2
                ;;
            --blank)
                blank=true
                shift 1
                ;;
            *)
                echo "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    # check that tag is provided
    if [[ -z $tag ]];
    then
        echo "Missing required argument: --tag"
        usage
        exit 1
    fi

    # check that tag is one of: sshnp/sshnpd/sshrvd
    if [[ $tag != "sshnp" && $tag != "sshnpd" && $tag != "sshrvd" ]];
    then
        echo "Invalid tag: $tag, must be one of: sshnp/sshnpd/sshrvd"
        usage
        exit 1
    fi

    # check that at least one of the following is provided: local branch release blank
    if [[ -z $local && -z $branch && -z $release && -z $blank ]];
    then
        echo "Missing required argument: ONE OF THE FOLLOWING: --local, --branch, --release, --blank"
        usage
        exit 1
    fi

    # check that only one and only one of the following is provided: local branch release blank
    local_count=0
    branch_count=0
    release_count=0
    blank_count=0

    if [[ ! -z $local ]];
    then
        type=local
        local_count=1
    fi

    if [[ ! -z $branch ]];
    then
        type=branch
        branch_count=1
    fi

    if [[ ! -z $release ]];
    then
        type=release
        release_count=1
    fi

    if [[ ! -z $blank ]];
    then
        type=blank
        blank_count=1
    fi

    if [[ $local_count + $branch_count + $release_count + $blank_count -gt 1 ]];
    then
        echo "Too many arguments provided: ONE OF THE FOLLOWING: --local, --branch, --release, --blank"
        usage
        exit 1
    fi
}

main() {
    # if type is branch
    if [[ $type == "branch" ]];
    then
        sudo docker compose build --no-cache --build-arg branch=$branch
    else if [[ $type == "release" ]]
        sudo docker compose build --no-cache --build-arg release=$release
    else
        sudo docker compose build
    fi

}

parse_args $@
main
