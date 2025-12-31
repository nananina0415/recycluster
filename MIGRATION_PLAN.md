# RCCR OS 이미지 기반 배포 전환 계획

## 📋 변경 개요

APK 빌드 방식에서 **즉시 사용 가능한 OS 이미지** 방식으로 전환합니다.

### 주요 변경사항
- ❌ **제거**: APK 패키지 빌드 시스템
- ✅ **추가**: OS 이미지 빌드 (ISO/IMG 파일)
- ✅ **추가**: 컨트롤 노드 / 대상 노드 구분
- ✅ **추가**: SSH 임시 키 사전 구성
- ✅ **추가**: 호스트명 기반 필터링 (`ReCyClusteR`)

---

## 🏗️ 새로운 아키텍처

### 배포 대상 (6개 아키텍처)

| 아키텍처 | 설명 | 주요 용도 |
|---------|------|----------|
| **aarch64** | Alpine 표준 64-bit ARM | ARM64 서버, 최신 SBC |
| **x86** | Alpine 표준 32-bit x86 | 구형 PC, 임베디드 |
| **x86_64** | Alpine 표준 64-bit x86 | 현대 PC, 서버 |
| **rpi-aarch64** | 라즈베리파이용 64-bit ARM | Raspberry Pi 3/4/5 |
| **armv7** | 라즈베리파이용 32-bit ARMv7 | Raspberry Pi 2/3 |
| **armhf** | 라즈베리파이용 32-bit ARM | Raspberry Pi 1/Zero |

### 노드 타입 (2가지)

| 타입 | 역할 | 사전 설치 도구 |
|------|------|--------------|
| **control** | 클러스터 관리 노드 (마스터) | rccr CLI, nmap, ansible, Python 3 |
| **target** | 클러스터 워커 노드 | SSH 서버, 최소 패키지 |

### 배포 형태 (2가지)

| 형태 | 파일 수 | 배포 위치 | 용도 |
|------|---------|----------|------|
| **Docker 이미지** | 12개 (6 아키텍처 × 2 타입) | Docker Hub | 테스트, 개발 환경 |
| **OS 이미지** | 12개 (6 아키텍처 × 2 타입) | GitHub Releases | 실제 하드웨어 설치 |

**총 24개 이미지**

---

## 📦 이미지 명명 규칙

### OS 이미지 (GitHub Releases)
```
rccr-{버전}-{아키텍처}-{타입}.{확장자}

예시:
- rccr-0.0.2-aarch64-control.img
- rccr-0.0.2-aarch64-target.img
- rccr-0.0.2-x86_64-control.iso
- rccr-0.0.2-x86_64-target.iso
- rccr-0.0.2-rpi-aarch64-control.img
- rccr-0.0.2-armv7-target.img
```

### Docker 이미지 (Docker Hub)
```
{registry}/{repo}:{버전}-{아키텍처}-{타입}

예시:
- nananina0415/rccr:0.0.2-aarch64-control
- nananina0415/rccr:0.0.2-aarch64-target
- nananina0415/rccr:latest-x86_64-control
```

---

## 🔑 SSH 키 관리 전략

### 1. 임시 SSH 키 생성 및 포함
```
/home/user/recycluster/.rccr/
├── ssh_temp_key          # 임시 개인키 (4096-bit RSA)
├── ssh_temp_key.pub      # 임시 공개키
└── README.md             # 키 사용 안내
```

### 2. 이미지에 임시 키 포함
- **Control 노드**: `~/.ssh/id_rsa`에 임시 개인키 복사
- **Target 노드**: `~/.ssh/authorized_keys`에 임시 공개키 추가

### 3. 초기 셋업 시 키 교체 로직
```python
# lib/ssh_manager.py (새 파일)
class SSHKeyManager:
    def generate_new_keypair():
        """새로운 SSH 키쌍 생성"""

    def deploy_keys_to_nodes():
        """모든 노드에 새 키 배포"""

    def remove_temp_keys():
        """임시 키 제거"""
```

