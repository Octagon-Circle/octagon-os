#!/bin/bash
###############################################################################
# OctagonOS Build Script
# Builds a super-optimized Debian Bookworm-based ISO with KDE Plasma
# for desktop daily use and gaming.
#
# Usage: sudo ./build.sh
#
# Requirements:
#   - Debian or Ubuntu host system
#   - Root privileges
#   - ~15 GB free disk space
#   - Internet connection
###############################################################################

set -euo pipefail

# ── Constants ────────────────────────────────────────────────────────────────
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="${SCRIPT_DIR}/build-$(date +%Y%m%d-%H%M%S).log"
readonly DISTRIBUTION="bookworm"
readonly ARCHITECTURE="amd64"
readonly ISO_APPLICATION="OctagonOS"
readonly ISO_PUBLISHER="OctagonOS Project; https://github.com/octagonos"
readonly ISO_VOLUME="OctagonOS 1.0"

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
die()   { error "$*"; exit 1; }

# ── Pre-flight checks ───────────────────────────────────────────────────────
preflight() {
    # Must be root
    if [[ $EUID -ne 0 ]]; then
        die "This script must be run as root.  Use: sudo $0"
    fi

    # Must be on Debian or Ubuntu
    if [[ ! -f /etc/os-release ]]; then
        die "Cannot detect OS. /etc/os-release not found."
    fi

    # shellcheck disable=SC1091
    source /etc/os-release
    case "${ID:-}" in
        debian|ubuntu|linuxmint|pop) ok "Detected host OS: ${PRETTY_NAME}" ;;
        *) die "Unsupported host OS '${ID}'. Run this on Debian or Ubuntu." ;;
    esac

    # Check disk space (need ~15 GB free)
    local free_kb
    free_kb=$(df --output=avail "${SCRIPT_DIR}" | tail -1)
    local free_gb=$(( free_kb / 1048576 ))
    if (( free_gb < 10 )); then
        warn "Only ${free_gb} GB free in ${SCRIPT_DIR}. Recommend at least 15 GB."
    else
        ok "Disk space: ${free_gb} GB free"
    fi
}

