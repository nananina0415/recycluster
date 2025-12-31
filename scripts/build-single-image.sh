#!/bin/bash
set -e

# ═══════════════════════════════════════════════════════════════════
# RCCR Single Image Builder
# ═══════════════════════════════════════════════════════════════════
# Builds a single RCCR OS image using alpine-make-iso
#
# Usage:
#   ./build-single-image.sh <arch> <type> [version]
#
# Examples:
#   ./build-single-image.sh x86_64 control 0.0.2
#   ./build-single-image.sh aarch64 target
# ═══════════════════════════════════════════════════════════════════

ARCH=$1
TYPE=$2
VERSION=${3:-0.0.2}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Print with color
print_info() { echo -e "${BLUE}ℹ ${NC}$1"; }
print_success() { echo -e "${GREEN}✓${NC} $1"; }
print_error() { echo -e "${RED}✗${NC} $1"; }
print_warn() { echo -e "${YELLOW}⚠${NC} $1"; }

# Validate arguments
if [ -z "$ARCH" ] || [ -z "$TYPE" ]; then
    print_error "Usage: $0 <arch> <type> [version]"
    echo ""
    echo "Arguments:"
    echo "  arch    : x86, x86_64, aarch64, rpi-aarch64, armv7, armhf"
    echo "  type    : control, target"
    echo "  version : (optional) default: 0.0.2"
    echo ""
    echo "Examples:"
    echo "  $0 x86_64 control 0.0.2"
    echo "  $0 aarch64 target"
    exit 1
fi

# Validate TYPE
if [[ "$TYPE" != "control" ]] && [[ "$TYPE" != "target" ]]; then
    print_error "Invalid type: $TYPE (must be 'control' or 'target')"
    exit 1
fi

# Get script directory
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT="$SCRIPT_DIR/.."
PROFILE_DIR="$PROJECT_ROOT/image-profiles/$TYPE"
OUTPUT_DIR="$PROJECT_ROOT/build/$ARCH-$TYPE"

# Alpine version
ALPINE_VERSION="3.19"

# Architecture mapping for Alpine and Docker
case "$ARCH" in
    x86)
        PLATFORM="linux/386"
        ALPINE_ARCH="x86"
        ;;
    x86_64)
        PLATFORM="linux/amd64"
        ALPINE_ARCH="x86_64"
        ;;
    aarch64)
        PLATFORM="linux/arm64"
        ALPINE_ARCH="aarch64"
        ;;
    rpi-aarch64)
        PLATFORM="linux/arm64"
        ALPINE_ARCH="aarch64"
        ;;
    armv7)
        PLATFORM="linux/arm/v7"
        ALPINE_ARCH="armv7"
        ;;
    armhf)
        PLATFORM="linux/arm/v6"
        ALPINE_ARCH="armhf"
        ;;
    *)
        print_error "Unsupported architecture: $ARCH"
        exit 1
        ;;
esac

print_info "╔═══════════════════════════════════════════════════════════════════╗"
print_info "║           RCCR Image Builder                                      ║"
print_info "╚═══════════════════════════════════════════════════════════════════╝"
echo ""
print_info "Architecture: $ARCH (Alpine: $ALPINE_ARCH)"
print_info "Type: $TYPE"
print_info "Version: $VERSION"
print_info "Platform: $PLATFORM"
print_info "Alpine: $ALPINE_VERSION"
echo ""

# Check dependencies
print_info "Checking dependencies..."

if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install Docker first."
    exit 1
fi
print_success "Docker found"

# Create output directory
mkdir -p "$OUTPUT_DIR"
print_success "Output directory: $OUTPUT_DIR"

# Generate SSH keys if not exist
if [ ! -f "$PROJECT_ROOT/.rccr/ssh_temp_key" ]; then
    print_warn "SSH temporary key not found. Generating..."
    mkdir -p "$PROJECT_ROOT/.rccr"

    if command -v ssh-keygen &> /dev/null; then
        ssh-keygen -t rsa -b 4096 -f "$PROJECT_ROOT/.rccr/ssh_temp_key" -N "" -C "rccr-temporary-key"
        print_success "SSH key generated"
    else
        # Use Docker to generate key
        print_info "Using Docker to generate SSH key..."
        docker run --rm -v "$PROJECT_ROOT/.rccr:/keys" alpine:3.19 sh -c \
            "apk add --no-cache openssh-keygen && \
             ssh-keygen -t rsa -b 4096 -f /keys/ssh_temp_key -N '' -C 'rccr-temporary-key' && \
             chmod 600 /keys/ssh_temp_key && \
             chmod 644 /keys/ssh_temp_key.pub"
        print_success "SSH key generated via Docker"
    fi
else
    print_success "SSH temporary key exists"
fi

# Copy SSH keys to temporary location
print_info "Preparing SSH keys..."
mkdir -p /tmp/rccr-ssh
cp "$PROJECT_ROOT/.rccr/ssh_temp_key" /tmp/rccr-ssh/id_rsa
cp "$PROJECT_ROOT/.rccr/ssh_temp_key.pub" /tmp/rccr-ssh/id_rsa.pub
chmod 600 /tmp/rccr-ssh/id_rsa
chmod 644 /tmp/rccr-ssh/id_rsa.pub
print_success "SSH keys prepared"

