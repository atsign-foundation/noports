#!/bin/sh
create_api_group() {
  wget -O- --post-data "$1" \
    --header='Content-Type:application/json' \
    "http://$HOST:$PORT/api/policy/group"
}

# TODO: Multiple bob/alice devices, with different groups
# roles around groups
if [ -f /second_run ]; then
  create_api_group '{"name":"Barbara","description":"Full access to alice","daemonAtSigns":["@alice🛠"],"devices":[{"name":"default","permitOpens":["localhost:*"]}],"deviceGroups":[],"userAtSigns":["@barbara🛠"]}'
  create_api_group '{"name":"Murali","description":"Remote desktop access only","daemonAtSigns":["@bob🛠"],"devices":[{"name":"default","permitOpens":["*:5900","*:3389"]}],"deviceGroups":[{"name":"device group name","permitOpens":[]}],"userAtSigns":["@murali🛠"]}'
  create_api_group '{"name":"Developers","description":"SSH access","daemonAtSigns":["@alice🛠","@bob🛠"],"devices":[{"name":"default","permitOpens":["localhost:22"]}],"deviceGroups":[],"userAtSigns":["@sitaram🛠","@purnima🛠"]}'
else
  touch /second_run
fi