# ── Install prerequisites ───────────────────────────────────────────────────
install_deps() {
    info "Checking build dependencies …"

    local pkgs=(live-build debootstrap squashfs-tools xorriso
                grub-efi-amd64-bin grub-pc-bin syslinux syslinux-common
                isolinux mtools dosfstools)

    local missing=()
    for pkg in "${pkgs[@]}"; do
        if ! dpkg -s "$pkg" &>/dev/null; then
            missing+=("$pkg")
        fi
    done

    if (( ${#missing[@]} > 0 )); then
        info "Installing missing packages: ${missing[*]}"
        apt-get update -qq
        apt-get install -y --no-install-recommends "${missing[@]}"
    fi

    ok "All build dependencies satisfied"
}

# ── Enable i386 architecture (required for Steam) ───────────────────────────
enable_i386() {
    info "Enabling i386 architecture on the host (needed for Steam/wine)…"
    if ! dpkg --print-foreign-architectures | grep -q i386; then
        dpkg --add-architecture i386
        apt-get update -qq
        ok "i386 architecture enabled"
    else
        ok "i386 architecture already enabled"
    fi
}

# ── Configure live-build ─────────────────────────────────────────────────────
configure() {
    info "Running lb config …"

    cd "${SCRIPT_DIR}"

    # Clean any prior partial state but keep config/
    lb clean --purge 2>/dev/null || true

    # Detect whether lb uses --bootloaders (Debian newer) or --bootloader (Ubuntu/Debian 3.x)
    local bl_opt="--bootloader"
    if lb config --help 2>&1 | grep -q -- '--bootloaders'; then
        bl_opt="--bootloaders"
    fi

    lb config noauto \
        --distribution          "${DISTRIBUTION}" \
        --architectures         "${ARCHITECTURE}" \
        --binary-images         iso-hybrid \
        ${bl_opt}               "grub-efi" \
        --mirror-bootstrap      "http://deb.debian.org/debian" \
        --mirror-chroot         "http://deb.debian.org/debian" \
        --mirror-binary         "http://deb.debian.org/debian" \
        --mirror-chroot-security "http://deb.debian.org/debian-security" \
        --mirror-binary-security "http://deb.debian.org/debian-security" \
        --archive-areas         "main contrib non-free non-free-firmware" \
        --linux-flavours        "amd64" \
        --memtest               "none" \
        --iso-application       "${ISO_APPLICATION}" \
        --iso-publisher         "${ISO_PUBLISHER}" \
        --iso-volume            "${ISO_VOLUME}" \
        --apt-recommends        "false" \
        --firmware-binary       "true" \
        --firmware-chroot       "true" \
        --cache                 "true" \
        --compression           "xz" \
        --security              "true" \
        --backports             "false" \
        "${@}"

    ok "lb config complete"
}

# ── Build the ISO ────────────────────────────────────────────────────────────
build() {
    info "Starting live-build (this will take a while) …"
    info "Build log: ${LOG_FILE}"

    cd "${SCRIPT_DIR}"

    # Apply container compatibility patches for Colab/Docker/LXD environments
    info "Applying container filesystem compatibility patches (bind mounts) …"
    for dir in /usr/lib/live/build /usr/share/live/build /usr/lib/live/build/scripts/build; do
        if [ -d "$dir" ]; then
            sed -i 's|mount -t proc.*chroot/proc|mount --bind /proc chroot/proc|g' "$dir"/* 2>/dev/null || true
            sed -i 's|mount -t sysfs.*chroot/sys|mount --bind /sys chroot/sys|g' "$dir"/* 2>/dev/null || true
        fi
    done

    # Ensure any previous stale mounts are cleanly unmounted
    umount -lf "${SCRIPT_DIR}/chroot/proc" 2>/dev/null || true
    umount -lf "${SCRIPT_DIR}/chroot/sys" 2>/dev/null || true
    umount -lf "${SCRIPT_DIR}/chroot/dev/pts" 2>/dev/null || true
    umount -lf "${SCRIPT_DIR}/chroot/dev" 2>/dev/null || true

    lb build 2>&1 | tee "${LOG_FILE}"
    local rc=${PIPESTATUS[0]}

    if [[ $rc -ne 0 ]]; then
        die "lb build failed with exit code ${rc}. Check ${LOG_FILE}"
    fi

    # Rename to clean release ISO name
    if [[ -f "live-image-amd64.hybrid.iso" ]]; then
        mv -f "live-image-amd64.hybrid.iso" "OctagonOS-1.0-amd64.iso"
    fi

    ok "Build completed successfully!"
}

# ── Summary ──────────────────────────────────────────────────────────────────
summary() {
    echo ""
    echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}  OctagonOS Build Summary${NC}"
    echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"

    local iso
    iso=$(find "${SCRIPT_DIR}" -maxdepth 1 -name '*.iso' -type f | head -1)

    if [[ -n "$iso" ]]; then
        local size
        size=$(du -h "$iso" | cut -f1)
        echo -e "  ISO path : ${GREEN}${iso}${NC}"
        echo -e "  ISO size : ${GREEN}${size}${NC}"
        echo -e "  SHA256   : $(sha256sum "$iso" | cut -d' ' -f1)"
    else
        warn "No ISO file found. The build may have failed."
    fi

    echo ""
    echo -e "  Built on : $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo -e "  Log file : ${LOG_FILE}"
    echo -e "${BOLD}══════════════════════════════════════════════════════════${NC}"
}

# ── Main ─────────────────────────────────────────────────────────────────────
main() {
    echo -e "${BOLD}"
    echo "   ____       _                          ___  ____  "
    echo "  / __ \\     | |                        / _ \\/ ___| "
    echo " | |  | | ___| |_ __ _  __ _  ___  _ __| | | \\___ \\ "
    echo " | |  | |/ __| __/ _\` |/ _\` |/ _ \\| '_ \\ | | |___) |"
    echo " | |__| | (__| || (_| | (_| | (_) | | | | |_| |____/ "
    echo "  \\____/ \\___|\\__\\__,_|\\__, |\\___/|_| |_|\\___/|_____/ "
    echo "                        __/ |                         "
    echo "                       |___/   Build System v1.0      "
    echo -e "${NC}"

    preflight
    install_deps
    enable_i386
    configure "$@"
    build
    summary
}

main "$@"
