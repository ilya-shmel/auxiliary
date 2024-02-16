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

CURRENT_NODE_IP="172.30.254.77"
INITIAL_HOST=$(hostname -i)
SCRIPT_FILE="/root/migration.sh"

ssh_function $CURRENT_NODE_IP "scp root@"$INITIAL_HOST":"$SCRIPT_FILE" /root"
ssh_function $CURRENT_NODE_IP "(crontab -u root -l; echo "*/5 * * * * root !/root/migration.sh "$NUMBER_OF_SHARDS" >/dev/null 2>&1") | crontab -u root -"