#!/bin/bash
echo "SSHNP START ENTRY"
SSHNP_COMMAND="$HOME/.local/bin/sshnp -f @sshnpatsign -t @sshnpdatsign -d deviceName -h @sshrvdatsign args > sshnp.log"

run_test()
{
    echo "Running: $SSHNP_COMMAND"
    eval "$SSHNP_COMMAND"
    cat sshnp.log
    tail -n 20 sshnp.log | grep "ssh -p" > sshcommand.txt

    # if sshcommand is empty, exit code 1
    if [ ! -s sshcommand.txt ]; then
        echo "sshcommand.txt is empty"
        return 1
    fi

    sed '1!d' sshcommand.txt
    echo "ssh -p command: $(cat sshcommand.txt)"
    echo "./test.sh " | eval "$(cat sshcommand.txt)"
    sleep 2 # time for ssh connection to properly exit
    return 0
}

main()
{
    # run test 3 times, while run_test is not successful
    for i in {1..3}
    do
        run_test
        if [ $? -eq 0 ]; then
            exit 0
        fi
        sleep 5
    done
    exit 1
}

main
