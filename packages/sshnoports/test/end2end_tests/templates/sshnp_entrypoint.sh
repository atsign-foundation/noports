#!/bin/bash
sleep 2 # time for sshnpd to share device name
~/.local/bin/sshnp -f @sshnpatsign -t @sshnpdatsign -d deviceName -h @sshrvdatsign -s id_ed25519.pub -v > logs.txt
cat logs.txt
tail -n 5 logs.txt | grep "ssh -p" > sshcommand.txt

if [ ! -s sshcommand.txt ]
then
    echo "could not find \'ssh -p\' command in logs.txt"
    echo "last 5 lines of logs.txt:"
    tail -n 5 logs.txt || echo
    exit 1
fi

echo " -o StrictHostKeyChecking=no " >> sshcommand.txt ;
echo "sh test.sh " | $(cat sshcommand.txt)
sleep 2 # time for ssh connection to properly exit