# Copy RCCR files to temporary location
print_info "Preparing RCCR files..."
mkdir -p /tmp/rccr-files
cp -r "$PROJECT_ROOT"/*.playbook /tmp/rccr-files/ 2>/dev/null || true
cp -r "$PROJECT_ROOT"/machine_layer /tmp/rccr-files/ 2>/dev/null || true
cp -r "$PROJECT_ROOT"/container_layer /tmp/rccr-files/ 2>/dev/null || true
cp -r "$PROJECT_ROOT"/orchestration_layer /tmp/rccr-files/ 2>/dev/null || true
cp -r "$PROJECT_ROOT"/playbooks /tmp/rccr-files/ 2>/dev/null || true
cp -r "$PROJECT_ROOT"/templates /tmp/rccr-files/ 2>/dev/null || true
cp "$PROJECT_ROOT"/cluster_config.yml /tmp/rccr-files/ 2>/dev/null || true
print_success "RCCR files prepared"

# Build image using alpine-make-iso in Docker
print_info ""
print_info "Building image (this may take several minutes)..."
print_info ""

docker run --rm --privileged \
    -e "RCCR_ARCH=$ARCH" \
    -v "$PROFILE_DIR:/profile:ro" \
    -v "$OUTPUT_DIR:/output" \
    -v "/tmp/rccr-ssh:/tmp/rccr-ssh:ro" \
    -v "/tmp/rccr-files:/tmp/rccr-files:ro" \
    --platform "$PLATFORM" \
    alpine:${ALPINE_VERSION} /bin/sh -c "
        set -ex

        echo '═══════════════════════════════════════════════════════════════════'
        echo 'Installing build dependencies...'
        echo '═══════════════════════════════════════════════════════════════════'
        apk add --no-cache \
            alpine-sdk \
            build-base \
            apk-tools \
            alpine-conf \
            xorriso \
            squashfs-tools \
            grub \
            grub-efi \
            mtools \
            dosfstools \
            git

        echo ''
        echo '═══════════════════════════════════════════════════════════════════'
        echo 'Downloading Alpine aports (for mkimage.sh)...'
        echo '═══════════════════════════════════════════════════════════════════'

        # Try GitHub mirror first (more reliable in GitHub Actions)
        if ! git clone --depth 1 --branch ${ALPINE_VERSION}-stable \
            https://github.com/alpinelinux/aports.git /aports; then
            echo \"⚠ GitHub mirror failed, trying GitLab...\"
            git clone --depth 1 --branch ${ALPINE_VERSION}-stable \
                https://gitlab.alpinelinux.org/alpine/aports.git /aports
        fi

        cd /aports/scripts

        echo ''
        echo '═══════════════════════════════════════════════════════════════════'
        echo 'Setting up profile...'
        echo '═══════════════════════════════════════════════════════════════════'

        # Copy mkimg profile script (mkimage.sh auto-discovers mkimg.*.sh files)
        cp /profile/mkimg.rccr-${TYPE}.sh ./
        chmod +x mkimg.rccr-${TYPE}.sh

        # Copy overlay generator script
        cp /profile/genapkovl-*.sh ./
        chmod +x genapkovl-*.sh

        echo \"✓ Profile script: mkimg.rccr-${TYPE}.sh\"
        echo \"✓ Overlay script: genapkovl-rccr-${TYPE}.sh\"

        echo ''
        echo '═══════════════════════════════════════════════════════════════════'
        echo 'Building ISO image...'
        echo '═══════════════════════════════════════════════════════════════════'

        # Run mkimage.sh with our profile
        # mkimage.sh will auto-discover mkimg.rccr-*.sh and call profile_rccr_*()
        sh mkimage.sh \
            --tag ${ALPINE_VERSION} \
            --outdir /output \
            --arch ${ALPINE_ARCH} \
            --repository http://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/main \
            --repository http://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/community \
            --profile rccr_${TYPE}

        echo ''
        echo '═══════════════════════════════════════════════════════════════════'
        echo 'Renaming output files...'
        echo '═══════════════════════════════════════════════════════════════════'
        cd /output
        ls -lh

        # Find and rename ISO
        for file in *.iso; do
            if [ -f \"\$file\" ]; then
                mv \"\$file\" rccr-${VERSION}-${ARCH}-${TYPE}.iso
                echo \"✓ Renamed to: rccr-${VERSION}-${ARCH}-${TYPE}.iso\"
            fi
        done

        echo ''
        echo '═══════════════════════════════════════════════════════════════════'
        echo 'Final output:'
        echo '═══════════════════════════════════════════════════════════════════'
        ls -lh /output/
    " || {
        print_error "Docker build failed"
        exit 1
    }

# Cleanup
print_info "Cleaning up temporary files..."
rm -rf /tmp/rccr-ssh /tmp/rccr-files
print_success "Cleanup complete"

# Verify output
echo ""
print_info "Verifying output..."
if ls "$OUTPUT_DIR"/rccr-${VERSION}-${ARCH}-${TYPE}.* 1> /dev/null 2>&1; then
    print_success "Image built successfully!"
    echo ""
    print_info "Output files:"
    ls -lh "$OUTPUT_DIR"/rccr-${VERSION}-${ARCH}-${TYPE}.*
    echo ""

    # Calculate checksum
    print_info "Generating checksums..."
    cd "$OUTPUT_DIR"
    sha256sum rccr-${VERSION}-${ARCH}-${TYPE}.* > SHA256SUMS
    print_success "Checksums saved to: $OUTPUT_DIR/SHA256SUMS"

    echo ""
    print_success "╔═══════════════════════════════════════════════════════════════════╗"
    print_success "║              Build Complete!                                      ║"
    print_success "╚═══════════════════════════════════════════════════════════════════╝"
    echo ""
    print_info "Image: $OUTPUT_DIR/rccr-${VERSION}-${ARCH}-${TYPE}.*"
else
    print_error "Build failed - no output file found"
    exit 1
fi
