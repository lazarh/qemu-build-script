#!/usr/bin/env bash
set -euo pipefail

# Usage: sudo ./scripts/assemble_sd.sh [sd-image] [rootfs-dir] [u-boot-bin] [zImage] [dtb]
SD_IMAGE=${1:-sdcard.img}
ROOTFS_DIR=${2:-$HOME/qemu-rootfs/rootfs-armhf}
UBOOT_BIN=${3:-sources/u-boot/u-boot.bin}
ZIMAGE=${4:-sources/linux/arch/arm/boot/zImage}
DTB=${5:-$(ls sources/linux/arch/arm/boot/dts/*vexpress*.dtb 2>/dev/null | head -n1 || true)}

if [ "$EUID" -ne 0 ]; then
  echo "This script performs loop/device operations and should be run with sudo" >&2
  exit 1
fi

echo "Creating empty image: $SD_IMAGE (2GB)"
dd if=/dev/zero of="$SD_IMAGE" bs=1M count=2048 status=progress

parted --script "$SD_IMAGE" mklabel msdos \
  mkpart primary fat32 1MiB 100MiB \
  mkpart primary ext4 100MiB 100%

LOOP=$(losetup --show -fP "$SD_IMAGE")
if [ -z "$LOOP" ]; then
  echo "losetup failed" >&2
  exit 1
fi

mkfs.vfat -F32 "${LOOP}p1"
mkfs.ext4 "${LOOP}p2"

mkdir -p /mnt/sdboot /mnt/sdroot
mount "${LOOP}p2" /mnt/sdroot
rsync -a --numeric-ids "$ROOTFS_DIR/" /mnt/sdroot/
mount "${LOOP}p1" /mnt/sdboot
mkdir -p /mnt/sdboot/boot
cp -a "$ZIMAGE" /mnt/sdboot/
cp -a "$DTB" /mnt/sdboot/ 2>/dev/null || true

# Install U-Boot binary at offset so QEMU can use it when booting from -sd
if [ -f "$UBOOT_BIN" ]; then
  dd if="$UBOOT_BIN" of="$SD_IMAGE" bs=1k seek=8 conv=notrunc
else
  echo "Warning: U-Boot binary not found at $UBOOT_BIN" >&2
fi

sync
umount /mnt/sdboot
umount /mnt/sdroot
losetup -d "$LOOP"

echo "SD image $SD_IMAGE assembled. Use qemu-system-arm -M vexpress-a9 -m 512 -drive file=$SD_IMAGE,if=sd,format=raw -serial stdio"
