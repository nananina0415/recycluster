# Raspberry Pi 수동 설치 가이드

가장 확실한 방법: Alpine 공식 이미지 + RCCR overlay

## 준비물

- Raspberry Pi (3/4/5)
- MicroSD 카드 (최소 2GB)
- 카드 리더기

## 설치 단계

### 1. SD 카드 포맷

**Windows:**
```powershell
# SD 카드를 FAT32로 포맷
# 디스크 관리 또는 Rufus 사용
```

**Linux/Mac:**
```bash
# SD 카드 확인
lsblk

# 포맷 (주의: /dev/sdX를 실제 SD 카드로 변경)
sudo mkfs.vfat -F 32 -n RCCR /dev/sdX1
```

### 2. Alpine 공식 이미지 다운로드

```bash
# Raspberry Pi 3/4/5 (64-bit)
wget http://dl-cdn.alpinelinux.org/alpine/v3.21/releases/aarch64/alpine-rpi-3.21.0-aarch64.tar.gz

# Raspberry Pi 2/3 (32-bit)
wget http://dl-cdn.alpinelinux.org/alpine/v3.21/releases/armv7/alpine-rpi-3.21.0-armv7.tar.gz

# Raspberry Pi 1/Zero
wget http://dl-cdn.alpinelinux.org/alpine/v3.21/releases/armhf/alpine-rpi-3.21.0-armhf.tar.gz
```

### 3. Alpine 파일을 SD 카드에 풀기

**Linux/Mac:**
```bash
# SD 카드 마운트
sudo mount /dev/sdX1 /mnt

# Alpine 압축 해제
sudo tar -xzf alpine-rpi-*.tar.gz -C /mnt/

# 확인
ls /mnt/
# 출력: apks  boot  ...
```

**Windows:**
- 7-Zip 또는 WinRAR로 tar.gz 압축 해제
- 압축 해제된 모든 파일을 SD 카드 루트에 복사

### 4. RCCR Overlay 생성

```bash
cd recycluster/image-profiles/control  # 또는 target

# Overlay 생성
bash genapkovl-rccr-control.sh ReCyClusteR-Node

# 출력: ReCyClusteR-Node.apkovl.tar.gz
```

### 5. Overlay를 SD 카드에 복사

```bash
# Linux/Mac
sudo cp ReCyClusteR-Node.apkovl.tar.gz /mnt/

# Windows: 파일 탐색기로 복사
```

### 6. SD 카드 언마운트

```bash
sudo umount /mnt
sync
```

### 7. 라즈베리파이 부팅

1. SD 카드를 라즈베리파이에 삽입
2. 전원 연결
3. 부팅 확인:
   - 빨간불: 전원 (쭉 켜짐)
   - 초록불: SD 카드 읽기 (깜빡이다가 꺼짐)

### 8. 로그인

```bash
# 시리얼 콘솔 또는 HDMI 연결
# 로그인: root (비밀번호 없음)

# SSH 접속 (IP 확인 후)
ssh root@<IP주소>
```

## 정상 부팅 확인

```bash
# 로그인 후 확인
hostname
# ReCyClusteR-Node

ls /root/rccr
# cluster_config.yml  setup.playbook  ...

which ansible
# /usr/bin/ansible  (Control 노드만)
```

## 문제 해결

### 부팅 안 됨 (노란불 계속 켜짐)

1. SD 카드를 FAT32로 다시 포맷
2. Alpine 파일 다시 풀기
3. Overlay 파일명 확인: `*.apkovl.tar.gz`

### Overlay 적용 안 됨

```bash
# 수동으로 overlay 적용
lbu pkg /media/mmcblk0p1/ReCyClusteR-Node.apkovl.tar.gz
setup-alpine
```

## 자동화 스크립트

```bash
#!/bin/bash
# install-to-sdcard.sh

SD_CARD="/dev/sdX1"  # ⚠️ 변경 필요
ALPINE_VERSION="3.21.0"
ARCH="aarch64"       # armv7 또는 armhf

# 1. 포맷
sudo mkfs.vfat -F 32 -n RCCR "$SD_CARD"

# 2. 마운트
sudo mount "$SD_CARD" /mnt

# 3. Alpine 다운로드 & 압축 해제
wget http://dl-cdn.alpinelinux.org/alpine/v3.21/releases/${ARCH}/alpine-rpi-${ALPINE_VERSION}-${ARCH}.tar.gz
sudo tar -xzf alpine-rpi-*.tar.gz -C /mnt/

# 4. Overlay 생성 & 복사
cd image-profiles/control
bash genapkovl-rccr-control.sh ReCyClusteR-Node
sudo cp ReCyClusteR-Node.apkovl.tar.gz /mnt/

# 5. 언마운트
sudo umount /mnt
sync

echo "✓ SD 카드 준비 완료!"
```

## 참고

- [Alpine Linux Raspberry Pi](https://wiki.alpinelinux.org/wiki/Raspberry_Pi)
- [Alpine Linux apkovl](https://wiki.alpinelinux.org/wiki/Alpine_local_backup)
