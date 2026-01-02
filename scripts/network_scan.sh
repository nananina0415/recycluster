#!/bin/sh
set -e

# RCCR Network Scanner - ARP-based host discovery
# Finds SSH-enabled hosts on the local network without additional packages

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# ===================================================================
# Configuration
# ===================================================================

SSH_PORT=22
SSH_TIMEOUT=2
MAX_PARALLEL=10
OUTPUT_FILE="${1:-/tmp/rccr-discovered-hosts.txt}"

# ===================================================================
# Functions
# ===================================================================

log() {
    echo "[$(date +'%H:%M:%S')] $*"
}

# Get current subnet
get_subnet() {
    ip -4 addr show | grep 'inet ' | grep -v '127.0.0.1' | head -1 | awk '{print $2}'
}

# Get active hosts from ARP cache
get_arp_hosts() {
    # Ping broadcast to populate ARP cache
    SUBNET=$(get_subnet)
    BROADCAST=$(echo "$SUBNET" | cut -d'/' -f1 | awk -F. '{print $1"."$2"."$3".255"}')

    log "Pinging broadcast address to populate ARP cache..."
    ping -c 3 -b "$BROADCAST" >/dev/null 2>&1 || true

    # Get hosts from ARP cache
    ip neigh show | awk '/REACHABLE|STALE|DELAY/ {print $1}' | sort -V
}

# Check if SSH is running on a host
check_ssh() {
    local host="$1"

    # Try to connect to SSH port
    if timeout "$SSH_TIMEOUT" sh -c "echo > /dev/tcp/$host/$SSH_PORT" 2>/dev/null; then
        return 0
    else
        return 1
    fi
}

# Parallel SSH check
check_ssh_parallel() {
    local host="$1"
    if check_ssh "$host"; then
        echo "$host"
    fi
}

# ===================================================================
# Main
# ===================================================================

echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║              RCCR Network Scanner (ARP-based)                     ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""

SUBNET=$(get_subnet)
log "Current network: $SUBNET"
echo ""

log "Step 1: Discovering active hosts via ARP..."
HOSTS=$(get_arp_hosts)
HOST_COUNT=$(echo "$HOSTS" | wc -l)
log "Found $HOST_COUNT active host(s) on network"
echo ""

if [ -z "$HOSTS" ] || [ "$HOST_COUNT" -eq 0 ]; then
    log "ERROR: No hosts found on network"
    log "Please ensure other machines are powered on and connected"
    exit 1
fi

log "Active hosts:"
echo "$HOSTS" | while read -r host; do
    echo "  - $host"
done
echo ""

log "Step 2: Checking for SSH servers (port $SSH_PORT)..."
echo ""

# Clear output file
> "$OUTPUT_FILE"

# Check SSH on each host in parallel
PIDS=""
for host in $HOSTS; do
    # Skip if too many parallel jobs
    while [ $(jobs -r | wc -l) -ge $MAX_PARALLEL ]; do
        sleep 0.1
    done

    (check_ssh_parallel "$host" >> "$OUTPUT_FILE") &
    PIDS="$PIDS $!"
done

# Wait for all checks to complete
wait $PIDS

# Read results
SSH_HOSTS=$(cat "$OUTPUT_FILE" | sort -V)
SSH_COUNT=$(echo "$SSH_HOSTS" | grep -c '.' || echo 0)

echo ""
log "SSH scan complete"
echo ""

if [ "$SSH_COUNT" -eq 0 ]; then
    log "ERROR: No SSH servers found"
    log "Please ensure SSH is running on target machines"
    exit 1
fi

echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║                    Discovered SSH Hosts                           ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo ""
log "Found $SSH_COUNT SSH-enabled host(s):"
echo ""

i=1
echo "$SSH_HOSTS" | while read -r host; do
    echo "  [$i] $host"
    i=$((i + 1))
done

echo ""
log "Results saved to: $OUTPUT_FILE"
echo ""
echo "Next steps:"
echo "  1. Run node mapper: ./scripts/node_mapper.sh"
echo "  2. Or manually edit: $OUTPUT_FILE"
echo ""
