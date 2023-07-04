#!/bin/bash

# Spin up an interactive container with a specific version of ssh no ports

usage() {
    echo "usage: $0"
    echo "  -h|--help"
    echo "  -t|--type <sshnp/sshnpd/sshrvd> (required)"
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
                type=$2
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

    if [[ -z $type ]];
    then
        echo "Missing required argument: --type"
        usage
        exit 1
    fi

    if [[ $type != "sshnp" && $type != "sshnpd" && $type != "sshrvd" ]];
    then
        echo "Invalid type: $type, must be one of: sshnp/sshnpd/sshrvd"
        usage
        exit 1
    fi

    if [[ -z $local && -z $branch && -z $release && -z $blank ]];
    then
        echo "Missing required argument: ONE OF THE FOLLOWING: --local, --branch, --release, --blank"
        usage
        exit 1
    fi
}

cd ..
sudo docker-compose up --exit-code-from=sshnp-trunk --build $@
sudo docker-compose down