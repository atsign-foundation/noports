#!/bin/bash

usage() {
    echo ""
    echo "usage: $0"
    echo "  -1 <@sshnp>"
    echo "  -2 <@sshnpd>"
    echo "  -3 <@sshrvd>"
    echo "  -t <test>"
    echo ""
    echo "  example: $0 -1 @alice -2 @bob -3 @rv_am -t local-local-release"
    echo "  example: $0 -1 @alice -2 @bob -3 @charlie -t local-trunk-release"
    echo "  example: $0 -1 @alice -2 @bob -3 @charlie -t trunk-local-release"
}


pargs_args() {
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

}

pargs_args $@
main