#!/bin/bash
# APK 패키지 빌드 스크립트

set -e

# 변수 설정
PKGNAME="rccr"
PKGVER="0.0.1"
BUILDDIR="build"

echo "==================================================================="
echo "  RCCR APK 패키지 빌드"
echo "==================================================================="

# 빌드 디렉토리 생성
echo "→ 빌드 디렉토리 준비 중..."
rm -rf "$BUILDDIR"
mkdir -p "$BUILDDIR/$PKGNAME-$PKGVER"

# 필요한 파일 복사
echo "→ 파일 복사 중..."
cp -r lib "$BUILDDIR/$PKGNAME-$PKGVER/"
cp -r bin "$BUILDDIR/$PKGNAME-$PKGVER/"
cp -r machine_layer "$BUILDDIR/$PKGNAME-$PKGVER/"
cp -r container_layer "$BUILDDIR/$PKGNAME-$PKGVER/"
cp -r orchestration_layer "$BUILDDIR/$PKGNAME-$PKGVER/"
cp cluster_config.yml "$BUILDDIR/$PKGNAME-$PKGVER/"
cp deploy_cluster.playbook "$BUILDDIR/$PKGNAME-$PKGVER/"
cp setup.playbook "$BUILDDIR/$PKGNAME-$PKGVER/"
cp README.md "$BUILDDIR/$PKGNAME-$PKGVER/"
cp LICENSE "$BUILDDIR/$PKGNAME-$PKGVER/"

# tar.gz 아카이브 생성
echo "→ 아카이브 생성 중..."
cd "$BUILDDIR"
tar -czf "$PKGNAME-$PKGVER.tar.gz" "$PKGNAME-$PKGVER"
cd ..

# APKBUILD 파일 복사
echo "→ APKBUILD 파일 복사 중..."
cp APKBUILD "$BUILDDIR/"

echo ""
echo "✓ 빌드 준비 완료!"
echo ""
echo "다음 단계:"
echo "  1. Alpine Linux 빌드 환경으로 이동"
echo "  2. abuild-keygen -a -i  # 키 생성 (최초 1회)"
echo "  3. cd build/"
echo "  4. abuild checksum      # 체크섬 생성"
echo "  5. abuild -r            # 패키지 빌드"
echo ""
echo "로컬 테스트:"
echo "  sudo apk add --allow-untrusted ~/packages/main/x86_64/$PKGNAME-$PKGVER-r0.apk"
echo ""
echo "빌드된 패키지:"
echo "  ~/packages/main/<arch>/$PKGNAME-$PKGVER-r0.apk"
echo ""
