# RCCR (ReCyClusteR)

네트워크상의 머신을 자동으로 감지하고 클러스터로 구성하는 셋업 도구입니다.

## 특징

- 🔍 **자동 머신 감지**: 네트워크에 연결된 머신을 실시간으로 감지
- 🗺️ **대화형 노드 매핑**: 감지된 머신을 설정 파일의 노드와 자동 매핑
- 📦 **컨테이너 자동 배포**: 각 노드에 정의된 컨테이너를 자동으로 배포
- 🎯 **간단한 설정**: YAML 파일로 클러스터 전체를 정의
- 📦 **APK 패키지**: Alpine Linux에서 간편하게 설치

## 요구사항

### 클러스터 노드 (Alpine Linux)
- Alpine Linux
- SSH 접근 가능
- 네트워크 연결

### 셋업 머신 (어디서든 실행 가능)
- **Docker** (권장) - Windows/Mac/Linux 모두 지원
- 또는 **Alpine Linux** - APK 패키지 설치

## 설치

### Docker (권장 - Windows/Mac/Linux 모두 지원)

Docker를 사용하면 **어떤 OS에서든** 클러스터를 셋업할 수 있습니다!

```bash
# Docker 이미지 다운로드
docker pull ghcr.io/nananina0415/recycluster:latest

# 또는 로컬에서 빌드
git clone https://github.com/nananina0415/recycluster.git
cd recycluster
docker build -t rccr .
```

### Alpine Linux (APK)

#### GitHub Releases에서 다운로드 (권장)

아키텍처에 맞는 패키지를 다운로드하세요:

| 아키텍처 | 설명 | 다운로드 |
|---------|------|---------|
| `x86` | 32-bit x86 (구형 PC) |
| `x86_64` | 64-bit x86 (일반 PC/서버) |
| `armhf` | 32-bit ARM (Raspberry Pi 1/Zero) |
| `armv7` | 32-bit ARMv7 (일반 ARM 기기) |
| `aarch64` | 64-bit ARM (Raspberry Pi 3/4, ARM64) |

설치 예시:

```bash
# x86_64 (일반 PC/서버)
wget https://github.com/nananina0415/recycluster/releases/latest/download/rccr-0.0.1-r0-x86_64.apk
apk add --allow-untrusted rccr-0.0.1-x86_64.apk

# aarch64 (Raspberry Pi 3/4, 64-bit ARM)
wget https://github.com/nananina0415/recycluster/releases/latest/download/rccr-0.0.1-r0-aarch64.apk
apk add --allow-untrusted rccr-0.0.1-aarch64.apk

# armhf (Raspberry Pi 1/Zero)
wget https://github.com/nananina0415/recycluster/releases/latest/download/rccr-0.0.1-r0-armhf.apk
apk add --allow-untrusted rccr-0.0.1-armhf.apk
```

아키텍처 확인:

```bash
# 현재 시스템 아키텍처 확인
uname -m

# 출력 예시:
# x86_64    → x86_64 패키지 사용
# aarch64   → aarch64 패키지 사용
# armv7l    → armv7 패키지 사용
# armv6l    → armhf 패키지 사용
```

#### APK 저장소에서 설치 (향후)

```bash
# 공식 저장소 등록 후
apk add rccr
```

### 소스에서 빌드

```bash
git clone https://github.com/nananina0415/recycluster.git
cd recycluster
./build-apk.sh

# Alpine Linux에서
cd build
abuild checksum
abuild -r
sudo apk add --allow-untrusted ~/packages/main/x86_64/rccr-0.0.1-r0.apk
```

## 빠른 시작

### Docker 사용 (Windows/Mac/Linux)

```bash
# 1. 작업 디렉토리 생성
mkdir my-cluster
cd my-cluster

# 2. 프로젝트 초기화
docker run -it -v ${PWD}:/workspace ghcr.io/nananina0415/recycluster:latest init

# 3. 설정 파일 편집
notepad cluster_config.yml  # Windows
# 또는
vim cluster_config.yml      # Linux/Mac

# 4. 셋업 실행 (네트워크 스캔 및 클러스터 배포)
docker run -it -v ${PWD}:/workspace --network host ghcr.io/nananina0415/recycluster:latest setup
```

### Alpine Linux 사용

```bash
# 1. 작업 디렉토리 생성
mkdir my-cluster
cd my-cluster

# 2. 프로젝트 초기화
rccr init

# 3. 설정 파일 편집
vi cluster_config.yml

# 4. 셋업 실행
sudo rccr setup
```

### 설정 파일 예시

```bash
vi cluster_config.yml
```

`cluster_config.yml` 파일을 열어 클러스터 구성을 정의합니다:

```yaml
network_config:
  subnet: "192.168.219.0/24"
  gateway: "192.168.219.1"
  dns: "1.1.1.1 4.4.4.4"

machines:
  - name: laptop-1
    ip: 192.168.219.201
    role: manager
    containers:
      - storage
      - task_queue
      - runnin_gmate

  - name: rpi3-1
    ip: 192.168.219.202
    role: worker
    containers:
      - runner
```

### 4. 셋업 실행

```bash
sudo rccr setup
```

### 5. 대화형 안내에 따라 진행

