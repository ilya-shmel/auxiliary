#!/bin/bash

SCRIPT_CONTENT=()
SCRIPT_FILE="/opt/pangeoradar/support_tools/opensearch/migration.sh"

## Convert the migration script into an array
readarray -t SCRIPT_CONTENT < $SCRIPT_FILE    

for (( KEY=0; KEY < ${#SCRIPT_CONTENT[@]}; ++KEY ))
do
    echo "$KEY" "${SCRIPT_CONTENT[KEY]}"
done