### 4. 셋업 플로우
```
1. Control 노드 부팅
2. rccr setup 실행
3. 임시 키로 Target 노드 SSH 접속
4. 새 SSH 키쌍 생성
5. 모든 노드에 새 키 배포
6. 임시 키 제거
7. 새 키로 재연결 테스트
```

---

## 🔍 호스트명 기반 네트워크 스캔

### 변경 전 (현재)
```python
# 모든 활성 호스트 감지
new_hosts = self.get_new_hosts()
```

### 변경 후
```python
# "ReCyClusteR" 호스트명만 필터링
new_hosts = self.get_new_hosts(hostname_filter="ReCyClusteR")
```

### 호스트명 설정
- **Control 노드**: `ReCyClusteR-Control`
- **Target 노드**: `ReCyClusteR-Target`

### network_scanner.py 수정사항
```python
def get_new_hosts(self, hostname_filter: str = None) -> List[Dict[str, str]]:
    """
    새로 추가된 호스트를 감지하며, 선택적으로 호스트명 필터링

    Args:
        hostname_filter: 호스트명 필터 (부분 문자열 매칭)
    """
    current_hosts = self.scan_network()

    # 호스트명 필터링
    if hostname_filter:
        current_hosts = [
            host for host in current_hosts
            if hostname_filter.lower() in host['hostname'].lower()
        ]

    # 기존 로직 계속...
```

---

## 🛠️ 이미지 빌드 시스템 설계

### 디렉토리 구조
```
/home/user/recycluster/
├── .rccr/
│   ├── ssh_temp_key
│   ├── ssh_temp_key.pub
│   └── README.md
├── image-builder/
│   ├── base/
│   │   ├── alpine-aarch64.dockerfile
│   │   ├── alpine-x86.dockerfile
│   │   ├── alpine-x86_64.dockerfile
│   │   ├── rpi-aarch64.dockerfile
│   │   ├── rpi-armv7.dockerfile
│   │   └── rpi-armhf.dockerfile
│   ├── control/
│   │   ├── Dockerfile.template
│   │   ├── setup.sh                # Control 노드 초기화 스크립트
│   │   └── motd                    # 로그인 환영 메시지
│   ├── target/
│   │   ├── Dockerfile.template
│   │   ├── setup.sh                # Target 노드 초기화 스크립트
│   │   └── motd
│   ├── scripts/
│   │   ├── build-docker.sh         # Docker 이미지 빌드
│   │   ├── build-os-image.sh       # OS 이미지 생성
│   │   └── test-image.sh           # 이미지 테스트
│   └── README.md
```

### Control 노드 Dockerfile 템플릿
```dockerfile
FROM alpine:{{VERSION}}

# 호스트명 설정
RUN echo "ReCyClusteR-Control" > /etc/hostname

# 필수 패키지 설치
RUN apk add --no-cache \
    openssh \
    openssh-client \
    nmap \
    ansible \
    python3 \
    py3-pip \
    py3-yaml \
    bash \
    sudo

# RCCR 설치
COPY bin/ /usr/bin/
COPY lib/ /usr/share/rccr/lib/
COPY *.playbook /usr/share/rccr/
COPY machine_layer/ /usr/share/rccr/machine_layer/
COPY cluster_config.yml /usr/share/rccr/

# SSH 임시 키 설정
RUN mkdir -p /root/.ssh
COPY .rccr/ssh_temp_key /root/.ssh/id_rsa
COPY .rccr/ssh_temp_key.pub /root/.ssh/id_rsa.pub
RUN chmod 600 /root/.ssh/id_rsa && \
    chmod 644 /root/.ssh/id_rsa.pub

# SSH 서버 설정
RUN ssh-keygen -A && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication no" >> /etc/ssh/sshd_config

# 초기화 스크립트 설정
COPY image-builder/control/setup.sh /usr/local/bin/rccr-init
RUN chmod +x /usr/local/bin/rccr-init

# 부팅 시 SSH 서비스 자동 시작
RUN rc-update add sshd default

CMD ["/sbin/init"]
```