셋업 스크립트가 실행되면 다음과 같은 안내가 표시됩니다:

```
=================================================================
  RCCR (ReCyClusteR) Setup
=================================================================

서브넷 192.168.219.0/24 를 스캔합니다...
현재 0개의 호스트 감지됨.

┌─────────────────────────────────────────────────────────────────┐
│ [1/4] 다음 노드를 네트워크에 연결해주세요                        │
├─────────────────────────────────────────────────────────────────┤
│ 노드명:       laptop-1                                          │
│ 할당 IP:      192.168.219.201                                   │
│ 역할:         manager                                           │
│ 컨테이너:     - storage                                         │
│              - task_queue                                       │
│              - runnin_gmate                                     │
└─────────────────────────────────────────────────────────────────┘

머신을 연결(전원 켜기 또는 랜선 연결)하고 Enter를 누르세요...
```

각 노드를 순서대로 연결하고 Enter를 누르면 자동으로 감지되어 매핑됩니다.

## 동작 원리

### 1단계: 종속성 설치
- Python 3, pip, nmap, Ansible 등 필요한 도구 자동 설치
- Alpine Linux APK 패키지 관리자 사용

### 2단계: 노드 감지 및 매핑
- 네트워크 스냅샷을 생성하여 현재 상태 저장
- 사용자가 머신을 연결할 때마다 네트워크를 재스캔
- 스냅샷 비교를 통해 새로 추가된 머신 자동 감지
- 감지된 머신을 설정 파일의 노드와 순서대로 매핑

### 3단계: 설정 파일 업데이트
- 감지된 IP 주소를 `cluster_config.yml`의 `detected_ip` 필드에 저장
- `cluster_config.yml`이 단일 정보 소스로 사용됨

### 4단계: 클러스터 배포
- Ansible playbook을 사용하여 각 노드 설정
- 각 노드에 Docker 설치 (노드는 다양한 Linux 배포판 가능)
- 컨테이너 이미지 다운로드 및 실행

## 프로젝트 구조

```
recycluster/
├── bin/
│   └── rccr                      # CLI 실행 파일
├── lib/
│   ├── network_scanner.py        # 네트워크 스캔 모듈
│   ├── node_mapper.py            # 노드 매핑 모듈
│   └── rccr_setup.py             # 메인 셋업 로직
├── cluster_config.yml            # 클러스터 설정 파일 (템플릿)
├── deploy_cluster.playbook       # Ansible 배포 플레이북
├── machine_layer/                # 머신 레이어 플레이북
├── container_layer/              # 컨테이너 레이어 플레이북
├── orchestration_layer/          # 오케스트레이션 레이어 플레이북
├── APKBUILD                      # Alpine APK 빌드 파일
└── build-apk.sh                  # APK 빌드 스크립트
```

## 설치 경로 (APK 설치 시)

```
/usr/bin/rccr                     # 실행 파일
/usr/share/rccr/                  # 프로그램 파일
  ├── lib/                        # Python 모듈
  ├── *.playbook                  # Ansible playbook
  └── cluster_config.yml          # 설정 파일 템플릿
/usr/share/doc/rccr/              # 문서
/usr/share/licenses/rccr/         # 라이선스
```

## 생성되는 파일

셋업 과정에서 `cluster_config.yml` 파일이 업데이트됩니다:
- 각 머신의 `detected_ip` 필드에 감지된 IP 주소가 기록됨
- Ansible playbook이 이 파일을 직접 읽어서 배포 수행

## CLI 명령어

```bash
# 프로젝트 초기화 (템플릿 생성)
rccr init

# 클러스터 셋업
sudo rccr setup

# 버전 확인
rccr version

# 도움말
rccr help
```

## 고급 사용법

### 설정 파일 확인

```bash
cat cluster_config.yml
```

셋업 완료 후 각 머신의 `detected_ip` 필드에 감지된 IP가 기록됩니다.

### 수동으로 Ansible playbook 실행

```bash
ansible-playbook -e @cluster_config.yml /usr/share/rccr/deploy_cluster.playbook
```

### 태그를 사용한 부분 실행

```bash
# Docker 설치만 실행
ansible-playbook -e @cluster_config.yml /usr/share/rccr/deploy_cluster.playbook --tags docker

# 컨테이너 배포만 실행
ansible-playbook -e @cluster_config.yml /usr/share/rccr/deploy_cluster.playbook --tags containers

# 네트워크 설정만 실행
ansible-playbook -e @cluster_config.yml /usr/share/rccr/deploy_cluster.playbook --tags network
```

## 문제 해결

### nmap이 설치되지 않음
```bash
# Ubuntu/Debian
sudo apt-get install nmap

# CentOS/RHEL
sudo yum install nmap

# Alpine
apk add nmap
```

### Python 패키지 오류
```bash
pip3 install --upgrade pyyaml ansible
```

### 네트워크 스캔이 작동하지 않음
- 방화벽 설정 확인
- 올바른 서브넷이 설정되어 있는지 확인
- Root 권한으로 실행되고 있는지 확인

## 라이선스

MIT License

## 기여

이슈와 풀 리퀘스트를 환영합니다!

## 작성자

nananina0415
