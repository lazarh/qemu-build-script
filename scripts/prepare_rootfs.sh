#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/prepare_rootfs.sh [rootfs-dir]
ROOTFS_DIR=${1:-$HOME/qemu-rootfs/rootfs-armhf}
DEBIAN_DIST=${DEBIAN_DIST:-bookworm}
ARCH=${ARCH:-armhf}

mkdir -p "$ROOTFS_DIR"

if command -v qemu-debootstrap >/dev/null 2>&1; then
  echo "Using qemu-debootstrap to build Debian $DEBIAN_DIST ($ARCH) at $ROOTFS_DIR"
  sudo qemu-debootstrap --arch="$ARCH" --variant=minbase "$DEBIAN_DIST" "$ROOTFS_DIR" http://deb.debian.org/debian
else
  echo "qemu-debootstrap not found; falling back to debootstrap + qemu-user-static"
  sudo apt-get update
  sudo apt-get install -y debootstrap qemu-user-static
  sudo debootstrap --arch="$ARCH" --foreign "$DEBIAN_DIST" "$ROOTFS_DIR" http://deb.debian.org/debian
  sudo cp /usr/bin/qemu-arm-static "$ROOTFS_DIR/usr/bin/"
  sudo chroot "$ROOTFS_DIR" /usr/bin/qemu-arm-static /bin/sh -c "/debootstrap/debootstrap --second-stage"
fi

# Minimal in-chroot setup
sudo cp /usr/bin/qemu-arm-static "$ROOTFS_DIR/usr/bin/" 2>/dev/null || true
sudo chroot "$ROOTFS_DIR" /usr/bin/qemu-arm-static /bin/bash -c "apt-get update && apt-get install -y --no-install-recommends ssh locales ca-certificates sudo || true"

# create a user
sudo chroot "$ROOTFS_DIR" /usr/bin/qemu-arm-static /bin/bash -c "useradd -m -s /bin/bash user || true; echo 'user:password' | chpasswd || true; adduser user sudo || true"

echo "Rootfs prepared at $ROOTFS_DIR"
