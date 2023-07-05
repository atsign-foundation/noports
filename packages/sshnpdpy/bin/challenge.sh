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

# Run the OpenSSL connection and get the secondary address
root_answer="$({ echo "$atsign" ; sleep 1 ; echo "Q"; } | openssl s_client -brief -connect root.atsign.org:64 2>&1)"

#regex for server address
regex='@[a-fA-F0-9-]+\.[a-zA-Z0-9.-]+:[0-9]+'
 
if [[ $root_answer =~ $regex ]]; then
  server_address="${BASH_REMATCH[0]:1}"
else
  echo "No match found."
fi

#same thing to start authentication into server
server_answer="$({ echo "from:$atsign" ; sleep 1 ; echo "Q"; } | openssl s_client -brief -connect $server_address 2>&1)"

if [[ $server_answer =~ @data:(.*) ]]; then
  temp="${BASH_REMATCH[1]}"
else
  echo "Pattern not found."
fi

result=$(echo "$temp" | sed 's/@DONE//g')

#returns passing challenge and server address
echo "$result | $server_address"

