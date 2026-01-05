# RCCR (ReCyClusteR) v0.0.1

> Alpine Linux 기반 클러스터 자동 셋업 도구

Alpine 공식 이미지 기반으로 네트워크 스캔부터 클러스터 구성까지 자동화하는 **즉시 사용 가능한 OS 이미지**를 제공합니다.

## ✨ 특징

- 🚀 **Alpine 공식 이미지 기반**: mkimage 없이 Alpine 공식 IMG/ISO 직접 사용
- 🔍 **ARP 기반 네트워크 스캔**: nmap 불필요, SSH 병렬 체크로 빠른 감지
- 🤖 **순수 Ansible**: Python 스크립트 없이 100% Ansible 플레이북
- 🎯 **단일 설정 파일**: `cluster_config.yml` 하나로 모든 설정 관리
- ⚡ **빠른 부팅**: DHCP 자동 활성화, 3초 이내 SSH 준비
- 🔐 **이중 보안**: 원격 접속(비밀번호) + 노드 간 통신(SSH 키)
- 💻 **다양한 아키텍처**: x86/x86_64/aarch64 지원

## 🎯 사용 사례

- 홈랩 클러스터 구축
- Raspberry Pi 클러스터 셋업
- Alpine Linux 기반 경량 클러스터
- 테스트 환경 빠른 배포

---

## 🏗️ 아키텍처

### 이미지 타입

| 노드 타입 | 사전 설치 패키지 | 용도 |
|----------|----------------|------|
| **Control** | openssh, python3, py3-yaml, ansible, sudo | 클러스터 관리 노드 |
| **Target** | openssh, sudo | 워커 노드 (Python은 Ansible이 설치) |

### 부팅 프로세스

```
부팅 → DHCP 네트워크 활성화 (자동) → Hostname 설정 → SSH 시작 → 완료
                 ↓ 10초 이내
            네트워크 준비 완료
```

### 셋업 워크플로우

```
1. Network Scan (ARP + SSH)
   ↓
2. Node Mapping (cluster_config.yml 생성)
   ↓
3. Python Installation (Ansible raw mode)
   ↓
4. Cluster Setup (Ansible playbooks)
```

---

## 📦 빌드

### 요구사항

- Alpine Linux 또는 Docker
- `genisoimage` (x86 ISO)
- `xorriso` (aarch64 ISO)

### 단일 이미지 빌드

```bash
# x86_64 Control Node (ISO)
bash scripts/build-x86-from-official.sh x86_64 control

# x86_64 Target Node (ISO)
bash scripts/build-x86-from-official.sh x86_64 target

# Raspberry Pi Control Node (IMG)
bash scripts/build-rpi-from-official.sh aarch64 control

# Raspberry Pi Target Node (IMG)
bash scripts/build-rpi-from-official.sh aarch64 target
```

### 빌드 출력

```
build/
├── rccr-x86_64-control.iso         # x86_64 Control ISO
├── rccr-x86_64-target.iso          # x86_64 Target ISO
├── rccr-aarch64-control.img.gz     # Raspberry Pi Control IMG
└── rccr-aarch64-target.img.gz      # Raspberry Pi Target IMG
```

---

## 💻 이미지 플래시

### Linux/Mac

```bash
# USB/SD 카드 확인
lsblk

# x86/x86_64: ISO 플래시
sudo dd if=build/rccr-x86_64-control.iso of=/dev/sdX bs=4M status=progress

# Raspberry Pi: IMG.GZ 압축 해제 후 플래시
gunzip -c build/rccr-aarch64-control.img.gz | sudo dd of=/dev/sdX bs=4M status=progress

sync
```

### Windows

