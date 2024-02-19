#!/bin/bash

exec 200>/tmp/flock_file.lock

if ! flock -n 200
then
    echo "Another instance is running"
    exit 1
fi

echo "The main script is running."
read -r PAUSE
# this now runs under the lock until 9 is closed (it will be closed automatically when the script ends)