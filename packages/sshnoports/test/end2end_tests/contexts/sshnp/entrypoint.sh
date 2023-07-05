#!/bin/bash
sleep 2
~/.local/bin/sshnp -f @jeremy_0 -t @smoothalligator -d sad -h @rv_am -s id_ed25519.pub -v > logs.txt
cat logs.txt
tail -n 5 logs.txt | grep "ssh -p" > command.txt

# if command.txt is empty, exit 1
if [ ! -s command.txt ]
then
    echo "command.txt is empty"
    tail -n 1 logs.txt || echo
    exit 1
fi

echo " -o StrictHostKeyChecking=no " >> command.txt ;
echo " -tt " >> command.txt ;
echo "sh test.sh && exit" | $(cat command.txt)
exit
