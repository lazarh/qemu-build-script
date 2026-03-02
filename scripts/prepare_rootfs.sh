#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/prepare_rootfs.sh [rootfs-dir]
# Environment variables:
#  DEBIAN_DIST  - Debian release to bootstrap (default: bookworm)
#  ROOTFS_ARCH  - target architecture for rootfs (default: armhf)
#  MIRROR       - Debian mirror to use (default: http://deb.debian.org/debian)
# Note: ROOTFS_ARCH is intentionally separate from ARCH (used for kernel builds).
# Defaults rootfs to the repository root (./rootfs-armhf).

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOTFS_DIR=${1:-"$REPO_ROOT/rootfs-armhf"}
DEBIAN_DIST=${DEBIAN_DIST:-bookworm}
ROOTFS_ARCH=${ROOTFS_ARCH:-armhf}
MIRROR=${MIRROR:-http://deb.debian.org/debian}

echo "Building Debian $DEBIAN_DIST ($ROOTFS_ARCH) rootfs at $ROOTFS_DIR using mirror $MIRROR"

sudo apt-get install -y debootstrap qemu-user-static

# Stage 1: debootstrap --foreign (no chroot execution needed yet)
sudo rm -rf "$ROOTFS_DIR"
sudo mkdir -p "$ROOTFS_DIR"
sudo debootstrap --arch="$ROOTFS_ARCH" --variant=minbase --foreign "$DEBIAN_DIST" "$ROOTFS_DIR" "$MIRROR"

# Stage 2: copy qemu-arm-static and run second stage inside the rootfs
sudo cp /usr/bin/qemu-arm-static "$ROOTFS_DIR/usr/bin/"
sudo chroot "$ROOTFS_DIR" /usr/bin/qemu-arm-static /bin/sh -c "/debootstrap/debootstrap --second-stage"

# Minimal in-chroot setup
sudo chroot "$ROOTFS_DIR" /usr/bin/qemu-arm-static /bin/bash -c "
  echo 'deb $MIRROR $DEBIAN_DIST main contrib non-free' > /etc/apt/sources.list
  apt-get update

  # Init system + essential runtime packages
  apt-get install -y --no-install-recommends \
    systemd systemd-sysv dbus \
    udev \
    util-linux procps kmod login bash \
    iproute2 iputils-ping ifupdown \
    openssh-server locales ca-certificates sudo \
    nano

  # Hostname and /etc/hosts
  echo 'debian-armhf' > /etc/hostname
  printf '127.0.0.1\tlocalhost\n127.0.1.1\tdebian-armhf\n' >> /etc/hosts

  # fstab
  cat > /etc/fstab <<'FSTAB'
/dev/mmcblk0p2  /      ext4  defaults  0 1
/dev/mmcblk0p1  /boot  vfat  defaults  0 2
proc            /proc  proc  defaults  0 0
sysfs           /sys   sysfs defaults  0 0
FSTAB

  # Network: DHCP on eth0
  cat > /etc/network/interfaces <<'NET'
auto lo
iface lo inet loopback
auto eth0
iface eth0 inet dhcp
NET

  # Serial console login on ttyAMA0 (vexpress UART)
  systemctl enable serial-getty@ttyAMA0.service

  # Generate machine-id (required by systemd)
  systemd-machine-id-setup 2>/dev/null || true

  # Accounts
  echo 'root:root' | chpasswd
  useradd -m -s /bin/bash user || true
  echo 'user:password' | chpasswd
  adduser user sudo || true

  # Locale
  echo 'LANG=en_US.UTF-8' > /etc/default/locale
  locale-gen en_US.UTF-8 || true
"

echo "Rootfs prepared at $ROOTFS_DIR"
