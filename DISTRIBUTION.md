# RCCR APK 패키지 배포 가이드

## 배포 방법 개요

Alpine Linux APK 패키지를 배포하는 방법은 크게 3가지입니다:

### 1. 공식 Alpine 저장소 등록 (권장, 장기적)
### 2. 개인 APK 저장소 운영
### 3. GitHub Releases를 통한 직접 배포

---

## 방법 1: 공식 Alpine 저장소 등록

### 장점
- 사용자가 `apk add rccr`로 바로 설치 가능
- Alpine 커뮤니티의 신뢰
- 자동 업데이트 지원

### 단점
- 승인 과정이 필요 (며칠~몇 주 소요)
- 엄격한 품질 기준 충족 필요

### 절차

1. **Alpine GitLab 계정 생성**
   - https://gitlab.alpinelinux.org 에서 계정 생성

2. **aports 저장소 포크**
   ```bash
   git clone https://gitlab.alpinelinux.org/alpine/aports.git
   cd aports
   ```

3. **패키지 추가**
   ```bash
   # testing 저장소에 추가 (신규 패키지)
   mkdir -p testing/rccr
   cp /path/to/your/APKBUILD testing/rccr/

   # 체크섬 생성
   cd testing/rccr
   abuild checksum
   ```

4. **빌드 테스트**
   ```bash
   abuild -r
   ```

5. **커밋 및 Merge Request**
   ```bash
   git checkout -b add-rccr
   git add testing/rccr
   git commit -m "testing/rccr: new aport"
   git push origin add-rccr
   ```

6. **Merge Request 생성**
   - GitLab에서 Merge Request 생성
   - Alpine 패키지 가이드라인 준수 확인
   - 커뮤니티 리뷰 대기

7. **승인 후**
   - testing → community → main 순으로 승격 가능

### 참고 자료
- Alpine Package Policy: https://wiki.alpinelinux.org/wiki/Creating_an_Alpine_package
- APKBUILD Reference: https://wiki.alpinelinux.org/wiki/APKBUILD_Reference

---

## 방법 2: 개인 APK 저장소 운영 (중기적)

### 장점
- 완전한 통제권
- 빠른 배포 가능
- 베타/개발 버전 배포 용이

### 단점
- 인프라 유지 필요
- 사용자가 저장소 추가 필요

### 구축 방법

#### 2-1. 저장소 서버 준비

```bash
# 웹 서버 설치 (nginx 예시)
apk add nginx

# 저장소 디렉토리 생성
mkdir -p /var/www/apk/v3.19/main/x86_64
```

#### 2-2. 패키지 빌드 및 서명

```bash
# 서명 키 생성 (최초 1회)
abuild-keygen -a -i

# 패키지 빌드
./build-apk.sh
cd build
abuild checksum
abuild -r

# 빌드된 패키지 복사
cp ~/packages/main/x86_64/rccr-*.apk /var/www/apk/v3.19/main/x86_64/
```

#### 2-3. 저장소 인덱스 생성

```bash
cd /var/www/apk/v3.19/main/x86_64/

# 인덱스 생성
apk index -o APKINDEX.tar.gz *.apk

# 서명
abuild-sign -k ~/.abuild/your-key.rsa APKINDEX.tar.gz
```

#### 2-4. 공개 키 배포

```bash
# 공개 키를 웹 서버에 복사
cp ~/.abuild/your-key.rsa.pub /var/www/apk/your-key.rsa.pub
```

#### 2-5. nginx 설정

```nginx
server {
    listen 80;
    server_name apk.yourdomain.com;

    root /var/www/apk;
    autoindex on;

    location / {
        try_files $uri $uri/ =404;
    }
}
```

#### 2-6. 사용자 설치 방법

```bash
# 공개 키 다운로드
wget http://apk.yourdomain.com/your-key.rsa.pub -O /etc/apk/keys/your-key.rsa.pub

# 저장소 추가
echo "http://apk.yourdomain.com/v3.19/main" >> /etc/apk/repositories

# 업데이트 및 설치
apk update
apk add rccr
```

