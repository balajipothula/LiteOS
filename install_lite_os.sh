#!/bin/bash

# Exit immediately if any command returns a non-zero status.
set -e

# Define the target disk device where LiteOS will be installed.
DISK=/dev/xvdf

# Define EFI System Partition — partition 1.
EFI=${DISK}1

# Define root filesystem partition — partition 2.
ROOT_FS=${DISK}2

# Define LiteOS build output directory.
LITE_OS=$HOME/LiteOS

# Define public SSH key to be injected for root login.
PUB_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDNHlYyDburNESaGZ035Tlym1bIdEVA6lGT1ixcCE2PNeEa8x7AAkaa2knakreDTWznSdfJe7wU/nkp2x0qxqFv+6qUOGLMO3nIFoeeprxVjMYxVa8+jDSkrdkOvZfBYkp3y6La8sry98LgkW7kAqGOYS1NNvuqnVIzSEkVaqBKp930gNwKA0bdo9AWX3n0xNxNfGYZSCTFLdPVxijoQckA4MDXzy/Dggq6JwvkdnJAR/Axozh4j8jh8YYkOtFSqGV/dAPloIb+H2PmTCpBvy7X/xgWimy5D2BF5bFeiT34elJt6eNMkXutbyPLlwTgs5uJ+ro68/m2M+U6aaxhXwwX"

# Install required packages for SSH key generation and GRUB EFI bootloader creation.
sudo apt --yes update
sudo apt --yes install dropbear grub-efi-amd64-bin grub2-common

# Create a new GPT partition table on the target disk.
sudo parted "$DISK" --script mklabel gpt

# Create EFI System Partition (FAT32) from 1MiB to 201MiB.
sudo parted "$DISK" --script mkpart ESP fat32 1MiB 201MiB

# Mark partition 1 as EFI bootable.
sudo parted "$DISK" --script set 1 esp on

# Create root filesystem partition (ext4) using remaining disk space.
sudo parted "$DISK" --script mkpart root ext4 201MiB 100%

# Create FAT32 filesystem on EFI partition.
sudo mkfs.vfat -F32 -n EFI "$EFI"

# Create ext4 filesystem on root partition.
sudo mkfs.ext4 -L rootfs "$ROOT_FS"

# Create mount point for LiteOS root filesystem.
sudo mkdir --parents /mnt/liteos

# Mount root filesystem partition.
sudo mount "$ROOT_FS" /mnt/liteos

# Create EFI mount directory inside the target root filesystem.
sudo mkdir --parents /mnt/liteos/boot/efi

# Mount EFI partition inside the target root filesystem.
sudo mount "$EFI" /mnt/liteos/boot/efi

# Copy LiteOS filesystem built by mkroot.sh into the target root filesystem.
sudo cp --archive "$LITE_OS/fs/." /mnt/liteos/

# Set root ownership on all files copied from the build container.
sudo chown --recursive root:root /mnt/liteos/

# Copy the Linux kernel image to the target boot directory.
sudo cp "$LITE_OS/linux-kernel" /mnt/liteos/boot/vmlinuz

# Create resolv.conf with EC2 internal DNS resolver.
echo "nameserver 169.254.169.253" | sudo tee /mnt/liteos/etc/resolv.conf

# Create rc directory for network event scripts.
sudo mkdir --parents /mnt/liteos/etc/rc

# Create DHCP event script used to configure networking after DHCP lease.
sudo tee /mnt/liteos/etc/rc/ifup > /dev/null <<'EoN'
#!/bin/sh
case "$1" in
  bound|renew)
    ifconfig eth0 $ip netmask $subnet
    route add default gw $router
    ;;
  deconfig)
    ifconfig eth0 0.0.0.0
    ;;
esac
EoN

# Make DHCP event script executable.
sudo chmod +x /mnt/liteos/etc/rc/ifup

