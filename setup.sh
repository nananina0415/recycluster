#!/bin/sh

# ==================================================================
# 1. 제어 노드(이 머신) 준비
# ==================================================================
echo "--- Preparing Control Node (this machine) ---"

# 1-1. 루트 권한 확인
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root (or with sudo)." >&2
  exit 1
fi

# 1-2. Ansible 종속성 설치 (Python, Nmap 등)
echo "Installing Python3, Pip, SSH tools, and Nmap..."
apk update
apk add --no-cache python3 py3-pip openssh-client sshpass nmap

# 1-3. Ansible 설치
echo "Installing Ansible via pip..."
pip3 install ansible

echo "Ansible installation complete."
ansible --version


# ==================================================================
# 2. 메인 플레이북 실행
# ==================================================================
echo "--- Executing Main Playbook ---"

# 2-1. 플레이북 경로 찾기
SCRIPT_DIR=$(dirname "$0")
PLAYBOOK_PATH="$SCRIPT_DIR/main_playbook.yml"

# 2-2. 플레이북 파일이 있는지 확인
if [ ! -f "$PLAYBOOK_PATH" ]; then
    echo "Error: main_playbook.yml not found in $SCRIPT_DIR" >&2
    exit 1
fi

# 2-3. 메인 플레이북 실행
#      (플레이북 자체가 localhost를 대상으로 하므로 -i 플래그가 필요 없습니다.)
ansible-playbook "$PLAYBOOK_PATH"

echo "--- Setup Script Finished ---"