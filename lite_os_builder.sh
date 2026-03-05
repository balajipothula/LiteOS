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

./mkroot/mkroot.sh dropbear overlay OVERLAY=~/blah

# toybox > mkroot > packages > dropbear 7&8 10&11 lines

curl --silent --location --fail --show-error --remote-name https://matt.ucc.asn.au/dropbear/releases/dropbear-2025.89.tar.bz2 && sha1sum dropbear-2025.89.tar.bz2
65a32c5de0041e65cf9ab6cc894a64e07ed31e47  dropbear-2025.89.tar.bz2

curl --silent --location --fail --show-error --remote-name https://www.zlib.net/fossils/zlib-1.3.2.tar.gz && sha1sum zlib-1.3.2.tar.gz
0097186c2635358f2239c95d559796238c6640d4  zlib-1.3.2.tar.gz

sudo chown --recursive balaji:balaji $HOME/LiteOS

