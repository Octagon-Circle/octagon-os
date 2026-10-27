#!/bin/bash
###############################################################################
# OctagonOS Clean Script
# Removes all build artifacts and resets the working tree for a fresh build.
#
# Usage: sudo ./clean.sh [--purge]
#
# Options:
#   --purge   Also remove the download cache (forces full re-download)
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[CLEAN]${NC} $*"; }
warn()  { echo -e "${YELLOW}[CLEAN]${NC} $*"; }

# Must be root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[ERROR]${NC} Run as root: sudo $0" >&2
    exit 1
fi

cd "${SCRIPT_DIR}"

# Unmount any active chroot mounts before attempting to clean
info "Unmounting any active chroot mounts …"
umount -lf "${SCRIPT_DIR}/chroot/proc" 2>/dev/null || true
umount -lf "${SCRIPT_DIR}/chroot/sys" 2>/dev/null || true
umount -lf "${SCRIPT_DIR}/chroot/dev/pts" 2>/dev/null || true
umount -lf "${SCRIPT_DIR}/chroot/dev" 2>/dev/null || true

if [[ "${1:-}" == "--purge" ]]; then
    info "Purging everything including download caches …"
    lb clean --purge 2>/dev/null || true
else
    info "Cleaning build artifacts (keeping caches) …"
    lb clean 2>/dev/null || true
fi

# Remove generated files that lb clean might miss
info "Removing leftover build files …"
rm -rf .build/
rm -f  *.iso *.img *.zsync *.contents *.files *.packages
rm -f  build-*.log
rm -rf chroot/ binary/ source/
rm -f  chroot.packages.install chroot.packages.live
rm -f  binary.packages
rm -f  config/common config/bootstrap config/chroot config/binary config/source

info "Clean complete. Ready for a fresh build."
