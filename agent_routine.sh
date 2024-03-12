#!/usr/bin/bash

apt install wget

## Install Log Navigator
wget https://github.com/tstack/lnav/releases/download/v0.12.0/lnav-0.12.0-linux-musl-x86_64.zip
unzip lnav-0.12.0-linux-musl-x86_64.zip
cd lnav-0.12.0/ && cp lnav /usr/sbin

## Set root aliases
echo "alias lnav='/usr/sbin/lnav'" >> /root/.bashrc
echo "alias ls='ls -lh'" >> /root/.bashrc
. /root/.bashrc

## Delete temporal directories
rm lnav-0.12.0-linux-musl-x86_64.zip
rm lnav-0.12.0/
