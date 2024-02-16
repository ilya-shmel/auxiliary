#!/bin/bash

## The ssh connection function
ssh_function(){
    local IP="$1"
    local COMMAND="$2"

    if [[ $IP == $(hostname -i) ]]
    then
        eval "${COMMAND} 2>/dev/null"
    else
        eval "ssh -o 'StrictHostKeyChecking no' -i "$KEY_PATH" root@"$IP" "${COMMAND}" 2>/dev/null"
    fi
}

KEY_PATH="$HOME/.ssh/id_rsa"
SCRIPT_FILE="/opt/pangeoradar/support_tools/opensearch/migration.sh"
HOST_IP="172.30.254.84"
CURRENT_NODE_IP="172.30.254.77"

## Copy script to node
ssh_function $CURRENT_NODE_IP "scp root@"$HOST_IP":$SCRIPT_FILE /tmp"