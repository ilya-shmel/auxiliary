#!/usr/bin/bash
SOURCE_LINES=(4 5 7 8)
MASTER_NODE=$1

## Correct the sources.list - comment the third line and uncomment lines 4,5,7,8
cd /etc/apt/

sed '3 s/./#&/' sources.list >output.txt && mv output.txt sources.list

for LINE in ${SOURCE_LINES[@]}
do
    sed "$LINE s/^.//" sources.list >output.txt && mv output.txt sources.list
done

#apt install wget
#
### Install Log Navigator
#wget https://github.com/tstack/lnav/releases/download/v0.12.0/lnav-0.12.0-linux-musl-x86_64.zip
#unzip lnav-0.12.0-linux-musl-x86_64.zip
#cd lnav-0.12.0/ && cp lnav /usr/sbin
#
### Set root aliases
#echo "alias lnav='/usr/sbin/lnav'" >> /root/.bashrc
#echo "alias ls='ls -lh'" >> /root/.bashrc
#. /root/.bashrc
#
### Delete temporal directories
#rm lnav-0.12.0-linux-musl-x86_64.zip
#rm lnav-0.12.0/
