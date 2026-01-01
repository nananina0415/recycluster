# RCCR (ReCyClusteR) v0.0.4

> Alpine Linux 기반 클러스터 자동 셋업 도구

네트워크상의 머신을 자동으로 감지하고 클러스터로 구성하는 **즉시 사용 가능한 OS 이미지**를 제공합니다.

## ✨ 특징

- 🚀 **즉시 부팅 가능**: ISO(x86/x86_64) / IMG(ARM/Raspberry Pi) 파일을 플래시하여 바로 사용
- 🔍 **자동 호스트 감지**: `ReCyClusteR` 호스트명 기반 자동 필터링
- 🤖 **Ansible 100%**: Python 스크립트 없이 순수 Ansible 플레이북
- 🔐 **이중 보안**: 원격 접속(비밀번호) + 노드 간 통신(SSH 키)
- 📦 **최소 의존성**: 외부 라이브러리 없이 Alpine 기본 도구만 사용
- 🎯 **단일 설정 파일**: `cluster_config.yml` 하나로 모든 설정 관리
- 💻 **Windows 친화적**: PowerShell/PuTTY로 간편한 원격 접속

## 🎯 사용 사례

- 홈랩 클러스터 구축
- Raspberry Pi 클러스터 셋업
- Alpine Linux 기반 경량 클러스터
- Docker Swarm/Kubernetes 기반 인프라

---

## 📦 설치

### 방법 1: OS 이미지 다운로드 (권장)

즉시 부팅 가능한 이미지를 다운로드하여 SD 카드/USB에 플래시합니다.

#### 1.1. 이미지 다운로드

