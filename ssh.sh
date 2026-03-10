#!/bin/bash

# Author      : BALAJI POTHULA <balaji.pothula@techie.com>,
# Date        : 31 August 2016,
# Description : Remote Server SSH Login.

# Generate 4096-bit RSA key, rename to .pem, set secure permissions
# ssh-keygen -q -N '' -m pem -t rsa -b 4096 -C balaji.pothula@techie.com -f $HOME/webapp && mv $HOME/webapp $HOME/webapp.pem && chmod 400 $HOME/webapp.pem

readonly USR=ubuntu
readonly HOST=3.108.53.72
readonly PORT=22
readonly PEM=ec2helper.pem

ssh -o ServerAliveInterval=60 -o ServerAliveCountMax=30 -o CheckHostIP=no -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $HOME/$PEM $USR@$HOST -p $PORT

