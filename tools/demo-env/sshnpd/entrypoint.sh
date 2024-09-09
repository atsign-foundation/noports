#!/bin/sh

# Pull the key from the bootstrapper
cp /home/atsign/mount/"${ATSIGN}_key.atKeys" /home/atsign/.atsign/keys/

# Start sshd
sudo /home/atsign/sshd.sh &

if [ -n "$MANAGER" ]; then
  ARGS="-m $MANAGER $ARGS"
fi

if [ -n "$POLICY" ]; then
  ARGS="-p $POLICY $ARGS"
fi

# Start nginx
sudo /usr/sbin/nginx

echo Running command: /home/atsign/sshnpd -a \"$ATSIGN\" $ARGS

# Run the NoPorts agent
/home/atsign/sshnpd -a "$ATSIGN" $ARGS

# Pause after a crash before restarting
sleep 5
