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

    if [[ -z $sshnp || -z $sshnpd || -z $sshrvd || -z $test ]];
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
    cp ~/.atsign/keys/${sshnp}_key.atKeys ../../contexts/sshnp/keys/${sshnp}_key.atKeys
    cp ~/.atsign/keys/${sshnpd}_key.atKeys ../../contexts/sshnpd/keys/${sshnpd}_key.atKeys
    if [[ $sshrvd != "@rv_am" && $sshrvd != "@rv_eu" && $sshrvd != "@rv_ap" ]];
    then
        run_srs_locally=true
        cp ~/.atsign/keys/${sshrvd}_key.atKeys ../../contexts/sshrvd/keys/${sshrvd}_key.atKeys
    fi

    if [[ ! -f ../../contexts/sshnp/keys/${sshnp}_key.atKeys ]];
    then
        echo "Could not copy ${sshnp}_key.atKeys to ../../contexts/sshnp/keys/${sshnp}_key.atKeys"
        exit 1
    fi

    if [[ ! -f ../../contexts/sshnpd/keys/${sshnpd}_key.atKeys ]];
    then
        echo "Could not copy ${sshnpd}_key.atKeys to ../../contexts/sshnpd/keys/${sshnpd}_key.atKeys"
        exit 1
    fi

    if [[ ! -z $run_srs_locally ]];
    then
        if [[ ! -f ../../contexts/sshrvd/keys/${sshrvd}_key.atKeys ]];
        then
            echo "Could not copy ${sshrvd}_key.atKeys to ../../contexts/sshrvd/keys/${sshrvd}_key.atKeys"
            exit 1
        fi
    fi

    # copy and sed the entrypoints
    cp ../../templates/sshnp_entrypoint.sh ../../contexts/sshnp/entrypoint.sh
    cp ../../templates/sshnpd_entrypoint.sh ../../contexts/sshnpd/entrypoint.sh
    if [[ ! -z $run_srs_locally ]];
    then
        cp ../../templates/sshrvd_entrypoint.sh ../../contexts/sshrvd/entrypoint.sh
    fi

    # if on MacOS
    prefix="sed -i"
    if [[ $(uname) == "Darwin" ]];
    then
        prefix="$prefix ''"
    fi

    eval $prefix "s/@sshnpatsign/${sshnp}/g" ../../contexts/sshnp/entrypoint.sh
    eval $prefix "s/@sshnpdatsign/${sshnpd}/g" ../../contexts/sshnp/entrypoint.sh
    eval $prefix "s/@sshrvdatsign/${sshrvd}/g" ../../contexts/sshnp/entrypoint.sh

    eval $prefix "s/@sshnpatsign/${sshnp}/g" ../../contexts/sshnpd/entrypoint.sh
    eval $prefix "s/@sshnpdatsign/${sshnpd}/g" ../../contexts/sshnpd/entrypoint.sh

    eval $prefix "s/deviceName/${device}/g" ../../contexts/sshnpd/entrypoint.sh
    eval $prefix "s/deviceName/${device}/g" ../../contexts/sshnp/entrypoint.sh
    if [[ ! -z $run_srs_locally ]];
    then
        eval $prefix "s/@sshnpdatsign/${sshnpd}/g" ../../contexts/sshrvd/entrypoint.sh
        eval $prefix "s/@sshrvdatsign/${sshrvd}/g" ../../contexts/sshrvd/entrypoint.sh
    fi

    cd ../../tests

    cd $test

    buildcmd="sudo docker-compose build"

    if [[ ! -z $nocache ]];
    then
        buildcmd="$buildcmd --no-cache"
    fi

    upcmd="sudo docker-compose up --exit-code-from=container-sshnp"

    downcmd="sudo docker-compose down"

    echo "Running: $buildcmd"
    echo "Running: $upcmd"
    echo "Running: $downcmd"

    eval $buildcmd
    eval $upcmd
    eval $downcmd

}

pargs_args $@
main