#!/usr/bin/env bash
set -euo pipefail

# Orchestrator: build U-Boot, kernel, prepare rootfs, assemble SD image
SCRIPTDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPTDIR/build_uboot.sh"
"$SCRIPTDIR/build_kernel.sh"
"$SCRIPTDIR/prepare_rootfs.sh"

# assemble image requires sudo
sudo "$SCRIPTDIR/assemble_sd.sh"

echo "Full build completed."
