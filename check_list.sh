#!/usr/bin/bash

## Check a service status function
check_status_function(){
    local STATUS SERVICE
    local SERVICE=$2
    local FORCE=$3

    #log_function "check_status" "$@"

    if [[ $IP_LIST == *"$1"* ]]
    then
        STATUS=$(systemctl status ${SERVICE})
    else
        STATUS=$(ssh -o "StrictHostKeyChecking no" -i $KEY_PATH root@$1 systemctl status ${SERVICE} 2>&1)
    fi

    if echo "$STATUS"| grep --quiet "$ACTIVE"
    then
         echo "${SERVICE}: ${GREEN}[OK]${RESET}"

    	if [ ${conf[diag]} -eq 1 ]
    	then
		    SERVICE_LIST+="$1=${SERVICE}|"
    fi

	if [ $FORCE -eq 1 ]
	then
        SERVICE_LIST+="$1=${SERVICE}|"
	fi

    return 1;

    elif [[ "$STATUS" == *"No route to host"* ]]
    then
	    echo "${SERVICE}: ${RED} [No route to host] ${RESET}"
    else
        echo "${SERVICE}: ${RED} [ERROR] ${RESET}"
	    SERVICE_LIST+="$1=$2|"
        return 0;
    fi
}

## Font variables
RED=$(tput setaf 1)
YELLOW=$(tput setaf 3)
GREEN=$(tput setaf 2)
ORANGE=$(tput setaf 202)
RESET=$(tput sgr 0)
BOLD=$(tput bold)
NORMAL=$(tput sgr0)

## Configuration array
declare -A conf
conf[diag]=0
conf[diag_worker]=0


## Check worker array
declare -A check_worker
check_worker[pangeoradar-termite]=1
check_worker[pangeoradar-termite-api]=1


TRESHOLD=85
CURRENT_NODE_IP=$(hostname -i)
TERMITE_DIR="/opt/pangeoradar/configs/termite/"
TERMITE_SUB_DIR=("normalizers/" "normalizers/system" "normalizers/debug" "normalizers/client" "parsers/client" "parsers/debug" "parsers/system")

## Проверить доступность мониторинга и собираемых метрик -> master?
#echo "Checking the monitoring availability."
MONITORING=$(curl -s https://$(hostname -i)/admin/monitoring)

if [[ ! -n $(echo $MONITORING) ]]
then
    echo "The monitoring page: ${RED}[ERROR]${RESET}"
else
    echo "The monitoring page: ${GREEN}[OK]${RESET}"
fi

#echo "Checking the Prometheus metrics."
METRICS=$(curl -s https://$(hostname -i):9100/metrics)

if [[ ! -z $(echo $METRICS | grep "400 Bad Request") ]]
then
    echo "${RED}${BOLD}The Prometheus metrics are unavailable!${RESET}"
else
    if [[ $(echo $METRICS | wc --words) -le 40 ]]
    then
        echo "The Prometheus metrics: ${RED}[ERROR]${RESET}"
    else 
        echo "The Prometheus metrics: ${GREEN}[OK]${RESET}"
    fi
fi

## Проверка наличия дискового пространства на всех нодах и разделах (должно быть занято менее 85%) -> all nodes
#echo "Checking the disk space availability."
USED_DISK_SPACE=$(df -h / | grep "/dev" | awk -F' ' '{print $5}' | awk -F'%' '{print $1}')
PARTITION=$(df -h / | grep "/dev" | awk -F' ' '{print $1}')

if [[ $USED_DISK_SPACE -ge $TRESHOLD ]]
then 
	echo "Used disk space: ${RED}[ALERT] ("$USED_DISK_SPACE"%)${RESET}"
else
    echo "Used disk space: ${GREEN}[OK]${RESET}"
fi

## Проверка наличия ошибок на всех нодах -> all nodes
PROBLEM_ENTRIES=$(journalctl --quiet --output=short --priority=0..3 --since yesterday)

if [[ -z $PROBLEM_ENTRIES ]]
then
    echo "Error log entries: ${GREEN}[OK]${RESET}"
else
    echo "Error log entries: ${RED}[ERROR]${RESET}"
fi

### Проверка работы каждого термита -> worker
## Cобытия поступают -?, нет ошибок -> worker
TERMITE_ERRORS=$(echo $(journalctl --quiet --output=short --priority=0..3 --since yesterday) | grep "termite")
if [[ -z $TERMITE_ERRORS ]]
then
    echo "Termite errors: ${GREEN}[OK]${RESET}"
else
    echo "Termite errors: ${RED}[ERROR]${RESET}"
fi

## Проверка работы парсинга на термитах (исправление при обнаружении) -> worker
PARSING_ERRORS=$(echo $(journalctl --quiet --output=short --since yesterday) | grep "could not be parsed")

if [[ -z $PARSING_ERRORS ]]
then
    echo "Parsing errors: ${GREEN}[OK]${RESET}"
else
    echo "Parsing errors: ${RED}[ERROR]${RESET}"
fi

## Убедиться в том, что служба Termite API функционирует корректно -> worker
#TERMITE_API_STATUS=$(systemctl status pangeoradar-termite-api.service | grep "Active:" | awk -F' ' '{print $2}')
for KEY in "${!check_worker[@]}"
do
    check_status_function $CURRENT_NODE_IP $KEY ${conf[diag_worker]}
done

## Убедиться что директории присутствуют (для версии 3.7 и выше)
PANGEO_VERSION=$(dpkg -l | grep pangeoradar-ui | awk -F' ' '{print $3}' | awk -F'.' '{print $1 $2}')

if [[ "$PANGEO_VERSION" -ge "37" ]]
then
	for DIR in ${TERMITE_SUB_DIR[@]}
	do
		if [ ! -d $DIR ]
		then
			echo "Termite directory "$DIR""$TERMITE_SUB_DIR": ${RED}[ERROR]${RESET}"
		else
            echo "Termite directory "$DIR""$TERMITE_SUB_DIR": ${GREEN}[OK]${RESET}"
        fi
	done
fi

## Проверка балансировщика
## Убедиться, что количество партиций источника равно или больше количеству нод термита

#Убедиться, что количество партиций топика нормализед соответствует количеству гетеров бивера


## Просмотреть аудит действий




#CORRELATOR_IDLE=$(top -bn1 | grep "%Cpu" | awk -F'.' '{print $4}'| awk -F' ' '{print $3}')
#CORRELATOR_WAIT=$(top -bn1 | grep "%Cpu" | awk -F'.' '{print $5}' | awk -F' ' '{print $3}')  
#
#CORRELATOR_LA1=$(awk -F' ' '{print $1}' /proc/loadavg)
#CORRELATOR_LA5=$(awk -F' ' '{print $2}' /proc/loadavg)
#CORRELATOR_LA15=$(awk -F' ' '{print $3}' /proc/loadavg)