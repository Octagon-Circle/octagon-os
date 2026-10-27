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
        debian|ubuntu|linuxmint|pop|kali) ok "Detected host OS: ${PRETTY_NAME}" ;;
        *)
            if [[ "${ID_LIKE:-}" == *"debian"* || "${ID_LIKE:-}" == *"ubuntu"* ]]; then
                ok "Detected Debian/Ubuntu-derived OS: ${PRETTY_NAME}"
            else
                die "Unsupported host OS '${ID}'. Run this on Debian or Ubuntu."
            fi
            ;;
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
                isolinux mtools dosfstools debian-archive-keyring)

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

# ── Upgrade legacy live-build 3.0 (from Ubuntu 22.04) to modern Debian version ───
ensure_modern_live_build() {
    info "Verifying live-build version …"
    local lb_ver
    lb_ver=$(dpkg -s live-build 2>/dev/null | grep '^Version:' | awk '{print $2}' || true)

    if [[ "$lb_ver" =~ ^3\.0 || "$lb_ver" == "" ]]; then
        info "Upgrading legacy live-build (${lb_ver:-not installed}) to official Debian 12 package (1:20230502) …"
        local lb_deb="/tmp/live-build_20230502_all.deb"
        curl -fsSL -o "${lb_deb}" "http://ftp.debian.org/debian/pool/main/l/live-build/live-build_20230502_all.deb"
        dpkg -i "${lb_deb}" 2>/dev/null || apt-get install -f -y --no-install-recommends
        rm -f "${lb_deb}"
        ok "live-build upgraded to $(dpkg -s live-build 2>/dev/null | grep '^Version:' | awk '{print $2}')"
    else
        ok "live-build is already up-to-date (${lb_ver})"
    fi
}

