FROM python:3.11-alpine

LABEL org.opencontainers.image.source="https://github.com/nananina0415/recycluster"
LABEL org.opencontainers.image.description="RCCR - Alpine Linux cluster setup tool"
LABEL org.opencontainers.image.licenses="MIT"

# 필수 패키지 설치
RUN apk add --no-cache \
    nmap \
    openssh-client \
    sshpass \
    ansible \
    bash

# 작업 디렉토리 설정
WORKDIR /app

# Python 의존성 설치
RUN pip install --no-cache-dir pyyaml

# 애플리케이션 파일 복사
COPY lib/ /app/lib/
COPY bin/rccr /app/bin/rccr
COPY *.playbook /app/
COPY machine_layer/ /app/machine_layer/
COPY container_layer/ /app/container_layer/
COPY orchestration_layer/ /app/orchestration_layer/
COPY cluster_config.yml /app/cluster_config.yml
COPY README.md /app/README.md
COPY LICENSE /app/LICENSE

# 실행 권한 설정
RUN chmod +x /app/bin/rccr

# PATH 및 PYTHONPATH 설정
ENV PATH="/app/bin:${PATH}"
ENV PYTHONPATH="/app/lib:${PYTHONPATH}"

# 작업 디렉토리를 /workspace로 변경 (사용자 파일 마운트용)
WORKDIR /workspace

# 기본 명령어
ENTRYPOINT ["python3", "/app/bin/rccr"]
CMD ["help"]
