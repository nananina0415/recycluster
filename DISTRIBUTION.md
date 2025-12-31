# RCCR 배포 전략 및 방법

> OS 이미지 기반 배포 가이드

## 📦 배포 개요

RCCR은 즉시 사용 가능한 **부팅 이미지**를 제공합니다:
- **OS 이미지**: ISO/IMG 파일 (GitHub Releases)
- **Docker 이미지**: 컨테이너 (GitHub Container Registry)

---

## 🎯 배포 방식

### 1. GitHub Releases (권장)

**대상**: 최종 사용자

**제공 파일**:
- OS 이미지 (ISO/IMG)
- 체크섬 파일 (SHA256SUMS)
- 릴리스 노트

**장점**:
- ✅ 무료
- ✅ 버전 관리 자동화
- ✅ 다운로드 통계
- ✅ CDN 제공

**단점**:
- ❌ 파일 크기 제한 (2GB per file)
- ❌ 대역폭 제한 (soft limit)

---

### 2. GitHub Container Registry (ghcr.io)

**대상**: 개발자, 테스터

**제공**:
- Docker 이미지

**사용**:
```bash
docker pull ghcr.io/nananina0415/recycluster:latest
docker pull ghcr.io/nananina0415/recycluster:0.0.2
```

**장점**:
- ✅ 무료 (공개 저장소)
- ✅ GitHub 통합
- ✅ 자동 빌드 (CI/CD)

---

## 🏗️ 빌드 및 배포 워크플로우

### 자동 배포 (GitHub Actions)

#### 1. 태그 생성 및 푸시

```bash
# 버전 태그 생성
git tag v0.0.2

# 태그 푸시
git push origin v0.0.2
```

#### 2. GitHub Actions 자동 실행

**워크플로우**: `.github/workflows/build-os-images.yml`

**동작**:
1. SSH 임시 키 생성
2. 6개 아키텍처 × 2개 타입 = 12개 이미지 빌드
3. 체크섬 생성
4. GitHub Release 생성
5. 이미지 업로드

**소요 시간**: 약 60-90분 (병렬 빌드)

#### 3. Docker 이미지 자동 푸시

**워크플로우**: `.github/workflows/build-docker.yml`

**동작**:
1. Dockerfile 빌드
2. ghcr.io에 푸시
3. 태그 지정 (버전, latest)

---

## 📋 배포 체크리스트

### 릴리스 전 체크리스트

- [ ] 모든 테스트 통과
- [ ] 문서 업데이트 (README.md, CHANGELOG.md)
- [ ] 버전 번호 업데이트
  - [ ] `cluster_config.yml` (주석)
  - [ ] `Dockerfile` (LABEL)
  - [ ] `README.md`
  - [ ] `.github/workflows/*.yml` (예시)
- [ ] 로컬 빌드 테스트
- [ ] CHANGELOG.md 작성

### 릴리스 과정

1. **버전 결정** (Semantic Versioning)
   - MAJOR.MINOR.PATCH
   - 예: 0.0.2 → 0.0.3 (bugfix)
   - 예: 0.0.2 → 0.1.0 (feature)
   - 예: 0.1.0 → 1.0.0 (breaking change)

2. **코드 업데이트**
   ```bash
   # 버전 번호 업데이트
   git checkout -b release/v0.0.3

   # 파일들 수정...

   git add -A
   git commit -m "chore: bump version to 0.0.3"
   git push origin release/v0.0.3
   ```

3. **PR 생성 및 머지**
   ```bash
   gh pr create --title "Release v0.0.3" --body "..."
   gh pr merge --squash
   ```

4. **태그 생성**
   ```bash
   git checkout main
   git pull
   git tag -a v0.0.3 -m "Release v0.0.3"
   git push origin v0.0.3
   ```

5. **GitHub Actions 확인**
   - https://github.com/nananina0415/recycluster/actions
   - 빌드 성공 확인
   - Release 페이지 확인

6. **릴리스 노트 편집 (선택)**
   - https://github.com/nananina0415/recycluster/releases
   - 자동 생성된 릴리스 노트 수정

---

## 🔧 수동 빌드 및 배포

### 로컬 빌드

```bash
# 단일 이미지
bash scripts/build-single-image.sh x86_64 control 0.0.2

# 모든 이미지
bash scripts/build-all-images.sh 0.0.2
```

**출력**:
```
build/
├── x86_64-control/
│   ├── rccr-0.0.2-x86_64-control.iso
│   └── SHA256SUMS
├── x86_64-target/
│   ├── rccr-0.0.2-x86_64-target.iso
│   └── SHA256SUMS
...
```

### 수동 GitHub Release 생성

```bash
# GitHub CLI 사용
gh release create v0.0.2 \
  --title "RCCR v0.0.2" \
  --notes "Release notes here..." \
  build/*/*.iso \
  build/*/*.img \
  build/SHA256SUMS-all
```

### Docker 이미지 수동 푸시

```bash
# 로컬 빌드
docker build -t ghcr.io/nananina0415/recycluster:0.0.2 .
docker tag ghcr.io/nananina0415/recycluster:0.0.2 \
           ghcr.io/nananina0415/recycluster:latest

# 로그인
echo $GITHUB_TOKEN | docker login ghcr.io -u nananina0415 --password-stdin

# 푸시
docker push ghcr.io/nananina0415/recycluster:0.0.2
docker push ghcr.io/nananina0415/recycluster:latest
```

---

## 📊 배포 전략 비교

### APK 패키지 vs OS 이미지

