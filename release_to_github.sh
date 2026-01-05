#!/bin/bash
set -e

# Check if build_output directory exists
if [ ! -d "build_output" ]; then
    echo "Error: build_output directory not found. Run build_local.sh first."
    exit 1
fi

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is not installed."
    echo "Install from: https://cli.github.com/"
    exit 1
fi

# Get version tag
VERSION="v$(date +%Y%m%d-%H%M%S)"
echo "Creating release: $VERSION"

# Create release
gh release create "$VERSION" \
    --title "ReCyClusteR Alpine Images $VERSION" \
    --notes "## Pre-configured Alpine Linux Images for ReCyClusteR

### 🔑 SSH Configuration
- Hostname: \`ReCyClusteR-Node\`
- Authentication: SSH key-based (password-less)
- All nodes share the same SSH key for initial cluster setup

⚠️ **WARNING**: These images contain a shared SSH key for initial setup only.
Replace with unique keys using Ansible after deployment.

### 📦 Available Images
- Standard x86_64, x86, aarch64
- Raspberry Pi aarch64, armv7, armhf

### 🚀 Usage
1. Flash image to device
2. Boot and connect to network (DHCP)
3. SSH using the provided key
4. Run Ansible playbooks for cluster configuration

### 📋 Build Information
- Built on: $(date)
- Alpine Version: 3.23.2
- Build Host: $(hostname)" \
    build_output/*.gz

echo "✓ Release created: $VERSION"
echo "View at: $(gh repo view --web)"
