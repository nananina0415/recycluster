# Maintainer: nananina0415 <nananina0415@users.noreply.github.com>
pkgname=rccr
pkgver=0.0.1
pkgrel=0
pkgdesc="ReCyClusteR - Automated cluster setup tool with network discovery"
url="https://github.com/nananina0415/recycluster"
arch="noarch"
license="MIT"
depends="
    python3
    py3-pip
    py3-yaml
    nmap
    openssh-client
    sshpass
    "
makedepends=""
install=""
subpackages=""
source="
    rccr-$pkgver.tar.gz
    "
builddir="$srcdir/rccr-$pkgver"

build() {
    # Python 패키지는 빌드 불필요
    return 0
}

check() {
    # 기본 import 테스트
    python3 -c "import yaml" || return 1
    return 0
}

package() {
    # 설치 디렉토리 생성
    install -dm755 "$pkgdir/usr/share/rccr"
    install -dm755 "$pkgdir/usr/share/rccr/lib"
    install -dm755 "$pkgdir/usr/share/rccr/machine_layer"
    install -dm755 "$pkgdir/usr/share/rccr/container_layer"
    install -dm755 "$pkgdir/usr/share/rccr/orchestration_layer"
    install -dm755 "$pkgdir/usr/bin"

    # Python 라이브러리 복사
    install -m644 "$builddir/lib/__init__.py" "$pkgdir/usr/share/rccr/lib/"
    install -m644 "$builddir/lib/network_scanner.py" "$pkgdir/usr/share/rccr/lib/"
    install -m644 "$builddir/lib/node_mapper.py" "$pkgdir/usr/share/rccr/lib/"
    install -m644 "$builddir/lib/rccr_setup.py" "$pkgdir/usr/share/rccr/lib/"

    # Playbook 파일 복사
    install -m644 "$builddir/deploy_cluster.playbook" "$pkgdir/usr/share/rccr/"
    install -m644 "$builddir/setup.playbook" "$pkgdir/usr/share/rccr/"

    if [ -f "$builddir/machine_layer/main.playbook" ]; then
        install -m644 "$builddir/machine_layer/main.playbook" "$pkgdir/usr/share/rccr/machine_layer/"
    fi

    if [ -f "$builddir/machine_layer/init_starter_machine.playbook" ]; then
        install -m644 "$builddir/machine_layer/init_starter_machine.playbook" "$pkgdir/usr/share/rccr/machine_layer/"
    fi

    # 설정 파일 템플릿 복사
    install -m644 "$builddir/cluster_config.yml" "$pkgdir/usr/share/rccr/"

    # 실행 파일 설치
    install -m755 "$builddir/bin/rccr" "$pkgdir/usr/bin/rccr"

    # 문서 복사
    if [ -f "$builddir/README.md" ]; then
        install -dm755 "$pkgdir/usr/share/doc/rccr"
        install -m644 "$builddir/README.md" "$pkgdir/usr/share/doc/rccr/"
    fi

    if [ -f "$builddir/LICENSE" ]; then
        install -dm755 "$pkgdir/usr/share/licenses/rccr"
        install -m644 "$builddir/LICENSE" "$pkgdir/usr/share/licenses/rccr/"
    fi
}

sha512sums=""  # abuild checksum으로 자동 생성
