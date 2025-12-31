#!/bin/bash
set -e

# ═══════════════════════════════════════════════════════════════════
# RCCR All Images Builder
# ═══════════════════════════════════════════════════════════════════
# Builds all RCCR OS images for all architectures and types
#
# Usage:
#   ./build-all-images.sh [version]
#
# Example:
#   ./build-all-images.sh 0.0.4
# ═══════════════════════════════════════════════════════════════════

VERSION=${1:-0.0.4}

# Architectures
ARCHS=("x86" "x86_64" "aarch64" "rpi-aarch64" "armv7" "armhf")

# Types
TYPES=("control" "target")

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}ℹ ${NC}$1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }

# Get script directory
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

echo ""
print_info "╔═══════════════════════════════════════════════════════════════════╗"
print_info "║           RCCR Batch Image Builder                               ║"
print_info "╚═══════════════════════════════════════════════════════════════════╝"
echo ""
print_info "Version: $VERSION"
print_info "Architectures: ${ARCHS[*]}"
print_info "Types: ${TYPES[*]}"
print_info "Total images: $(( ${#ARCHS[@]} * ${#TYPES[@]} ))"
echo ""

# Track start time
START_TIME=$(date +%s)

# Track success/failure
SUCCESSFUL=0
FAILED=0
FAILED_BUILDS=()

# Build all images
for ARCH in "${ARCHS[@]}"; do
    for TYPE in "${TYPES[@]}"; do
        echo ""
        echo "═══════════════════════════════════════════════════════════════════"
        print_info "Building: ${ARCH} - ${TYPE}"
        echo "═══════════════════════════════════════════════════════════════════"
        echo ""

        if bash "$SCRIPT_DIR/build-single-image.sh" "$ARCH" "$TYPE" "$VERSION"; then
            print_success "Build succeeded: ${ARCH}-${TYPE}"
            ((SUCCESSFUL++))
        else
            print_error "Build failed: ${ARCH}-${TYPE}"
            ((FAILED++))
            FAILED_BUILDS+=("${ARCH}-${TYPE}")
        fi

        echo ""
    done
done

# Calculate duration
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
MINUTES=$((DURATION / 60))
SECONDS=$((DURATION % 60))

# Summary
echo ""
echo "═══════════════════════════════════════════════════════════════════"
print_info "Build Summary"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
print_success "Successful: $SUCCESSFUL"
if [ $FAILED -gt 0 ]; then
    echo -e "${RED}✗${NC} Failed: $FAILED"
    echo ""
    echo "Failed builds:"
    for BUILD in "${FAILED_BUILDS[@]}"; do
        echo "  - $BUILD"
    done
fi
echo ""
print_info "Total time: ${MINUTES}m ${SECONDS}s"
echo ""
print_info "Output directory: $SCRIPT_DIR/../build/"
echo ""

# List all built files
echo "═══════════════════════════════════════════════════════════════════"
print_info "Built Images"
echo "═══════════════════════════════════════════════════════════════════"
echo ""
find "$SCRIPT_DIR/../build" -type f \( -name "*.iso" -o -name "*.img" \) -exec ls -lh {} \; | awk '{print $9, "(" $5 ")"}'
echo ""

# Generate master checksum file
echo "═══════════════════════════════════════════════════════════════════"
print_info "Generating Master Checksum File"
echo "═══════════════════════════════════════════════════════════════════"
echo ""

MASTER_CHECKSUM="$SCRIPT_DIR/../build/SHA256SUMS-all"
> "$MASTER_CHECKSUM"

find "$SCRIPT_DIR/../build" -type f \( -name "*.iso" -o -name "*.img" \) | while read -r FILE; do
    sha256sum "$FILE" >> "$MASTER_CHECKSUM"
done

if [ -f "$MASTER_CHECKSUM" ]; then
    print_success "Master checksum file: $MASTER_CHECKSUM"
    cat "$MASTER_CHECKSUM"
fi

echo ""
if [ $FAILED -eq 0 ]; then
    print_success "╔═══════════════════════════════════════════════════════════════════╗"
    print_success "║           All Builds Completed Successfully!                     ║"
    print_success "╚═══════════════════════════════════════════════════════════════════╝"
    exit 0
else
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║          Build Completed with Errors                              ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    exit 1
fi
