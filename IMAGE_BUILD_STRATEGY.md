# RCCR 이미지 빌드 전략 (Alpine-Make-ISO 기반)

## 🎯 핵심 원칙

1. **alpine-make-iso 사용** - Alpine 공식 ISO 빌드 도구 활용
2. **Ansible 중심 아키텍처** - Python/Shell 스크립트 호출 최소화
3. **단일 설정 파일** - cluster_config.yml만 사용, 동적 생성 금지
4. **사전 구성** - SSH, Python, 임시 키 모두 이미지에 포함

---

## 🏗️ Alpine-Make-ISO 아키텍처

### 디렉토리 구조

```
/home/user/recycluster/
├── image-profiles/                    # alpine-make-iso 프로파일
│   ├── base/                          # 공통 설정
│   │   ├── genapkovl-rccr.sh         # Overlay 생성 스크립트
│   │   ├── packages.txt               # 공통 패키지 목록
│   │   └── repos.txt                  # Alpine 저장소 설정
│   │
│   ├── control/                       # Control 노드 프로파일
│   │   ├── profile.conf               # 빌드 설정
│   │   ├── packages.txt               # Control 전용 패키지
│   │   ├── answerfile                 # setup-alpine 자동 응답
│   │   └── overlay/                   # 사전 구성 파일
│   │       ├── etc/
│   │       │   ├── hostname          # ReCyClusteR-Node
│   │       │   ├── ssh/
│   │       │   │   └── sshd_config
│   │       │   ├── apk/
│   │       │   │   └── world          # 사전 설치 패키지 목록
│   │       │   └── local.d/
│   │       │       └── rccr-init.start  # 부팅 시 실행
│   │       ├── root/
│   │       │   ├── .ssh/
│   │       │   │   ├── id_rsa         # 임시 개인키
│   │       │   │   └── id_rsa.pub     # 임시 공개키
│   │       │   └── rccr/              # RCCR 설치 경로
│   │       │       ├── cluster_config.yml
│   │       │       ├── *.playbook
│   │       │       └── machine_layer/
│   │       └── usr/
│   │           └── local/
│   │               └── bin/
│   │                   └── rccr       # CLI 심링크
│   │
│   └── target/                        # Target 노드 프로파일
│       ├── profile.conf
│       ├── packages.txt
│       ├── answerfile
│       └── overlay/
│           ├── etc/
│           │   ├── hostname          # ReCyClusteR-Node
│           │   ├── ssh/
│           │   │   └── sshd_config
│           │   └── local.d/
│           │       └── ssh-init.start
│           └── root/
│               └── .ssh/
│                   └── authorized_keys  # 임시 공개키
│
├── build/                             # 빌드 출력 디렉토리
│   ├── control/
│   └── target/
│
└── scripts/
    ├── build-all-images.sh            # 모든 이미지 빌드
    └── build-single-image.sh          # 단일 이미지 빌드
```

---

## 📦 alpine-make-iso 프로파일 상세

### 1. Control 노드 프로파일

#### `image-profiles/control/profile.conf`

```bash
profile_control() {
    profile_standard
    kernel_addons="xtables-addons"
    kernel_flavors="lts"

    # 기본 설정
    hostname="ReCyClusteR-Node"
    apks="$apks
        openssh openssh-client openssh-server
        python3 py3-pip py3-yaml
        nmap ansible
        bash curl wget git
        docker docker-compose
        avahi dbus
        "

    # 로컬 APK 저장소 (RCCR 패키지)
    local_apks="base"

    # Overlay 생성
    apkovl="genapkovl-rccr-control.sh"

    # 커널 모듈
    kernel_cmdline="modules=loop,squashfs,sd-mod,usb-storage quiet"
}
```

#### `image-profiles/control/answerfile`

