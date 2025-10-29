# Recycluster

안 쓰는 컴퓨터, 노트북, 스마트폰, 라즈베리파이를 활용한 작지만 완벽한 초소형 홈서버 클러스터 솔루션

## 프로젝트 소개

Recycluster는 집에 방치된 낡은 하드웨어를 재활용(Recycle)하여 강력한 홈서버 클러스터(Cluster)를 구축할 수 있는 Ansible 기반 자동화 솔루션입니다. 복잡한 클러스터 설정 과정을 간단한 대화형 인터페이스로 제공하여, 누구나 쉽게 자신만의 분산 컴퓨팅 환경을 만들 수 있습니다.

### 주요 특징

- **자동화된 클러스터 구축**: Ansible을 이용한 완전 자동화된 설정
- **대화형 설치**: 사용자 친화적인 대화형 인터페이스
- **네트워크 자동 감지**: 새로운 머신을 자동으로 발견하고 설정
- **이기종 하드웨어 지원**: 다양한 종류의 장비를 하나의 클러스터로 통합
- **레이어드 아키텍처**: 머신 레이어, 오케스트레이션 레이어, 컨테이너 레이어로 구분된 명확한 구조
- **경량 OS 기반**: Alpine Linux를 사용하여 최소한의 리소스로 운영

### 지원 아키텍처

Recycluster는 Alpine Linux Standard의 다음 아키텍처를 지원합니다:

- **x86_64**: 64-bit PC, 노트북
- **x86**: 32-bit PC, 낡은 노트북
- **aarch64**: 64-bit ARM (라즈베리파이 3/4/5 등)
- **armv7**: 32-bit ARM (라즈베리파이 2/3 등)

> **주의**: 모든 머신은 Alpine Linux가 설치되어 있어야 합니다.

## 아키텍처

Recycluster는 3개의 레이어로 구성됩니다:

1. **머신 레이어** (Machine Layer)
   - OS 기본 설정
   - 호스트명 설정
   - 네트워크 구성
   - SSH 설정

2. **오케스트레이션 레이어** (Orchestration Layer) - 추후 구현 예정
   - Docker 설치 및 설정
   - Docker Swarm 클러스터 구성
   - 컨테이너 오케스트레이션

3. **컨테이너 레이어** (Container Layer) - 추후 구현 예정
   - 서비스 컨테이너 배포
   - 스토리지 서비스
   - 작업 큐
   - 웹 서비스

## 시작하기

### 사전 요구사항

- **제어 노드** (설정을 실행할 컴퓨터):
  - Alpine Linux (지원 아키텍처: x86, x86_64, armv7, aarch64)
  - 루트 권한
  - 인터넷 연결

- **관리 대상 노드** (클러스터에 포함될 컴퓨터들):
  - Alpine Linux (지원 아키텍처: x86, x86_64, armv7, aarch64)
  - SSH 접속 가능
  - 동일한 네트워크에 연결
  - 루트 또는 sudo 권한 가능한 계정

> **중요**: Recycluster는 Alpine Linux 전용으로 설계되었습니다. 다른 Linux 배포판은 지원하지 않습니다.

### 설치 및 설정

#### 1단계: 클러스터 구성 파일 작성

`cluster_config.yml` 파일을 편집하여 클러스터 구성을 정의합니다:

```yaml
cluster_managers:
  - cm

network_config:
  subnet: "192.168.1.0/24"
  gateway: "192.168.1.1"
  dns: "8.8.8.8 1.1.1.1"

machines:
  - name: rpicluster-laptop-1
    ip: 192.168.1.101
    role: manager
    containers:
      - storage
      - task_queue

  - name: rpicluster-rpi3-1
    ip: 192.168.1.102
    role: worker
    containers:
      - runner

  - name: rpicluster-rpi0-1
    ip: 192.168.1.103
    role: worker
    containers:
      - service
      - reverse_proxy
```

#### 2단계: 셋업 스크립트 실행

클러스터에 포함될 아무 컴퓨터에서 다음 명령을 실행합니다:

```bash
# 루트 권한으로 실행
sudo sh setup.sh
```