**[GitHub Releases](https://github.com/nananina0415/recycluster/releases)** 에서 다운로드:

| 노드 타입 | 설명 | 사전 설치 패키지 |
|----------|------|------|
| **Control** | 클러스터 관리 노드 | Ansible, Docker, SSH |
| **Target** | 워커 노드 | Docker, SSH |

| 아키텍처 | 파일 형식 | 설명 | 예시 |
|---------|---------|------|------|
| `x86_64` | ISO | 64-bit x86 | 현대 PC, 서버 |
| `x86` | ISO | 32-bit x86 | 구형 PC |
| `aarch64` | ISO | 64-bit ARM | 일반 ARM64 서버 (non-RPi) |
| `rpi-aarch64` | IMG.GZ | 라즈베리파이용 ARM64 | Raspberry Pi 3/4/5 전용 |
| `armv7` | IMG.GZ | 32-bit ARMv7 | Raspberry Pi 2/3 |
| `armhf` | IMG.GZ | 32-bit ARM | Raspberry Pi 1/Zero |

```bash
# Control 노드 (x86_64 예시 - ISO 형식)
wget https://github.com/nananina0415/recycluster/releases/latest/download/rccr-0.0.4-x86_64-control.iso

# Target 노드 (Raspberry Pi 예시 - IMG.GZ 형식)
wget https://github.com/nananina0415/recycluster/releases/latest/download/rccr-0.0.4-rpi-aarch64-target.img.gz
```

#### 1.2. 체크섬 검증

```bash
# SHA256 체크섬 다운로드
wget https://github.com/nananina0415/recycluster/releases/latest/download/SHA256SUMS

# 검증
sha256sum -c SHA256SUMS
```

#### 1.3. 부팅 미디어 생성

**Linux/Mac:**
```bash
# USB/SD 카드 확인
lsblk

# x86/x86_64: ISO 플래시
sudo dd if=rccr-0.0.4-x86_64-control.iso of=/dev/sdX bs=4M status=progress

# Raspberry Pi: IMG.GZ 압축 해제 후 플래시
gunzip -c rccr-0.0.4-rpi-aarch64-control.img.gz | sudo dd of=/dev/sdX bs=4M status=progress

sync
```

**Windows:**
- [Rufus](https://rufus.ie/) 또는 [Etcher](https://www.balena.io/etcher/) 사용
- ISO 파일: 직접 선택 후 플래시
- IMG.GZ 파일: 압축 해제 후 IMG 파일 플래시 (또는 Etcher가 자동 처리)

#### 1.4. 부팅

1. SD 카드/USB를 머신에 삽입
2. 전원 켜기
3. 자동으로 Alpine Linux 부팅

**기본 설정:**
- **호스트명**: `ReCyClusteR-Node` (모든 노드 공통)
- **사용자**: `root`
- **노드 간 통신**: SSH 키 (자동 생성 및 교체)
- **원격 접속**: 비밀번호 (첫 부팅 시 설정)

#### 1.5. 첫 부팅 시 비밀번호 설정

Control 노드를 처음 부팅하면 원격 접속용 비밀번호를 설정하라는 메시지가 표시됩니다:

```
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║               RCCR (ReCyClusteR) - First Boot Setup              ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝

Welcome to RCCR Control Node!

For remote access from Windows/other computers, please set a root password.
Node-to-node communication will use SSH keys automatically.

Please set root password for remote SSH access:
New password:
```

비밀번호를 설정하면 IP 주소와 SSH 접속 정보가 표시됩니다.

---

## 💻 Windows에서 원격 접속

Control 노드에 Windows에서 SSH로 접속할 수 있습니다.

### 자동 접속 스크립트 (권장)

**가장 쉬운 방법**: Control 노드를 자동으로 찾아서 접속하는 스크립트

**1. 스크립트 다운로드:**
```powershell
# Git 저장소를 클론했다면
cd recycluster

# 또는 직접 다운로드
# https://github.com/nananina0415/recycluster/blob/main/windows-connect.ps1
# https://github.com/nananina0415/recycluster/blob/main/windows-connect.bat
```

**2. 실행:**
```powershell
# Option A: PowerShell 스크립트
.\windows-connect.ps1

# Option B: 더블클릭
# windows-connect.bat 파일을 더블클릭

# 다른 네트워크 대역 사용 시
.\windows-connect.ps1 -Subnet "192.168.0"
```

**동작:**
```
[1/3] Scanning network 192.168.1.0/24 for active hosts...
      ✓ Found: 192.168.1.100

[2/3] Checking hostnames via SSH...
      Trying 192.168.1.100... hostname: ReCyClusteR-Node
      ✓ Match found!

[3/3] Connecting to Control node...

╔═══════════════════════════════════════════════════════════════════╗
║  Control Node Found!                                             ║
║  IP Address: 192.168.1.100                                       ║
╚═══════════════════════════════════════════════════════════════════╝

Connecting...
```

---

### 수동 접속 (IP 주소를 알 때)

#### PowerShell/Windows Terminal 사용

```powershell
# SSH 접속 (Control 노드의 IP 주소 확인 후)
ssh root@192.168.1.100

# 비밀번호 입력
```

#### PuTTY 사용

1. [PuTTY](https://www.putty.org/) 다운로드 및 설치
2. Host Name: `192.168.1.100` (Control 노드 IP)
3. Port: `22`
4. Connection type: `SSH`
5. Open 클릭
6. 사용자명: `root`
7. 비밀번호 입력

**Tip**: Control 노드에 로그인하면 화면에 현재 IP 주소가 표시됩니다.

---

## 🚀 빠른 시작

### Control 노드에서 실행

#### 1. Control 노드 접속

Control 노드 이미지로 부팅한 후 접속:

```bash
# Windows/Linux/Mac에서 SSH로 접속
ssh root@<control-node-ip>

# 또는 직접 콘솔 로그인
```

첫 부팅 시 설정한 비밀번호를 입력합니다.

#### 2. 설정 파일 편집

```bash
cd /root/rccr
vi cluster_config.yml
```

**예시 설정:**

```yaml
cluster_name: my-cluster

network_config:
  subnet: "192.168.1.0/24"
  gateway: "192.168.1.1"
  dns: "1.1.1.1 8.8.8.8"
  hostname_filter: "ReCyClusteR"  # 이 호스트명 패턴만 감지

machines:
  - name: rccr-control
    ip: 192.168.1.200
    detected_ip: null  # 자동 업데이트됨
    role: manager
    type: control
    containers: []

  - name: rccr-node-1
    ip: 192.168.1.201
    detected_ip: null
    role: worker
    type: target
    containers:
      - nginx
      - redis

  - name: rccr-node-2
    ip: 192.168.1.202
    detected_ip: null
    role: worker
    type: target
    containers:
      - postgres
```

#### 3. 클러스터 셋업 실행

```bash
cd /root/rccr
ansible-playbook setup.playbook
```

**진행 과정:**

```
╔═══════════════════════════════════════════════════════════════════╗
║            RCCR (ReCyClusteR) Cluster Setup v0.0.4               ║
║                  Alpine Linux Cluster Manager                    ║
╚═══════════════════════════════════════════════════════════════════╝

Phase 1: Network Scanning
═══════════════════════════════════════════════════════════════════

Machine 1/3
═══════════════════════════════════════════════════════════════════
Name: rccr-node-1
Role: worker
Expected IP: 192.168.1.201

Please:
1. Power on the machine
2. Wait for it to boot
3. Press ENTER when ready to scan...

[Enter를 누르면 네트워크 스캔]

✓ Host detected!
IP: 192.168.1.201
Hostname: ReCyClusteR-Node
Mapping to: rccr-node-1
```

**자동으로 수행되는 작업:**
1. 🔍 네트워크 스캔 (호스트명 `ReCyClusteR*` 필터링)
2. 🗺️ 감지된 호스트와 설정 노드 매핑
3. 🔐 SSH 키 교체 (임시 키 → 새 키)
4. ⚙️ 머신 레이어 구성 (호스트명, 네트워크)
5. 🐳 Docker 설치 및 컨테이너 배포

#### 4. 완료 확인

```bash
# 모든 노드 연결 확인
ansible all -m ping

# 노드 정보 확인
ansible all -m setup

# Docker 컨테이너 확인
ansible all -a "docker ps"
```

---

## 🐳 Docker 사용 (개발/테스트)

Docker 환경에서도 동일하게 사용 가능:

```bash
# 1. 설정 파일 템플릿 생성
docker run -it -v ${PWD}:/workspace rccr init

# 2. 설정 편집
vi cluster_config.yml

# 3. 전체 셋업 실행
docker run -it -v ${PWD}:/workspace --network host rccr setup

# 4. 네트워크 스캔만 실행
docker run -it -v ${PWD}:/workspace --network host rccr scan

# 5. SSH 키 교체만 실행
docker run -it -v ${PWD}:/workspace --network host rccr rotate-keys

# 6. 대화형 셸
docker run -it -v ${PWD}:/workspace --network host rccr bash
```

---

## 📖 주요 개념

### Control 노드 vs Target 노드

| 구분 | Control | Target |
|------|---------|--------|
| **역할** | 클러스터 관리 | 워커 |
| **호스트명** | `ReCyClusteR-Node` | `ReCyClusteR-Node` |
| **사전 설치** | Ansible, Docker, Python3 | Docker, Python3 |
| **SSH 인증** | 키(노드간) + 비밀번호(원격) | 키(노드간) |
| **용도** | 셋업 실행, 관리 | 컨테이너 실행 |

### 호스트명 필터링

네트워크 스캔 시 `ReCyClusteR-Node` 호스트명을 가진 머신만 감지합니다.
이렇게 하면 네트워크상의 다른 머신들은 무시됩니다.

### SSH 키 자동 교체

1. **초기 상태**: 이미지에 임시 SSH 키 포함
2. **첫 연결**: 임시 키로 Target 노드 접속
3. **자동 교체**: `ansible-playbook setup.playbook` 실행 시
   - 새 SSH 키쌍 생성 (4096-bit RSA)
   - 모든 노드에 배포
   - 임시 키 제거
4. **완료**: 새 키로만 접속 가능

---

## 📁 프로젝트 구조

```
recycluster/
├── image-profiles/              # alpine-make-iso 프로파일
│   ├── control/                 # Control 노드 이미지 설정
│   │   ├── profile.conf
│   │   ├── answerfile
│   │   └── genapkovl-*.sh      # Overlay 생성 스크립트
│   └── target/                  # Target 노드 이미지 설정
│       ├── profile.conf
│       ├── answerfile
│       └── genapkovl-*.sh
│
├── playbooks/                   # Ansible 플레이북
│   ├── 01_scan_network.playbook
│   └── 02_rotate_ssh_keys.playbook
│
├── machine_layer/               # 머신 레이어 플레이북
├── container_layer/             # 컨테이너 레이어 플레이북
├── orchestration_layer/         # 오케스트레이션 레이어 플레이북
│
├── scripts/                     # 빌드 스크립트
│   ├── build-single-image.sh
│   └── build-all-images.sh
│
├── templates/                   # Ansible 템플릿
│   └── inventory.yml.j2
│
├── cluster_config.yml           # 클러스터 설정 (단일 소스)
├── setup.playbook               # 마스터 플레이북
└── Dockerfile                   # Docker 이미지
```

---

## 🔧 고급 사용법

### 특정 Phase만 실행

```bash
# Phase 1: 네트워크 스캔만
ansible-playbook playbooks/01_scan_network.playbook

# Phase 2: SSH 키 교체만
ansible-playbook playbooks/02_rotate_ssh_keys.playbook

# Phase 3: 머신 레이어만
ansible-playbook machine_layer/main.playbook
```

### 수동 Ansible 실행

```bash
# 모든 노드에 명령 실행
ansible all -m shell -a "uptime"

# 특정 그룹만
ansible workers -m shell -a "docker ps"

# 팩트 수집
ansible all -m setup
```

### 커스텀 플레이북

```yaml
# custom.playbook
---
- name: Custom Configuration
  hosts: all
  vars_files:
    - cluster_config.yml

  tasks:
    - name: Install custom package
      ansible.builtin.apk:
        name: htop
        state: present
```

```bash
ansible-playbook custom.playbook
```

---

## 🏗️ 이미지 빌드 (개발자용)

### 로컬 빌드

```bash
# 단일 이미지 빌드
bash scripts/build-single-image.sh x86_64 control 0.0.4

# 모든 이미지 빌드 (24개)
bash scripts/build-all-images.sh 0.0.4
```

**요구사항:**
- Docker (QEMU 지원)
- 인터넷 연결
- 충분한 디스크 공간 (~2GB per image)

### CI/CD

GitHub Actions가 자동으로 이미지를 빌드합니다:

1. 태그 푸시: `git tag v0.0.4 && git push --tags`
2. GitHub Actions 실행
3. 12개 OS 이미지 생성 (6 아키텍처 × 2 타입)
4. GitHub Release 자동 생성

---

## ❓ 문제 해결

### 1. 네트워크 스캔이 작동하지 않음

**증상:** `nmap` 스캔에서 호스트를 찾지 못함

**해결:**
```bash
# 방화벽 확인
iptables -L

# 서브넷 확인
ip addr show

# 수동 스캔 테스트
nmap -sn 192.168.1.0/24
```

### 2. SSH 연결 실패

**증상:** Ansible이 Target 노드에 연결하지 못함

**해결:**
```bash
# SSH 서비스 확인 (Target 노드)
rc-service sshd status
rc-service sshd start

# 수동 연결 테스트 (Control 노드)
ssh -i /root/.ssh/id_rsa root@<target-ip>

# 키 권한 확인
chmod 600 /root/.ssh/id_rsa
chmod 644 /root/.ssh/id_rsa.pub
```

### 3. 호스트명이 감지되지 않음

**증상:** 네트워크 스캔에서 `ReCyClusteR` 호스트가 안 보임

**해결:**
```bash
# 호스트명 확인
hostname
cat /etc/hostname

# 호스트명 수동 설정
echo "ReCyClusteR-Node" > /etc/hostname
hostname -F /etc/hostname

# SSH 재시작
rc-service sshd restart
```

### 4. Docker 컨테이너가 시작되지 않음

**증상:** Ansible이 컨테이너를 배포했지만 실행 안 됨

**해결:**
```bash
# Docker 서비스 확인
rc-service docker status
rc-service docker start

# 로그 확인
docker logs <container-name>

# 수동 실행 테스트
docker run -d --name test nginx:alpine
```

---

## 📚 추가 문서

- **[IMAGE_BUILD_STRATEGY.md](IMAGE_BUILD_STRATEGY.md)** - alpine-make-iso 빌드 전략
- **[MIGRATION_PLAN.md](MIGRATION_PLAN.md)** - APK → OS 이미지 마이그레이션 계획
- **[DISTRIBUTION.md](DISTRIBUTION.md)** - 배포 전략 및 방법

---

## 🤝 기여

이슈와 풀 리퀘스트를 환영합니다!

**개발 환경:**
```bash
git clone https://github.com/nananina0415/recycluster.git
cd recycluster

# 문법 체크
bash -n scripts/*.sh
python3 -c "import yaml; yaml.safe_load(open('cluster_config.yml'))"

# 로컬 빌드 테스트
bash scripts/build-single-image.sh x86_64 control 0.0.4
```

---

## 📄 라이선스

MIT License - 자유롭게 사용, 수정, 배포 가능

---

## 👤 작성자

**nananina0415**

- GitHub: [@nananina0415](https://github.com/nananina0415)
- Repository: [recycluster](https://github.com/nananina0415/recycluster)

---

## 🌟 Star History

프로젝트가 유용하다면 ⭐ Star를 눌러주세요!

---

**버전**: 0.0.4
**마지막 업데이트**: 2025-12-30
**Alpine Linux**: 3.19
**Ansible**: 최신
