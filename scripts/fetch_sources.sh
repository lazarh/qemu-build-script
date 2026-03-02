#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/fetch_sources.sh [u-boot-repo] [linux-repo] [sources-dir]
UBOOT_REPO=${1:-https://github.com/u-boot/u-boot.git}
LINUX_REPO=${2:-https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git}
SOURCES_DIR=${3:-sources}

mkdir -p "$SOURCES_DIR"
cd "$SOURCES_DIR"

if [ ! -d u-boot ]; then
  echo "Cloning U-Boot from $UBOOT_REPO"
  git clone --depth 1 "$UBOOT_REPO" u-boot
else
  echo "u-boot already exists in $SOURCES_DIR/u-boot"
fi

if [ ! -d linux ]; then
  echo "Cloning Linux from $LINUX_REPO"
  git clone --depth 1 "$LINUX_REPO" linux
else
  echo "linux already exists in $SOURCES_DIR/linux"
fi

echo "Sources are available in $(pwd)"
