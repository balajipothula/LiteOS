#!/bin/bash

# Define the build workspace ─ 'path' is critical for the build process.
# Note: '/var/tmp/' is available on most Linux distributions.
SYSROOT="/var/tmp/sysroot"
DL="$SYSROOT/dl"

# Toybox, Linux Kernel, Zlib and Dropbear package details.
toybox_tar="toybox-0.8.13.tar.gz"
linux_tar="linux-6.12.79.tar.xz"
zlib_tar="zlib-1.3.1.tar.gz"
dropbear_tar="dropbear-2024.86.tar.bz2"

toybox_src="toybox-0.8.13"
linux_src="linux-6.12.79"

# Extract the Toybox source.
tar -xf "$DL/$toybox_tar" -C "$DL" || exit 1

# Move Zlib and Dropbear packages into Toybox source.
mv "$DL/$zlib_tar"     "$DL/$toybox_src/" || exit 1
mv "$DL/$dropbear_tar" "$DL/$toybox_src/" || exit 1

# Switch to the Toybox source tree.
cd "$DL/$toybox_src/" || exit 1

# Create the minimal Toybox configuration.
cat > "$DL/$toybox_src/lite_os.config" << 'EoC'
CONFIG_PING=y
EoC

# Generate the complete Toybox configuration.
KCONFIG_ALLCONFIG="$DL/$toybox_src/lite_os.config" make defconfig >/dev/null || exit 1

# Extract the Linux Kernel source.
tar -xf "$DL/$linux_tar" -C "$DL" || exit 1

# Build a bootable LiteOS image.
./mkroot/mkroot.sh \
  TARGET='x86_64' \
  PENDING='dhcp' \
  LINUX="$DL/$linux_src/" \
  KEXTRA='CRYPTO,CRYPTO_AES,CRYPTO_HASH,CRYPTO_HMAC,CRYPTO_SHA1,CRYPTO_SHA256,DEVPTS_FS,EPOLL,FUTEX,HYPERVISOR_GUEST,IP_PNP,IP_PNP_DHCP,KVM_GUEST,PARAVIRT,SHMEM,UNIX98_PTYS,VIRTIO,VIRTIO_BLK,VIRTIO_MMIO,VIRTIO_MMIO_CMDLINE_DEVICES,VIRTIO_NET,VIRTIO_PCI' \
  OUTPUT="$DL/LiteOS/" \
  dropbear >/dev/null || exit 1

