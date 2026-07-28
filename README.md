# LiteOS

LiteOS is a lightweight Linux-based operating system built from source
using the Toybox and Linux Kernel.

## Features

-   Linux Kernel **6.12.79**
-   Toybox **0.8.13**
-   Dropbear SSH
-   DHCP networking
-   Boots in QEMU
-   Small memory footprint

## Why LiteOS?

LiteOS demonstrates that a fully functional Linux system can run with an extremely small memory footprint, making it ideal for learning, embedded systems, virtual machines, and experimentation. Its minimal design also makes it suitable for building secure, real-time server environments. By including only essential components, LiteOS reduces its attack surface—fewer packages mean fewer entry points for potential security threats.


## Memory Footprint

``` text
RAM Usage: 10M
HDD Usage of rootfs: 3.5M
```

Despite using only about **10 MB RAM**, LiteOS provides a shell,
networking, SSH, and standard Linux utilities.

## Build

``` bash
mkdir -p /var/tmp/sysroot/dl
cd /var/tmp/sysroot/dl
./build setup_docker
./build setup_docker_rootless
./build lite_os_inn_docker
```

## Boot

``` bash
cd /var/tmp/sysroot/dl/lite_os
./run-qemu.sh
```
