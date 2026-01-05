#!/bin/bash
set -e

# Configuration
ALPINE_VERSION="3.23.2"
ARCHITECTURES=(
    "x86_64:std:qemu-system-x86_64:pc"
    "x86:std:qemu-system-i386:pc"
    "aarch64:std:qemu-system-aarch64:virt"
    "aarch64:rpi:qemu-system-aarch64:virt"
    "armv7:rpi:qemu-system-arm:virt"
    "armhf:rpi:qemu-system-arm:virt"
)

BUILD_DIR="build_output"
mkdir -p "$BUILD_DIR"

# SSH Keys (same as GitHub Actions)
SSH_PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPzvIteUj6kIAAPE8VsYJG7Ax6Q28jOce1d3vfPh71AJ recycluster-init-key"
SSH_PRIVKEY="-----BEGIN OPENSSH PRIVATE KEY-----
b3BlbnNzaC1rZXktdjEAAAAABG5vbmUAAAAEbm9uZQAAAAAAAAABAAAAMwAAAAtzc2gtZW
QyNTUxOQAAACD87yLXlI+pCAADxPFbGCRuwMekNvIznHtXd73z4e9QCQAAAJj/Y6S4/2Ok
uAAAAAtzc2gtZWQyNTUxOQAAACD87yLXlI+pCAADxPFbGCRuwMekNvIznHtXd73z4e9QCQ
AAAEDKrmrbB2FntPlNC7NQeB9eJPNyWsOLFxAQifT4Cd6ycPzvIteUj6kIAAPE8VsYJG7A
x6Q28jOce1d3vfPh71AJAAAAFHJlY3ljbHVzdGVyLWluaXQta2V5AQ==
-----END OPENSSH PRIVATE KEY-----"

# Function to create setup script
create_setup_script() {
    cat > setup_alpine.sh << 'SCRIPT_EOF'
#!/bin/sh
set -e

# 호스트네임 설정
setup-hostname -n ReCyClusteR-Node

# 네트워크 설정 (DHCP)
setup-interfaces -a

# SSH 설정
rc-update add sshd default
/etc/init.d/sshd start

# SSH 디렉토리 생성
mkdir -p /root/.ssh
chmod 700 /root/.ssh

# SSH 키 설정
cat > /root/.ssh/authorized_keys << 'EOF'
SSH_PUBKEY_PLACEHOLDER
EOF

cat > /root/.ssh/id_ed25519 << 'EOF'
SSH_PRIVKEY_PLACEHOLDER
EOF

cat > /root/.ssh/id_ed25519.pub << 'EOF'
SSH_PUBKEY_PLACEHOLDER
EOF

chmod 600 /root/.ssh/authorized_keys
chmod 600 /root/.ssh/id_ed25519
chmod 644 /root/.ssh/id_ed25519.pub

# SSH 클라이언트 설정
cat > /root/.ssh/config << 'EOF'
Host *
    StrictHostKeyChecking no
    UserKnownHostsFile=/dev/null
EOF
chmod 600 /root/.ssh/config

# SSH 서버 설정
sed -i 's/^#PermitRootLogin.*/PermitRootLogin prohibit-password/' /etc/ssh/sshd_config
sed -i 's/^#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config

# LBU 설정
lbu add /root/.ssh
lbu add /etc/ssh/sshd_config
lbu add /etc/hostname
lbu add /etc/network/interfaces

# 설정 저장
lbu commit -d
lbu package /media/setup/rccr-config.apkovl.tar.gz

echo "Setup complete!"
poweroff
SCRIPT_EOF

    # Replace placeholders
    sed -i "s|SSH_PUBKEY_PLACEHOLDER|$SSH_PUBKEY|g" setup_alpine.sh
    sed -i "s|SSH_PRIVKEY_PLACEHOLDER|$SSH_PRIVKEY|g" setup_alpine.sh
    chmod +x setup_alpine.sh
}

# Function to build image
build_image() {
    local arch=$1
    local type=$2
    local qemu_system=$3
    local qemu_machine=$4

    echo "========================================="
    echo "Building: $type-$arch"
    echo "========================================="

    # Download Alpine image
    if [ "$type" == "std" ]; then
        local download_url="https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/$arch/alpine-standard-$ALPINE_VERSION-$arch.iso"
        local image_file="alpine-$type-$arch.iso"
    else
        local download_url="https://dl-cdn.alpinelinux.org/alpine/v3.23/releases/$arch/alpine-rpi-$ALPINE_VERSION-$arch.img.gz"
        local image_file="alpine-$type-$arch.img.gz"
    fi

    echo "Downloading: $download_url"
    wget -q --show-progress -O "$image_file" "$download_url"

    # Prepare image
    if [ "$type" == "std" ]; then
        # ISO - boot with expect
        echo "Booting VM with expect..."
        expect << EXPECT_EOF
set timeout 3600

spawn $qemu_system \
    -M $qemu_machine \
    -m 2048 \
    -smp 2 \
    -boot d \
    -cdrom $image_file \
    -nographic

expect "localhost login:"
send "root\r"

expect "localhost:~#"
send "setup-alpine -q\r"

expect "localhost:~#"
send "poweroff\r"

expect eof
EXPECT_EOF

        # Create configured ISO
        mkdir -p iso_mount iso_custom
        sudo mount -o loop "$image_file" iso_mount
        cp -r iso_mount/* iso_custom/
        sudo umount iso_mount

        # Add apkovl if exists
        if [ -f rccr-config.apkovl.tar.gz ]; then
            cp rccr-config.apkovl.tar.gz iso_custom/
        fi

        # Create new ISO
        xorriso -as mkisofs \
            -iso-level 3 \
            -full-iso9660-filenames \
            -volid "ReCyClusteR" \
            -output "$BUILD_DIR/rccr-$type-$arch.iso" \
            -eltorito-boot boot/syslinux/isolinux.bin \
            -eltorito-catalog boot/syslinux/boot.cat \
            -no-emul-boot \
            -boot-load-size 4 \
            -boot-info-table \
            iso_custom/

        gzip "$BUILD_DIR/rccr-$type-$arch.iso"

        # Cleanup
        rm -rf iso_mount iso_custom "$image_file"
    else
        # RPI IMG - extract and boot
        echo "Extracting RPI image..."
        gunzip -c "$image_file" > alpine.img
        qemu-img convert -f raw -O qcow2 alpine.img alpine.qcow2
        qemu-img resize alpine.qcow2 +1G
        rm alpine.img

        echo "Booting RPI VM..."
        timeout 3600 $qemu_system \
            -M $qemu_machine \
            -m 2048 \
            -smp 2 \
            -drive file=alpine.qcow2,format=qcow2 \
            -nographic || true

        # Convert back to raw
        qemu-img convert -f qcow2 -O raw alpine.qcow2 "$BUILD_DIR/rccr-$type-$arch.img"
        gzip "$BUILD_DIR/rccr-$type-$arch.img"

        # Cleanup
        rm -f alpine.qcow2 "$image_file"
    fi

    echo "✓ Built: $BUILD_DIR/rccr-$type-$arch.{iso|img}.gz"
}

# Main build loop
create_setup_script

for arch_config in "${ARCHITECTURES[@]}"; do
    IFS=':' read -r arch type qemu_system qemu_machine <<< "$arch_config"
    build_image "$arch" "$type" "$qemu_system" "$qemu_machine"
done

echo ""
echo "========================================="
echo "✓ All images built successfully!"
echo "========================================="
echo "Output directory: $BUILD_DIR/"
ls -lh "$BUILD_DIR/"
