#!/bin/bash

set -e

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

# Copy kernel
sudo cp "$LITEOS/linux-kernel" /mnt/liteos/boot/vmlinuz

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
    linux /boot/vmlinuz root=/dev/nvme0n1p2 rootfstype=ext4 rootwait console=ttyS0,115200 HOST=x86_64
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
devpts          /dev/pts    devpts  defaults          0 0
EoT

# Fix /init networking — replace hardcoded QEMU IPs with DHCP for EC2
sudo sed -i \
  's|ifconfig eth0 10.0.2.15.*||;s|route add default gw 10.0.2.2.*||;s|ifconfig eth0 up|ifconfig eth0 up\n  udhcpc -i eth0|' \
  /mnt/liteos/init

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
