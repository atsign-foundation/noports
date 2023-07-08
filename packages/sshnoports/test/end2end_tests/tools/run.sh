#!/bin/bash

# Spin up an interactive container with a specific version of ssh no ports

usage() {
    echo ""
    echo "usage: $0"
    echo "  -h|--help"
    echo "  -t|--tag <sshnp/sshnpd/sshrvd> (required) - docker container tag"
    echo "  --no-cache (optional) - docker build without cache"
    echo "  ONE OF THE FOLLOWING (required)"
    echo "  -l|--local - build from local source"
    echo "  -b|--branch <branch/commitid> - build from branch/commitid"
    echo "  -r|--release [release] - build from a sshnoports release, latest release by default"
    echo "  --blank - build container with no binaries"
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
            --no-cache)
                nocache=true
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

                if [[ ! -z $release ]];
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
    command="cd $type"
    if [[ $type == "branch" ]];
    then
        dockercmd1="sudo docker compose build --build-arg branch=$branch"
        dockercmd2="sudo docker compose run -it container-branch-$tag"
    fi

    if [[ $type == "release" ]];
    then
        dockercmd1="sudo docker compose build"
        if [[ ! ($release == true) ]]; # if release was provided, pass it as a build arg
        then
            dockercmd1="$dockercmd1 --build-arg release=$release"
        fi
        dockercmd2="sudo docker compose run -it container-release-$tag"
    fi

    if [[ $type == "local" ]];
    then
        dockercmd1="sudo docker compose build"
        dockercmd2="sudo docker compose run -it container-local-$tag"
    fi

    if [[ $type == "blank" ]];
    then
        dockercmd1="sudo docker compose build"
        dockercmd2="sudo docker compose run -it container-blank-$tag"
    fi

    command="$command ; $dockercmd1"

    if [[ ! -z $nocache ]];
    then
        command="$command --no-cache"
    fi

    command="$command ; $dockercmd2"
    command="$command ; cd .."

    # execute command
    echo "Executing command: $command"
    eval $command
}

parse_args $@
main
