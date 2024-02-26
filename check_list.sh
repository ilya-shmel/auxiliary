#!/usr/bin/bash

## Font variables
RED=$(tput setaf 1)
YELLOW=$(tput setaf 3)
GREEN=$(tput setaf 2)
ORANGE=$(tput setaf 202)
RESET=$(tput sgr 0)
BOLD=$(tput bold)
NORMAL=$(tput sgr0)

## Проверить доступность мониторинга и собираемых метрик - master?
echo "Checking the monitoring availability."
MONITORING=$(curl -s https://$(hostname -i)/admin/monitoring)

if [[ ! -n $(echo $MONITORING) ]]
then
    echo "${RED}${BOLD}The monitoring page is unavailable!${RESET}"
else
    echo "${YELLOW}The monitoring page is available!${RESET}"
fi

echo "Checking the Prometheus metrics."
METRICS=$(curl -s https://$(hostname -i):9100/metrics)

if [[ ! -z $(echo $METRICS | grep "400 Bad Request") ]]
then
    echo "${RED}${BOLD}The Prometheus metrics are unavailable!${RESET}"
else
    if [[ $(echo $METRICS | wc --words) -le 40 ]]
    then
        echo "${RED}${BOLD}The Prometheus metrics are unavailable!${RESET}"
    else 
        echo "${YELLOW}The Prometheus metrics are available!${RESET}"
    fi
fi

#CORRELATOR_IDLE=$(top -bn1 | grep "%Cpu" | awk -F'.' '{print $4}'| awk -F' ' '{print $3}')
#CORRELATOR_WAIT=$(top -bn1 | grep "%Cpu" | awk -F'.' '{print $5}' | awk -F' ' '{print $3}')  
#
#CORRELATOR_LA1=$(awk -F' ' '{print $1}' /proc/loadavg)
#CORRELATOR_LA5=$(awk -F' ' '{print $2}' /proc/loadavg)
#CORRELATOR_LA15=$(awk -F' ' '{print $3}' /proc/loadavg)