```bash
# setup-alpine 자동 응답 파일
KEYMAPOPTS="us us"
HOSTNAMEOPTS="ReCyClusteR-Node"
INTERFACESOPTS="auto lo
iface lo inet loopback

auto eth0
iface eth0 inet dhcp
    hostname ReCyClusteR-Node
"
DNSOPTS="1.1.1.1 8.8.8.8"
TIMEZONEOPTS="UTC"
PROXYOPTS="none"
APKREPOSOPTS="http://dl-cdn.alpinelinux.org/alpine/v3.19/main http://dl-cdn.alpinelinux.org/alpine/v3.19/community"
SSHDOPTS="-c openssh"
NTPOPTS="-c chrony"
DISKOPTS="none"  # 디스크 설치는 사용자가 선택
```

#### `image-profiles/control/genapkovl-rccr-control.sh`

```bash
#!/bin/sh -e

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

# 호스트명 설정
mkdir -p "$tmp"/etc
echo "$HOSTNAME" > "$tmp"/etc/hostname

# SSH 서버 설정
mkdir -p "$tmp"/etc/ssh
cat > "$tmp"/etc/ssh/sshd_config <<EOF
PermitRootLogin yes
PasswordAuthentication no
PubkeyAuthentication yes
UsePAM yes
X11Forwarding no
PrintMotd yes
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/ssh/sftp-server
EOF

# SSH 임시 키 복사
mkdir -p "$tmp"/root/.ssh
if [ -f /tmp/rccr-ssh/id_rsa ]; then
    cp /tmp/rccr-ssh/id_rsa "$tmp"/root/.ssh/id_rsa
    cp /tmp/rccr-ssh/id_rsa.pub "$tmp"/root/.ssh/id_rsa.pub
    chmod 600 "$tmp"/root/.ssh/id_rsa
    chmod 644 "$tmp"/root/.ssh/id_rsa.pub
fi

# RCCR 파일 복사
mkdir -p "$tmp"/root/rccr
if [ -d /tmp/rccr-files ]; then
    cp -r /tmp/rccr-files/* "$tmp"/root/rccr/
fi

# Ansible 설정
mkdir -p "$tmp"/etc/ansible
cat > "$tmp"/etc/ansible/ansible.cfg <<EOF
[defaults]
inventory = /root/rccr/inventory.yml
host_key_checking = False
timeout = 30
remote_user = root

[privilege_escalation]
become = True
become_method = sudo
become_user = root
become_ask_pass = False

[ssh_connection]
pipelining = True
control_path = /tmp/ansible-ssh-%%h-%%p-%%r
EOF

# 부팅 시 초기화 스크립트
mkdir -p "$tmp"/etc/local.d
cat > "$tmp"/etc/local.d/rccr-init.start <<'EOF'
#!/bin/sh

# Avahi 데몬 시작 (호스트명 광고)
rc-service avahi-daemon start

# SSH 서비스 시작
rc-service sshd start

# Docker 서비스 시작
rc-service docker start

# MOTD 표시
cat <<'MOTD'
╔═══════════════════════════════════════════════════╗
║                                                   ║
║   RCCR (ReCyClusteR) - Control Node              ║
║   Alpine Linux Cluster Manager                   ║
║                                                   ║
╚═══════════════════════════════════════════════════╝

Hostname: ReCyClusteR-Node
Type: Control Node (Cluster Manager)

Quick Start:
  1. cd /root/rccr
  2. ansible-playbook setup.playbook

Available Commands:
  - ansible-playbook: Run cluster configuration
  - nmap: Network scanning
  - docker: Container management

Configuration: /root/rccr/cluster_config.yml
MOTD
EOF
chmod +x "$tmp"/etc/local.d/rccr-init.start

# 서비스 자동 시작 설정
rc_add sshd default
rc_add docker default
rc_add avahi-daemon default
rc_add local default

# APK World (사전 설치 패키지)
mkdir -p "$tmp"/etc/apk
cat > "$tmp"/etc/apk/world <<EOF
openssh
python3
py3-yaml
nmap
ansible
docker
avahi
EOF

# Tar로 압축
tar -c -C "$tmp" etc root | gzip -9n > "$HOSTNAME".apkovl.tar.gz
```

