#!/bin/bash

## The ssh connection function
ssh_function(){
    local IP="$1"
    local COMMAND="$2"

    if [[ $IP == $(hostname -i) ]]
    then
        "${COMMAND}" 2>/dev/null
    else
        ssh -o 'StrictHostKeyChecking no' -i "$KEY_PATH" root@"$IP" "${COMMAND}" 2>/dev/null
    fi
}

KEY_PATH="$HOME/.ssh/id_rsa"
SCRIPT_CONTENT=()
SCRIPT_FILE="/opt/pangeoradar/support_tools/opensearch/migration.sh"
CURRENT_NODE_IP="172.30.254.77"

## Convert the migration script into an array
readarray -t SCRIPT_CONTENT < $SCRIPT_FILE   

## Create a new file for the script
ssh_function $CURRENT_NODE_IP "touch /tmp/migration.sh"

for (( KEY=0; KEY < ${#SCRIPT_CONTENT[@]}; ++KEY ))
do
    ssh_function $CURRENT_NODE_IP "${SCRIPT_CONTENT[KEY]} >> /tmp/migration.sh"
done