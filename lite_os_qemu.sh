#!/bin/bash

sudo apt --yes install qemu-system-x86 qemu-utils erofs-utils

mkfs.erofs rootfs.erofs fs

mkfs.erofs -zlz4 rootfs.erofs fs

mkfs.erofs -zstd rootfs.erofs fs

mkfs.erofs -zlz4 $HOME/toybox/root/host/rootfs.erofs $HOME/toybox/root/host/fs

qemu-system-x86_64 \
  -m 256M \
  -nographic \
  -no-reboot \
  -kernel linux-kernel \
  -initrd initramfs.cpio.gz \
  -append "HOST=x86_64 console=ttyS0" \
  -netdev user,id=net0 \
  -device e1000,netdev=net0

qemu-system-x86_64 \
  -m 256M \
  -nographic \
  -no-reboot \
  -kernel linux-kernel \
  -initrd initramfs.cpio.gz \
  -append "HOST=x86_64 console=ttyS0 root=/dev/sda ro" \
  -drive file=rootfs.erofs,format=raw,if=ide \
  -netdev user,id=net0 \
  -device e1000,netdev=net0