- [Rufus](https://rufus.ie/) 또는 [Etcher](https://www.balena.io/etcher/) 사용
- ISO 파일: 직접 선택 후 플래시
- IMG.GZ 파일: Etcher가 자동 처리

---

## 🚀 빠른 시작

### 1. 이미지 플래시 및 부팅

1. Control 노드와 Target 노드 각각 이미지 플래시
2. 네트워크에 연결 (DHCP 자동 설정)
3. 부팅 (3초 이내 SSH 준비)

### 2. Control 노드 첫 부팅

Control 노드를 처음 부팅하면 루트 비밀번호 설정 화면이 나타납니다:

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

비밀번호 설정 후 IP 주소가 표시됩니다.

### 3. Control 노드 접속

```bash
# Windows/Linux/Mac에서 SSH로 접속
ssh root@<control-node-ip>
```

### 4. 네트워크 스캔

```bash
cd /root/rccr/scripts
./network_scan.sh
```

**출력:**
```
╔══════════════════════════════════════════════════════════════════╗
║         RCCR Network Scanner - ARP-based Host Discovery         ║
╚══════════════════════════════════════════════════════════════════╝

[1/3] Getting network configuration...
      Subnet: 192.168.1.0/24

[2/3] Scanning for active hosts...
      ✓ Populated ARP cache

[3/3] Checking SSH connectivity in parallel...

╔══════════════════════════════════════════════════════════════════╗
║ Scan Results                                                     ║
╚══════════════════════════════════════════════════════════════════╝

✓ 192.168.1.100  SSH: UP    Hostname: ReCyClusteR-Node
✓ 192.168.1.101  SSH: UP    Hostname: ReCyClusteR-Node
✓ 192.168.1.102  SSH: UP    Hostname: ReCyClusteR-Node

Total SSH hosts: 3
Results saved to: /tmp/rccr_scan_results.txt
```

### 5. 노드 매핑

```bash
./node_mapper.sh
```

**인터랙티브 프로세스:**
```
╔══════════════════════════════════════════════════════════════════╗
║              RCCR Node Mapper - Interactive Setup               ║
╚══════════════════════════════════════════════════════════════════╝

Available hosts from scan: /tmp/rccr_scan_results.txt

Found 3 hosts:
  1. 192.168.1.100
  2. 192.168.1.101
  3. 192.168.1.102

Select CONTROL nodes (space-separated numbers, e.g., "1"):
> 1

Select TARGET nodes (space-separated numbers, e.g., "2 3"):
> 2 3

╔══════════════════════════════════════════════════════════════════╗
║ Mapping Summary                                                  ║
╚══════════════════════════════════════════════════════════════════╝

Control Nodes: 1
  - 192.168.1.100

Target Nodes: 2
  - 192.168.1.101
  - 192.168.1.102

Confirm? (y/N): y

✓ Configuration saved to: /root/rccr/cluster_config.yml
```

**생성된 cluster_config.yml:**
```yaml
# RCCR Cluster Configuration
# This is the ONLY configuration file for the cluster

cluster:
  name: rccr-cluster

ssh:
  user: root
  private_key: ~/.ssh/id_rsa
  options: -o StrictHostKeyChecking=no

nodes:
  - ip: 192.168.1.100
    hostname: control-node-1
    role: control

  - ip: 192.168.1.101
    hostname: target-node-1
    role: target

  - ip: 192.168.1.102
    hostname: target-node-2
    role: target
```

### 6. Python 설치 (Target 노드)

```bash
cd /root/rccr/playbooks
ansible-playbook install-python.yml
```

**진행 과정:**
```
PLAY [Load cluster configuration] **********************************

TASK [Read cluster config] *****************************************
ok: [localhost]

TASK [Add target nodes to inventory] *******************************
ok: [localhost] => (item={'ip': '192.168.1.101', 'hostname': 'target-node-1', 'role': 'target'})
ok: [localhost] => (item={'ip': '192.168.1.102', 'hostname': 'target-node-2', 'role': 'target'})

PLAY [Install Python on target nodes] ******************************

TASK [Install Python3 (if not present)] ****************************
changed: [target-node-1]
changed: [target-node-2]

PLAY RECAP *********************************************************
target-node-1  : ok=1    changed=1    unreachable=0    failed=0
target-node-2  : ok=1    changed=1    unreachable=0    failed=0
```

### 7. 클러스터 셋업

```bash
ansible-playbook setup.yml
```

**진행 과정:**
```
PLAY [Load cluster configuration] **********************************

TASK [Add all nodes to inventory] **********************************
ok: [localhost] => (item={'ip': '192.168.1.100', 'hostname': 'control-node-1', 'role': 'control'})
ok: [localhost] => (item={'ip': '192.168.1.101', 'hostname': 'target-node-1', 'role': 'target'})
ok: [localhost] => (item={'ip': '192.168.1.102', 'hostname': 'target-node-2', 'role': 'target'})

PLAY [Configure all cluster nodes] *********************************

TASK [Set hostname] ************************************************
changed: [control-node-1]
changed: [target-node-1]
changed: [target-node-2]

TASK [Install base packages] ***************************************
changed: [control-node-1]
changed: [target-node-1]
changed: [target-node-2]

PLAY RECAP *********************************************************
control-node-1 : ok=2    changed=2    unreachable=0    failed=0
target-node-1  : ok=2    changed=2    unreachable=0    failed=0
target-node-2  : ok=2    changed=2    unreachable=0    failed=0
```

### 8. 완료 확인

```bash
# 모든 노드 연결 확인
ansible all -m ping -i cluster_config.yml

# 노드 정보 확인
ansible all -m shell -a "hostname && python3 --version" -i cluster_config.yml
```

---

## 📁 프로젝트 구조

```
recycluster/
├── image-profiles/
│   ├── control/
│   │   └── genapkovl-rccr-control.sh    # Control overlay 생성
│   └── target/
│       └── genapkovl-rccr-target.sh     # Target overlay 생성
│
├── scripts/
│   ├── build-x86-from-official.sh       # x86/aarch64 ISO 빌드
│   ├── build-rpi-from-official.sh       # Raspberry Pi IMG 빌드
│   ├── network_scan.sh                   # ARP 기반 네트워크 스캔
│   └── node_mapper.sh                    # 인터랙티브 노드 매핑
│
├── playbooks/
│   ├── install-python.yml                # Target에 Python 설치 (raw)
│   └── setup.yml                         # 클러스터 전체 설정
│
├── cluster_config.yml.example            # 설정 파일 예시
└── README.md
```

---

## 🔧 설정 파일

### cluster_config.yml

**단일 설정 소스** - 자동 생성되는 파일 없음

```yaml
# RCCR Cluster Configuration
# This is the ONLY configuration file for the cluster

cluster:
  name: rccr-cluster

ssh:
  user: root
  private_key: ~/.ssh/id_rsa
  options: -o StrictHostKeyChecking=no

nodes:
  - ip: 192.168.1.100
    hostname: control-node-1
    role: control

  - ip: 192.168.1.101
    hostname: target-node-1
    role: target

  - ip: 192.168.1.102
    hostname: target-node-2
    role: target
```

---

## 🔍 네트워크 스캔 상세

### ARP 기반 스캔

**nmap 불필요** - ARP 캐시와 SSH 병렬 체크 사용

```bash
# 1. ARP 캐시 채우기
ping -c 3 -b <broadcast> >/dev/null 2>&1

# 2. ARP 테이블에서 호스트 추출
ip neigh show | awk '/REACHABLE|STALE|DELAY/ {print $1}'

# 3. SSH 병렬 체크 (30초 타임아웃)
for host in $HOSTS; do
    (ssh -o ConnectTimeout=2 root@$host hostname) &
done
wait
```

**장점:**
- 빠름 (병렬 처리)
- 추가 패키지 불필요
- Alpine 기본 도구만 사용

---

## ❓ 문제 해결

### 1. 네트워크가 활성화되지 않음

**증상:** 부팅 후 IP 주소가 없음

**해결:**
```bash
# 네트워크 서비스 상태 확인
rc-service networking status

# 수동 시작
rc-service networking start

# DHCP 확인
ip -4 addr show
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

### 3. Python이 설치되지 않음

**증상:** Ansible playbook이 "No module named" 에러

**해결:**
```bash
# Target 노드에서 Python 확인
python3 --version

# 수동 설치
apk update
apk add python3

# Ansible raw 모드로 재설치
ansible-playbook playbooks/install-python.yml
```

### 4. 노드 스캔에서 호스트가 안 보임

**증상:** network_scan.sh 실행 시 호스트 0개

**해결:**
```bash
# ARP 캐시 수동 확인
ip neigh show

# Ping으로 캐시 채우기
ping -c 3 -b 192.168.1.255

# SSH 수동 테스트
ssh -o ConnectTimeout=2 root@192.168.1.100 hostname
```

---

## 🛠️ 개발

### Overlay 수정

```bash
# Control overlay 수정
vi image-profiles/control/genapkovl-rccr-control.sh

# 검증
sh -n image-profiles/control/genapkovl-rccr-control.sh

# 테스트 생성
cd image-profiles/control
./genapkovl-rccr-control.sh "test-hostname"

# 내용 확인
tar -tzf test-hostname.apkovl.tar.gz
tar -xzf test-hostname.apkovl.tar.gz -O etc/hostname
```

### 빌드 스크립트 수정

```bash
# 문법 검증
sh -n scripts/build-x86-from-official.sh

# 로컬 테스트 빌드
bash scripts/build-x86-from-official.sh x86_64 control
```

### Ansible Playbook 수정

```bash
# YAML 문법 검증
python3 -c "import yaml; yaml.safe_load(open('playbooks/setup.yml'))"

# Dry run
ansible-playbook playbooks/setup.yml --check

# 특정 태스크만 실행
ansible-playbook playbooks/setup.yml --tags "hostname"
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

**버전**: 0.0.1
**Alpine Linux**: 3.23.2
**마지막 업데이트**: 2026-01-05