### Target 노드 Dockerfile 템플릿
```dockerfile
FROM alpine:{{VERSION}}

# 호스트명 설정
RUN echo "ReCyClusteR-Target" > /etc/hostname

# 최소 패키지 설치
RUN apk add --no-cache \
    openssh \
    openssh-server \
    docker \
    bash

# SSH 임시 키 설정
RUN mkdir -p /root/.ssh
COPY .rccr/ssh_temp_key.pub /root/.ssh/authorized_keys
RUN chmod 700 /root/.ssh && \
    chmod 600 /root/.ssh/authorized_keys

# SSH 서버 설정
RUN ssh-keygen -A && \
    echo "PermitRootLogin yes" >> /etc/ssh/sshd_config && \
    echo "PasswordAuthentication no" >> /etc/ssh/sshd_config

# Docker 서비스 설정
RUN rc-update add docker default
RUN rc-update add sshd default

CMD ["/sbin/init"]
```

---

## 🔄 CI/CD 워크플로우 설계

### 1. Docker 이미지 빌드 (.github/workflows/build-docker-images.yml)

```yaml
name: Build and Push Docker Images

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:

jobs:
  build-docker:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        arch: [aarch64, x86, x86_64, rpi-aarch64, armv7, armhf]
        type: [control, target]
        include:
          - arch: aarch64
            platform: linux/arm64
          - arch: x86
            platform: linux/386
          - arch: x86_64
            platform: linux/amd64
          - arch: rpi-aarch64
            platform: linux/arm64
          - arch: armv7
            platform: linux/arm/v7
          - arch: armhf
            platform: linux/arm/v6

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to Docker Hub
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}

      - name: Extract version
        id: version
        run: echo "VERSION=${GITHUB_REF#refs/tags/v}" >> $GITHUB_OUTPUT

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          file: image-builder/${{ matrix.type }}/Dockerfile.${{ matrix.arch }}
          platforms: ${{ matrix.platform }}
          push: true
          tags: |
            nananina0415/rccr:${{ steps.version.outputs.VERSION }}-${{ matrix.arch }}-${{ matrix.type }}
            nananina0415/rccr:latest-${{ matrix.arch }}-${{ matrix.type }}
```

### 2. OS 이미지 빌드 (.github/workflows/build-os-images.yml)

