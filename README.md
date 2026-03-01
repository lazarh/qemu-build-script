qemu-build-script — build and assemble U-Boot, Linux kernel and Debian rootfs for QEMU vexpress-a9 (ARMv7)

Overview

This repository contains helper scripts to cross-compile U-Boot and the Linux kernel for QEMU vexpress-a9 (ARMv7), prepare a Debian armhf rootfs, and assemble a bootable SD image for testing in QEMU.

Prerequisites (host)

- Debian/Ubuntu: sudo apt update && sudo apt install -y gcc-arm-linux-gnueabihf qemu-system-arm qemu-user-static binfmt-support build-essential git debootstrap device-tree-compiler u-boot-tools dosfstools kpartx parted rsync pkg-config
- Optional but recommended: ccache to speed repeated kernel builds

Scripts

All scripts are in the scripts/ directory. Make them executable before first use:

  chmod +x scripts/*.sh

Environment variables

- DEBIAN_DIST: Debian release to bootstrap (default: bookworm)
- ARCH: target architecture for rootfs (default: armhf)
- MIRROR: Debian mirror to use (default: http://deb.debian.org/debian)

Individual steps

1) Build U-Boot

  ./scripts/build_uboot.sh [u-boot-src]

- Default u-boot source path: sources/u-boot
- Artifacts are copied to sources/output/uboot if produced

2) Build Linux kernel

  ./scripts/build_kernel.sh [linux-src]

- Default linux source path: sources/linux
- Produces arch/arm/boot/zImage and DTBs, copied to sources/output/kernel

3) Prepare Debian rootfs

  DEBIAN_DIST=bookworm MIRROR=http://deb.debian.org/debian ./scripts/prepare_rootfs.sh [rootfs-dir]

- Default rootfs dir: $HOME/qemu-rootfs/rootfs-armhf
- The script will prefer qemu-debootstrap when available; otherwise it falls back to debootstrap + qemu-user-static
- If you see errors such as "Invalid Release file, no entry for main/binary-arm/Packages", try switching MIRROR to an official mirror (http://deb.debian.org/debian) or use an older stable release (bookworm)

4) Assemble SD image

  sudo ./scripts/assemble_sd.sh [sd-image] [rootfs-dir] [u-boot-bin] [zImage] [dtb]

- Default sd-image: sdcard.img
- Default paths assume you used the script defaults and the kernel/uboot were built in sources/
- This script creates a 2GB image with a FAT boot partition and ext4 root partition, writes U-Boot at the offset QEMU expects, and copies the kernel/dtb to the boot partition

Booting in QEMU

- Quick test (U-Boot on SD or direct kernel load):

  qemu-system-arm -M vexpress-a9 -m 512 -drive file=sdcard.img,if=sd,format=raw -serial stdio -append 'root=/dev/mmcblk0p2 rw console=ttyAMA0'

- Alternatively, boot kernel+dtb directly (bypassing U-Boot):

  qemu-system-arm -M vexpress-a9 -m 512 -kernel sources/linux/arch/arm/boot/zImage -dtb sources/linux/arch/arm/boot/dts/<exact-dtb-name>.dtb -sd sdcard.img -append 'root=/dev/mmcblk0p2 rw console=ttyAMA0' -serial stdio

Notes & troubleshooting

- If a DTB is missing, run: cd sources/linux && export ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- && make vexpress_defconfig && make zImage dtbs and then copy the produced DTB (look in arch/arm/boot/dts)
- If you see an "Invalid Release file" or missing architecture packages when bootstrapping, change MIRROR to http://deb.debian.org/debian or switch DEBIAN_DIST to bookworm
- If an image partition is busy, unmount and detach the loop device: sudo umount -l <mountpoint>; sudo losetup -d /dev/loopN
- .gitignore ignores sources/output/, sdcard.img, qemu-rootfs/, and common image files by default

Automated full build

- To run everything (requires sudo for image assembly):

  ./scripts/build_all.sh

Repository layout

- scripts/: helper build scripts
- sources/: expected location for u-boot and linux source trees
- sources/output/: script output (zImage, DTBs, u-boot artifacts)
- qemu-rootfs/: default location for prepared rootfs

License

- No license declared (add LICENSE if you want to publish this project)