---

### 2. Target 노드 프로파일

#### `image-profiles/target/profile.conf`

```bash
profile_target() {
    profile_standard
    kernel_flavors="lts"

    hostname="ReCyClusteR-Node"
    apks="$apks
        openssh openssh-server
        python3
        bash
        docker docker-compose
        avahi dbus
        "

    apkovl="genapkovl-rccr-target.sh"

    kernel_cmdline="modules=loop,squashfs,sd-mod,usb-storage quiet"
}
```

#### `image-profiles/target/genapkovl-rccr-target.sh`

```bash
#!/bin/sh -e

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

# 호스트명 설정
mkdir -p "$tmp"/etc
echo "$HOSTNAME" > "$tmp"/etc/hostname

# SSH 서버 설정
mkdir -p "$tmp"/etc/ssh
cat > "$tmp"/etc/ssh/sshd_config <<EOF
PermitRootLogin yes
PasswordAuthentication no
PubkeyAuthentication yes
UsePAM yes
X11Forwarding no
PrintMotd yes
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/ssh/sftp-server
EOF

# SSH 임시 공개키 설정
mkdir -p "$tmp"/root/.ssh
if [ -f /tmp/rccr-ssh/id_rsa.pub ]; then
    cp /tmp/rccr-ssh/id_rsa.pub "$tmp"/root/.ssh/authorized_keys
    chmod 600 "$tmp"/root/.ssh/authorized_keys
fi

# 부팅 시 초기화 스크립트
mkdir -p "$tmp"/etc/local.d
cat > "$tmp"/etc/local.d/ssh-init.start <<'EOF'
#!/bin/sh

# Avahi 데몬 시작 (호스트명 광고)
rc-service avahi-daemon start

# SSH 서비스 시작
rc-service sshd start

# Docker 서비스 시작
rc-service docker start

cat <<'MOTD'
╔═══════════════════════════════════════════════════╗
║                                                   ║
║   RCCR (ReCyClusteR) - Target Node               ║
║   Alpine Linux Cluster Worker                    ║
║                                                   ║
╚═══════════════════════════════════════════════════╝

Hostname: ReCyClusteR-Node
Type: Target Node (Worker)

This node is ready to be managed by the Control Node.
Waiting for Ansible configuration...
MOTD
EOF
chmod +x "$tmp"/etc/local.d/ssh-init.start

# 서비스 자동 시작
rc_add sshd default
rc_add docker default
rc_add avahi-daemon default
rc_add local default

# APK World
mkdir -p "$tmp"/etc/apk
cat > "$tmp"/etc/apk/world <<EOF
openssh
python3
docker
avahi
EOF

tar -c -C "$tmp" etc root | gzip -9n > "$HOSTNAME".apkovl.tar.gz
```

---

## 🔄 Ansible 중심 아키텍처 재설계

### 기존 문제점
- ❌ `setup.sh`가 Python 스크립트 호출 (`rccr_setup.py`)
- ❌ Python에서 네트워크 스캔 로직 처리
- ❌ 동적 인벤토리 생성

### 새로운 설계 (Ansible Native)

#### 1. 네트워크 스캔 → Ansible Playbook

**`playbooks/01_scan_network.playbook`**

