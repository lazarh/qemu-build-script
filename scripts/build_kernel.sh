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

# Apply config options from any *.config fragments in the scripts/ directory.
# Each fragment is a plain list of CONFIG_FOO=y / CONFIG_FOO=m lines (comments ok).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAGMENTS=()
for fragment in "$SCRIPT_DIR"/*.config; do
  [ -f "$fragment" ] || continue
  FRAGMENTS+=("$fragment")
done

if [ ${#FRAGMENTS[@]} -gt 0 ]; then
  cp .config .config.base
  for fragment in "${FRAGMENTS[@]}"; do
    echo "Applying config fragment: $(basename "$fragment")"
    while IFS= read -r line; do
      [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue
      key="${line%%=*}"
      val="${line#*=}"
      case "$val" in
        y) ./scripts/config --enable  "${key#CONFIG_}" ;;
        m) ./scripts/config --module  "${key#CONFIG_}" ;;
        n) ./scripts/config --disable "${key#CONFIG_}" ;;
        *) ./scripts/config --set-val "${key#CONFIG_}" "$val" ;;
      esac
    done < "$fragment"
  done
  make olddefconfig
  echo "Config changes applied (vs vexpress_defconfig):"
  diff .config.base .config | grep '^[<>]' \
    | sed 's/^< /  removed: /; s/^> /  added:   /' || true
  rm -f .config.base
fi

echo "Building kernel zImage and DTBs (jobs=$NPROC)"
make -j"$NPROC" zImage dtbs

OUTDIR="$(pwd)/../output/kernel"
mkdir -p "$OUTDIR"
cp -a arch/arm/boot/zImage "$OUTDIR/" 2>/dev/null || true
cp -a arch/arm/boot/dts/*.dtb "$OUTDIR/" 2>/dev/null || true

echo "Kernel build complete; zImage and dtbs copied to sources/output/kernel"
popd >/dev/null
