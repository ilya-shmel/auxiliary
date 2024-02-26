#!/usr/bin/bash



## Проверить доступность мониторинга и собираемых метрик
METRICS=$(curl -s https://$(hostname -i):9100/metrics)

if [[ ! -z $(echo $METRICS | grep "400 Bad Request") ]]
then
    echo "The Prometheus metrics are unavailable!"
fi

CORRELATOR_IDLE=$(top -bn1 | grep "%Cpu" | awk -F'.' '{print $4}'| awk -F' ' '{print $3}')
CORRELATOR_WAIT=$(top -bn1 | grep "%Cpu" | awk -F'.' '{print $5}' | awk -F' ' '{print $3}')  

CORRELATOR_LA1=$(awk -F' ' '{print $1}' /proc/loadavg)
CORRELATOR_LA5=$(awk -F' ' '{print $2}' /proc/loadavg)
CORRELATOR_LA15=$(awk -F' ' '{print $3}' /proc/loadavg)