```yaml
---
- name: Network Scanning and Node Discovery
  hosts: localhost
  gather_facts: yes

  vars_files:
    - ../cluster_config.yml

  tasks:
    - name: Display scan configuration
      ansible.builtin.debug:
        msg: |
          Scanning subnet: {{ network_config.subnet }}
          Looking for hostname: ReCyClusteR*

    - name: Take initial network snapshot
      ansible.builtin.command:
        cmd: nmap -sn -oG - {{ network_config.subnet }}
      register: initial_scan
      changed_when: false

    - name: Parse initial hosts
      ansible.builtin.set_fact:
        initial_hosts: "{{ initial_scan.stdout |
          regex_findall('Host: ([0-9.]+) \\(([^)]+)\\)') }}"

    - name: Display detected machines from config
      ansible.builtin.debug:
        msg: |
          Waiting for machine: {{ item.name }}
          Expected role: {{ item.role }}
          Expected IP: {{ item.ip }}
      loop: "{{ machines }}"

    - name: Wait for user to connect each machine
      ansible.builtin.pause:
        prompt: |

          ═══════════════════════════════════════════════════
          Please connect machine: {{ item.name }}
          Role: {{ item.role }}
          Expected IP: {{ item.ip }}
          ═══════════════════════════════════════════════════

          Power on the machine and press ENTER when ready...
      loop: "{{ machines }}"
      register: user_confirmations

    - name: Scan for new host after confirmation
      ansible.builtin.command:
        cmd: nmap -sn -oG - {{ network_config.subnet }}
      register: new_scan
      changed_when: false
      loop: "{{ machines }}"
      loop_control:
        index_var: machine_index

    - name: Parse and filter new hosts (ReCyClusteR only)
      ansible.builtin.set_fact:
        new_hosts: "{{ new_scan.results |
          map(attribute='stdout') |
          map('regex_findall', 'Host: ([0-9.]+) \\(ReCyClusteR[^)]*\\)') |
          flatten }}"

    - name: Map detected hosts to configured machines
      ansible.builtin.set_fact:
        detected_machines: "{{ detected_machines | default([]) + [item.0 | combine({'detected_ip': item.1.0})] }}"
      loop: "{{ machines | zip(new_hosts) | list }}"
      when: item.1 | length > 0

    - name: Update cluster_config.yml with detected IPs
      ansible.builtin.lineinfile:
        path: ../cluster_config.yml
        regexp: "^(\\s+)detected_ip:.*# {{ item.name }}$"
        line: "\\1detected_ip: {{ item.detected_ip }}  # {{ item.name }}"
        backrefs: yes
      loop: "{{ detected_machines }}"
      when: detected_machines is defined

    - name: Display scan summary
      ansible.builtin.debug:
        msg: |
          ═══════════════════════════════════════════════════
          Network Scan Complete
          ═══════════════════════════════════════════════════
          Detected {{ detected_machines | length }} machines:
          {% for machine in detected_machines %}
          - {{ machine.name }}: {{ machine.detected_ip }} ({{ machine.role }})
          {% endfor %}
```

#### 2. SSH 키 교체 → Ansible Playbook

**`playbooks/02_rotate_ssh_keys.playbook`**

```yaml
---
- name: SSH Key Rotation
  hosts: all
  gather_facts: no

  vars:
    temp_key_path: /root/.ssh/id_rsa_temp
    new_key_path: /root/.ssh/id_rsa_new

  tasks:
    - name: Test initial SSH connection with temp key
      ansible.builtin.wait_for_connection:
        timeout: 30

    - name: Generate new SSH key pair on control node
      delegate_to: localhost
      run_once: yes
      community.crypto.openssh_keypair:
        path: "{{ new_key_path }}"
        type: rsa
        size: 4096
        comment: "rccr-{{ ansible_date_time.epoch }}"
      register: new_keypair

    - name: Read new public key
      delegate_to: localhost
      run_once: yes
      ansible.builtin.slurp:
        src: "{{ new_key_path }}.pub"
      register: new_pubkey

    - name: Deploy new public key to all target nodes
      ansible.builtin.authorized_key:
        user: root
        key: "{{ new_pubkey.content | b64decode }}"
        state: present
        exclusive: no
      when: "'target' in group_names"

    - name: Test connection with new key
      delegate_to: localhost
      ansible.builtin.command:
        cmd: ssh -i {{ new_key_path }} -o StrictHostKeyChecking=no root@{{ ansible_host }} echo "Connection OK"
      register: test_result
      changed_when: false
      when: "'target' in group_names"

    - name: Remove temporary key from authorized_keys
      ansible.builtin.authorized_key:
        user: root
        key: "{{ lookup('file', '/root/.ssh/id_rsa.pub') }}"
        state: absent
      when: "'target' in group_names and test_result is succeeded"

    - name: Replace control node private key
      delegate_to: localhost
      run_once: yes
      ansible.builtin.copy:
        src: "{{ new_key_path }}"
        dest: /root/.ssh/id_rsa
        mode: '0600'
        backup: yes
      when: test_result is succeeded

    - name: Remove temporary key files
      ansible.builtin.file:
        path: "{{ item }}"
        state: absent
      loop:
        - /root/.ssh/id_rsa_temp
        - /root/.ssh/id_rsa_temp.pub
      when: test_result is succeeded

    - name: Display key rotation summary
      delegate_to: localhost
      run_once: yes
      ansible.builtin.debug:
        msg: |
          ═══════════════════════════════════════════════════
          SSH Key Rotation Complete
          ═══════════════════════════════════════════════════
          Old temporary key has been removed.
          New key: {{ new_key_path }}

          All target nodes are now using the new key.
```

