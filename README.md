qemu-build-script — build and assemble U-Boot, Linux kernel and Debian rootfs for QEMU vexpress-a9 (ARMv7)

Educational purpose

This project is for educational purposes — to understand how an embedded ARM Linux system is built from scratch: cross-compiling U-Boot and the Linux kernel, bootstrapping a Debian rootfs, and assembling a bootable SD card image that runs inside QEMU. It is not intended for production use.

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
- Configures vexpress_ca9x4_defconfig and overrides CONFIG_BOOTCOMMAND to load zImage and DTB directly from the SD card FAT partition using explicit DRAM addresses (0x60100000 / 0x68000000), bypassing the distro_bootcmd which requires env vars not present in the default vexpress config
- Artifacts (u-boot, u-boot.bin, etc.) are copied to sources/output/uboot

2) Build Linux kernel

  ./scripts/build_kernel.sh [linux-src]

- Default linux source path: sources/linux
- Produces arch/arm/boot/zImage and DTBs, copied to sources/output/kernel

3) Prepare Debian rootfs

  DEBIAN_DIST=bookworm MIRROR=http://deb.debian.org/debian ./scripts/prepare_rootfs.sh [rootfs-dir]

- Default rootfs dir: ./rootfs-armhf
- Bootstraps a minimal Debian armhf rootfs via debootstrap (two-stage, using qemu-arm-static for the second stage)
- Installs systemd, udev, networking tools (iproute2, iputils-ping, ifupdown), SSH, and other essentials
- Enables serial-getty@ttyAMA0.service so a login prompt appears on the QEMU serial console
- Default credentials: root / root and user / password
- If you see errors such as "Invalid Release file, no entry for main/binary-arm/Packages", try switching MIRROR to an official mirror (http://deb.debian.org/debian) or use an older stable release (bookworm)

4) Assemble SD image

  sudo ./scripts/assemble_sd.sh [sd-image] [rootfs-dir] [u-boot-bin] [zImage] [dtb]

- Default sd-image: sdcard.img
- Default paths assume you used the script defaults and the kernel/uboot were built in sources/
- Creates a 2GB image: FAT boot partition (zImage + DTB + boot.scr) and ext4 root partition (Debian rootfs)
- Requires mkimage (u-boot-tools) to create boot.scr

Booting in QEMU

- Boot from SD card (U-Boot loads kernel + DTB from the FAT partition):

  qemu-system-arm -M vexpress-a9 -m 1024 \
    -kernel sources/u-boot/u-boot \
    -drive file=sdcard.img,if=sd,format=raw \
    -nographic

  Login: root / root

- Boot with networking (SSH forwarded to host port 2222):

  qemu-system-arm -M vexpress-a9 -m 1024 \
    -kernel sources/u-boot/u-boot \
    -drive file=sdcard.img,if=sd,format=raw \
    -nographic \
    -netdev user,id=net0,hostfwd=tcp::2222-:22 \
    -net nic,netdev=net0

  Inside the VM, bring up the network manually if ifupdown did not auto-configure:

    ip link set eth0 up
    ip addr add 10.0.2.15/24 dev eth0
    ip route add default via 10.0.2.2

  Then SSH in from the host: ssh -p 2222 root@localhost

- Alternatively, boot kernel+dtb directly (bypassing U-Boot):

  qemu-system-arm -M vexpress-a9 -m 1024 \
    -kernel sources/linux/arch/arm/boot/zImage \
    -dtb sources/linux/arch/arm/boot/dts/arm/vexpress-v2p-ca9.dtb \
    -drive file=sdcard.img,if=sd,format=raw \
    -append 'root=/dev/mmcblk0p2 rw console=ttyAMA0' \
    -nographic

Notes & troubleshooting

- U-Boot must be loaded with -kernel (ELF), not -bios (raw .bin). With -bios, QEMU places U-Boot at address 0x0 (NOR flash) but the binary is linked for DRAM (~0x60800000), causing the serial driver to fail before relocation.
- 1024 MB (-m 1024) is required. U-Boot's vexpress_ca9x4_defconfig sets scriptaddr=0x90000000 which is outside the 512 MB DRAM window (0x60000000–0x7fffffff); 1 GB maps DRAM up to 0x9fffffff.
- If a DTB is missing, run: cd sources/linux && export ARCH=arm CROSS_COMPILE=arm-linux-gnueabihf- && make vexpress_defconfig && make zImage dtbs
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
- rootfs-armhf/: default location for prepared rootfs

License

- No license declared (add LICENSE if you want to publish this project)
