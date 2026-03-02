#!/usr/bin/env bash
set -euo pipefail

# Usage: sudo ./scripts/assemble_sd.sh [sd-image] [rootfs-dir] [u-boot-bin] [zImage] [dtb]
SD_IMAGE=${1:-sdcard.img}
ROOTFS_DIR=${2:-rootfs-armhf}
UBOOT_BIN=${3:-sources/u-boot/u-boot.bin}
ZIMAGE=${4:-sources/linux/arch/arm/boot/zImage}
DTB=${5:-$(find sources/linux/arch/arm/boot/dts -name '*vexpress*ca9*.dtb' 2>/dev/null | head -n1 || true)}

if [ "$EUID" -ne 0 ]; then
  echo "This script performs loop/device operations and should be run with sudo" >&2
  exit 1
fi

if [ ! -d "$ROOTFS_DIR" ]; then
  echo "Rootfs directory $ROOTFS_DIR not found. Specify a valid rootfs path as second argument." >&2
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
# Copy kernel and DTB without preserving ownership (FAT doesn't support Unix ownership)
cp --no-preserve=ownership "$ZIMAGE" /mnt/sdboot/ || cp -a "$ZIMAGE" /mnt/sdboot/
if [ -n "$DTB" ] && [ -f "$DTB" ]; then
  cp --no-preserve=ownership "$DTB" /mnt/sdboot/ || cp -a "$DTB" /mnt/sdboot/
  DTB_BASENAME=$(basename "$DTB")
else
  DTB_BASENAME=""
fi
# boot.scr is mandatory — require mkimage (u-boot-tools) to create it
if ! command -v mkimage >/dev/null 2>&1; then
  echo "mkimage not found. Install u-boot-tools (apt install u-boot-tools) and re-run." >&2
  exit 1
fi

# Use explicit vexpress DRAM addresses: kernel at 0x60100000, DTB at 0x68000000
cat > /mnt/sdboot/boot.cmd <<EOF
setenv bootargs 'root=/dev/mmcblk0p2 rw console=ttyAMA0'
fatload mmc 0:1 0x60100000 zImage
EOF
if [ -n "$DTB_BASENAME" ]; then
  cat >> /mnt/sdboot/boot.cmd <<EOF
fatload mmc 0:1 0x68000000 $DTB_BASENAME
bootz 0x60100000 - 0x68000000
EOF
else
  cat >> /mnt/sdboot/boot.cmd <<'EOF'
bootz 0x60100000
EOF
fi
mkimage -A arm -T script -C none -n 'Boot script' -d /mnt/sdboot/boot.cmd /mnt/sdboot/boot.scr

# Install U-Boot binary at offset so QEMU can use it when booting from -sd
if [ -f "$UBOOT_BIN" ]; then
  # Write U-Boot to the loop device (not the backing file) to avoid corrupting mounted filesystems
  dd if="$UBOOT_BIN" of="$LOOP" bs=1k seek=8 conv=notrunc
else
  echo "Warning: U-Boot binary not found at $UBOOT_BIN" >&2
fi

sync
umount /mnt/sdboot
umount /mnt/sdroot
losetup -d "$LOOP"

echo "SD image $SD_IMAGE assembled."
echo "Boot with: qemu-system-arm -M vexpress-a9 -m 1024 -kernel sources/u-boot/u-boot -drive file=$SD_IMAGE,if=sd,format=raw -nographic"
