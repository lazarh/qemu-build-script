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
  apt-get install -y --no-install-recommends ssh locales ca-certificates sudo
  useradd -m -s /bin/bash user || true
  echo 'user:password' | chpasswd
  adduser user sudo || true
"

echo "Rootfs prepared at $ROOTFS_DIR"
