#!/bin/bash

# Exit immediately if any command returns a non-zero status.
set -e

# ─── CONFIGURATION ────────────────────────────────────────────────────────────

# Target disk attached to the helper EC2 instance (LiteOS will be installed here).
DISK=/dev/xvdf

# EFI System Partition — partition 1 (FAT32, 200MiB).
EFI=${DISK}1

# Root filesystem partition — partition 2 (ext4, remaining space).
ROOTFS=${DISK}2

# LiteOS build output directory produced by mkroot/mkroot.sh inside the builder container.
LITEOS=$HOME/LiteOS

# Public SSH key injected into root's authorized_keys — only key-based login is allowed.
# Password login is intentionally disabled (no /etc/shadow entry for root).
PUB_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDNHlYyDburNESaGZ035Tlym1bIdEVA6lGT1ixcCE2PNeEa8x7AAkaa2knakreDTWznSdfJe7wU/nkp2x0qxqFv+6qUOGLMO3nIFoeeprxVjMYxVa8+jDSkrdkOvZfBYkp3y6La8sry98LgkW7kAqGOYS1NNvuqnVIzSEkVaqBKp930gNwKA0bdo9AWX3n0xNxNfGYZSCTFLdPVxijoQckA4MDXzy/Dggq6JwvkdnJAR/Axozh4j8jh8YYkOtFSqGV/dAPloIb+H2PmTCpBvy7X/xgWimy5D2BF5bFeiT34elJt6eNMkXutbyPLlwTgs5uJ+ro68/m2M+U6aaxhXwwX"

# ─── DEPENDENCIES ─────────────────────────────────────────────────────────────

# Install required tools on the helper instance.
# dropbear      — used to pre-generate SSH host keys for LiteOS.
# grub-efi-*    — used to build the standalone BOOTX64.EFI with embedded grub.cfg.
sudo apt --yes update
sudo apt --yes install dropbear grub-efi-amd64-bin grub2-common

# ─── PARTITION & FORMAT ───────────────────────────────────────────────────────

# Create a fresh GPT partition table on the target disk.
sudo parted "$DISK" --script mklabel gpt

# Partition 1: EFI System Partition (FAT32), 200MiB.
sudo parted "$DISK" --script mkpart ESP fat32 1MiB 201MiB
sudo parted "$DISK" --script set 1 esp on

# Partition 2: Root filesystem (ext4), rest of disk.
sudo parted "$DISK" --script mkpart root ext4 201MiB 100%

# Format EFI partition as FAT32.
sudo mkfs.vfat -F32 -n EFI "$EFI"

# Format root partition as ext4.
sudo mkfs.ext4 -L rootfs "$ROOTFS"

# ─── MOUNT ────────────────────────────────────────────────────────────────────

sudo mkdir -p /mnt/liteos
sudo mount "$ROOTFS" /mnt/liteos
sudo mkdir -p /mnt/liteos/boot/efi
sudo mount "$EFI" /mnt/liteos/boot/efi

# ─── COPY ROOTFS ──────────────────────────────────────────────────────────────

# Copy LiteOS filesystem — built by mkroot.sh inside the lite_os_builder container.
# -a preserves symlinks, permissions, timestamps.
sudo cp -a "$LITEOS/fs/." /mnt/liteos/

# Fix ownership — cp -a preserves source ownership from build container (non-root).
# Without this, /init and other files may be owned by the build user, causing boot failure.
sudo chown -R root:root /mnt/liteos/

# Copy kernel image built by mkroot.sh.
sudo cp "$LITEOS/linux-kernel" /mnt/liteos/boot/vmlinuz

# ─── RESOLV.CONF ──────────────────────────────────────────────────────────────

# Pre-populate resolv.conf with EC2's internal DNS resolver.
# This is done at install time because /etc is read-only at early boot
# before remount,rw and writing to it would fail.
echo "nameserver 169.254.169.253" | sudo tee /mnt/liteos/etc/resolv.conf

# ─── DHCP EVENT SCRIPT ────────────────────────────────────────────────────────

# Toybox dhcp supports -s PROG which calls this script with $ip $subnet $router
# as environment variables when a lease is obtained or renewed.
# This avoids blocking /init waiting for DHCP — dhcp runs in background with &
# and calls this script automatically when the lease arrives.
sudo mkdir -p /mnt/liteos/etc/rc
sudo tee /mnt/liteos/etc/rc/ifup > /dev/null <<'EoN'
#!/bin/sh
case "$1" in
  bound|renew)
    # Assign leased IP and netmask to eth0, add default gateway.
    ifconfig eth0 $ip netmask $subnet
    route add default gw $router
    ;;
  deconfig)
    # Clear IP when lease is released or lost.
    ifconfig eth0 0.0.0.0
    ;;
