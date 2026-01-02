#!/bin/sh -e

# RCCR Target Node Overlay Generator
# This script creates the overlay (apkovl) for the Target (worker) node

HOSTNAME="$1"
if [ -z "$HOSTNAME" ]; then
	HOSTNAME="ReCyClusteR-Node"
fi

cleanup() {
	rm -rf "$tmp"
}

rc_add() {
	mkdir -p "$tmp"/etc/runlevels/"$2"
	ln -sf /etc/init.d/"$1" "$tmp"/etc/runlevels/"$2"/"$1"
}

tmp="$(mktemp -d)"
trap cleanup EXIT

# ===================================================================
# System Configuration
# ===================================================================

# Hostname
mkdir -p "$tmp"/etc
echo "$HOSTNAME" > "$tmp"/etc/hostname

# Hosts file
cat > "$tmp"/etc/hosts <<EOF
127.0.0.1	localhost localhost.localdomain
::1		localhost localhost.localdomain
127.0.1.1	$HOSTNAME
EOF

# ===================================================================
# SSH Configuration
# ===================================================================

mkdir -p "$tmp"/etc/ssh
cat > "$tmp"/etc/ssh/sshd_config <<'EOF'
# RCCR Target Node SSH Configuration

# Port and Protocol
Port 22
AddressFamily any
ListenAddress 0.0.0.0

# Host keys
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Authentication
PermitRootLogin yes
PubkeyAuthentication yes
PasswordAuthentication no
PermitEmptyPasswords no

# PAM
UsePAM yes

# X11 and forwarding
X11Forwarding no

# Environment
AcceptEnv LANG LC_*

# Subsystems
Subsystem sftp /usr/lib/ssh/sftp-server

# Security
StrictModes yes
MaxAuthTries 3
MaxSessions 10
EOF

# SSH authorized_keys (temporary key)
mkdir -p "$tmp"/root/.ssh
if [ -f /tmp/rccr-ssh/id_rsa.pub ]; then
	cp /tmp/rccr-ssh/id_rsa.pub "$tmp"/root/.ssh/authorized_keys
	chmod 700 "$tmp"/root/.ssh
	chmod 600 "$tmp"/root/.ssh/authorized_keys
fi

# ===================================================================
# Init Scripts
# ===================================================================

mkdir -p "$tmp"/etc/local.d

# Target node init script
cat > "$tmp"/etc/local.d/target-init.start <<'INITEOF'
#!/bin/sh

# RCCR Target Node Initialization

# ===================================================================
# Hostname Setup (BEFORE network)
# ===================================================================

# Ensure hostname is set from overlay before network comes up
if [ -f /etc/hostname ]; then
    HOSTNAME=$(cat /etc/hostname)
    hostname "$HOSTNAME" 2>/dev/null || true
    echo "✓ Hostname: $HOSTNAME"
fi

# ===================================================================
# Network Wait & Check
# ===================================================================

echo ""
echo "⚠️  IMPORTANT: Network cable must be connected for initial setup!"
echo "Waiting for network connection..."
sleep 3

# Check network connectivity
MAX_RETRIES=5
RETRY_COUNT=0
NETWORK_OK=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    if ping -c 1 -W 2 dl-cdn.alpinelinux.org >/dev/null 2>&1; then
        NETWORK_OK=1
        echo "✓ Network connection established"
        break
    fi
    RETRY_COUNT=$((RETRY_COUNT + 1))
    echo "  Checking network... ($RETRY_COUNT/$MAX_RETRIES)"
    sleep 2
done

if [ $NETWORK_OK -eq 0 ]; then
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║                         NETWORK ERROR                             ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "⚠️  No network connection detected!"
    echo ""
    echo "RCCR requires internet to download packages (SSH, Python)."
    echo ""
    echo "Please:"
    echo "  1. Connect network cable"
    echo "  2. Check DHCP server is running"
    echo "  3. Reboot: 'reboot'"
    echo ""
    echo "Continuing with limited functionality in 5 seconds..."
    sleep 5
fi

# ===================================================================
# Package Installation (Requires Network)
# ===================================================================

if [ $NETWORK_OK -eq 1 ] && [ -f /etc/apk/world ]; then
    # Check if packages are already installed
    MISSING_PKGS=""
    while IFS= read -r pkg; do
        if ! apk info -e "$pkg" >/dev/null 2>&1; then
            MISSING_PKGS="$MISSING_PKGS $pkg"
        fi
    done < /etc/apk/world

    if [ -n "$MISSING_PKGS" ]; then
        echo ""
        echo "Installing required packages..."
        apk update
        apk add $MISSING_PKGS
        echo "✓ Packages installed"
    fi
fi

# ===================================================================
# Service Startup
# ===================================================================

# Ensure services are running
rc-service sshd start 2>/dev/null || true

# ===================================================================
# Display MOTD
# ===================================================================

cat <<'MOTD'

╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║                RCCR (ReCyClusteR) - Target Node                  ║
║                  Alpine Linux Cluster Worker                     ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝

System Information:
  Hostname: ReCyClusteR-Node
  Type: Target Node (Worker)
  OS: Alpine Linux

Status:
  ✓ SSH Server: Running
  ✓ Python3: Installed
  ✓ Hostname: ReCyClusteR-Node

This node is ready to be managed by the Control Node.
Waiting for Ansible configuration from the cluster manager...

⚠️  SECURITY: This node uses a temporary SSH key for initial access.
    The Control Node will automatically rotate keys during setup.

MOTD

INITEOF
chmod +x "$tmp"/etc/local.d/target-init.start

# ===================================================================
# APK World (Pre-installed packages)
# ===================================================================

mkdir -p "$tmp"/etc/apk
cat > "$tmp"/etc/apk/world <<'EOF'
openssh
python3
sudo
EOF

# ===================================================================
# Service Configuration
# ===================================================================

# Enable services
rc_add sshd default
rc_add local default

# ===================================================================
# Shell Profile (sh compatible)
# ===================================================================

cat > "$tmp"/root/.profile <<'EOF'
# RCCR Target Node Shell Configuration

export PS1='rccr-target:\w\$ '

alias ll='ls -lah'

# Welcome message
if [ -f /etc/motd ]; then
    cat /etc/motd
fi
EOF

# ===================================================================
# Pack Overlay
# ===================================================================

tar -c -C "$tmp" etc root 2>/dev/null | gzip -9n > "$HOSTNAME".apkovl.tar.gz

echo "✓ Overlay generated: $HOSTNAME.apkovl.tar.gz"
