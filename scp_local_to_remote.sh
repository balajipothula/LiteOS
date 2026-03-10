#!/bin/bash

# Author      : BALAJI POTHULA <balaji.pothula@techie.com>,
# Date        : 31 August 2016,
# Description : SCP from Client to Remote Server.

# tar --create  --gzip --file=$HOME/lite_os.tar.gz --directory $HOME LiteOS
# tar --extract --gzip --file=$HOME/lite_os.tar.gz --directory $HOME
# BhārOṠ

readonly USR=ubuntu
readonly HOST=3.108.53.72
readonly PORT=22
readonly PEM=ec2helper.pem

readonly SH="install_lite_os.sh"
readonly LITE_OS=lite_os.tar.gz

# Copying file(s) from local to remote.
scp -o CheckHostIP=no -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $(pwd)/$PEM -P $PORT $(pwd)/$SH $USR@$HOST:~

