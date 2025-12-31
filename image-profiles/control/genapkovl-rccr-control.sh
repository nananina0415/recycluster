#!/bin/sh -e

# RCCR Control Node Overlay Generator
# This script creates the overlay (apkovl) for the Control node

HOSTNAME="$1"
if [ -z "$HOSTNAME" ]; then
	HOSTNAME="ReCyClusteR-Node"
fi

cleanup() {
	rm -rf "$tmp"
}

makefile() {
	OWNER="$1"
	PERMS="$2"
	FILENAME="$3"
	cat > "$FILENAME"
	chown "$OWNER" "$FILENAME"
	chmod "$PERMS" "$FILENAME"
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
# RCCR Control Node SSH Configuration

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
PasswordAuthentication yes
PermitEmptyPasswords no
ChallengeResponseAuthentication no

# PAM
UsePAM yes

# X11 and forwarding
X11Forwarding no
AllowTcpForwarding yes
AllowAgentForwarding yes

# Environment
AcceptEnv LANG LC_*

# Subsystems
Subsystem sftp /usr/lib/ssh/sftp-server

# Security
StrictModes yes
MaxAuthTries 3
MaxSessions 10
EOF

# SSH temporary keys
mkdir -p "$tmp"/root/.ssh
if [ -f /tmp/rccr-ssh/id_rsa ]; then
	cp /tmp/rccr-ssh/id_rsa "$tmp"/root/.ssh/id_rsa
	cp /tmp/rccr-ssh/id_rsa.pub "$tmp"/root/.ssh/id_rsa.pub
	chmod 700 "$tmp"/root/.ssh
	chmod 600 "$tmp"/root/.ssh/id_rsa
	chmod 644 "$tmp"/root/.ssh/id_rsa.pub
fi

# SSH client config
cat > "$tmp"/root/.ssh/config <<'EOF'
# RCCR SSH Client Configuration
Host *
	StrictHostKeyChecking no
	UserKnownHostsFile /dev/null
	LogLevel ERROR
	ServerAliveInterval 60
	ServerAliveCountMax 3
EOF
chmod 600 "$tmp"/root/.ssh/config

# ===================================================================
# RCCR Installation
# ===================================================================

mkdir -p "$tmp"/root/rccr

# Copy RCCR files if available
if [ -d /tmp/rccr-files ]; then
	cp -r /tmp/rccr-files/* "$tmp"/root/rccr/ 2>/dev/null || true
fi

# ===================================================================
# Ansible Configuration
# ===================================================================

mkdir -p "$tmp"/etc/ansible
cat > "$tmp"/etc/ansible/ansible.cfg <<'EOF'
[defaults]
inventory = /root/rccr/inventory.yml
host_key_checking = False
timeout = 30
remote_user = root
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_facts
fact_caching_timeout = 3600

[privilege_escalation]
become = True
become_method = sudo
become_user = root
become_ask_pass = False

[ssh_connection]
pipelining = True
control_path = /tmp/ansible-ssh-%%h-%%p-%%r
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
EOF

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

# RCCR init script
cat > "$tmp"/etc/local.d/rccr-init.start <<'INITEOF'
#!/bin/sh

# RCCR Control Node Initialization

# Wait for network
sleep 2

# Ensure services are running
rc-service sshd start 2>/dev/null || true
rc-service docker start 2>/dev/null || true

# First boot setup
SETUP_FLAG="/root/.rccr-setup-done"

if [ ! -f "$SETUP_FLAG" ]; then
    # First boot - setup root password for remote access
    clear
    cat <<'SETUP'
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║               RCCR (ReCyClusteR) - First Boot Setup              ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝

Welcome to RCCR Control Node!

For remote access from Windows/other computers, please set a root password.
Node-to-node communication will use SSH keys automatically.

SETUP

    echo ""
    echo "Please set root password for remote SSH access:"
    passwd root

    if [ $? -eq 0 ]; then
        touch "$SETUP_FLAG"
        echo ""
        echo "✓ Password set successfully!"
        echo ""
        echo "Connection Information:"
        IP_ADDR=$(ip -4 addr show | grep 'inet ' | awk '{print $2}' | cut -d/ -f1 | grep -v 127.0.0.1 | head -1)
        echo "  IP Address: $IP_ADDR"
        echo "  SSH Access: ssh root@$IP_ADDR"
        echo ""
        echo "Press Enter to continue..."
        read dummy
    else
        echo ""
        echo "⚠️  Password setup failed. You can set it later with: passwd root"
        echo ""
    fi
fi

# Display MOTD
cat <<'MOTD'

╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║               RCCR (ReCyClusteR) - Control Node                  ║
║                  Alpine Linux Cluster Manager                    ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝

System Information:
  Hostname: ReCyClusteR-Node
  Type: Control Node (Cluster Manager)
  OS: Alpine Linux

Quick Start:
  1. cd /root/rccr
  2. Edit configuration: vi cluster_config.yml
  3. Run setup: ansible-playbook setup.playbook

Available Commands:
  - ansible-playbook: Run cluster automation
  - docker: Container management

Configuration: /root/rccr/cluster_config.yml
Documentation: /root/rccr/README.md

⚠️  SECURITY: This node uses a temporary SSH key for initial setup.
    Run 'ansible-playbook setup.playbook' to rotate keys automatically.

MOTD

# Show current IP address
IP_ADDR=$(ip -4 addr show | grep 'inet ' | awk '{print $2}' | cut -d/ -f1 | grep -v 127.0.0.1 | head -1)
if [ -n "$IP_ADDR" ]; then
    echo "Network Status:"
    echo "  IP Address: $IP_ADDR"
    echo "  Remote Access: ssh root@$IP_ADDR"
    echo ""
fi

INITEOF
chmod +x "$tmp"/etc/local.d/rccr-init.start

# ===================================================================
# APK World (Pre-installed packages)
# ===================================================================

mkdir -p "$tmp"/etc/apk
cat > "$tmp"/etc/apk/world <<'EOF'
openssh
openssh-client
python3
py3-yaml
ansible
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
# Shell Profile (sh compatible)
# ===================================================================

cat > "$tmp"/root/.profile <<'EOF'
# RCCR Control Node Shell Configuration

export PS1='rccr-control:\w\$ '
export PATH="/root/rccr/scripts:$PATH"

alias ll='ls -lah'
alias rccr='cd /root/rccr'
alias cluster='ansible-playbook /root/rccr/setup.playbook'

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
