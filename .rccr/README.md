# RCCR 임시 SSH 키

이 디렉토리에는 RCCR 이미지에 포함될 임시 SSH 키가 저장됩니다.

## 파일 구조

```
.rccr/
├── ssh_temp_key      # 임시 개인키 (RSA 4096-bit)
├── ssh_temp_key.pub  # 임시 공개키
└── README.md         # 이 파일
```

## 키 생성 방법

### 로컬 환경

```bash
ssh-keygen -t rsa -b 4096 -f .rccr/ssh_temp_key -N "" -C "rccr-temporary-key"
```

### Docker 환경

```bash
docker run --rm -v "$PWD/.rccr:/keys" alpine:3.19 sh -c \
  "apk add --no-cache openssh-keygen && \
   ssh-keygen -t rsa -b 4096 -f /keys/ssh_temp_key -N '' -C 'rccr-temporary-key'"
```

## 보안 주의사항

⚠️ **중요**: 이 키는 **임시 키**로만 사용됩니다!

1. **이미지에 포함**: Control 노드와 Target 노드 이미지에 사전 구성됨
2. **초기 연결 전용**: 첫 부팅 시 Control → Target 노드 SSH 연결에만 사용
3. **자동 교체**: `ansible-playbook setup.playbook` 실행 시 즉시 새 키로 교체됨
4. **교체 후 삭제**: 임시 키는 모든 노드에서 자동으로 제거됨

## 키 사용 흐름

```
1. 이미지 빌드
   ├─ Control: .rccr/ssh_temp_key → /root/.ssh/id_rsa
   └─ Target: .rccr/ssh_temp_key.pub → /root/.ssh/authorized_keys

2. 첫 부팅
   └─ Control 노드가 임시 키로 Target 노드 접속 가능

3. ansible-playbook setup.playbook 실행
   ├─ 새 SSH 키 쌍 생성 (4096-bit RSA)
   ├─ 모든 Target 노드에 새 공개키 배포
   ├─ 연결 테스트
   └─ 임시 키 제거

4. 완료
   └─ 새 키만 남음 (임시 키는 모든 노드에서 삭제됨)
```

## Git 관리

**.gitignore 설정**:
```gitignore
.rccr/ssh_temp_key
.rccr/ssh_temp_key.pub
```

실제 키 파일은 Git에 커밋하지 않습니다. CI/CD에서 자동 생성합니다.

## CI/CD에서 키 생성

GitHub Actions에서는 빌드 시 자동으로 생성:

```yaml
- name: Generate temporary SSH keys
  run: |
    ssh-keygen -t rsa -b 4096 -f .rccr/ssh_temp_key -N "" -C "rccr-temporary-key"
```

## 수동 테스트

로컬에서 이미지 빌드 전에 키 생성:

```bash
# 1. 키 생성
make generate-temp-keys

# 또는 직접 실행
ssh-keygen -t rsa -b 4096 -f .rccr/ssh_temp_key -N "" -C "rccr-temporary-key"

# 2. 권한 확인
ls -la .rccr/
# -rw------- ssh_temp_key
# -rw-r--r-- ssh_temp_key.pub

# 3. 이미지 빌드
bash scripts/build-all-images.sh 0.0.2
```

## 트러블슈팅

### 키 파일이 없을 때

빌드 스크립트가 자동으로 생성하므로 문제없습니다:

```bash
# scripts/build-single-image.sh 내부
if [ ! -f .rccr/ssh_temp_key ]; then
    echo "Generating temporary SSH keys..."
    ssh-keygen -t rsa -b 4096 -f .rccr/ssh_temp_key -N "" -C "rccr-temporary-key"
fi
```

### 권한 오류

```bash
chmod 600 .rccr/ssh_temp_key
chmod 644 .rccr/ssh_temp_key.pub
```

---

**작성일**: 2025-12-30
**보안 등급**: 임시 (Temporary)
**자동 교체**: 필수
