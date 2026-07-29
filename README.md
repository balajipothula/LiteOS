# LiteOS

LiteOS is a lightweight Linux-based operating system built from source
using the Toybox and Linux Kernel.

## Features

-   Toybox **0.8.13**
-   Linux Kernel **6.12.79**
-   Dropbear SSH
-   DHCP networking
-   Boots in QEMU
-   Boots in AWS Cloud
-   Small memory footprint

## Why LiteOS?

LiteOS demonstrates that a fully functional Linux system can run with an extremely small memory footprint, making it ideal for embedded systems and virtual machines. Its minimal design also makes it suitable for building secure, real-time server environments. By including only essential components, LiteOS reduces its attack surface—fewer packages mean fewer entry points for potential security threats.


## Memory Footprint

``` text
RAM Usage: 10M
HDD Usage: 3.5M
```

Despite using only about **10 MB RAM**, LiteOS provides a shell,
networking, SSH, and standard Linux utilities.

## Build
#### Note: `/var/tmp/` typically has `drwxrwxrwt` permissions on most Linux distributions.
##### Place `build`, `build_lite_os.sh`, and `Dockerfile` from the LiteOS repository in `/var/tmp/sysroot/dl/`.
###### Tested on: AWS EC2 Ubuntu Server 24.04 LTS (x86_64, AMI: `ami-02b8269d5e85954ef`)
###### Please wait while the build is running. Build time varies by system configuration.
``` bash
mkdir -p /var/tmp/sysroot/dl
cd /var/tmp/sysroot/dl/
git clone https://github.com/balajipothula/LiteOS.git
mv LiteOS/* /var/tmp/sysroot/dl/
chmod +x build
./build setup_docker
./build setup_docker_rootless
./build lite_os_inn_docker
```

## Boot

``` bash
cd /var/tmp/sysroot/dl/LiteOS
./run-qemu.sh
```
