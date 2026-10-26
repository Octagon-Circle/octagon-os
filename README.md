<p align="center">
  <!-- Replace with actual logo -->
  <img src=".assets/octagonos-logo.png" alt="OctagonOS Logo" width="200">
</p>

<h1 align="center">OctagonOS</h1>

<p align="center">
  <em>A super-optimized Debian-based Linux distribution for desktop daily use and gaming.</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/base-Debian%20Bookworm-A81D33?style=flat-square&logo=debian" alt="Debian Bookworm">
  <img src="https://img.shields.io/badge/desktop-KDE%20Plasma-1D99F3?style=flat-square&logo=kde" alt="KDE Plasma">
  <img src="https://img.shields.io/badge/arch-amd64-blue?style=flat-square" alt="amd64">
  <img src="https://img.shields.io/badge/license-GPL--3.0-green?style=flat-square" alt="GPL-3.0">
</p>

---

## Overview

**OctagonOS** is a custom Debian Bookworm (stable) distribution purpose-built
for desktop power users and gamers. It ships a dual desktop experience:
- **⚡ Hyprland**: Dynamic tiling Wayland compositor with fluid physics, custom Waybar, Kitty, and ultra-low RAM footprint (~180MB RAM).
- **🖥️ KDE Plasma**: Clean, minimal and familiar floating desktop with Breeze theming (~500MB RAM).

With aggressive system optimizations — fast boot times, low memory
footprint, high I/O throughput, and day-one gaming readiness with Vulkan, Steam,
Lutris, and GameMode pre-configured out of the box.

## Key Features

| Feature | Details |
|---|---|
| **⚡ Hyprland Tiling** | Wayland compositor, animations bezier, `allow_tearing=true` for zero gaming latency |
| **⚡ Fast Boot** | Stripped services, systemd-boot, zram swap with zstd, preload |
| **🧠 Ultra-Low RAM** | Hyprland (~180MB RAM) / KDE Plasma (~500MB RAM), earlyoom OOM guard |
| **🎮 Gaming-Ready** | Steam (i386), Lutris, GameMode, MangoHud, Vulkan drivers (Mesa) |
| **🖥️ Dual Desktop** | Select either Hyprland or KDE Plasma directly from SDDM login |
| **🔊 Modern Audio** | PipeWire + WirePlumber (replaces PulseAudio) |
| **📦 Flatpak** | Flathub pre-configured via Plasma Discover |
| **🔒 Secure** | UFW firewall (deny incoming), auto-updates ready |
| **🛠️ Optimized Kernel** | BBR congestion control, tuned sysctl, irqbalance |
| **🌡️ Thermal Mgmt** | thermald + TLP for laptop battery & thermal optimization |
| **🧹 Auto-tuned** | ananicy-cpp process scheduler for desktop responsiveness |

## System Requirements

| | Minimum | Recommended |
|---|---|---|
| **CPU** | 64-bit (amd64) dual-core | Quad-core 3.0 GHz+ |
| **RAM** | 2 GB | 8 GB+ |
| **Storage** | 20 GB | 50 GB+ (SSD recommended) |
| **GPU** | Any with Mesa support | AMD or Intel (Vulkan capable) |
| **Network** | Ethernet or supported WiFi | — |
| **Boot** | UEFI or Legacy BIOS | UEFI with Secure Boot |

## Build Instructions

### Prerequisites

- A **Debian 12 (Bookworm)** or **Ubuntu 22.04+** host system
- Root privileges (`sudo`)
- At least **15 GB** of free disk space
- Internet connection

### Building the ISO

```bash
# Clone the repository
git clone https://github.com/octagonos/octagonos.git
cd octagonos

# Build (must be root)
sudo ./build.sh

# The ISO will be created in the current directory
ls -lh *.iso
```

### Cleaning Build Artifacts

```bash
# Standard clean (keeps download cache for faster rebuilds)
sudo ./clean.sh

# Full purge (removes everything including caches)
sudo ./clean.sh --purge
```

### Writing the ISO to USB

```bash
# Find your USB device (e.g., /dev/sdX)
lsblk

# Write the ISO (replace /dev/sdX with your device!)
sudo dd if=live-image-amd64.hybrid.iso of=/dev/sdX bs=4M status=progress oflag=sync
```

> [!CAUTION]
> Double-check the target device with `lsblk`. Writing to the wrong device
> will destroy all data on it.

## Post-Install Optimization Tips

### 1. Install NVIDIA Drivers (if applicable)

```bash
# Add non-free repos (already configured)
sudo apt update
sudo apt install nvidia-driver firmware-misc-nonfree
sudo reboot
```

### 2. Enable Additional Flatpak Apps

```bash
# Install apps from Flathub
flatpak install flathub com.spotify.Client
flatpak install flathub com.discordapp.Discord
flatpak install flathub org.mozilla.firefox
```

### 3. Configure GameMode per-game

```bash
# Run a game with GameMode
gamemoderun ./your-game

# Or add to Steam launch options:
# gamemoderun %command%
```

### 4. Adjust Swap / zram

```bash
# Edit zram settings
sudo nano /etc/default/zramswap

# Restart zram
sudo systemctl restart zramswap
```

### 5. Check System Health

```bash
# View boot time
systemd-analyze

# View service startup times
systemd-analyze blame | head -20

# Monitor system resources
btop
```

## Project Structure

```
OctagonOS/
├── build.sh                                    # Main build script
├── clean.sh                                    # Clean / reset script
├── README.md                                   # This file
└── config/
    ├── packages/
    │   └── octagonos.list.chroot               # Package selection
    └── hooks/
        └── 0100-octagonos-setup.hook.chroot    # System configuration hook
```

## License

This project is licensed under the **GNU General Public License v3.0**.
See [LICENSE](LICENSE) for details.

## Credits & Acknowledgments

OctagonOS is built on the shoulders of giants:

- [**Debian**](https://www.debian.org/) — The universal operating system
- [**KDE Plasma**](https://kde.org/plasma-desktop/) — A beautiful, powerful desktop
- [**live-build**](https://live-team.pages.debian.net/live-manual/) — Debian Live system build tools
- [**PipeWire**](https://pipewire.org/) — Next-generation audio/video infrastructure
- [**GameMode**](https://github.com/FeralInteractive/gamemode) — Optimise Linux system performance on demand
- [**MangoHud**](https://github.com/flightlessmango/MangoHud) — Vulkan/OpenGL overlay for monitoring
- [**ananicy-cpp**](https://github.com/CachyOS/ananicy-cpp) — Auto nice daemon for process scheduling
- [**earlyoom**](https://github.com/rfjakob/earlyoom) — Early OOM daemon
- [**Steam**](https://store.steampowered.com/) — Gaming platform for Linux
- [**Lutris**](https://lutris.net/) — Open gaming platform

---

<p align="center">
  Made with ❤️ for the Linux desktop and gaming community.
</p>
