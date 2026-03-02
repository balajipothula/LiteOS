#!/bin/bash

# Start a build
# Build Docker image (Toybox 0.8.13) using specified Dockerfile
docker image build --tag toybox:0.8.13 --file $HOME/Dockerfile_Toybox0.8.13 .

# Create docker volume mapping directory
mkdir --parents $HOME/toybox/root/host

# Create and run a new container from an image
# Create and run Toybox build container with output bind mount
docker container run --name lite_os_builder --hostname lite-os-builder --interactive --tty --detach --mount type=bind,source=$HOME/toybox/root/host/,target=/toybox/root/host/ toybox:0.8.13

# Execute a command in a running container
# Open interactive bash shell inside lite_os_builder container
docker container exec --interactive --tty lite_os_builder bash

cd /dropbear && \
./configure --prefix=/usr --disable-zlib --disable-pam CFLAGS="-static" LDFLAGS="-static" && \
make PROGRAMS="dropbear dropbearkey" -j$(nproc)

mkdir --parents /toybox/root/usr/bin /toybox/root/etc/dropbear

cp /dropbear/dropbear /toybox/root/usr/bin/
cp /dropbear/dropbearkey /toybox/root/usr/bin/

# Generate host keys
/dropbear/dropbearkey -t ecdsa -f /toybox/root/etc/dropbear/dropbear_ecdsa_host_key

make defconfig && make && TARGET=x86_64 LINUX=/linux KCONFIG_ALLCONFIG=lite_os_kernel.config ./mkroot/mkroot.sh

TARGET=x86_64 LINUX=/toybox/linux ./mkroot/mkroot.sh ext4=2048

