#!/bin/bash

usage() {
    echo ""
    echo "usage: $0"
    echo "  -h|--help"
    echo "  -1 <@sshnp>"
    echo "  -2 <@sshnpd>"
    echo "  -3 <@sshrvd>"
    echo "  -t|--test <test>"
    echo "  -d|--device <deviceName>"
    echo "  --no-cache - build without docker cache"
    echo "  example: $0 -1 @alice -2 @bob -3 @rv_am -d test -t local-local-release"
    echo "  example: $0 -1 @alice -2 @bob -3 @charlie -d docker -t local-trunk-release"
    echo "  example: $0 -1 @alice -2 @bob -3 @charlie -d e2e -t trunk-local-release"
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
            -1)
                sshnp=$2
                shift 2
                ;;
            -2)
                sshnpd=$2
                shift 2
                ;;
            -3)
                sshrvd=$2
                shift 2
                ;;
            -t|--test)
                test=$2
                shift 2
                ;;
            -d|--device)
                device=$2
                shift 2
                ;;
            --no-cache)
                nocache=true
                shift 1
                ;;
            *)
                echo "Invalid argument: $1"
                usage
                exit 1
                ;;
        esac
    done

    if [[ -z $sshnp || -z $sshnpd || -z $sshrvd || -z $test || -z $device ]];
    then
        echo "You are missing arguments..."
        usage
        exit 1
    fi

    if [[ ${sshnp:0:1} != "@" ]];
    then
        sshnp="@${sshnp}"
    fi

    if [[ ${sshnpd:0:1} != "@" ]];
    then
        sshnpd="@${sshnpd}"
    fi

    if [[ ${sshrvd:0:1} != "@" ]];
    then
        sshrvd="@${sshrvd}"
    fi
}

main() {
    ../configuration/setup-sshnp-keys.sh $sshnp
    ../configuration/setup-sshnpd-keys.sh $sshnpd
    if [[ $sshrvd != "@rv_am" && $sshrvd != "@rv_eu" && $sshrvd != "@rv_ap" ]];
    then
        run_srs_locally=true
        ../configuration/setup-sshrvd-keys.sh $sshrvd
    fi

    ../configuration/setup-sshnp-entrypoint.sh $device $sshnp $sshnpd $sshrvd
    ../configuration/setup-sshnpd-entrypoint.sh $device $sshnp $sshnpd
    ../configuration/setup-sshrvd-entrypoint.sh $sshrvd

    buildcmd="sudo docker-compose build"

    if [[ ! -z $nocache ]];
    then
        buildcmd="$buildcmd --no-cache"
    fi

    upcmd="sudo docker-compose up --exit-code-from=container-sshnp"

    downcmd="sudo docker-compose down"

    echo "Running: cd $test"
    echo "Running: $buildcmd"
    echo "Running: $upcmd"
    echo "Running: $downcmd"

    cd $test
    eval $buildcmd
    eval $upcmd
    eval $downcmd

}

pargs_args $@
main