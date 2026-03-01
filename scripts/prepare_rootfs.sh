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

# Ensure required host tools
sudo apt-get update
sudo apt-get install -y --no-install-recommends debootstrap qemu-user-static

# Stage 1: debootstrap --foreign
sudo rm -rf "$ROOTFS_DIR"
sudo mkdir -p "$ROOTFS_DIR"

if ! sudo debootstrap --arch="$ROOTFS_ARCH" --variant=minbase --foreign "$DEBIAN_DIST" "$ROOTFS_DIR" "$MIRROR"; then
  echo "debootstrap initial stage failed for $ROOTFS_ARCH on $MIRROR" >&2
  exit 1
fi

# Stage 2: copy qemu static binary and run second stage inside the rootfs
sudo cp /usr/bin/qemu-arm-static "$ROOTFS_DIR/usr/bin/" 2>/dev/null || true
sudo chroot "$ROOTFS_DIR" /usr/bin/qemu-arm-static /bin/sh -c "/debootstrap/debootstrap --second-stage"

# Minimal in-chroot setup
sudo chroot "$ROOTFS_DIR" /usr/bin/qemu-arm-static /bin/bash -c "set -e; \
  echo 'deb $MIRROR $DEBIAN_DIST main contrib non-free' > /etc/apt/sources.list; \
  apt-get update; \
  apt-get install -y --no-install-recommends ssh locales ca-certificates sudo; \
  useradd -m -s /bin/bash user || true; \
  echo 'user:password' | chpasswd; \
  adduser user sudo || true"

echo "Rootfs prepared at $ROOTFS_DIR"
