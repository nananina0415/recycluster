#!/bin/sh
set -e

# RCCR Node Mapper - Interactive node role assignment
# Maps discovered hosts to control/target roles and generates inventory

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# ===================================================================
# Configuration
# ===================================================================

DISCOVERED_HOSTS="${1:-/tmp/rccr-discovered-hosts.txt}"
CLUSTER_CONFIG="$PROJECT_DIR/cluster_config.yml"

# ===================================================================
# Functions
# ===================================================================

log() {
    echo "[$(date +'%H:%M:%S')] $*"
}

# Interactive host mapping
map_nodes() {
    local hosts="$1"
    local control_nodes=""
    local target_nodes=""

    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║                    Interactive Node Mapping                       ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo ""
    echo "For each host, specify its role:"
    echo "  [c] Control Node (cluster manager)"
    echo "  [t] Target Node (worker)"
    echo "  [s] Skip (ignore this host)"
    echo ""

    i=1
    echo "$hosts" | while read -r host; do
        if [ -z "$host" ]; then
            continue
        fi

        echo "───────────────────────────────────────────────────────────────────"
        echo "Host #$i: $host"
        echo ""

        # Get hostname if possible
        HOSTNAME=$(timeout 2 ssh -o ConnectTimeout=1 -o StrictHostKeyChecking=no root@"$host" hostname 2>/dev/null || echo "unknown")
        if [ "$HOSTNAME" != "unknown" ]; then
            echo "  Detected hostname: $HOSTNAME"
        fi

        while true; do
            printf "  Role [c/t/s]: "
            read -r role

            case "$role" in
                c|C)
                    echo "  → Control Node"
                    echo "$host" >> /tmp/rccr-control-nodes.txt
                    break
                    ;;
                t|T)
                    echo "  → Target Node"
                    echo "$host" >> /tmp/rccr-target-nodes.txt
                    break
                    ;;
                s|S)
                    echo "  → Skipped"
                    break
                    ;;
                *)
                    echo "  Invalid input. Please enter c, t, or s."
                    ;;
            esac
        done

        echo ""
        i=$((i + 1))
    done
}

# Generate cluster config
generate_cluster_config() {
    local control_file="/tmp/rccr-control-nodes.txt"
    local target_file="/tmp/rccr-target-nodes.txt"

    echo ""
    log "Generating cluster configuration..."

    # Start cluster config
    cat > "$CLUSTER_CONFIG" <<'EOF'
# RCCR Cluster Configuration
# This is the ONLY configuration file for the cluster

cluster:
  name: rccr-cluster

ssh:
  user: root
  private_key: ~/.ssh/id_rsa
  options: -o StrictHostKeyChecking=no

nodes:
EOF

    # Add control nodes
    if [ -f "$control_file" ] && [ -s "$control_file" ]; then
        i=1
        while read -r host; do
            [ -z "$host" ] && continue
            cat >> "$CLUSTER_CONFIG" <<EOF
  - ip: $host
    hostname: control-node-$i
    role: control
EOF
            i=$((i + 1))
        done < "$control_file"
    fi

    # Add target nodes
    if [ -f "$target_file" ] && [ -s "$target_file" ]; then
        i=1
        while read -r host; do
            [ -z "$host" ] && continue
            cat >> "$CLUSTER_CONFIG" <<EOF
  - ip: $host
    hostname: target-node-$i
    role: target
EOF
            i=$((i + 1))
        done < "$target_file"
    fi

    # Cleanup temp files
    rm -f "$control_file" "$target_file"

    log "Cluster config generated: $CLUSTER_CONFIG"
}

# Display summary
display_summary() {
    echo ""
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║                       Mapping Complete                            ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo ""

    if [ -f "$CLUSTER_CONFIG" ]; then
        echo "Cluster configuration:"
        echo "───────────────────────────────────────────────────────────────────"
        cat "$CLUSTER_CONFIG"
        echo "───────────────────────────────────────────────────────────────────"
    fi

    echo ""
    echo "Next steps:"
    echo "  1. Review config: cat $CLUSTER_CONFIG"
    echo "  2. Install Python on targets: ansible-playbook playbooks/install-python.yml"
    echo "  3. Run setup: ansible-playbook playbooks/setup.yml"
    echo ""
}

# ===================================================================
# Main
# ===================================================================

echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║                      RCCR Node Mapper                              ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

# Check if discovered hosts file exists
if [ ! -f "$DISCOVERED_HOSTS" ]; then
    log "ERROR: Discovered hosts file not found: $DISCOVERED_HOSTS"
    log "Please run network_scan.sh first"
    exit 1
fi

HOSTS=$(cat "$DISCOVERED_HOSTS")
if [ -z "$HOSTS" ]; then
    log "ERROR: No hosts found in $DISCOVERED_HOSTS"
    exit 1
fi

HOST_COUNT=$(echo "$HOSTS" | grep -c '.' || echo 0)
log "Found $HOST_COUNT host(s) to map"
echo ""

# Clear temp files
rm -f /tmp/rccr-control-nodes.txt /tmp/rccr-target-nodes.txt

# Interactive mapping
map_nodes "$HOSTS"

# Generate cluster config
generate_cluster_config

# Display summary
display_summary
