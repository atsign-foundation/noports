
usage() {
    echo "usage: $0"
    echo "  -h|--help"
    echo "  -t|--type <type> (required)"
    echo "  ONE OF THE FOLLOWING (required)"
    echo "  -l|--local"
    echo "  -b|--branch <branch/commitid>"
    echo "  -r|--release <release>"
    echo "  --blank"
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

    if [[ -z $local && -z $branch && -z $release && -z $blank ]]; 
    then
        echo "Missing required argument: ONE OF THE FOLLOWING: --local, --branch, --release, --blank"
        usage
        exit 1
    fi
}

build_base_image() {
    sudo docker build -t atsigncompany/sshnp_test_base -f ../base/Dockerfile ../base
}

main() {

    build_base_image

    containertag=sshnp_test_$type # example: sshnp_test_sshnpd
    imagetag=atsigncompany/$containertag # example: atsigncompany/sshnp_test_sshnpd
    networkname=${containertag}_network # example: sshnp_test_sshnpd_network

    sudo docker container stop $containertag
    sudo docker container rm $containertag
    sudo docker network create $networkname

    if [[ ! -z $local ]];
    then
        sudo docker build -t $imagetag -f ../images/local/Dockerfile ../../../
    elif [[ ! -z $branch ]];
    then
        sudo docker build -t $imagetag --build-arg branch=$branch -f ../images/branch/Dockerfile ../
    elif [[ ! -z $release ]];
    then
        sudo docker build -t $imagetag --build-arg release=$release -f ../images/release/Dockerfile ../
    elif [[ ! -z $blank ]];
    then
        sudo docker build -t $imagetag -f ../images/blank/Dockerfile ../
    fi

    sudo docker run -it --network=$networkname --name $containertag $imagetag
}

parse_args $@
main