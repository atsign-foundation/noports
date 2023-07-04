#!/bin/bash

# Spin up an interactive container with a specific version of ssh no ports

usage() {
    echo ""
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
    echo ""
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
            -t|--tag)
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
                echo "Invalid argument: $1"
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

    if [[ ! -z $local ]];
    then
        type=local
    fi

    if [[ ! -z $branch ]];
    then
        type=branch
    fi

    if [[ ! -z $release ]];
    then
        type=release
    fi

    if [[ ! -z $blank ]];
    then
        type=blank
    fi

}

main() {
    if [[ $type == "branch" ]];
    then
        cd branch
        sudo docker compose run -it --build --rm container-branch-$tag
        cd ..
    fi

    if [[ $type == "release" ]];
    then
        cd release
        sudo docker compose run -it --build --rm container-release-$tag --entrypoint="sudo service ssh start && sh"
        cd ..
    fi

    if [[ $type == "local" ]];
    then
        cd local
        sudo docker compose run -it --build --rm --entrypoint="sudo service ssh start" container-local-$tag /bin/bash
        cd ..
    fi

    if [[ $type == "blank" ]];
    then
        cd blank
        sudo docker compose run -it --build --rm --entrypoint="sudo service ssh start" container-blank-$tag /bin/bash
        cd ..
    fi
}

parse_args $@
main