esac
EoN
sudo chmod +x /mnt/liteos/etc/rc/ifup

# ─── /init ────────────────────────────────────────────────────────────────────

# This is the PID 1 init script. The kernel executes this directly via init=/init.
# It mounts essential filesystems, remounts root rw, starts networking,
# runs /etc/rc/* package scripts (e.g. Dropbear SSH), then hands off to /bin/sh
# via setsid on the active console (ttyS0 on EC2).
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
# Remount root filesystem read-write — kernel mounts it ro initially.
mount -o remount,rw /
echo 0 99999 > /proc/sys/net/ipv4/ping_group_range
if [ $$ -eq 1 ]; then
  mountpoint -q mnt || [ -e /dev/?da ] && mount /dev/?da /mnt
  # Bring up loopback and ethernet interfaces.
  ifconfig lo 127.0.0.1
  ifconfig eth0 up
  # Start DHCP in background — -s calls /etc/rc/ifup with $ip/$subnet/$router
  # when lease is obtained. -q exits after first lease. Does not block init.
  dhcp -i eth0 -s /etc/rc/ifup -q &
  [ "$(date +%s)" -lt 10000000 ] && sntp -sq time.google.com
  # Source all scripts in /etc/rc/ in order — this starts Dropbear SSH daemon.
  for i in $(ls -1 /etc/rc 2>/dev/null | sort); do . /etc/rc/"$i"; done
  echo 3 > /proc/sys/kernel/printk
  [ -z "$HANDOFF" ] && [ -e /mnt/init ] && HANDOFF=/mnt/init
  [ -z "$HANDOFF" ] && HANDOFF=/bin/sh && echo -e '\e[?7hType exit when done.'
  # Hand off to shell on the active serial console (ttyS0 on EC2).
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

# ─── GRUB ─────────────────────────────────────────────────────────────────────

# Write grub.cfg — kernel cmdline:
# root=/dev/nvme0n1p2  — EC2 NVMe root partition
# rw                   — mount root read-write from the start
# init=/init           — use our custom PID 1 init script
# console=ttyS0        — serial console for EC2 Serial Console access
sudo mkdir -p /mnt/liteos/boot/grub
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

# Build a standalone GRUB EFI binary with grub.cfg embedded inside BOOTX64.EFI.
# This avoids GRUB dropping to shell when it cannot find grub.cfg on the EFI partition.
sudo mkdir -p /mnt/liteos/boot/efi/EFI/BOOT
sudo grub-mkstandalone \
  --format=x86_64-efi \
  --output=/mnt/liteos/boot/efi/EFI/BOOT/BOOTX64.EFI \
  --modules="part_gpt ext2 linux gzio normal search" \
  "boot/grub/grub.cfg=/mnt/liteos/boot/grub/grub.cfg"

# ─── FSTAB ────────────────────────────────────────────────────────────────────

sudo tee /mnt/liteos/etc/fstab > /dev/null <<'EoT'
/dev/nvme0n1p2  /           ext4    defaults,noatime  0 1
/dev/nvme0n1p1  /boot/efi   vfat    defaults          0 2
proc            /proc       proc    defaults          0 0
sysfs           /sys        sysfs   defaults          0 0
devpts          /dev/pts    devpts  defaults          0 0
EoT

# ─── SSH ──────────────────────────────────────────────────────────────────────

# Inject public key for root — only key-based SSH login is permitted.
# Password login is disabled by not setting a root password in /etc/shadow.
sudo mkdir -p /mnt/liteos/root/.ssh
sudo chmod 700 /mnt/liteos/root/.ssh
echo "$PUB_KEY" | sudo tee /mnt/liteos/root/.ssh/authorized_keys > /dev/null
sudo chmod 600 /mnt/liteos/root/.ssh/authorized_keys

# Pre-generate Dropbear RSA and ECDSA host keys.
# Without these, Dropbear generates them at first boot which takes time.
sudo mkdir -p /mnt/liteos/etc/dropbear
sudo dropbearkey -t rsa -f /mnt/liteos/etc/dropbear/dropbear_rsa_host_key
sudo dropbearkey -t ecdsa -f /mnt/liteos/etc/dropbear/dropbear_ecdsa_host_key

# ─── FINALISE ─────────────────────────────────────────────────────────────────

sync
sudo umount /mnt/liteos/boot/efi
sudo umount /mnt/liteos

echo "=== LiteOS installation complete ==="
