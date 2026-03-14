#!/bin/bash

# Start a build
# Build Docker image (Toybox 0.8.13) using specified Dockerfile
docker image build --tag toybox:0.8.13 --file $HOME/Dockerfile_Toybox-0.8.13 .

# Create docker volume mapping directory
mkdir --parents $HOME/LiteOS

# Create and run a new container from an image
# Create and run Toybox build container with output bind mount
docker container run --name lite_os_builder --hostname lite-os-builder --interactive --tty --detach --mount type=bind,source=$HOME/LiteOS,target=/LiteOS toybox:0.8.13

# Execute a command in a running container
# Open interactive bash shell inside lite_os_builder container
docker container exec --interactive --tty lite_os_builder bash

# Edit toybox > mkroot > packages > dropbear shell file for latest dropbear and zlib
vi /toybox/mkroot/packages/dropbear

download 0097186c2635358f2239c95d559796238c6640d4 \
  https://www.zlib.net/fossils/zlib-1.3.2.tar.gz

download 65a32c5de0041e65cf9ab6cc894a64e07ed31e47 \
  https://matt.ucc.asn.au/dropbear/releases/dropbear-2025.89.tar.bz2

# Building Toybox Root Filesystem with Dropbear SSH Server and Kernel
KCONFIG_ALLCONFIG=/toybox/lite_os.config make defconfig && \
make && \
./mkroot/mkroot.sh \
  TARGET='x86_64' \
  LINUX='/linux' \
  PENDING='dhcp' \
  KEXTRA='NET,PACKET,UNIX,INET,IP_PNP,IP_PNP_DHCP,NETDEVICES,ETHERNET,CRYPTO,CRYPTO_HASH,CRYPTO_SHA1,CRYPTO_SHA256,CRYPTO_AES,CRYPTO_HMAC,VIRTIO,VIRTIO_MMIO,VIRTIO_MMIO_CMDLINE_DEVICES,VIRTIO_PCI,VIRTIO_BLK,VIRTIO_NET,NVME_CORE,BLK_DEV_NVME,PCI,PCI_MSI,NET_VENDOR_AMAZON,ENA_ETHERNET,HYPERVISOR_GUEST,PARAVIRT,KVM_GUEST,DEVTMPFS,DEVTMPFS_MOUNT,DEVPTS_FS,UNIX98_PTYS' \
  CROSS_COMPILE='/x86_64-linux-musl-cross/bin/x86_64-linux-musl-' \
  OUTPUT="/LiteOS" \
  CONSOLE='ttyS0' \
  MEMORY='256M' \
  SIZE=2048 \
  FSTYPE='ext4' \
  NATIVE=1 \
  dropbear

./mkroot/mkroot.sh dropbear overlay OVERLAY=~/blah

curl --silent --location --fail --show-error --remote-name https://www.zlib.net/fossils/zlib-1.3.2.tar.gz && sha1sum zlib-1.3.2.tar.gz

