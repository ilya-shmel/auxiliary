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
    echo CORRELATOR_IDLE
fi

## Проверить кроны на нодах (что не изменились) -> all nodes
CRON_JOBS=('/etc/crontab' '/etc/cron.d/atop' '/etc/cron.d/sysstat' '/etc/cron.daily/apt-compat' '/etc/cron.daily/bsdmainutils' '/etc/cron.daily/dpkg' '/etc/cron.daily/logrotate' '/etc/cron.daily/ntp' '/etc/cron.daily/passwd' '/etc/cron.daily/sysstat') 
#CRON_DATES=(1629225944 1629375535 1708065682 1629225924 1629225944 1629225923 1629225943 1701862388 1629225925 1708065682)
SYSTREM_BOOT=$(who -b)
REBOOT_TIME=$(date --date="$(echo $SYSTEM_BOOT | awk -F' ' '{print $3, $4}')" +"%s")
CRON_WARN=0


for (( INDEX=0; INDEX<${#CRON_JOBS[@]}; ++INDEX ))
do
    LAST_CHANGE=$(stat --format %Z ${CRON_JOBS[INDEX]})
    if [[ $LAST_CHANGE -ge $REBOOT_TIME  ]]
    then
        echo "${CRON_JOBS[INDEX]} was edited"
        CRON_WARN=$((CRON_WARN + 1))
    fi
done

## Check if the CRON directories are empty
if [[ -n $(ls -l /etc/cron.monthly/* 2>/dev/null) ]] || [[ -n $(ls -l /etc/cron.weekly/* 2>/dev/null) ]] || [[ -n $(ls -l /etc/cron.hourly/* 2>/dev/null) ]]
then
    CRON_WARN=$((CRON_WARN + 1)) 
fi

## Check the number of files in the cron.d directory
if [[ $(ls /etc/cron.d | wc --lines) -gt 2 ]]
then
    echo "Additional jobs in /etc/cron.d!"
    CRON_WARN=$((CRON_WARN + 1))
fi

if [[ $CRON_WARN -gt 0 ]]
then 
    echo "CRON jobs: ${YELLOW}[WARNING]${RESET}"
else
    echo "CRON jobs: ${GREEN}[OK]${RESET}"
fi

## Сервер корреляции -> correlator
## Проверить наличие свободной памяти (ОЗУ)
FREE_MEMORY=$(free -m | grep "Mem:")
FREE_MEMORY=$(echo $FREE_MEMORY | awk -F' ' '{print $4}')

if [[ $FREE_MEMORY -le 1000 ]]
then 
    echo "Free memory: ${YELLOW}[WARNING - "$FREE_MEMORY"Mb]${RESET}"
else
    echo "Free memory: ${GREEN}[OK]${RESET}"
fi

## Проверить загрузку - id, wa in top
CPU_LINE=$(top -bn1 | grep Cpu)
CORRELATOR_IDLE=$(echo $CPU_LINE | awk -F'.' '{print $4}'| awk -F' ' '{print $3}')
CORRELATOR_WAIT=$(echo $CPU_LINE | awk -F'.' '{print $5}' | awk -F' ' '{print $3}')

## Check the CPU idle
if [[ $CORRELATOR_IDLE -le 50 ]]
then
    echo "CPU idle time: ${YELLOW}[WARNING]${RESET}"
else
    echo "CPU idle time: ${GREEN}[OK]${RESET}"
fi

## Check the CPU wait
if [[ $CORRELATOR_WAIT -gt 3 ]]
then
    echo "CPU wait time: ${YELLOW}[WARNING]${RESET}"
else
    echo "CPU wait time: ${GREEN}[OK]${RESET}"
fi

## Проверить LA
LOAD_AVERAGE=$(cat /proc/loadavg)

CORRELATOR_LA1=$(echo $LOAD_AVERAGE | awk -F' ' '{print $1}' /proc/loadavg)
CORRELATOR_LA5=$(echo $LOAD_AVERAGE | awk -F' ' '{print $2}' /proc/loadavg)
CORRELATOR_LA15=$(echo $LOAD_AVERAGE | awk -F' ' '{print $3}' /proc/loadavg)

CORES=$(nproc --all)

COMPARE1=$(echo $CORES $CORRELATOR_LA1 | awk '{if ($1 > $2) print 1;}')
COMPARE5=$(echo $CORES $CORRELATOR_LA5 | awk '{if ($1 > $2) print 1;}')
COMPARE15=$(echo $CORES $CORRELATOR_LA15 | awk '{if ($1 > $2) print 1;}')

if [[ $COMPARE1 != 1 || $COMPARE5 != 1 || $COMPARE15 != 1 ]]
then 
    echo "Load average: ${RED}[WARNING]${RESET}"
else
    echo "Load average: ${GREEN}[OK]${RESET}"
fi