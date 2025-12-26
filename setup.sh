#!/bin/bash

# ==================================================================
# RCCR (Recycluster) Setup Script
# ==================================================================

# 루트 권한 확인
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root (or with sudo)." >&2
  exit 1
fi

# 스크립트 디렉토리 경로
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

# ==================================================================
# 1. 종속성 설치
# ==================================================================
echo "==================================================================="
echo "  Step 1: Installing Dependencies"
echo "==================================================================="

# 패키지 관리자 감지 (apt, yum, apk 등)
if command -v apt-get &> /dev/null; then
    echo "Detected: Debian/Ubuntu (apt)"
    apt-get update
    apt-get install -y python3 python3-pip python3-yaml openssh-client sshpass nmap
elif command -v yum &> /dev/null; then
    echo "Detected: RedHat/CentOS (yum)"
    yum install -y python3 python3-pip openssh-clients sshpass nmap
elif command -v apk &> /dev/null; then
    echo "Detected: Alpine Linux (apk)"
    apk update
    apk add --no-cache python3 py3-pip py3-yaml openssh-client sshpass nmap
else
    echo "Warning: Unsupported package manager. Please install dependencies manually."
    echo "Required: python3, pip, openssh-client, sshpass, nmap"
fi

# Python 패키지 설치
echo "Installing Python packages..."
pip3 install --upgrade pip
pip3 install ansible pyyaml

echo "✓ Dependencies installed successfully"
echo ""

# ==================================================================
# 2. RCCR 노드 감지 및 매핑
# ==================================================================
echo "==================================================================="
echo "  Step 2: Node Detection and Mapping"
echo "==================================================================="

# Python 셋업 스크립트 실행
python3 "$SCRIPT_DIR/lib/rccr_setup.py" "$SCRIPT_DIR/cluster_config.yml"

# Python 스크립트 실행 결과 확인
if [ $? -ne 0 ]; then
    echo "Error: Node mapping failed" >&2
    exit 1
fi

echo "✓ Node mapping completed successfully"
echo ""

# ==================================================================
# 3. Ansible 플레이북 실행
# ==================================================================
echo "==================================================================="
echo "  Step 3: Deploying Cluster with Ansible"
echo "==================================================================="

# 인벤토리 파일 확인
INVENTORY_PATH="$SCRIPT_DIR/inventory.yml"
if [ ! -f "$INVENTORY_PATH" ]; then
    echo "Error: inventory.yml not found. Node mapping may have failed." >&2
    exit 1
fi

# 동적 플레이북 생성 및 실행
DEPLOY_PLAYBOOK="$SCRIPT_DIR/deploy_cluster.playbook"

# 플레이북이 존재하면 실행
if [ -f "$DEPLOY_PLAYBOOK" ]; then
    echo "Running deployment playbook..."
    ansible-playbook -i "$INVENTORY_PATH" "$DEPLOY_PLAYBOOK"

    if [ $? -ne 0 ]; then
        echo "Warning: Deployment playbook failed" >&2
    fi
else
    echo "Warning: deploy_cluster.playbook not found. Skipping deployment."
    echo "You can manually run playbooks using:"
    echo "  ansible-playbook -i inventory.yml <your-playbook>.yml"
fi

echo ""

# ==================================================================
# 완료
# ==================================================================
echo "==================================================================="
echo "  ✓ RCCR Setup Complete!"
echo "==================================================================="
echo ""
echo "Generated files:"
echo "  - inventory.yml: Ansible inventory with detected nodes"
echo ""
echo "Next steps:"
echo "  1. Review the inventory file: cat inventory.yml"
echo "  2. Run Ansible playbooks to configure nodes"
echo "  3. Deploy containers to the cluster"
echo ""