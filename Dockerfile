FROM alpine:3.19

LABEL org.opencontainers.image.source="https://github.com/nananina0415/recycluster"
LABEL org.opencontainers.image.description="RCCR - Alpine Linux cluster setup tool (Ansible-based)"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.version="0.0.2"

# Install required packages
RUN apk add --no-cache \
    openssh-client \
    openssh-keygen \
    ansible \
    python3 \
    py3-yaml \
    && rm -rf /var/cache/apk/*

# Create application directory
WORKDIR /app

# Copy RCCR files
COPY playbooks/ /app/playbooks/
COPY templates/ /app/templates/
COPY machine_layer/ /app/machine_layer/
COPY container_layer/ /app/container_layer/
COPY orchestration_layer/ /app/orchestration_layer/
COPY *.playbook /app/
COPY cluster_config.yml /app/cluster_config.yml
COPY README.md /app/README.md
COPY LICENSE /app/LICENSE

# Configure Ansible
RUN mkdir -p /etc/ansible && \
    printf '[defaults]\n\
inventory = /workspace/inventory.yml\n\
host_key_checking = False\n\
timeout = 30\n\
remote_user = root\n\
gathering = smart\n\
\n\
[privilege_escalation]\n\
become = True\n\
become_method = sudo\n\
become_user = root\n\
become_ask_pass = False\n\
\n\
[ssh_connection]\n\
pipelining = True\n\
control_path = /tmp/ansible-ssh-%%h-%%p-%%r\n\
ssh_args = -o ControlMaster=auto -o ControlPersist=60s\n' > /etc/ansible/ansible.cfg

# Create workspace directory (for user mounts)
WORKDIR /workspace

# Create entrypoint script
RUN printf '#!/bin/bash\n\
set -e\n\
\n\
# Display banner\n\
cat <<EOF\n\
╔═══════════════════════════════════════════════════════════════════╗\n\
║                                                                   ║\n\
║            RCCR (ReCyClusteR) Docker Container                   ║\n\
║                  Alpine Linux Cluster Setup                      ║\n\
║                                                                   ║\n\
╚═══════════════════════════════════════════════════════════════════╝\n\
\n\
Working directory: /workspace\n\
Configuration: cluster_config.yml\n\
\n\
EOF\n\
\n\
# If no arguments, show help\n\
if [ $# -eq 0 ]; then\n\
    cat <<HELP\n\
Usage:\n\
  docker run -it -v \${PWD}:/workspace rccr <command>\n\
\n\
Commands:\n\
  init                    - Create cluster_config.yml template\n\
  setup                   - Run full cluster setup\n\
  scan                    - Network scan only\n\
  rotate-keys             - SSH key rotation only\n\
  bash                    - Interactive bash shell\n\
  ansible-playbook <file> - Run specific playbook\n\
\n\
Examples:\n\
  # Initialize configuration\n\
  docker run -it -v \${PWD}:/workspace rccr init\n\
\n\
  # Run full setup\n\
  docker run -it -v \${PWD}:/workspace --network host rccr setup\n\
\n\
  # Network scan only\n\
  docker run -it -v \${PWD}:/workspace --network host rccr scan\n\
\n\
  # Interactive shell\n\
  docker run -it -v \${PWD}:/workspace --network host rccr bash\n\
HELP\n\
    exit 0\n\
fi\n\
\n\
# Process commands\n\
case "$1" in\n\
    init)\n\
        echo "Creating cluster_config.yml template..."\n\
        cp /app/cluster_config.yml /workspace/cluster_config.yml\n\
        echo "✓ Created: /workspace/cluster_config.yml"\n\
        echo ""\n\
        echo "Edit this file and then run: docker run -it -v \${PWD}:/workspace --network host rccr setup"\n\
        ;;\n\
    setup)\n\
        echo "Running full RCCR setup..."\n\
        cd /app\n\
        ansible-playbook setup.playbook\n\
        ;;\n\
    scan)\n\
        echo "Running network scan..."\n\
        cd /app\n\
        ansible-playbook playbooks/01_scan_network.playbook\n\
        ;;\n\
    rotate-keys)\n\
        echo "Running SSH key rotation..."\n\
        cd /app\n\
        ansible-playbook playbooks/02_rotate_ssh_keys.playbook\n\
        ;;\n\
    bash|sh)\n\
        echo "Starting interactive shell..."\n\
        exec /bin/sh\n\
        ;;\n\
    ansible-playbook)\n\
        shift\n\
        cd /app\n\
        exec ansible-playbook "$@"\n\
        ;;\n\
    *)\n\
        echo "Unknown command: $1"\n\
        echo "Run without arguments to see help"\n\
        exit 1\n\
        ;;\n\
esac\n' > /usr/local/bin/rccr-entrypoint.sh && \
    chmod +x /usr/local/bin/rccr-entrypoint.sh

# Set entrypoint
ENTRYPOINT ["/usr/local/bin/rccr-entrypoint.sh"]
CMD []