셋업 스크립트는 다음을 수행합니다:
- Python3, Ansible, Nmap 등 필요한 도구 설치
- 메인 플레이북 자동 실행

#### 3단계: 시작 머신 설정

대화형 인터페이스가 시작되면 다음 단계를 따릅니다:

1. **준비 단계**
   - cluster_config.yml 확인
   - 다른 모든 컴퓨터를 꺼둠
   - Enter 키를 눌러 계속

2. **머신 선택**
   - 화면에 표시된 머신 리스트에서 번호 선택
   - 현재 컴퓨터를 어떤 노드로 사용할지 지정

3. **호스트명 설정**
   - 자동으로 호스트명이 변경됨
   - 완료 메시지 확인

#### 4단계: 다른 머신들 설정

시작 머신 설정이 완료되면 자동으로 다른 머신들의 설정이 시작됩니다:

1. **주의사항 확인**
   - 네트워크에 불필요한 장치 연결하지 않기
   - Enter 키를 눌러 계속

2. **각 머신 설정 반복**
   - 설정할 머신 정보 확인
   - 해당 머신의 전원을 켬
   - Enter 키 누름
   - 네트워크 스캔으로 자동 감지
   - 머신 정보 확인 (CPU, 메모리 등)
   - SSH 자격증명 입력
   - 확인 후 자동 설정

3. **모든 머신 설정 완료**
   - 완료 메시지 확인
   - 각 머신 재부팅 (권장)

## 사용 예시

### 예제 1: 3대의 라즈베리파이 클러스터

```yaml
machines:
  - name: rpi-master
    ip: 192.168.1.100
    role: manager

  - name: rpi-worker-1
    ip: 192.168.1.101
    role: worker

  - name: rpi-worker-2
    ip: 192.168.1.102
    role: worker
```

### 예제 2: 혼합 하드웨어 클러스터

```yaml
machines:
  - name: laptop-manager
    ip: 192.168.1.100
    role: manager

  - name: rpi4-worker
    ip: 192.168.1.101
    role: worker

  - name: android-phone
    ip: 192.168.1.102
    role: worker
```

## 트러블슈팅

### 네트워크 스캔에서 머신이 감지되지 않을 때

- 머신이 완전히 부팅되었는지 확인 (30초-1분 대기)
- 네트워크 연결 상태 확인
- 방화벽 설정 확인
- subnet 설정이 올바른지 확인

### SSH 연결이 실패할 때

- SSH 서비스가 실행 중인지 확인
- 방화벽에서 SSH 포트(22) 개방 확인
- 사용자명과 비밀번호 확인
- SSH 키 기반 인증인 경우 적절한 설정 필요

### 호스트명 변경이 적용되지 않을 때

- 시스템 재부팅 필요
- /etc/hostname 파일 확인
- /etc/hosts 파일에 새 호스트명 추가 필요할 수 있음

## 프로젝트 구조

```
recycluster/
├── setup.sh                        # 초기 설정 스크립트
├── setup.playbook                  # 마스터 오케스트레이터
├── cluster_config.yml              # 클러스터 구성 파일
├── machine_layer/                  # 머신 레이어
│   ├── main.playbook
│   ├── init_starter_machine.playbook
│   ├── init_other_machines.playbook
│   └── tasks/
│       ├── initialize_single_machine.yml
│       └── gather_host_info.yml
├── orchestration_layer/            # 오케스트레이션 레이어 (예정)
│   └── main.playbook
└── container_layer/                # 컨테이너 레이어 (예정)
    └── main.playbook
```

## 기여하기

Recycluster는 오픈소스 프로젝트입니다. 기여를 환영합니다!

- 버그 리포트
- 기능 제안
- Pull Request
- 문서 개선

## 로드맵

- [x] 머신 레이어 기본 구현
- [x] 대화형 머신 설정
- [x] 네트워크 자동 감지
- [ ] 오케스트레이션 레이어 (Docker Swarm)
- [ ] 컨테이너 레이어 (서비스 배포)
- [ ] 웹 기반 관리 인터페이스
- [ ] 모니터링 및 로깅
- [ ] 자동 백업 및 복구

## 라이선스

MIT License

## 문의

이슈나 질문은 GitHub Issues를 이용해 주세요.
