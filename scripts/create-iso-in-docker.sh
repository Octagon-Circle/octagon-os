#!/bin/bash
# Build OctagonOS ISO inside a Docker container
# Useful when building from non-Debian systems or WSL

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

echo "⬡ OctagonOS Docker Build"
echo "━━━━━━━━━━━━━━━━━━━━━━━━"

# Check Docker
if ! command -v docker &>/dev/null; then
    echo "❌ Docker not found. Please install Docker first."
    exit 1
fi

# Build container
echo "🐳 Building build environment..."
docker build -t octagonos-builder -f - "$SCRIPT_DIR" << 'DOCKERFILE'
FROM debian:bookworm

RUN apt-get update && apt-get install -y \
    live-build \
    debootstrap \
    squashfs-tools \
    xorriso \
    grub-pc-bin \
    grub-efi-amd64-bin \
    mtools \
    dosfstools \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
DOCKERFILE

# Run build
echo "🔨 Building OctagonOS ISO..."
docker run --rm --privileged \
    -v "$SCRIPT_DIR:/build" \
    -v "$SCRIPT_DIR/output:/output" \
    octagonos-builder \
    bash -c "cd /build && bash build.sh && cp -v *.iso /output/ 2>/dev/null || echo 'ISO in /build/'"

echo ""
echo "✅ Build complete! Check output/ directory for the ISO."
