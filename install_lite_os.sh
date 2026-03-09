#!/bin/bash

set -e

# Install dependencies
sudo apt --yes update
sudo apt --yes install dropbear grub-efi-amd64-bin grub2-common

# Target disk
DISK=/dev/xvdf
EFI=${DISK}1
ROOTFS=${DISK}2

# LiteOS build output
LITEOS=$HOME/LiteOS

# Public SSH key
PUB_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDNHlYyDburNESaGZ035Tlym1bIdEVA6lGT1ixcCE2PNeEa8x7AAkaa2knakreDTWznSdfJe7wU/nkp2x0qxqFv+6qUOGLMO3nIFoeeprxVjMYxVa8+jDSkrdkOvZfBYkp3y6La8sry98LgkW7kAqGOYS1NNvuqnVIzSEkVaqBKp930gNwKA0bdo9AWX3n0xNxNfGYZSCTFLdPVxijoQckA4MDXzy/Dggq6JwvkdnJAR/Axozh4j8jh8YYkOtFSqGV/dAPloIb+H2PmTCpBvy7X/xgWimy5D2BF5bFeiT34elJt6eNMkXutbyPLlwTgs5uJ+ro68/m2M+U6aaxhXwwX"

# Partition the disk
sudo parted "$DISK" --script mklabel gpt
sudo parted "$DISK" --script mkpart ESP fat32 1MiB 201MiB
sudo parted "$DISK" --script set 1 esp on
sudo parted "$DISK" --script mkpart root ext4 201MiB 100%

# Format partitions
sudo mkfs.vfat -F32 -n EFI "$EFI"
sudo mkfs.ext4 -L rootfs "$ROOTFS"

# Mount
sudo mkdir -p /mnt/liteos
sudo mount "$ROOTFS" /mnt/liteos
sudo mkdir -p /mnt/liteos/boot/efi
sudo mount "$EFI" /mnt/liteos/boot/efi

# Copy fs/ contents as writable rootfs
sudo cp -a "$LITEOS/fs/." /mnt/liteos/

# Fix ownership — cp -a preserves source ownership from build container
sudo chown -R root:root /mnt/liteos/

# Copy kernel
sudo cp "$LITEOS/linux-kernel" /mnt/liteos/boot/vmlinuz

# Write clean /init with EC2 networking
sudo tee /mnt/liteos/init > /dev/null <<'EoI'
#!/bin/sh
export HOME=/home PATH=/bin:/sbin
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
echo 0 99999 > /proc/sys/net/ipv4/ping_group_range
if [ $$ -eq 1 ]; then
  mountpoint -q mnt || [ -e /dev/?da ] && mount /dev/?da /mnt
  # Networking
  ifconfig lo 127.0.0.1
  ifconfig eth0 up
  udhcpc -i eth0
  [ "$(date +%s)" -lt 10000000 ] && sntp -sq time.google.com
  # Run package scripts (if any)
  for i in $(ls -1 /etc/rc 2>/dev/null | sort); do . /etc/rc/"$i"; done
  echo 3 > /proc/sys/kernel/printk
  [ -z "$HANDOFF" ] && [ -e /mnt/init ] && HANDOFF=/mnt/init
  [ -z "$HANDOFF" ] && HANDOFF=/bin/sh && echo -e '\e[?7hType exit when done.'
  setsid -c <>/dev/$(sed '$s@.*[ /]@@' /sys/class/tty/console/active) >&0 2>&1 \
    $HANDOFF
  reboot -f &
  sleep 5
else # for chroot
  /bin/sh
  umount /dev/pts /dev /sys /proc
fi
EoI
sudo chown root:root /mnt/liteos/init
sudo chmod +x /mnt/liteos/init

# Write grub.cfg to /boot/grub/
sudo mkdir -p /mnt/liteos/boot/grub
sudo tee /mnt/liteos/boot/grub/grub.cfg > /dev/null <<'EoG'
set default=0
set timeout=5

menuentry "LiteOS" {
    insmod gzio
    insmod part_gpt
    insmod ext2
    set root=(hd0,gpt2)
    linux /boot/vmlinuz root=/dev/nvme0n1p2 rootfstype=ext4 rootwait console=ttyS0,115200 HOST=x86_64 init=/init
}
EoG

# Build standalone GRUB EFI binary with grub.cfg embedded
sudo mkdir -p /mnt/liteos/boot/efi/EFI/BOOT
sudo grub-mkstandalone \
  --format=x86_64-efi \
  --output=/mnt/liteos/boot/efi/EFI/BOOT/BOOTX64.EFI \
  --modules="part_gpt ext2 linux gzio normal search" \
  "boot/grub/grub.cfg=/mnt/liteos/boot/grub/grub.cfg"

# fstab
sudo tee /mnt/liteos/etc/fstab > /dev/null <<'EoT'
/dev/nvme0n1p2  /           ext4    defaults,noatime  0 1
/dev/nvme0n1p1  /boot/efi   vfat    defaults          0 2
proc            /proc       proc    defaults          0 0
sysfs           /sys        sysfs   defaults          0 0
devpts          /dev/pts    devpts  defaults          0 0
EoT

# SSH key for root
sudo mkdir -p /mnt/liteos/root/.ssh
sudo chmod 700 /mnt/liteos/root/.ssh
echo "$PUB_KEY" | sudo tee /mnt/liteos/root/.ssh/authorized_keys > /dev/null
sudo chmod 600 /mnt/liteos/root/.ssh/authorized_keys

# Pre-generate Dropbear host keys
sudo mkdir -p /mnt/liteos/etc/dropbear
sudo dropbearkey -t rsa -f /mnt/liteos/etc/dropbear/dropbear_rsa_host_key
sudo dropbearkey -t ecdsa -f /mnt/liteos/etc/dropbear/dropbear_ecdsa_host_key

# Set root password to root
echo 'root:$1$939UTPzb$/PfVYAsF2Hqi/AQ3UBjbK/:0:0:99999:7:::' | \
  sudo tee /mnt/liteos/etc/shadow > /dev/null

sync
sudo umount /mnt/liteos/boot/efi
sudo umount /mnt/liteos

echo "=== LiteOS installation complete ==="