| 항목 | APK 패키지 (구 방식) | OS 이미지 (현 방식) |
|------|-------------------|-------------------|
| **설치** | `apk add rccr` | SD 카드 플래시 |
| **사전 요구사항** | Alpine 설치 필요 | 없음 (즉시 부팅) |
| **초기화 시간** | ~10분 | ~2분 |
| **SSH 설정** | 수동 | 자동 (임시 키) |
| **버전 관리** | APK 저장소 | GitHub Releases |
| **배포 복잡도** | 높음 | 낮음 |
| **사용자 편의성** | 낮음 | 높음 |

**결론**: OS 이미지가 훨씬 사용하기 쉽고 배포도 간단합니다.

---

## 🌐 대체 배포 채널 (향후)

### 1. Docker Hub

**현재**: GitHub Container Registry (ghcr.io)
**향후**: Docker Hub 동시 배포 고려

```bash
# Docker Hub 푸시
docker tag rccr nananina0415/rccr:0.0.2
docker push nananina0415/rccr:0.0.2
```

**장점**:
- 더 넓은 사용자층
- 검색 노출 향상

**단점**:
- 무료 계정 제약 (pull rate limit)

---

### 2. CDN (Cloudflare R2 / AWS S3)

**현재**: GitHub Releases
**향후**: 대용량 파일 배포 시 CDN 고려

**장점**:
- 빠른 다운로드
- 대역폭 제한 없음
- 글로벌 배포

**단점**:
- 비용 발생
- 추가 인프라 관리

---

### 3. BitTorrent

**향후**: 대규모 배포 시 P2P 고려

**장점**:
- 대역폭 분산
- 빠른 다운로드 (피어 많을 때)

**단점**:
- 복잡한 설정
- 초기 시드 필요

---

## 📈 배포 모니터링

### GitHub Releases 다운로드 통계

```bash
# GitHub CLI로 다운로드 수 확인
gh release view v0.0.2 --json assets --jq '.assets[] | {name: .name, downloads: .download_count}'
```

### Docker 이미지 Pull 통계

- GitHub Packages Insights 확인
- https://github.com/nananina0415/recycluster/pkgs/container/recycluster

---

## 🔐 보안 고려사항

### 1. 체크섬 검증

**필수**: 모든 릴리스에 SHA256SUMS 제공

```bash
# 빌드 시 자동 생성
cd build
sha256sum *.iso *.img > SHA256SUMS

# 사용자 검증
sha256sum -c SHA256SUMS
```

### 2. 서명 (향후)

**GPG 서명** 추가 고려:

```bash
# 릴리스 서명
gpg --armor --detach-sign SHA256SUMS

# 사용자 검증
gpg --verify SHA256SUMS.asc SHA256SUMS
```

### 3. SSH 임시 키 보안

**중요**:
- 임시 키는 GitHub에 커밋하지 않음 (`.gitignore`)
- 빌드 시마다 새로 생성
- 이미지에 포함되지만 첫 셋업 시 즉시 교체됨

---

## 📝 릴리스 노트 템플릿

```markdown
# RCCR v0.0.3

## 🎉 주요 변경사항

- 새 기능 추가
- 버그 수정
- 성능 개선

## 📦 다운로드

### OS 이미지

**Control 노드:**
- [x86_64](https://github.com/nananina0415/recycluster/releases/download/v0.0.3/rccr-0.0.3-x86_64-control.iso)
- [aarch64](https://github.com/nananina0415/recycluster/releases/download/v0.0.3/rccr-0.0.3-aarch64-control.img)

**Target 노드:**
- [x86_64](https://github.com/nananina0415/recycluster/releases/download/v0.0.3/rccr-0.0.3-x86_64-target.iso)
- [aarch64](https://github.com/nananina0415/recycluster/releases/download/v0.0.3/rccr-0.0.3-aarch64-target.img)

**체크섬:**
- [SHA256SUMS](https://github.com/nananina0415/recycluster/releases/download/v0.0.3/SHA256SUMS)

### Docker 이미지

```bash
docker pull ghcr.io/nananina0415/recycluster:0.0.3
```

## 🐛 버그 수정

- #123: 네트워크 스캔 오류 수정
- #124: SSH 키 교체 실패 수정

## ✨ 새 기능

- Avahi mDNS 지원 추가
- 호스트명 자동 광고

## 📖 문서

- [README.md](https://github.com/nananina0415/recycluster/blob/v0.0.3/README.md)
- [IMAGE_BUILD_STRATEGY.md](https://github.com/nananina0415/recycluster/blob/v0.0.3/IMAGE_BUILD_STRATEGY.md)

## 🔍 체크섬 검증

```bash
sha256sum -c SHA256SUMS
```

---

**전체 변경사항**: [v0.0.2...v0.0.3](https://github.com/nananina0415/recycluster/compare/v0.0.2...v0.0.3)
```

---

## 🎯 장기 배포 로드맵

### Phase 1: GitHub 기반 (현재)
- ✅ GitHub Releases (OS 이미지)
- ✅ GitHub Container Registry (Docker)

### Phase 2: 다중 채널
- ⏳ Docker Hub 동시 배포
- ⏳ 릴리스 자동화 개선

### Phase 3: CDN 및 최적화
- ⏳ Cloudflare R2 연동
- ⏳ 미러 서버 추가
- ⏳ 다운로드 속도 최적화

### Phase 4: 커뮤니티
- ⏳ Alpine 공식 저장소 등록 검토
- ⏳ Package Manager 연동 (Homebrew, apt 등)

---

## 📞 배포 관련 문의

이슈 생성: https://github.com/nananina0415/recycluster/issues

---

**작성일**: 2025-12-30
**버전**: 0.0.2
**배포 방식**: OS 이미지 (GitHub Releases) + Docker (ghcr.io)