# Create the main init script executed as PID 1 during system boot.
sudo tee /mnt/liteos/init > /dev/null <<'EoI'
#!/bin/sh
export HOME=/home PATH=/bin:/sbin:/usr/bin:/usr/sbin
if ! mountpoint -q dev; then
  mount -t devtmpfs dev dev
  [ $$ -eq 1 ] && ! 2>/dev/null <0 && exec 0<>/dev/console 1>&0 2>&1
  for i in ,fd /0,stdin /1,stdout /2,stderr
  do ln -sf /proc/self/fd${i/,*/} dev/${i/*,/}; done
  mkdir -p dev/shm
  chmod +t /dev/shm
fi
mountpoint -q dev/pts || { mkdir -p dev/pts && mount -t devpts dev/pts dev/pts;}
mountpoint -q proc || mount -t proc proc proc
mountpoint -q sys || mount -t sysfs sys sys
mount -o remount,rw /
echo 0 99999 > /proc/sys/net/ipv4/ping_group_range
if [ $$ -eq 1 ]; then
  mountpoint -q mnt || [ -e /dev/?da ] && mount /dev/?da /mnt
  ifconfig lo 127.0.0.1
  ifconfig eth0 up
  dhcp -i eth0 -s /etc/rc/ifup -q &
  [ "$(date +%s)" -lt 10000000 ] && sntp -sq time.google.com
  for i in $(ls -1 /etc/rc 2>/dev/null | sort); do . /etc/rc/"$i"; done
  echo 3 > /proc/sys/kernel/printk
  [ -z "$HANDOFF" ] && [ -e /mnt/init ] && HANDOFF=/mnt/init
  [ -z "$HANDOFF" ] && HANDOFF=/bin/sh && echo -e '\e[?7hType exit when done.'
  setsid -c <>/dev/$(sed '$s@.*[ /]@@' /sys/class/tty/console/active) >&0 2>&1 \
    $HANDOFF
  reboot -f &
  sleep 5
else
  /bin/sh
  umount /dev/pts /dev /sys /proc
fi
EoI

# Set ownership and executable permissions on the init script.
sudo chown root:root /mnt/liteos/init
sudo chmod +x /mnt/liteos/init

# Create GRUB configuration directory.
sudo mkdir --parents /mnt/liteos/boot/grub

# Generate GRUB configuration file for LiteOS boot.
sudo tee /mnt/liteos/boot/grub/grub.cfg > /dev/null <<'EoG'
set default=0
set timeout=5

menuentry "LiteOS" {
    insmod gzio
    insmod part_gpt
    insmod ext2
    set root=(hd0,gpt2)
    linux /boot/vmlinuz root=/dev/nvme0n1p2 rootfstype=ext4 rootwait rw console=ttyS0,115200 init=/init
}
EoG

# Create EFI boot directory.
sudo mkdir --parents /mnt/liteos/boot/efi/EFI/BOOT

# Build standalone GRUB EFI bootloader with embedded grub.cfg.
sudo grub-mkstandalone \
  --format=x86_64-efi \
  --output=/mnt/liteos/boot/efi/EFI/BOOT/BOOTX64.EFI \
  --modules="part_gpt ext2 linux gzio normal search" \
  "boot/grub/grub.cfg=/mnt/liteos/boot/grub/grub.cfg"

# Create filesystem mount configuration file.
sudo tee /mnt/liteos/etc/fstab > /dev/null <<'EoT'
/dev/nvme0n1p2  /           ext4    defaults,noatime  0 1
/dev/nvme0n1p1  /boot/efi   vfat    defaults          0 2
proc            /proc       proc    defaults          0 0
sysfs           /sys        sysfs   defaults          0 0
devpts          /dev/pts    devpts  defaults          0 0
EoT

# Create root SSH directory.
sudo mkdir --parents /mnt/liteos/root/.ssh

# Set secure permissions on root SSH directory.
sudo chmod 700 /mnt/liteos/root/.ssh

# Add public SSH key to authorized_keys.
echo "$PUB_KEY" | sudo tee /mnt/liteos/root/.ssh/authorized_keys > /dev/null

# Set secure permissions on authorized_keys file.
sudo chmod 600 /mnt/liteos/root/.ssh/authorized_keys

# Create Dropbear SSH host key directory.
sudo mkdir --parents /mnt/liteos/etc/dropbear

# Generate Dropbear RSA host key.
sudo dropbearkey -t rsa -f /mnt/liteos/etc/dropbear/dropbear_rsa_host_key

# Generate Dropbear ECDSA host key.
sudo dropbearkey -t ecdsa -f /mnt/liteos/etc/dropbear/dropbear_ecdsa_host_key

# Flush filesystem buffers to disk.
sync

# Unmount EFI partition.
sudo umount /mnt/liteos/boot/efi

# Unmount root filesystem.
sudo umount /mnt/liteos

