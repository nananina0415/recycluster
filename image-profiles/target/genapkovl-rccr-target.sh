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

# Network interfaces - Minimal config (loopback only)
# Real interfaces will be auto-detected and configured by init script
mkdir -p "$tmp"/etc/network
cat > "$tmp"/etc/network/interfaces <<'NETEOF'
# Loopback
auto lo
iface lo inet loopback
NETEOF

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
# Hostname Setup
# ===================================================================

# Ensure hostname is set from overlay
if [ -f /etc/hostname ]; then
    HOSTNAME=$(cat /etc/hostname)
    hostname "$HOSTNAME" 2>/dev/null || true
    echo "✓ Hostname: $HOSTNAME"
fi

# ===================================================================
# Network Setup
# ===================================================================

echo "Configuring network interfaces..."

# Auto-configure all network interfaces with DHCP
# Directly write to /etc/network/interfaces (non-interactive)
for iface in $(ls /sys/class/net/ 2>/dev/null | grep -v '^lo$'); do
    if ! grep -q "^iface $iface" /etc/network/interfaces 2>/dev/null; then
        cat >> /etc/network/interfaces <<EOF

auto $iface
iface $iface inet dhcp
EOF
        echo "  ✓ Added $iface to network configuration"
    fi
done

# Restart networking service to apply configuration
echo "  Starting networking service..."
rc-service networking restart 2>/dev/null || rc-service networking start 2>/dev/null

# Wait for IP address (max 15 seconds)
echo "  Waiting for DHCP..."
for i in $(seq 1 150); do
    if ip -4 addr show | grep -q 'inet.*global'; then
        IP_ADDR=$(ip -4 addr show | grep 'inet ' | awk '{print $2}' | cut -d/ -f1 | grep -v 127.0.0.1 | head -1)
        echo "  ✓ Network configured: $IP_ADDR"
        break
    fi
    sleep 0.1
done

# Show final status
if ! ip -4 addr show | grep -q 'inet.*global'; then
    echo "  ⚠ No IP address assigned"
    echo "  Debug info:"
    ip link show | grep -E '^[0-9]+:' | awk '{print "    " $2 $3}'
fi

# ===================================================================
# Service Startup
# ===================================================================

# Start SSH service
rc-service sshd start 2>/dev/null || true
echo "✓ SSH service started"

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
  ✓ Hostname: ReCyClusteR-Node

This node is ready for cluster setup.
The Control Node will install Python and configure this node via Ansible.

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
sudo
EOF

# ===================================================================
# Service Configuration
# ===================================================================

# Enable services
rc_add networking boot
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
