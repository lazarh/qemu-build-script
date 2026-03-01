#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/prepare_rootfs.sh [rootfs-dir]
# Environment variables:
#  DEBIAN_DIST (default: bookworm)
#  ARCH (default: armhf)
#  MIRROR (default: http://deb.debian.org/debian)
# Defaults to the repository root (./rootfs-armhf) when no argument is provided.

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ROOTFS_DIR=${1:-"$REPO_ROOT/rootfs-armhf"}
DEBIAN_DIST=${DEBIAN_DIST:-bookworm}
ARCH=${ARCH:-armhf}
MIRROR=${MIRROR:-http://deb.debian.org/debian}

mkdir -p "$ROOTFS_DIR"

# Prefer running qemu-debootstrap via sudo if available (may be installed for root only)
if sudo qemu-debootstrap --help >/dev/null 2>&1; then
  echo "Using sudo qemu-debootstrap to build Debian $DEBIAN_DIST ($ARCH) at $ROOTFS_DIR from mirror $MIRROR"
  sudo qemu-debootstrap --arch="$ARCH" --variant=minbase "$DEBIAN_DIST" "$ROOTFS_DIR" "$MIRROR"
elif command -v qemu-debootstrap >/dev/null 2>&1; then
  echo "Using qemu-debootstrap (user) to build Debian $DEBIAN_DIST ($ARCH) at $ROOTFS_DIR from mirror $MIRROR"
  qemu-debootstrap --arch="$ARCH" --variant=minbase "$DEBIAN_DIST" "$ROOTFS_DIR" "$MIRROR"
else
  echo "qemu-debootstrap not found; falling back to debootstrap + qemu-user-static"
  sudo apt-get update
  sudo apt-get install -y debootstrap qemu-user-static

  # Try a list of mirrors until debootstrap initial stage succeeds.
  MIRRORS=("$MIRROR" "http://deb.debian.org/debian" "http://ftp.debian.org/debian" )
  SUCCESS=0
  for m in "${MIRRORS[@]}"; do
    echo "Attempting debootstrap (initial stage) with mirror: $m"
    # ensure target dir is empty
    sudo rm -rf "$ROOTFS_DIR"
    mkdir -p "$ROOTFS_DIR"
    if sudo debootstrap --arch="$ARCH" --foreign "$DEBIAN_DIST" "$ROOTFS_DIR" "$m"; then
      echo "debootstrap initial stage succeeded with $m"
      sudo cp /usr/bin/qemu-arm-static "$ROOTFS_DIR/usr/bin/" 2>/dev/null || true
      sudo chroot "$ROOTFS_DIR" /usr/bin/qemu-arm-static /bin/sh -c "/debootstrap/debootstrap --second-stage"
      SUCCESS=1
      break
    else
      echo "debootstrap initial stage failed with mirror $m, trying next"
    fi
  done

  if [ "$SUCCESS" -ne 1 ]; then
    echo "All debootstrap mirror attempts failed; aborting." >&2
    exit 1
  fi
fi

# Minimal in-chroot setup
sudo cp /usr/bin/qemu-arm-static "$ROOTFS_DIR/usr/bin/" 2>/dev/null || true
sudo chroot "$ROOTFS_DIR" /usr/bin/qemu-arm-static /bin/bash -c "apt-get update && apt-get install -y --no-install-recommends ssh locales ca-certificates sudo || true"

# create a user
sudo chroot "$ROOTFS_DIR" /usr/bin/qemu-arm-static /bin/bash -c "useradd -m -s /bin/bash user || true; echo 'user:password' | chpasswd || true; adduser user sudo || true"

echo "Rootfs prepared at $ROOTFS_DIR"
