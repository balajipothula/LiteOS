#!/bin/bash

# Start a build
# Build Docker image (Toybox 0.8.13) using specified Dockerfile
docker image build --tag toybox:0.8.13 --file $HOME/Dockerfile_Toybox0.8.13 .

# Create docker volume mapping directory
mkdir --parents $HOME/LiteOS

# Create and run a new container from an image
# Create and run Toybox build container with output bind mount
docker container run --name lite_os_builder --hostname lite-os-builder --interactive --tty --detach --mount type=bind,source=$HOME/LiteOS,target=/LiteOS toybox:0.8.13

# Execute a command in a running container
# Open interactive bash shell inside lite_os_builder container
docker container exec --interactive --tty lite_os_builder bash

make defconfig && \
make && \
./mkroot/mkroot.sh \
  TARGET='x86_64' \
  LINUX='/linux' \
  KEXTRA='NET,PACKET,UNIX,INET,IP_PNP,IP_PNP_DHCP,CRYPTO,CRYPTO_AES,CRYPTO_SHA256,CRYPTO_HMAC,VIRTIO,VIRTIO_MMIO,VIRTIO_MMIO_CMDLINE_DEVICES,VIRTIO_NET,VIRTIO_BLK' \
  CROSS_COMPILE='/x86_64-linux-musl-cross/bin/x86_64-linux-musl-' \
  OUTPUT="/LiteOS" \
  CONSOLE='ttyS0' \
  MEMORY='256M' \
  SIZE=2048 \
  FSTYPE='ext4' \
  NATIVE=1 \
  dropbear

