#!/bin/bash
set -e

# RCCR Raspberry Pi Image Builder (Simple Method)
# Uses Alpine official tar.gz + RCCR overlay

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# Arguments
ARCH="$1"        # rpi-aarch64, armv7, armhf
TYPE="$2"        # control, target
VERSION="${3:-0.0.4}"

if [ -z "$ARCH" ] || [ -z "$TYPE" ]; then
    echo "Usage: $0 <arch> <type> [version]"
    echo ""
    echo "Architecture:"
    echo "  rpi-aarch64  - Raspberry Pi 3/4/5 (64-bit)"
    echo "  armv7        - Raspberry Pi 2/3 (32-bit)"
    echo "  armhf        - Raspberry Pi 1/Zero"
    echo ""
    echo "Type: control, target"
    exit 1
fi

# Alpine version
ALPINE_VERSION="3.21"

# Map RCCR arch to Alpine arch
case "$ARCH" in
    rpi-aarch64)
        ALPINE_ARCH="aarch64"
        RPI_MODEL="rpi"
        ;;
    armv7)
        ALPINE_ARCH="armv7"
        RPI_MODEL="rpi"
        ;;
    armhf)
        ALPINE_ARCH="armhf"
        RPI_MODEL="rpi"
        ;;
    *)
        print_error "Unknown architecture: $ARCH"
        print_info "Use: rpi-aarch64, armv7, armhf"
        exit 1
        ;;
esac

OUTPUT_DIR="$PROJECT_DIR/build/$ARCH-$TYPE"
PROFILE_DIR="$PROJECT_DIR/image-profiles/$TYPE"

mkdir -p "$OUTPUT_DIR"

print_info "╔═══════════════════════════════════════════════════════════════════╗"
print_info "║           RCCR Raspberry Pi Image Builder (Simple)               ║"
print_info "╚═══════════════════════════════════════════════════════════════════╝"
echo ""
print_info "Architecture: $ARCH → Alpine $ALPINE_ARCH"
print_info "Type: $TYPE"
print_info "Version: $VERSION"
print_info "Alpine: $ALPINE_VERSION"
echo ""

# ===================================================================
# Download Alpine official Raspberry Pi tar.gz
# ===================================================================

ALPINE_FILE="alpine-${RPI_MODEL}-${ALPINE_VERSION}.0-${ALPINE_ARCH}.tar.gz"
ALPINE_URL="http://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/${ALPINE_ARCH}/${ALPINE_FILE}"

print_info "Downloading Alpine official Raspberry Pi image..."
echo "  URL: $ALPINE_URL"

if [ ! -f "/tmp/$ALPINE_FILE" ]; then
    wget -q --show-progress -O "/tmp/$ALPINE_FILE" "$ALPINE_URL" || {
        print_error "Failed to download Alpine image"
        exit 1
    }
else
    print_info "Using cached Alpine image"
fi

# ===================================================================
# Extract Alpine tar.gz
# ===================================================================

TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

print_info "Extracting Alpine image..."
tar -xzf "/tmp/$ALPINE_FILE" -C "$TEMP_DIR"

# ===================================================================
# Generate RCCR overlay (apkovl)
# ===================================================================

print_info "Generating RCCR overlay..."

cd "$TEMP_DIR"

# Copy overlay generator script
cp "$PROFILE_DIR/genapkovl-rccr-$TYPE.sh" ./
chmod +x "genapkovl-rccr-$TYPE.sh"

# Copy RCCR files to temporary location
mkdir -p /tmp/rccr-files
if [ -d "$PROJECT_DIR/playbooks" ]; then
    cp -r "$PROJECT_DIR/playbooks" /tmp/rccr-files/ 2>/dev/null || true
fi
if [ -f "$PROJECT_DIR/cluster_config.yml" ]; then
    cp "$PROJECT_DIR/cluster_config.yml" /tmp/rccr-files/ 2>/dev/null || true
fi

# Generate overlay
bash "./genapkovl-rccr-$TYPE.sh" "ReCyClusteR-Node" || {
    print_error "Overlay generation failed"
    exit 1
}

# Move overlay to boot directory (Alpine auto-loads .apkovl.tar.gz from boot)
if [ -f "ReCyClusteR-Node.apkovl.tar.gz" ]; then
    print_info "Installing overlay to boot directory..."

    # Alpine tar.gz structure has all files at root level
    # We need to place the overlay where Alpine will find it
    # For SD card boot, it should be in the root of the FAT32 partition

    # Just keep it in the temp directory for now - we'll package it
    print_info "✓ Overlay generated: ReCyClusteR-Node.apkovl.tar.gz"
else
    print_error "Overlay file not found!"
    exit 1
fi

# ===================================================================
# Create IMG file with FAT32 filesystem
# ===================================================================

print_info "Creating bootable IMG file..."

IMG_FILE="$OUTPUT_DIR/rccr-$VERSION-$ARCH-$TYPE.img"

# Create 2GB IMG file
dd if=/dev/zero of="$IMG_FILE" bs=1M count=2048 status=progress

# Format as FAT32
mkfs.vfat -F 32 -n "RCCR_BOOT" "$IMG_FILE"

# Mount IMG
MOUNT_DIR=$(mktemp -d)
trap "sudo umount $MOUNT_DIR 2>/dev/null || true; rm -rf $MOUNT_DIR $TEMP_DIR" EXIT

sudo mount -o loop "$IMG_FILE" "$MOUNT_DIR"

# Copy Alpine files
print_info "Copying Alpine system files..."
sudo cp -r "$TEMP_DIR"/* "$MOUNT_DIR/"

# Copy overlay
sudo cp "$TEMP_DIR/ReCyClusteR-Node.apkovl.tar.gz" "$MOUNT_DIR/"

# Unmount
sudo umount "$MOUNT_DIR"

print_info "✓ IMG file created"

# ===================================================================
# Compress IMG
# ===================================================================

print_info "Compressing IMG file..."
gzip -9 "$IMG_FILE"

print_info "✓ Compression complete"

# ===================================================================
# Generate checksum
# ===================================================================

print_info "Generating checksum..."
cd "$OUTPUT_DIR"
sha256sum "rccr-$VERSION-$ARCH-$TYPE.img.gz" > SHA256SUMS

# ===================================================================
# Complete
# ===================================================================

echo ""
print_info "╔═══════════════════════════════════════════════════════════════════╗"
print_info "║                    Build Complete!                                ║"
print_info "╚═══════════════════════════════════════════════════════════════════╝"
echo ""
print_info "Output: $OUTPUT_DIR"
ls -lh "$OUTPUT_DIR"
echo ""
print_info "Flash to SD card:"
print_info "  gunzip -c $IMG_FILE.gz | sudo dd of=/dev/sdX bs=4M status=progress"
echo ""