```yaml
name: Build and Release OS Images

on:
  push:
    tags:
      - 'v*'
  workflow_dispatch:

jobs:
  build-os:
    runs-on: ubuntu-latest
    strategy:
      fail-fast: false
      matrix:
        arch: [aarch64, x86, x86_64, rpi-aarch64, armv7, armhf]
        type: [control, target]

    steps:
      - name: Checkout
        uses: actions/checkout@v4

      - name: Set up QEMU
        uses: docker/setup-qemu-action@v3

      - name: Install dependencies
        run: |
          sudo apt-get update
          sudo apt-get install -y qemu-utils dosfstools

      - name: Extract version
        id: version
        run: echo "VERSION=${GITHUB_REF#refs/tags/v}" >> $GITHUB_OUTPUT

      - name: Build OS image
        run: |
          bash image-builder/scripts/build-os-image.sh \
            ${{ matrix.arch }} \
            ${{ matrix.type }} \
            ${{ steps.version.outputs.VERSION }}

      - name: Upload artifact
        uses: actions/upload-artifact@v4
        with:
          name: rccr-${{ steps.version.outputs.VERSION }}-${{ matrix.arch }}-${{ matrix.type }}
          path: output/rccr-${{ steps.version.outputs.VERSION }}-${{ matrix.arch }}-${{ matrix.type }}.*

  release:
    needs: build-os
    runs-on: ubuntu-latest
    if: startsWith(github.ref, 'refs/tags/')

    steps:
      - name: Download all artifacts
        uses: actions/download-artifact@v4
        with:
          path: artifacts

      - name: Prepare release files
        run: |
          mkdir -p release
          find artifacts -type f \( -name "*.img" -o -name "*.iso" \) -exec cp {} release/ \;
          cd release
          sha256sum * > SHA256SUMS

      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: release/*
          generate_release_notes: true
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

## 📝 수정이 필요한 파일 목록

### 1. 삭제할 파일
- ❌ `.github/workflows/build-apk.yml`
- ❌ `APKBUILD`
- ❌ `build-apk.sh`

### 2. 새로 생성할 파일
- ✅ `.rccr/ssh_temp_key` (임시 SSH 개인키)
- ✅ `.rccr/ssh_temp_key.pub` (임시 SSH 공개키)
- ✅ `.rccr/README.md` (키 관리 설명)
- ✅ `lib/ssh_manager.py` (SSH 키 관리 모듈)
- ✅ `image-builder/` 디렉토리 전체 (약 20개 파일)
- ✅ `.github/workflows/build-docker-images.yml`
- ✅ `.github/workflows/build-os-images.yml`

### 3. 수정할 파일
- 🔧 `lib/network_scanner.py` (호스트명 필터링 추가)
- 🔧 `lib/rccr_setup.py` (SSH 키 교체 로직 추가)
- 🔧 `bin/rccr` (새로운 명령어 추가: `keygen`, `keyrotate`)
- 🔧 `README.md` (새로운 배포 방식 문서화)
- 🔧 `DISTRIBUTION.md` (OS 이미지 사용법 추가)
- 🔧 `.dockerignore` (이미지 빌드 최적화)
- 🔧 `.gitignore` (.rccr/ssh_temp_key는 추가하되, 실제 키는 GitHub Secrets 사용)
- 🔧 `cluster_config.yml` (호스트명 필터 설정 추가)

---

## 🚀 단계별 구현 계획

### Phase 1: SSH 키 인프라 (1-2일)
1. `.rccr/` 디렉토리 생성
2. 임시 SSH 키쌍 생성 스크립트 작성
3. `lib/ssh_manager.py` 구현
4. `bin/rccr`에 `keygen`, `keyrotate` 명령어 추가
5. 테스트: 로컬에서 키 생성 및 교체 시뮬레이션

### Phase 2: 호스트명 필터링 (1일)
1. `lib/network_scanner.py`에 `hostname_filter` 파라미터 추가
2. `lib/rccr_setup.py`에서 `ReCyClusteR` 필터 적용
3. 테스트: 호스트명 기반 스캔 동작 확인

### Phase 3: Docker 이미지 빌드 시스템 (2-3일)
1. `image-builder/` 디렉토리 구조 생성
2. Control/Target 노드별 Dockerfile 작성
3. 6개 아키텍처별 base Dockerfile 작성
4. `build-docker.sh` 스크립트 구현
5. 로컬 테스트: 단일 아키텍처 빌드 검증

### Phase 4: OS 이미지 빌드 시스템 (3-4일)
1. `build-os-image.sh` 스크립트 구현
2. Alpine 및 라즈베리파이 OS 이미지 생성 로직
3. QEMU를 사용한 크로스 플랫폼 빌드
4. 이미지 압축 및 체크섬 생성
5. 로컬 테스트: 가상 머신에서 이미지 부팅

### Phase 5: CI/CD 통합 (2-3일)
1. `.github/workflows/build-docker-images.yml` 작성
2. `.github/workflows/build-os-images.yml` 작성
3. Docker Hub 및 GitHub Secrets 설정
4. 테스트: 태그 푸시로 전체 빌드 파이프라인 검증

### Phase 6: 문서화 및 테스트 (2일)
1. `README.md` 업데이트 (새로운 설치 방법)
2. `DISTRIBUTION.md` 업데이트 (OS 이미지 사용법)
3. 통합 테스트: 실제 하드웨어에서 설치 및 셋업
4. 사용자 가이드 작성

### Phase 7: 레거시 제거 및 릴리스 (1일)
1. APK 관련 파일 삭제
2. `.gitignore`, `.dockerignore` 정리
3. v0.0.2 태그 생성 및 릴리스
4. Docker Hub 및 GitHub Releases 확인

**총 예상 기간: 12-16일**

---

## 🎯 핵심 기술적 결정 사항

### 1. OS 이미지 형식 선택
- **x86/x86_64**: ISO 이미지 (CD/USB 부팅)
- **ARM 계열**: IMG 이미지 (SD 카드 플래시)

### 2. 이미지 크기 최적화
- Alpine Linux 최소 설치
- Control 노드: ~200MB
- Target 노드: ~100MB

### 3. 보안 고려사항
- 임시 SSH 키는 4096-bit RSA
- 임시 키는 첫 셋업 후 즉시 교체
- 키 교체 실패 시 롤백 메커니즘

### 4. 호환성
- Alpine Linux 3.19+ 기준
- Raspberry Pi OS와 호환되는 부트로더 포함

---

## 📊 변경 전후 비교

| 항목 | 변경 전 (APK) | 변경 후 (OS 이미지) |
|------|--------------|-------------------|
| **설치 방법** | `apk add rccr` | SD 카드 플래시 또는 ISO 부팅 |
| **사전 준비** | Alpine 설치 필요 | 즉시 사용 가능 |
| **파일 수** | 5개 APK | 12개 OS 이미지 + 12개 Docker 이미지 |
| **노드 구분** | 없음 | Control / Target 명확히 구분 |
| **SSH 설정** | 수동 | 사전 구성 (임시 키) |
| **호스트명** | 사용자 설정 | `ReCyClusteR` 자동 설정 |
| **네트워크 스캔** | 모든 호스트 | `ReCyClusteR` 호스트만 |
| **초기 셋업 시간** | ~10분 | ~2분 |

---

## ⚠️ 리스크 및 대응 방안

| 리스크 | 영향도 | 대응 방안 |
|--------|--------|----------|
| 임시 SSH 키 노출 | 높음 | GitHub Secrets 사용, 문서화 강화 |
| OS 이미지 빌드 실패 | 중간 | 로컬 테스트 철저히, QEMU 검증 |
| 이미지 크기 증가 | 낮음 | Alpine 최소 설치, 불필요한 패키지 제거 |
| 라즈베리파이 호환성 | 중간 | 실제 하드웨어 테스트, 부트로더 검증 |
| CI/CD 빌드 시간 증가 | 중간 | 병렬 빌드, 캐시 활용 |

---

## ✅ 성공 기준

### 기술적 성공 기준
- [ ] 24개 이미지 모두 정상 빌드
- [ ] Docker Hub에 12개 이미지 자동 푸시
- [ ] GitHub Releases에 12개 OS 이미지 배포
- [ ] 최소 2개 아키텍처에서 실제 하드웨어 테스트 성공
- [ ] SSH 키 자동 교체 동작 확인
- [ ] 호스트명 필터링 정상 동작

### 사용자 경험 성공 기준
- [ ] OS 이미지 플래시 → 부팅 → `rccr setup` 실행까지 5분 이내
- [ ] 임시 키로 초기 연결 성공률 100%
- [ ] 새 키 교체 성공률 95% 이상
- [ ] 설치 문서 명확성 (외부 피드백)

---

## 📞 다음 단계

1. **승인 대기**: 이 계획을 검토하고 승인
2. **Phase 1 시작**: SSH 키 인프라 구현
3. **주간 리뷰**: 매주 금요일 진행 상황 체크
4. **중간 점검**: Phase 3 완료 시 Docker 이미지 테스트
5. **최종 검증**: Phase 6 완료 시 전체 통합 테스트

---

## 📚 참고 자료

- Alpine Linux 공식 문서: https://wiki.alpinelinux.org/
- Docker 멀티 플랫폼 빌드: https://docs.docker.com/build/building/multi-platform/
- Raspberry Pi OS 이미지: https://www.raspberrypi.com/software/
- QEMU 사용 가이드: https://www.qemu.org/docs/master/
- GitHub Actions 매트릭스 빌드: https://docs.github.com/en/actions/using-jobs/using-a-matrix-for-your-jobs

---

**작성일**: 2025-12-30
**작성자**: Claude Code
**버전**: 1.0
**상태**: 검토 대기