#### 3. 마스터 플레이북 (단일 진입점)

**`setup.playbook`**

```yaml
---
# RCCR Master Setup Playbook
# 단일 설정 파일(cluster_config.yml) 기반 전체 프로세스 실행

- name: RCCR Cluster Setup
  hosts: localhost
  gather_facts: yes

  vars_files:
    - cluster_config.yml

  pre_tasks:
    - name: Display RCCR Banner
      ansible.builtin.debug:
        msg: |
          ╔═══════════════════════════════════════════════════╗
          ║                                                   ║
          ║   RCCR (ReCyClusteR) v0.0.2                      ║
          ║   Alpine Linux Cluster Setup                     ║
          ║                                                   ║
          ╚═══════════════════════════════════════════════════╝

          Configuration: cluster_config.yml
          Subnet: {{ network_config.subnet }}
          Machines: {{ machines | length }}

  tasks:
    - name: Validate cluster configuration
      ansible.builtin.assert:
        that:
          - machines is defined
          - machines | length > 0
          - network_config.subnet is defined
        fail_msg: "Invalid cluster_config.yml - check your configuration"

    - name: Phase 1 - Network Scanning and Node Discovery
      ansible.builtin.import_playbook: playbooks/01_scan_network.playbook

    - name: Phase 2 - SSH Key Rotation
      ansible.builtin.import_playbook: playbooks/02_rotate_ssh_keys.playbook

    - name: Phase 3 - Machine Layer Configuration
      ansible.builtin.import_playbook: machine_layer/main.playbook

    - name: Phase 4 - Orchestration Layer (Docker Swarm/K8s)
      ansible.builtin.import_playbook: orchestration_layer/main.playbook
      when: orchestration_layer_enabled | default(false)

    - name: Phase 5 - Container Deployment
      ansible.builtin.import_playbook: container_layer/main.playbook
      when: container_layer_enabled | default(false)

  post_tasks:
    - name: Display completion message
      ansible.builtin.debug:
        msg: |
          ╔═══════════════════════════════════════════════════╗
          ║   ✓ RCCR Cluster Setup Complete!                 ║
          ╚═══════════════════════════════════════════════════╝

          Next steps:
          1. Verify cluster: ansible all -m ping
          2. Check nodes: ansible all -m setup
          3. Deploy services: ansible-playbook container_layer/main.playbook
```

---

## 🛠️ 빌드 자동화 스크립트

### `scripts/build-single-image.sh`

