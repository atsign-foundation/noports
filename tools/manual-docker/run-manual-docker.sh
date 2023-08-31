#!/bin/bash

# Spin up an interactive container with a specific version of ssh no ports

usage() {
    echo ""
    echo "usage: $0"
    echo "  -h|--help"
    echo "  -t|--tag <sshnp/sshnpd/sshrvd> (required) - docker container tag"
    echo "  --no-cache (optional) - docker build without cache"
    echo "  --rm (optional) - remove container after exit"
    echo "  ONE OF THE FOLLOWING (required)"
    echo "  -l|--local - build from local source"
    echo "  -b|--branch <branch/commitid> - build from branch/commitid"
    echo "  -r|--release [release] - build from a sshnoports release, latest release by default"
    echo "  --blank - build container with no binaries"
    echo ""
    echo "  example: $0 -t sshnp -b trunk"
    echo "  example: $0 -t sshnpd -l"
    echo "  example: $0 -t sshrvd -r v3.3.0"
    echo "  example: $0 -t sshnp --release"
    echo "  example: $0 -t sshnp --blank"
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
            --no-cache)
                nocache=true
                shift 1
                ;;
            --rm)
                rm=true
                shift 1
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
                if [[ -z $release ]];
                then
                    release=true
                    shift 1
                fi

                if [[ -n $release ]];
                then
                    shift 2
                fi
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

    if [[ -n $local ]];
    then
        type=local
    fi

    if [[ -n $branch ]];
    then
        type=branch
    fi

    if [[ -n $release ]];
    then
        type=release
    fi

    if [[ -n $blank ]];
    then
        type=blank
    fi

}

main() {
    command="cd $type"
    dockercmd1="sudo docker compose build"
    dockercmd2="sudo docker compose run -it"

    # build dockercmd1 (docker compose build)

    if [[ $type == "branch" ]];
    then
        dockercmd1="$dockercmd1 --build-arg branch=$branch"
    fi

    if [[ $type == "release" ]];
    then
        if [[ ! ($release == true) ]]; # if release was provided, pass it as a build arg
        then
            dockercmd1="$dockercmd1 --build-arg release=$release"
        fi
    fi

    if [[ -n $nocache ]];
    then
        dockercmd1="$dockercmd1 --no-cache"
    fi

    # build dockercmd2 (docker compose run)

    if [[ -n $rm ]];
    then
        dockercmd2="$dockercmd2 --rm"
    fi
    dockercmd2="$dockercmd2 container-$tag"

    # build full command

    command="$command ; $dockercmd1"
    command="$command ; $dockercmd2"
    command="$command ; cd .."

    # execute command
    echo "Executing command: $command"
    eval "$command"
}

# Ignore the shell check warning for the following line
# We actually want array expansion here in order to parse the arguments correctly
# shellcheck disable=SC2068
parse_args $@
main
