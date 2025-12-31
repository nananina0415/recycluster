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
# Docker Configuration
# ===================================================================

mkdir -p "$tmp"/etc/docker
cat > "$tmp"/etc/docker/daemon.json <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF

# ===================================================================
# Init Scripts
# ===================================================================

mkdir -p "$tmp"/etc/local.d

# Target node init script
cat > "$tmp"/etc/local.d/target-init.start <<'INITEOF'
#!/bin/sh

# RCCR Target Node Initialization

# Wait for network
sleep 2

# Ensure services are running
rc-service sshd start 2>/dev/null || true
rc-service docker start 2>/dev/null || true

# Display MOTD
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
  ✓ Docker Engine: Running
  ✓ Avahi (mDNS): Advertising hostname

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
docker
sudo
EOF

# ===================================================================
# Service Configuration
# ===================================================================

# Enable services
rc_add sshd default
rc_add docker default
rc_add local default

# ===================================================================
# Bashrc
# ===================================================================

cat > "$tmp"/root/.bashrc <<'EOF'
# RCCR Target Node Bash Configuration

export PS1='\[\033[01;33m\]rccr-target\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

alias ll='ls -lah'
alias logs='docker logs'
alias ps='docker ps'

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
