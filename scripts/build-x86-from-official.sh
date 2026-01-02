#!/bin/bash
set -e

# RCCR x86/x86_64 Builder - Using Alpine Official ISO
# Downloads Alpine official ISO, adds RCCR overlay, repackages

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Arguments
ARCH="$1"        # x86, x86_64, aarch64
TYPE="$2"        # control, target
VERSION="${3:-0.0.4}"

if [ -z "$ARCH" ] || [ -z "$TYPE" ]; then
    echo "Usage: $0 <arch> <type> [version]"
    echo "Arch: x86, x86_64, aarch64"
    echo "Type: control, target"
    exit 1
fi

# Alpine version
ALPINE_VERSION="3.23"
ALPINE_RELEASE="3.23.2"

OUTPUT_DIR="$PROJECT_DIR/build/$ARCH-$TYPE"
PROFILE_DIR="$PROJECT_DIR/image-profiles/$TYPE"

mkdir -p "$OUTPUT_DIR"

echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║        RCCR x86/x86_64 Builder (Alpine Official ISO)             ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""
echo "Architecture: $ARCH"
echo "Type: $TYPE"
echo "Version: $VERSION"
echo "Alpine: $ALPINE_RELEASE"
echo ""

# ===================================================================
# 1. Download Alpine Official ISO
# ===================================================================

ALPINE_ISO="alpine-standard-${ALPINE_RELEASE}-${ARCH}.iso"
ALPINE_URL="https://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/releases/${ARCH}/${ALPINE_ISO}"

echo "[1/6] Downloading Alpine official ISO..."
echo "  URL: $ALPINE_URL"

if [ ! -f "/tmp/$ALPINE_ISO" ]; then
    wget -q --show-progress -O "/tmp/$ALPINE_ISO" "$ALPINE_URL" || {
        echo "ERROR: Download failed"
        exit 1
    }
else
    echo "  Using cached: /tmp/$ALPINE_ISO"
fi

# ===================================================================
# 2. Extract ISO
# ===================================================================

echo ""
echo "[2/6] Extracting ISO..."

TEMP_DIR=$(mktemp -d)
TEMP_ISO="/tmp/alpine-std-${ARCH}-$$.iso"
cp "/tmp/$ALPINE_ISO" "$TEMP_ISO"

# Mount ISO
MOUNT_DIR=$(mktemp -d)
sudo mount -o loop "$TEMP_ISO" "$MOUNT_DIR"

# Copy ISO contents
ISO_WORK=$(mktemp -d)
sudo cp -a "$MOUNT_DIR"/* "$ISO_WORK/" 2>/dev/null || true
sudo cp -a "$MOUNT_DIR"/.[!.]* "$ISO_WORK/" 2>/dev/null || true

sudo umount "$MOUNT_DIR"
rm -rf "$MOUNT_DIR"

echo "  ✓ Extracted"

# ===================================================================
# 3. Generate RCCR Overlay
# ===================================================================

echo ""
echo "[3/6] Generating RCCR overlay..."

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
    sudo rm -rf "$ISO_WORK" "$TEMP_ISO"
    exit 1
}

if [ ! -f "ReCyClusteR-Node.apkovl.tar.gz" ]; then
    echo "ERROR: Overlay file not found"
    sudo rm -rf "$ISO_WORK" "$TEMP_ISO"
    exit 1
fi

echo "  ✓ Overlay generated"

# ===================================================================
# 4. Add Overlay to ISO
# ===================================================================

echo ""
echo "[4/6] Installing overlay to ISO..."

sudo cp "ReCyClusteR-Node.apkovl.tar.gz" "$ISO_WORK/"
sudo ls -lh "$ISO_WORK/"*.apkovl.tar.gz

echo "  ✓ Overlay installed"

# ===================================================================
# 5. Repack ISO
# ===================================================================

echo ""
echo "[5/6] Repacking ISO..."

OUTPUT_ISO="$OUTPUT_DIR/rccr-$VERSION-$ARCH-$TYPE.iso"

# Create new ISO with architecture-specific boot options
if [ "$ARCH" = "aarch64" ]; then
    # aarch64: UEFI only (no BIOS/syslinux)
    echo "  Using UEFI boot (aarch64)"

    # Check for EFI boot files
    if [ -f "$ISO_WORK/efi/boot/bootaa64.efi" ]; then
        echo "  Found: /efi/boot/bootaa64.efi"

        # Create ISO with EFI boot support
        sudo genisoimage \
            -o "$OUTPUT_ISO" \
            -J -joliet-long \
            -R \
            -V "RCCR_${TYPE^^}" \
            -A "RCCR Alpine Linux" \
            -efi-boot efi/boot/bootaa64.efi \
            -no-emul-boot \
            "$ISO_WORK" 2>&1 | grep -v "Warning: creating filesystem that does not conform"
    else
        echo "  WARNING: /efi/boot/bootaa64.efi not found, trying alternative methods"

        # Try to find any EFI directory
        if [ -d "$ISO_WORK/EFI" ] || [ -d "$ISO_WORK/efi" ]; then
            echo "  Found EFI directory, creating basic ISO"
        fi

        # Create basic ISO (will still contain EFI files, just no boot flag)
        sudo genisoimage \
            -o "$OUTPUT_ISO" \
            -J -joliet-long \
            -R \
            -V "RCCR_${TYPE^^}" \
            "$ISO_WORK" 2>&1 | grep -v "Warning: creating filesystem that does not conform"
    fi
else
    # x86/x86_64: BIOS boot (syslinux)
    echo "  Using BIOS boot (x86/x86_64)"
    sudo genisoimage \
        -o "$OUTPUT_ISO" \
        -b boot/syslinux/isolinux.bin \
        -c boot/syslinux/boot.cat \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        -joliet \
        -rational-rock \
        -V "RCCR_${TYPE^^}" \
        "$ISO_WORK" 2>&1 | grep -v "Warning: creating filesystem that does not conform"

    # Make bootable (x86 only)
    sudo isohybrid "$OUTPUT_ISO" 2>/dev/null || true
fi

sudo chown $(whoami):$(whoami) "$OUTPUT_ISO"

echo "  ✓ ISO created"

# ===================================================================
# 6. Cleanup
# ===================================================================

echo ""
echo "[6/6] Cleaning up..."

sudo rm -rf "$ISO_WORK" "$TEMP_ISO"
rm -rf "$TEMP_DIR"

# Generate checksum
cd "$OUTPUT_DIR"
sha256sum "rccr-$VERSION-$ARCH-$TYPE.iso" > SHA256SUMS

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
echo "Flash with:"
echo "  dd if=$OUTPUT_ISO of=/dev/sdX bs=4M status=progress"
echo "  or use Rufus/Etcher"
echo ""
