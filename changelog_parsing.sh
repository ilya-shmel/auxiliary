#!/usr/bin/bash

## Font variables
RED=$(tput setaf 1)
YELLOW=$(tput setaf 3)
GREEN=$(tput setaf 2)
ORANGE=$(tput setaf 202)
RESET=$(tput sgr 0)
BOLD=$(tput bold)
NORMAL=$(tput sgr0)

IP=$(hostname -i)

## Get the API answer for an users' activity changelog 
curl "https://$IP:9009/toller/history/system_configs/00000000-0000-0000-0000-000000000000" \
  -H 'Accept: application/json, text/plain, */*' \
  -H 'Accept-Language: en-US,en;q=0.9' \
  -H 'PgrApiKey: 57dbc2b0-41e8-0f55-95d8-1c19c2e44347' \
  -H 'Connection: keep-alive' \
  -H 'Content-Type: application/json' \
  -H "Origin: https://$IP" \
  -H 'PgrSelectedInstance: 6a6176c1-b879-8f66-6ccb-2532ec151589' \
  -H "Referer: https://$IP/" \
  -H 'Sec-Fetch-Dest: empty' \
  -H 'Sec-Fetch-Mode: cors' \
  -H 'Sec-Fetch-Site: same-site' \
  -H 'User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36' \
  -H 'sec-ch-ua: "Chromium";v="122", "Not(A:Brand";v="24", "Google Chrome";v="122"' \
  -H 'sec-ch-ua-mobile: ?0' \
  -H 'sec-ch-ua-platform: "Linux"' \
  -H 'Content-Type: application/json' \
  --data-raw '{"Service":"clusterManager","Entity":"systemConfigs","Limit":10,"Offset":0}' \
  --insecure \
  --silent \
  --output "/tmp/changelog.json"

## Parse the JSON file by an action date
CHANGELOG_DATES=($(jq '.[].data.payload[].createdAt' /tmp/changelog.json | sed 's/^.//' | sed 's/.$//'))

## Getting dates
YESTERDAY=$(date --date="1 day ago" +%s)

for CREATED_AT in ${CHANGELOG_DATES[@]}
do
    CHANGES_DATE=$(date --date="$(echo $CREATED_AT | awk -F'T' '{print $1}')" +%s)

    if [[ $CHANGES_DATE -ge $YESTERDAY ]]
    then
        echo "System configs history: ${ORANGE}[New changes]${RESET}"
    else
        echo "System configs history: ${GREEN}[OK]${RESET}"
    fi
done