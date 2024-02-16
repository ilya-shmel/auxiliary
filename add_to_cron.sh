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

NUMBER_OF_SHARDS=3
CURRENT_NODE_IP="172.30.254.77"
INITIAL_HOST=$(hostname -i)
SCRIPT_FILE="$HOME/migration.sh"
CROND_FILE="$HOME/migration_job"
CRON_LINE="*/1 * * * * root /root/migration.sh "$NUMBER_OF_SHARDS" >/dev/null 2>&1"
KEY_PATH="$HOME/.ssh/id_rsa"

## Prepare a cron file
> "$CROND_FILE"
echo "SHELL=/bin/sh" >> "$CROND_FILE"
echo "PATH=/bin:/usr/bin:/sbin:/usr/sbin" >> "$CROND_FILE"
echo "# Every minute start the migration script" >> "$CROND_FILE"
echo "$CRON_LINE" >> "$CROND_FILE"

## Copy the script and the cron file
ssh_function $CURRENT_NODE_IP "scp root@"$INITIAL_HOST":"$SCRIPT_FILE" /root"
ssh_function $CURRENT_NODE_IP "scp root@"$INITIAL_HOST":"$CROND_FILE" /etc/cron.d"