```bash
#!/bin/bash
set -e

ARCH=$1
TYPE=$2  # control 또는 target
VERSION=${3:-0.0.2}

if [ -z "$ARCH" ] || [ -z "$TYPE" ]; then
    echo "Usage: $0 <arch> <control|target> [version]"
    echo "Example: $0 x86_64 control 0.0.2"
    exit 1
fi

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
PROJECT_ROOT="$SCRIPT_DIR/.."
PROFILE_DIR="$PROJECT_ROOT/image-profiles/$TYPE"
OUTPUT_DIR="$PROJECT_ROOT/build/$ARCH-$TYPE"

mkdir -p "$OUTPUT_DIR"

# SSH 키를 임시 디렉토리에 복사
mkdir -p /tmp/rccr-ssh
cp "$PROJECT_ROOT/.rccr/ssh_temp_key" /tmp/rccr-ssh/id_rsa
cp "$PROJECT_ROOT/.rccr/ssh_temp_key.pub" /tmp/rccr-ssh/id_rsa.pub

# RCCR 파일을 임시 디렉토리에 복사
mkdir -p /tmp/rccr-files
cp -r "$PROJECT_ROOT"/*.playbook /tmp/rccr-files/
cp -r "$PROJECT_ROOT"/machine_layer /tmp/rccr-files/
cp -r "$PROJECT_ROOT"/container_layer /tmp/rccr-files/
cp -r "$PROJECT_ROOT"/orchestration_layer /tmp/rccr-files/
cp "$PROJECT_ROOT"/cluster_config.yml /tmp/rccr-files/

# Alpine 버전 설정
ALPINE_VERSION="3.19"

# alpine-make-iso를 Docker로 실행
docker run --rm --privileged \
    -v "$PROFILE_DIR:/profiles" \
    -v "$OUTPUT_DIR:/output" \
    -v /tmp/rccr-ssh:/tmp/rccr-ssh:ro \
    -v /tmp/rccr-files:/tmp/rccr-files:ro \
    --platform "linux/${ARCH}" \
    alpine:${ALPINE_VERSION} /bin/sh -c "
        set -ex

        # alpine-sdk 설치
        apk add --no-cache alpine-sdk build-base apk-tools alpine-conf xorriso squashfs-tools grub

        # alpine-make-iso 다운로드
        git clone --depth 1 https://gitlab.alpinelinux.org/alpine/alpine-make-vm-image.git
        cd alpine-make-vm-image

        # 프로파일 복사
        cp /profiles/profile.conf profiles/rccr-${TYPE}.conf
        cp /profiles/genapkovl-*.sh .
        chmod +x genapkovl-*.sh

        # ISO 빌드
        sh mkimage.sh \
            --tag ${ALPINE_VERSION} \
            --outdir /output \
            --arch ${ARCH} \
            --profile rccr-${TYPE} \
            --repository http://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/main \
            --repository http://dl-cdn.alpinelinux.org/alpine/v${ALPINE_VERSION}/community

        # 결과 파일 이름 변경
        mv /output/alpine-rccr-${TYPE}-*.iso /output/rccr-${VERSION}-${ARCH}-${TYPE}.iso || true
        mv /output/alpine-rccr-${TYPE}-*.img /output/rccr-${VERSION}-${ARCH}-${TYPE}.img || true
    "

# 정리
rm -rf /tmp/rccr-ssh /tmp/rccr-files

echo "✓ Build complete: $OUTPUT_DIR/rccr-${VERSION}-${ARCH}-${TYPE}.*"
```

### `scripts/build-all-images.sh`

```bash
#!/bin/bash
set -e

VERSION=${1:-0.0.2}

ARCHS=("x86" "x86_64" "aarch64" "rpi-aarch64" "armv7" "armhf")
TYPES=("control" "target")

echo "Building all images for version ${VERSION}..."

for ARCH in "${ARCHS[@]}"; do
    for TYPE in "${TYPES[@]}"; do
        echo ""
        echo "═══════════════════════════════════════════════════"
        echo "Building: ${ARCH} - ${TYPE}"
        echo "═══════════════════════════════════════════════════"

        bash "$(dirname "$0")/build-single-image.sh" "$ARCH" "$TYPE" "$VERSION"
    done
done

echo ""
echo "✓ All images built successfully!"
echo "Output directory: $(pwd)/build/"
```

---

## 📋 수정된 cluster_config.yml

