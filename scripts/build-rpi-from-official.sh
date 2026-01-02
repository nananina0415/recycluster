#!/bin/bash
set -e

# RCCR Raspberry Pi Builder - Using Alpine Official IMG
# Downloads Alpine official IMG.GZ, adds RCCR overlay, repackages

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Arguments
ARCH="$1"        # rpi-aarch64, armv7, armhf
TYPE="$2"        # control, target
VERSION="${3:-0.0.4}"

if [ -z "$ARCH" ] || [ -z "$TYPE" ]; then
    echo "Usage: $0 <arch> <type> [version]"
    echo "Arch: rpi-aarch64, armv7, armhf"
    echo "Type: control, target"
    exit 1
fi

# Alpine version
ALPINE_VERSION="3.23"
ALPINE_RELEASE="3.23.2"

# Map RCCR arch to Alpine arch
case "$ARCH" in
    rpi-aarch64)
        ALPINE_ARCH="aarch64"
        ;;
    armv7)
        ALPINE_ARCH="armv7"
        ;;
    armhf)
        ALPINE_ARCH="armhf"
        ;;
    *)
        echo "ERROR: Unknown architecture: $ARCH"
        exit 1
        ;;
esac

OUTPUT_DIR="$PROJECT_DIR/build/$ARCH-$TYPE"
PROFILE_DIR="$PROJECT_DIR/image-profiles/$TYPE"

mkdir -p "$OUTPUT_DIR"

echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║        RCCR Raspberry Pi Builder (Alpine Official IMG)           ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""
echo "Architecture: $ARCH → Alpine $ALPINE_ARCH"
echo "Type: $TYPE"
echo "Version: $VERSION"
echo "Alpine: $ALPINE_RELEASE"
echo ""

# ===================================================================
# 1. Download Alpine Official IMG.GZ
# ===================================================================

ALPINE_IMG="alpine-rpi-${ALPINE_RELEASE}-${ALPINE_ARCH}.img.gz"
ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/${ALPINE_ARCH}/${ALPINE_IMG}"

echo "[1/6] Downloading Alpine official IMG..."
echo "  URL: $ALPINE_URL"

if [ ! -f "/tmp/$ALPINE_IMG" ]; then
    wget -q --show-progress -O "/tmp/$ALPINE_IMG" "$ALPINE_URL" || {
        echo "ERROR: Download failed"
        exit 1
    }
else
    echo "  Using cached: /tmp/$ALPINE_IMG"
fi

# ===================================================================
# 2. Decompress IMG
# ===================================================================

echo ""
echo "[2/6] Decompressing IMG..."

TEMP_IMG="/tmp/alpine-rpi-${ALPINE_ARCH}-$$.img"
gunzip -c "/tmp/$ALPINE_IMG" > "$TEMP_IMG"

echo "  ✓ Decompressed: $TEMP_IMG"
echo "  Size: $(du -h "$TEMP_IMG" | cut -f1)"

# ===================================================================
# 3. Mount IMG
# ===================================================================

echo ""
echo "[3/6] Mounting IMG..."

LOOP_DEV=$(sudo losetup -fP --show "$TEMP_IMG")
echo "  Loop device: $LOOP_DEV"

# Find the boot partition (usually first partition)
BOOT_PART="${LOOP_DEV}p1"

MOUNT_DIR=$(mktemp -d)
sudo mount "$BOOT_PART" "$MOUNT_DIR"
echo "  ✓ Mounted: $MOUNT_DIR"

# ===================================================================
# 4. Generate RCCR Overlay
# ===================================================================

echo ""
echo "[4/6] Generating RCCR overlay..."

cd "$PROFILE_DIR"

# Copy RCCR files to temp location
mkdir -p /tmp/rccr-files
if [ -d "$PROJECT_DIR/playbooks" ]; then
    cp -r "$PROJECT_DIR/playbooks" /tmp/rccr-files/ 2>/dev/null || true
fi
if [ -f "$PROJECT_DIR/cluster_config.yml" ]; then
    cp "$PROJECT_DIR/cluster_config.yml" /tmp/rccr-files/ 2>/dev/null || true
fi

# Generate overlay
bash "genapkovl-rccr-$TYPE.sh" "ReCyClusteR-Node" || {
    echo "ERROR: Overlay generation failed"
    sudo umount "$MOUNT_DIR"
    sudo losetup -d "$LOOP_DEV"
    rm -f "$TEMP_IMG"
    exit 1
}

if [ ! -f "ReCyClusteR-Node.apkovl.tar.gz" ]; then
    echo "ERROR: Overlay file not found"
    sudo umount "$MOUNT_DIR"
    sudo losetup -d "$LOOP_DEV"
    rm -f "$TEMP_IMG"
    exit 1
fi

echo "  ✓ Overlay generated"

# ===================================================================
# 5. Add Overlay to IMG
# ===================================================================

echo ""
echo "[5/6] Installing overlay to IMG..."

sudo cp "ReCyClusteR-Node.apkovl.tar.gz" "$MOUNT_DIR/"
sudo ls -lh "$MOUNT_DIR/"*.apkovl.tar.gz

echo "  ✓ Overlay installed"

# ===================================================================
# 6. Unmount and Compress
# ===================================================================

echo ""
echo "[6/6] Finalizing..."

sudo umount "$MOUNT_DIR"
sudo losetup -d "$LOOP_DEV"
rm -rf "$MOUNT_DIR"

echo "  ✓ Unmounted"

# Rename and compress
OUTPUT_IMG="$OUTPUT_DIR/rccr-$VERSION-$ARCH-$TYPE.img"
mv "$TEMP_IMG" "$OUTPUT_IMG"

echo "  Compressing..."
gzip -9 "$OUTPUT_IMG"

echo "  ✓ Compressed: ${OUTPUT_IMG}.gz"

# Generate checksum
cd "$OUTPUT_DIR"
sha256sum "rccr-$VERSION-$ARCH-$TYPE.img.gz" > SHA256SUMS

# ===================================================================
# Complete
# ===================================================================

echo ""
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║                    Build Complete!                                ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""
echo "Output:"
ls -lh "$OUTPUT_DIR"
echo ""
echo "Flash with Raspberry Pi Imager:"
echo "  1. Open Raspberry Pi Imager"
echo "  2. Choose 'Use custom' → Select rccr-$VERSION-$ARCH-$TYPE.img.gz"
echo "  3. Flash to SD card"
echo "  4. Boot!"
echo ""