# ── Ensure host has latest Debian 12 (Bookworm) GPG keys ─────────────────────
ensure_debian_keyring() {
    info "Verifying Debian 12 (Bookworm) GPG archive keys on host …"
    mkdir -p /usr/share/keyrings

    # Always ensure release-12 and release-12-security keys are present on Ubuntu/Debian hosts
    local tmp_deb12="/tmp/deb12.gpg"
    curl -fsSL "https://ftp-master.debian.org/keys/release-12.asc" | gpg --dearmor > "${tmp_deb12}" 2>/dev/null || true
    curl -fsSL "https://ftp-master.debian.org/keys/release-12-security.asc" | gpg --dearmor >> "${tmp_deb12}" 2>/dev/null || true
    if [[ -s "${tmp_deb12}" ]]; then
        if [[ -L /usr/share/keyrings/debian-archive-keyring.gpg ]]; then
            local target
            target=$(readlink -f /usr/share/keyrings/debian-archive-keyring.gpg || true)
            if [[ -n "$target" && -f "$target" ]]; then
                cat "${tmp_deb12}" >> "$target"
            else
                rm -f /usr/share/keyrings/debian-archive-keyring.gpg
                cat "${tmp_deb12}" > /usr/share/keyrings/debian-archive-keyring.gpg
            fi
        elif [[ -f /usr/share/keyrings/debian-archive-keyring.gpg ]]; then
            cat "${tmp_deb12}" >> /usr/share/keyrings/debian-archive-keyring.gpg
        else
            cat "${tmp_deb12}" > /usr/share/keyrings/debian-archive-keyring.gpg
        fi
        rm -f "${tmp_deb12}"
    fi

    ok "Debian 12 release key verified in host keyring"
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

    # Auto-sanitize: remove any residual fastfetch, swappy, or steam-installer entries from all package lists
    for f in config/package-lists/*.list* config/packages/*.list*; do
        if [ -f "$f" ]; then
            sed -i '/^fastfetch$/d' "$f" 2>/dev/null || true
            sed -i '/^swappy$/d' "$f" 2>/dev/null || true
            sed -i '/^steam-installer$/d' "$f" 2>/dev/null || true
        fi
    done

    # Unmount any active chroot mounts before cleaning
    umount -lf "${SCRIPT_DIR}/chroot/proc" 2>/dev/null || true
    umount -lf "${SCRIPT_DIR}/chroot/sys" 2>/dev/null || true
    umount -lf "${SCRIPT_DIR}/chroot/dev/pts" 2>/dev/null || true
    umount -lf "${SCRIPT_DIR}/chroot/dev" 2>/dev/null || true

    # Clean any prior partial state and stale generated lb files (keeping custom hooks/includes/packages)
    rm -rf .build/ chroot/ binary/ source/
    rm -f chroot.packages.install chroot.packages.live binary.packages
    rm -f config/common config/bootstrap config/chroot config/binary config/source
    lb clean --purge 2>/dev/null || true

    # Detect whether lb uses --bootloaders (Debian newer) or --bootloader (Ubuntu/Debian 3.x)
    local bl_opt="--bootloader"
    if lb config --help 2>&1 | grep -q -- '--bootloaders'; then
        bl_opt="--bootloaders"
    fi

    lb config noauto \
        --mode                  "debian" \
        --distribution          "${DISTRIBUTION}" \
        --architectures         "${ARCHITECTURE}" \
        --keyring-packages      "debian-archive-keyring" \
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
        --security              "false" \
        --backports             "false" \
        "${@}"

    ok "lb config complete"

    # Bypass debootstrap host GPG check to avoid Ubuntu host keyring issues with Debian Bookworm
    if [[ -f config/bootstrap ]]; then
        sed -i '/^LB_DEBOOTSTRAP_OPTIONS=/d' config/bootstrap
        echo 'LB_DEBOOTSTRAP_OPTIONS="--no-check-gpg"' >> config/bootstrap
        ok "Configured debootstrap to skip host GPG check (--no-check-gpg)"
    fi
}

# ── Build the ISO ────────────────────────────────────────────────────────────
build() {
    info "Starting live-build (this will take a while) …"
    info "Build log: ${LOG_FILE}"

    cd "${SCRIPT_DIR}"

    # Apply legacy live-build compatibility patches (/updates -> -security) and container bind mounts
    info "Applying live-build compatibility patches …"
    for dir in /usr/lib/live/build /usr/share/live/build /usr/share/live/build/scripts/build; do
        if [ -d "$dir" ]; then
            sed -i 's|mount -t proc.*chroot/proc|mount --bind /proc chroot/proc|g' "$dir"/* 2>/dev/null || true
            sed -i 's|mount -t sysfs.*chroot/sys|mount --bind /sys chroot/sys|g' "$dir"/* 2>/dev/null || true
            sed -i 's|\${LB_DISTRIBUTION}/updates|\${LB_DISTRIBUTION}-security|g' "$dir"/* 2>/dev/null || true
            sed -i 's|\${DISTRIBUTION}/updates|\${DISTRIBUTION}-security|g' "$dir"/* 2>/dev/null || true
            sed -i 's|@DISTRIBUTION@/updates|@DISTRIBUTION@-security|g' "$dir"/* 2>/dev/null || true
            sed -i 's|bookworm/updates|bookworm-security|g' "$dir"/* 2>/dev/null || true
            sed -i 's|/Contents-\${LB_ARCHITECTURES}\.gz|/main/Contents-\${LB_ARCHITECTURES}\.gz|g' "$dir"/* 2>/dev/null || true
            sed -i 's|/Contents-\${ARCHITECTURE}\.gz|/main/Contents-\${ARCHITECTURE}\.gz|g' "$dir"/* 2>/dev/null || true
            sed -i 's|/Contents-amd64\.gz|/main/Contents-amd64\.gz|g' "$dir"/* 2>/dev/null || true
        fi
    done

    # Ensure any previous stale mounts are cleanly unmounted
    umount -lf "${SCRIPT_DIR}/chroot/proc" 2>/dev/null || true
    umount -lf "${SCRIPT_DIR}/chroot/sys" 2>/dev/null || true
    umount -lf "${SCRIPT_DIR}/chroot/dev/pts" 2>/dev/null || true
    umount -lf "${SCRIPT_DIR}/chroot/dev" 2>/dev/null || true

    # Clean stale stagefiles and queued package files so package list changes are always applied
    rm -f .build/chroot_package-lists* .build/chroot_install-packages*
    rm -f "${SCRIPT_DIR}/chroot/root/packages.chroot"* 2>/dev/null || true

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
    ensure_modern_live_build
    ensure_debian_keyring
    enable_i386
    configure "$@"
    build
    summary
}

main "$@"
