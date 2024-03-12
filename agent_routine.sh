#!/usr/bin/bash

## The firs option is a master node IP address
SOURCE_LINES=(4 5 7 8)
MASTER_NODE=$1

## Correct the sources.list - comment the third line and uncomment lines 4,5,7,8
cd /etc/apt/

sed '3 s/./#&/' sources.list >output.txt && mv output.txt sources.list

for LINE in ${SOURCE_LINES[@]}
do
    sed "$LINE s/^.//" sources.list >output.txt && mv output.txt sources.list
done

## Add the pangeoradar.list file
echo "deb [trusted=yes] https://$MASTER_NODE:4443 1.7_x86-64 main" > /etc/apt/sources.list.d/pangeoradar.list

apt update
apt install -y wget

## Install Log Navigator
wget https://github.com/tstack/lnav/releases/download/v0.12.0/lnav-0.12.0-linux-musl-x86_64.zip
unzip lnav-0.12.0-linux-musl-x86_64.zip
cd lnav-0.12.0/ && cp lnav /usr/sbin

## Set root aliases
echo "alias lnav='/usr/sbin/lnav'" >> /root/.bashrc
echo "alias ls='ls -lh'" >> /root/.bashrc
source /root/.bashrc

## Delete temporal directories
cd ..
rm lnav-0.12.0-linux-musl-x86_64.zip
rm -r lnav-0.12.0
apt remove -y syslog-ng

sed '1 s/.$//' /etc/digsig/digsig_initramfs.conf >conf.txt && mv conf.txt /etc/digsig/digsig_initramfs.conf
sed '1 s/.*/\U&0/' /etc/digsig/digsig_initramfs.conf >conf.txt && mv conf.txt /etc/digsig/digsig_initramfs.conf
cat /etc/digsig/digsig_initramfs.conf

update-initramfs -u -k all

## Edit sshd config to open the root ssh connection
sed -i -e 's/ChallengeResponseAuthentication no/ChallengeResponseAuthentication yes/g' /etc/ssh/sshd_config
sed -i -e 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config

systemctl restart sshd

reboot now