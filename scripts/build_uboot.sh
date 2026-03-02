#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/build_uboot.sh [u-boot-src]
UBOOT_DIR=${1:-sources/u-boot}
NPROC=${NPROC:-$(nproc)}
: ${CROSS_COMPILE:=arm-linux-gnueabihf-}
: ${ARCH:=arm}

if [ ! -d "$UBOOT_DIR" ]; then
  echo "u-boot source directory not found: $UBOOT_DIR" >&2
  exit 1
fi

pushd "$UBOOT_DIR" >/dev/null
export ARCH="$ARCH"
export CROSS_COMPILE="$CROSS_COMPILE"

echo "Configuring U-Boot for vexpress_ca9x4_defconfig"
make vexpress_ca9x4_defconfig

# Override bootcmd with a direct fatload from SD card.
# vexpress_ca9x4_defconfig's distro_bootcmd relies on env vars (scriptaddr,
# kernel_addr_r) that are not set in its default env, causing boot.scr and
# extlinux to fail.  A direct fatload using explicit DRAM addresses is reliable.
# kernel at 0x60100000, DTB at 0x68000000 (valid in 1GB vexpress DRAM range).
./scripts/config --set-str CONFIG_BOOTCOMMAND \
  'fatload mmc 0:1 0x60100000 zImage; fatload mmc 0:1 0x68000000 vexpress-v2p-ca9.dtb; setenv bootargs "root=/dev/mmcblk0p2 rw console=ttyAMA0"; bootz 0x60100000 - 0x68000000'
make olddefconfig

echo "Building U-Boot (jobs=$NPROC)"
make -j"$NPROC"

mkdir -p ../output/uboot
cp -a u-boot u-boot.bin u-boot.spl u-boot.img u-boot.elf ../output/uboot/ 2>/dev/null || true

echo "U-Boot build complete; artifacts (if produced) copied to sources/output/uboot"
popd >/dev/null
