#!/usr/bin/env bash
set -euo pipefail

# Usage: ./scripts/build_kernel.sh [linux-src]
LINUX_DIR=${1:-sources/linux}
NPROC=${NPROC:-$(nproc)}
: ${CROSS_COMPILE:=arm-linux-gnueabihf-}
: ${ARCH:=arm}

if [ ! -d "$LINUX_DIR" ]; then
  echo "linux source directory not found: $LINUX_DIR" >&2
  exit 1
fi

pushd "$LINUX_DIR" >/dev/null
export ARCH="$ARCH"
export CROSS_COMPILE="$CROSS_COMPILE"

echo "Configuring kernel for vexpress"
make vexpress_defconfig

echo "Building kernel zImage and DTBs (jobs=$NPROC)"
make -j"$NPROC" zImage dtbs

OUTDIR="$(pwd)/../output/kernel"
mkdir -p "$OUTDIR"
cp -a arch/arm/boot/zImage "$OUTDIR/" 2>/dev/null || true
cp -a arch/arm/boot/dts/*.dtb "$OUTDIR/" 2>/dev/null || true

echo "Kernel build complete; zImage and dtbs copied to sources/output/kernel"
popd >/dev/null
