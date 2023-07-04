#!/bin/bash
#Check if the "atsign" argument is provided
if [ $# -ne 1 ]; then
  echo "Usage: $0 <atsign>"
  exit 1
fi

# Assign the "atsign" argument to a variable
atsign=$1

# Define the OpenSSL root server connection
root_connection="openssl s_client -ign_eof -quiet -connect root.atsign.org:64"
# it's hanging... no clue why
root_cmd= echo "chess69"| openssl s_client -ign_eof -quiet -connect root.atsign.org:64
echo -n "Q"
# Run the OpenSSL connection and get the secondary address
#output=$root_cmd

# Check if the output contains the "sshd" notification
if [[ $output =~ sshd ]]; then
  echo "Found 'sshd' notification!" 
else
  echo "No 'sshd' notification found."
fi

