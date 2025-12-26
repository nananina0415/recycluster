#!/usr/bin/env python3
"""
RCCR (ReCyClusteR) 메인 셋업 스크립트
클러스터 노드 감지, 매핑 및 초기화를 담당합니다.
"""

import sys
import os
from pathlib import Path

# lib 디렉토리를 Python 경로에 추가
script_dir = Path(__file__).parent
sys.path.insert(0, str(script_dir))

from network_scanner import NetworkScanner
from node_mapper import NodeMapper


class RCCRSetup:
    """ReCyClusteR 셋업 메인 클래스"""

    def __init__(self, config_path: str = 'cluster_config.yml'):
        """
        Args:
            config_path: 클러스터 설정 파일 경로
        """
        # 설정 파일 경로 설정 (상대 경로를 절대 경로로 변환)
        if not os.path.isabs(config_path):
            # 스크립트의 부모 디렉토리(프로젝트 루트)를 기준으로
            project_root = Path(__file__).parent.parent
            config_path = project_root / config_path

        self.config_path = config_path
        self.mapper = NodeMapper(str(self.config_path))
        self.scanner = None

    def print_banner(self):
        """시작 배너를 출력합니다."""
        print("\n" + "=" * 67)
        print("  RCCR (ReCyClusteR) Setup")
        print("=" * 67)

    def initialize_scanner(self):
        """네트워크 스캐너를 초기화합니다."""
        network_config = self.mapper.get_network_config()
        subnet = network_config.get('subnet', '192.168.1.0/24')

        print(f"\n서브넷 {subnet} 를 스캔합니다...")
        self.scanner = NetworkScanner(subnet)

        print("초기 네트워크 스냅샷 생성 중...")
        self.scanner.take_snapshot()
        print(f"현재 {len(self.scanner.previous_hosts)}개의 호스트 감지됨.\n")

    def run_interactive_setup(self):
        """대화형 노드 매핑 프로세스를 실행합니다."""
        machines = self.mapper.get_machines()

        if not machines:
            print("오류: cluster_config.yml에 머신이 정의되어 있지 않습니다.")
            return False

        print(f"총 {len(machines)}개의 노드를 설정합니다.\n")

        for i, machine in enumerate(machines, 1):
            # 노드 정보 출력
            self.mapper.display_node_info(machine, i, len(machines))

            # 사용자에게 머신 연결 안내
            prompt = "\n머신을 연결(전원 켜기 또는 랜선 연결)하고 Enter를 누르세요... "
            detected_host = self.scanner.wait_for_new_host(prompt)

            if detected_host is None:
                print("오류: 새 호스트를 감지하지 못했습니다.")
                retry = input("다시 시도하시겠습니까? (y/n): ").strip().lower()
                if retry == 'y':
                    i -= 1  # 현재 노드를 다시 시도
                    continue
                else:
                    return False

            # 매핑 수행 및 확인
            mapping = self.mapper.map_host_to_node(machine, detected_host)
            self.mapper.confirm_mapping(mapping)

        # 매핑 요약 출력
        self.mapper.display_summary()

        # 계속 진행 확인
        confirm = input("계속하시겠습니까? (y/n): ").strip().lower()
        if confirm != 'y':
            print("\n셋업이 취소되었습니다.")
            return False

        return True

    def save_configuration(self):
        """설정을 파일로 저장합니다."""
        print("\n" + "=" * 67)
        print("설정 저장 중...")
        print("=" * 67)

        # 감지된 IP 주소를 cluster_config.yml에 저장
        self.mapper.save_detected_ips()

        return True

    def display_next_steps(self):
        """다음 단계 안내를 출력합니다."""
        print("\n" + "=" * 67)
        print("✓ RCCR 노드 매핑 완료!")
        print("=" * 67)
        print("\n다음 단계:")
        print("  1. Ansible playbook을 실행하여 클러스터를 초기화합니다")
        print("  2. 각 노드에 컨테이너가 배포됩니다")
        print("\n자동으로 다음 단계가 진행됩니다...\n")

    def run(self):
        """전체 셋업 프로세스를 실행합니다."""
        try:
            # 1. 배너 출력
            self.print_banner()

            # 2. 네트워크 스캐너 초기화
            self.initialize_scanner()

            # 3. 대화형 노드 매핑
            if not self.run_interactive_setup():
                return 1

            # 4. 설정 저장
            if not self.save_configuration():
                return 1

            # 5. 다음 단계 안내
            self.display_next_steps()

            return 0

        except KeyboardInterrupt:
            print("\n\n셋업이 사용자에 의해 중단되었습니다.")
            return 1
        except Exception as e:
            print(f"\n오류 발생: {e}")
            import traceback
            traceback.print_exc()
            return 1


def main():
    """메인 함수"""
    # 설정 파일 경로 (커맨드라인 인자로 받거나 기본값 사용)
    config_path = sys.argv[1] if len(sys.argv) > 1 else 'cluster_config.yml'

    # 셋업 실행
    setup = RCCRSetup(config_path)
    exit_code = setup.run()

    sys.exit(exit_code)


if __name__ == '__main__':
    main()
