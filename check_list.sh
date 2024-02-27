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

CURRENT_NODE_IP=$(hostname -i)
IP=$CURRENT_NODE_IP

TRESHOLD=85
TERMITE_DIR="/opt/pangeoradar/configs/termite/"
TERMITE_SUB_DIR=("normalizers/" "normalizers/system" "normalizers/debug" "normalizers/client" "parsers/client" "parsers/debug" "parsers/system")
PGR_LOGROTATE="/etc/logrotate.d/pgr_logrotate"
CERT_DIR="/opt/pangeoradar/certs/"

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

## OpenSearch (Elasticsearch для версии 3.6.7 и ниже) -> data
## Убедиться, что статус кластера GREEN - получается, здесь надо переделать для data в самом скрипте
## Check OpenSearch or ElasticSearch distribution
SE_VERSION=$(curl --silent -k -X GET https://$IP:9200 | jq -r '.version.distribution')

if [[ $SE_VERSION == "opensearch" ]]
then 
    SE_VERSION="OpenSearch"
    SE_LOG="/var/log/opensearch/pgr-os-cluster.log"
    SE_CRT_NAME="os.crt"
else
    SE_VERSION="ElasticSearch"
    SE_LOG="/var/log/elasticsearch/pgr-es-cluster.log"
    SE_CRT_NAME="es.crt"
fi

CLUSTER_HEALTH=$(curl --connect-timeout 5 -k -XGET -s https://$IP:9200/_cluster/health?pretty)
CLUSTER_STATUS=$(echo $CLUSTER_HEALTH | jq -r '.status')

case "$CLUSTER_STATUS" in
    green) echo "The $SE_VERSION cluster status: ${GREEN}[GREEN]${RESET}";;
    yellow) echo "The $SE_VERSION cluster status: ${YELLOW}[YELLOW]${RESET}";; 
    red) echo "The $SE_VERSION cluster status: ${RED}[RED]${RESET}";;
    *) echo "${RED}WARNING: cannot obtain the cluster status.${RESET}";; 
esac

## Проверить работу ротации событий в OS (журнал работы)
ALLOC=$(grep "o.e.c.r.a.AllocationService" $SE_LOG)
MAPPING=$(grep "o.e.c.m.MetaDataMappingService" $SE_LOG)
TEMPLATE=$(grep "o.e.c.m.MetaDataIndexTemplateService" $SE_LOG)
CREATE=$(grep "o.e.c.m.MetaDataCreateIndexService" $SE_LOG)

if [[ -n $ALLOC ]] || [[ -n $MAPPING ]] || [[ -n $TEMPLATE ]] || [[ -n $CREATE ]]
then
    echo "The $SE_VERSION events rotation: ${GREEN}[OK]${RESET}"
else
    echo "The $SE_VERSION events rotation: ${RED}[No rotation]${RESET}"
fi

## Проверить объемы логов (/var/log) и настройки службы logrotate - объем логов не должен превышать 10% от общего объема диска
LOGS_SIZE=$(du -hs /var/log | awk -F' ' '{print $1}' | sed 's/.$//')
DISC_SIZE=$(df -h / | grep "/dev" | awk -F' ' '{print $2}' | sed 's/.$//')
LOGS_SIZE_TRESHOLD=$((DISC_SIZE * 1024 / 10))

## Check the '/var/log' size
if [[ $LOGS_SIZE -ge $LOGS_SIZE_TRESHOLD ]]
then
    echo "The /var/logs size: ${RED}["$LOGS_SIZE"M]${RESET}"
else    
    echo "The /var/logs size: ${GREEN}[OK]${RESET}"
fi

## Check the logrotate
if [[ ! -e $PGR_LOGROTATE ]] || [[ ! -s $PGR_LOGROTATE ]]
then
    echo "pgr_logrotate: ${RED}[ERROR]${RESET}"
else
    if [[ $(cat $PGR_LOGROTATE | wc --lines) -lt 200 ]]
    then
        echo "pgr_logrotate: ${RED}[ERROR]${RESET}"
    else 
        echo "pgr_logrotate: ${GREEN}[OK]${RESET}"
    fi
fi

## Проверить доступ в документацию -> master
MANUAL=$(curl -s "https://$IP:8097")

if [[ -z $(echo $MANUAL | grep "400 Bad Request") ]] && [[ -z $(echo $MANUAL | grep "404 Not Found") ]]
then 
    echo "Documentation: ${GREEN}[OK]${RESET}"
else
    echo "Documentation: ${RED}[ERROR]${RESET}"
fi

## Проверить сроки действия сертификатов NGINX и OpenSearch на всех нодах -> all nodes
SE_CRT=$(openssl x509 -noout -in "$CERT_DIR""$SE_CRT_NAME" -checkend 86400)
NGINX_CRT=$(openssl x509 -noout -in "$CERT_DIR"pgr.crt -checkend 86400)

if [[ $SE_CRT == "Certificate will not expire" ]]
then 
    echo "$SE_VERSION certificate: ${GREEN}[OK]${RESET}"
else
    echo "$SE_VERSION certificate: ${RED}[ERROR]${RESET}"
fi

if [[ $NGINX_CRT == "Certificate will not expire" ]]
then 
    echo "NGINX certificate: ${GREEN}[OK]${RESET}"
else
    echo "NGINX certificate: ${RED}[ERROR]${RESET}"
fi

#CORRELATOR_IDLE=$(top -bn1 | grep "%Cpu" | awk -F'.' '{print $4}'| awk -F' ' '{print $3}')
#CORRELATOR_WAIT=$(top -bn1 | grep "%Cpu" | awk -F'.' '{print $5}' | awk -F' ' '{print $3}')  
#
#CORRELATOR_LA1=$(awk -F' ' '{print $1}' /proc/loadavg)
#CORRELATOR_LA5=$(awk -F' ' '{print $2}' /proc/loadavg)
#CORRELATOR_LA15=$(awk -F' ' '{print $3}' /proc/loadavg)