
usage() {
    echo "usage: $0 <sshnp|sshnpd|sshrvd>"
}

parse_args() {
    # check that $1 is 'sshnp', 'sshnpd', or 'sshrvd'
    if [ "$1" != "sshnp" ] && [ "$1" != "sshnpd" ] && [ "$1" != "sshrvd" ]
    then
        usage
        exit 1
    fi
    type=$1
    containertag=sshnp_test_$type
    imagetag=atsigncompany/$containertag # example: sshnp_test_sshnp
    networkname=${containertag}_network # example: sshnp_test_sshnp_network
}

main() {
    sudo docker container stop $containertag
    sudo docker container rm $containertag
    sudo docker build -t $imagetag -f ../$type/Dockerfile ../$type
    sudo docker network create $networkname
    sudo docker run -it --network=$networkname --name $containertag $imagetag
}

parse_args $@
main