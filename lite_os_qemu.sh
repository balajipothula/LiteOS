#!/bin/bash

sudo apt --yes install qemu-system-x86 qemu-utils erofs-utils

lz4, lz4hc, lzma, deflate, libdeflate

mkfs.erofs rootfs.erofs fs

mkfs.erofs -zlz4 rootfs.erofs fs

mkfs.erofs -zstd rootfs.erofs fs

mkfs.erofs lz4 $HOME/LiteOS/rootfs.erofs $HOME/LiteOS/fs

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

qemu-system-x86_64 \
  -m 256M \
  -nographic \
  -no-reboot \
  -kernel linux-kernel \
  -initrd initramfs.cpio.gz \
  -append "HOST=x86_64 console=ttyS0 root=/dev/sda ro" \
  -drive file=rootfs.erofs,format=raw,if=ide \
  -nic user,hostfwd=tcp:127.0.0.1:2222-:22 \
  -nographic

balaji@pothula:~$ ssh -p 2222 root@127.0.0.1
The authenticity of host '[127.0.0.1]:2222 ([127.0.0.1]:2222)' can't be established.
ED25519 key fingerprint is SHA256:9n2O9Gw/yJAxuvxkS508wJRREasF0ghoYpaup1pDuWA.
This key is not known by any other names.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added '[127.0.0.1]:2222' (ED25519) to the list of known hosts.
root@127.0.0.1's password: 
$ ls
$ free -h
		total        used        free      shared     buffers
Mem:             240M        8.6M        231M           0           0
-/+ buffers/cache:           8.6M        231M
Swap:               0           0           0
$ df -h
Filesystem      Size Used Avail Use% Mounted on
dev             119M    0  119M   0% /dev