---

## 방법 3: GitHub Releases (단기적, 간단)

### 장점
- 가장 간단하고 빠름
- 무료
- GitHub 통합

### 단점
- 사용자가 수동 다운로드 필요
- 자동 업데이트 불가

### 절차

#### 3-1. 패키지 빌드

```bash
./build-apk.sh
cd build
abuild checksum
abuild -r
```

#### 3-2. GitHub Release 생성

```bash
# GitHub CLI 사용
gh release create v1.0.0 \
  ~/packages/main/x86_64/rccr-1.0.0-r0.apk \
  --title "RCCR v1.0.0" \
  --notes "Initial release"
```

또는 웹 UI에서:
1. GitHub 저장소 → Releases → Create a new release
2. Tag: v1.0.0
3. 파일 업로드: rccr-1.0.0-r0.apk
4. Publish release

#### 3-3. 사용자 설치 방법

```bash
# Release에서 다운로드
wget https://github.com/nananina0415/recycluster/releases/download/v1.0.0/rccr-1.0.0-r0.apk

# 설치
apk add --allow-untrusted rccr-1.0.0-r0.apk
```

---

## 권장 배포 전략

### 단계별 접근

1. **초기 (지금)**
   - GitHub Releases로 배포
   - 사용자 피드백 수집

2. **중기 (안정화 후)**
   - 개인 APK 저장소 구축
   - CI/CD로 자동 빌드 및 배포

3. **장기 (성숙 후)**
   - Alpine 공식 저장소 등록 신청
   - community/main 저장소 승격

---

## 자동화 (CI/CD)

### GitHub Actions 예시

```yaml
# .github/workflows/build-apk.yml
name: Build APK

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: ubuntu-latest
    container:
      image: alpine:latest

    steps:
      - uses: actions/checkout@v3

      - name: Install dependencies
        run: |
          apk add alpine-sdk sudo
          adduser -D builder
          addgroup builder abuild
          echo "builder ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

      - name: Setup build environment
        run: |
          su builder -c "abuild-keygen -a -i -n"

      - name: Build package
        run: |
          ./build-apk.sh
          cd build
          su builder -c "abuild checksum"
          su builder -c "abuild -r"

      - name: Upload to Release
        uses: softprops/action-gh-release@v1
        with:
          files: /home/builder/packages/main/x86_64/rccr-*.apk
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

## 체크리스트

### 배포 전 확인사항

- [ ] APKBUILD 파일 검증
- [ ] 모든 종속성 명시
- [ ] 라이선스 파일 포함
- [ ] README 및 문서 작성
- [ ] 여러 Alpine 버전에서 테스트
- [ ] 보안 검사 (취약점 스캔)

### 품질 기준

```bash
# 린트 검사
apk-tools -q lint APKBUILD

# 빌드 테스트
abuild sanitycheck
abuild -r

# 설치 테스트
apk add --allow-untrusted ~/packages/main/x86_64/rccr-*.apk
rccr version
rccr help
```

---

## 버전 관리

### Semantic Versioning

- `1.0.0`: 초기 릴리스
- `1.0.1`: 버그 수정
- `1.1.0`: 새 기능 추가 (하위 호환)
- `2.0.0`: 주요 변경 (하위 호환 깨짐)

### APKBUILD 버전 업데이트

```bash
# pkgver: 소프트웨어 버전
pkgver=1.0.1

# pkgrel: 패키지 릴리스 번호 (같은 버전의 재빌드 시 증가)
pkgrel=0
```

---

## 추가 리소스

- Alpine Wiki: https://wiki.alpinelinux.org
- APK Tools: https://gitlab.alpinelinux.org/alpine/apk-tools
- Alpine Packages: https://pkgs.alpinelinux.org
- Packaging Guide: https://wiki.alpinelinux.org/wiki/Creating_an_Alpine_package