```yaml
# RCCR Cluster Configuration (Single Source of Truth)
# 이 파일만 수정하면 모든 플레이북이 자동으로 적용됩니다.

cluster_name: my-rccr-cluster

network_config:
  subnet: "192.168.219.0/24"
  gateway: "192.168.219.1"
  dns: "1.1.1.1 8.8.8.8"
  hostname_filter: "ReCyClusteR"  # 네트워크 스캔 필터

machines:
  - name: rccr-control
    ip: 192.168.219.200
    detected_ip: null  # 자동 감지됨 (Ansible이 업데이트)
    role: manager
    type: control
    containers: []

  - name: rccr-node-1
    ip: 192.168.219.201
    detected_ip: null
    role: worker
    type: target
    containers:
      - storage
      - task_queue

  - name: rccr-node-2
    ip: 192.168.219.202
    detected_ip: null
    role: worker
    type: target
    containers:
      - runnin_gmate

  - name: rccr-node-3
    ip: 192.168.219.203
    detected_ip: null
    role: worker
    type: target
    containers:
      - backup

# 추가 설정 (선택 사항)
orchestration_layer_enabled: false  # Docker Swarm/K8s 사용 여부
container_layer_enabled: false      # 컨테이너 자동 배포 여부

# SSH 설정
ssh_config:
  temp_key_rotation: true           # 임시 키 자동 교체
  new_key_type: rsa
  new_key_size: 4096
```

---

## 🚀 사용 흐름

### 1. 이미지 빌드 (개발자)

```bash
# SSH 임시 키 생성
ssh-keygen -t rsa -b 4096 -f .rccr/ssh_temp_key -N ""

# 모든 이미지 빌드
bash scripts/build-all-images.sh 0.0.2

# 특정 이미지만 빌드
bash scripts/build-single-image.sh x86_64 control 0.0.2
```

### 2. 이미지 사용 (사용자)

```bash
# Control 노드 부팅 (ISO/IMG 플래시)
# 부팅 후 자동으로 ReCyClusteR-Node 호스트명 설정됨

# 로그인 (root, 비밀번호 없음 - SSH 키 인증)
cd /root/rccr

# 클러스터 설정 편집
vi cluster_config.yml

# 전체 셋업 실행 (단일 명령어)
ansible-playbook setup.playbook

# 또는 단계별 실행
ansible-playbook playbooks/01_scan_network.playbook
ansible-playbook playbooks/02_rotate_ssh_keys.playbook
ansible-playbook machine_layer/main.playbook
```

---

## ✅ 핵심 개선사항

| 항목 | 기존 | 개선 |
|------|------|------|
| **Python 스크립트** | setup.sh → Python | 제거 (Ansible만 사용) |
| **네트워크 스캔** | Python (nmap) | Ansible native (nmap 모듈) |
| **설정 파일** | 여러 개 + 동적 생성 | cluster_config.yml 하나만 |
| **SSH 키 관리** | Python 스크립트 | Ansible crypto 모듈 |
| **이미지 빌드** | Dockerfile (런타임) | alpine-make-iso (사전 구성) |
| **호스트명 필터** | Python 로직 | Ansible regex_findall |
| **진입점** | setup.sh → Python | ansible-playbook setup.playbook |

---

## 📦 최종 파일 구조 요약

```
recycluster/
├── .rccr/                            # SSH 임시 키
├── image-profiles/                   # alpine-make-iso 프로파일
│   ├── base/
│   ├── control/                      # Control 노드
│   └── target/                       # Target 노드
├── playbooks/                        # Ansible 플레이북
│   ├── 01_scan_network.playbook
│   └── 02_rotate_ssh_keys.playbook
├── machine_layer/
├── container_layer/
├── orchestration_layer/
├── scripts/
│   ├── build-all-images.sh
│   └── build-single-image.sh
├── cluster_config.yml                # 단일 설정 파일
└── setup.playbook                    # 마스터 플레이북
```

**Python/Shell 스크립트 제거**: `lib/`, `bin/rccr`, `setup.sh` 전부 삭제

---

**작성일**: 2025-12-30
**버전**: 2.0
**핵심**: alpine-make-iso + Ansible Native + 단일 설정
