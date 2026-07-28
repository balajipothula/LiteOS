# Use an official Ubuntu 24.04 base image.
FROM ubuntu:24.04

# Disable interactive prompts during package install.
# Set default timezone.
# Remove timestamp noise in toybox > .config
# Set vi as the default editor.
ENV \
  DEBIAN_FRONTEND=noninteractive \
  TZ=Etc/UTC \
  KCONFIG_NOTIMESTAMP=1 \
  EDITOR=vi \
  DL="/var/tmp/sysroot/dl"

# Docker image metadata.
LABEL \
  org.opencontainers.image.authors="Balaji Pothula - balan.pothula@gmail.com" \
  org.opencontainers.image.base.name="ubuntu:24.04" \
  org.opencontainers.image.title="toybox" \
  org.opencontainers.image.version="0.8.13" \
  org.opencontainers.image.description="Toybox: all-in-one Linux command line"

# Install required toybox and kernel build dependencies.
RUN \
  apt-get update >/dev/null && \
  apt-get install -y --no-install-recommends \
    bc \
    bison \
    build-essential \
    ca-certificates \
    cpio \
    erofs-utils \
    flex \
    libelf-dev \
    libssl-dev \
    wget \
    xz-utils >/dev/null && \
  rm -rf /var/lib/apt/lists/*

# Set /var/tmp/sysroot/dl/ as the working directory.
WORKDIR ${DL}/

# Copy essential source tarballs into /var/tmp/sysroot/dl/
COPY \
  toybox-0.8.13.tar.gz \
  linux-6.12.79.tar.xz \
  zlib-1.3.1.tar.gz \
  dropbear-2024.86.tar.bz2 \
  build_lite_os.sh \
  ${DL}/

# Make the 'LiteOS' build script executable.
RUN chmod +x ${DL}/build_lite_os.sh
