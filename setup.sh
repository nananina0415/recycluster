#!/bin/sh

# ==================================================================
# 1. 제어 노드(이 머신) 준비
# ==================================================================
echo "--- Preparing Control Node (this machine) ---"

# 1-1. 루트 권한 확인
#      (패키지를 설치하려면 루트 권한이 필요합니다)
if [ "$(id -u)" -ne 0 ]; then
  echo "This script must be run as root (or with sudo)." >&2
  exit 1
fi

# 1-2. Ansible 종속성 설치 (Python, Pip 등)
#      (Alpine은 매우 가벼워서 기본적으로 Python이 없습니다)
echo "Installing Python3, Pip, and SSH tools..."
apk update
apk add --no-cache python3 py3-pip openssh-client sshpass

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
#      (이 스크립트가 있는 '같은 폴더'를 기준으로 합니다)
SCRIPT_DIR=$(dirname "$0")
PLAYBOOK_PATH="$SCRIPT_DIR/main_playbook.yml"

# 2-2. 플레이북 파일이 있는지 확인
if [ ! -f "$PLAYBOOK_PATH" ]; then
    echo "Error: main_playbook.yml not found in $SCRIPT_DIR" >&2
    exit 1
fi

# 2-3. 메인 플레이북 실행
#      (이 플레이북이 대화형으로 다른 노드를 스캔하고
#       부트스트랩(raw 모듈)하는 작업을 수행할 것입니다)
ansible-playbook "$PLAYBOOK_PATH"

echo "--- Setup Script Finished ---"