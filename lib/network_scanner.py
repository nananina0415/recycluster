#!/usr/bin/env python3
"""
네트워크 스캐너 모듈
서브넷 내의 활성 호스트를 감지하고 스냅샷 비교를 통해 새로 추가된 호스트를 식별합니다.
"""

import subprocess
import re
from typing import List, Dict, Set
import xml.etree.ElementTree as ET


class NetworkScanner:
    """네트워크 스캔 및 호스트 감지를 담당하는 클래스"""

    def __init__(self, subnet: str):
        """
        Args:
            subnet: 스캔할 서브넷 (예: "192.168.219.0/24")
        """
        self.subnet = subnet
        self.previous_hosts: Set[str] = set()

    def scan_network(self) -> List[Dict[str, str]]:
        """
        네트워크를 스캔하여 활성 호스트 목록을 반환합니다.

        Returns:
            호스트 정보 딕셔너리 리스트
            [{"ip": "192.168.1.100", "mac": "aa:bb:cc:dd:ee:ff", "hostname": "device1"}, ...]
        """
        try:
            # nmap을 사용하여 네트워크 스캔 (-sn: ping scan, -oX -: XML 출력)
            result = subprocess.run(
                ['nmap', '-sn', '-oX', '-', self.subnet],
                capture_output=True,
                text=True,
                timeout=60
            )

            if result.returncode != 0:
                print(f"경고: nmap 스캔 실패 (리턴코드 {result.returncode})")
                return []

            # XML 파싱
            hosts = self._parse_nmap_xml(result.stdout)
            return hosts

        except subprocess.TimeoutExpired:
            print("경고: 네트워크 스캔 시간 초과")
            return []
        except FileNotFoundError:
            print("오류: nmap이 설치되어 있지 않습니다. 'apt-get install nmap' 또는 'yum install nmap'으로 설치하세요.")
            return []
        except Exception as e:
            print(f"오류: 네트워크 스캔 중 예외 발생 - {e}")
            return []

    def _parse_nmap_xml(self, xml_output: str) -> List[Dict[str, str]]:
        """
        nmap XML 출력을 파싱하여 호스트 정보를 추출합니다.

        Args:
            xml_output: nmap의 XML 형식 출력

        Returns:
            호스트 정보 딕셔너리 리스트
        """
        hosts = []

        try:
            root = ET.fromstring(xml_output)

            for host in root.findall('host'):
                # 호스트가 up 상태인지 확인
                status = host.find('status')
                if status is None or status.get('state') != 'up':
                    continue

                # IP 주소 추출
                address_elem = host.find("address[@addrtype='ipv4']")
                if address_elem is None:
                    continue
                ip = address_elem.get('addr')

                # MAC 주소 추출 (존재하는 경우)
                mac_elem = host.find("address[@addrtype='mac']")
                mac = mac_elem.get('addr') if mac_elem is not None else 'N/A'

                # 호스트명 추출 (존재하는 경우)
                hostname_elem = host.find('hostnames/hostname')
                hostname = hostname_elem.get('name') if hostname_elem is not None else 'Unknown'

                hosts.append({
                    'ip': ip,
                    'mac': mac,
                    'hostname': hostname
                })

        except ET.ParseError as e:
            print(f"경고: XML 파싱 오류 - {e}")

        return hosts

    def take_snapshot(self) -> None:
        """현재 네트워크 상태의 스냅샷을 저장합니다."""
        hosts = self.scan_network()
        self.previous_hosts = {host['ip'] for host in hosts}

    def get_new_hosts(self) -> List[Dict[str, str]]:
        """
        이전 스냅샷 이후 새로 추가된 호스트를 감지합니다.

        Returns:
            새로 추가된 호스트 정보 리스트
        """
        current_hosts = self.scan_network()
        current_ips = {host['ip'] for host in current_hosts}

        # 새로 추가된 IP 찾기
        new_ips = current_ips - self.previous_hosts

        # 새로운 IP에 해당하는 호스트 정보 반환
        new_hosts = [host for host in current_hosts if host['ip'] in new_ips]

        return new_hosts

    def wait_for_new_host(self, prompt_message: str = "머신을 연결하고 Enter를 누르세요...") -> Dict[str, str]:
        """
        사용자에게 머신 연결을 안내하고 새로운 호스트가 감지될 때까지 대기합니다.

        Args:
            prompt_message: 사용자에게 표시할 프롬프트 메시지

        Returns:
            감지된 새 호스트 정보
        """
        input(prompt_message)

        print("▶ 네트워크 스캔 중...")
        new_hosts = self.get_new_hosts()

        if len(new_hosts) == 0:
            print("경고: 새로운 호스트가 감지되지 않았습니다.")
            return None
        elif len(new_hosts) > 1:
            print(f"경고: 여러 개의 새 호스트가 감지되었습니다 ({len(new_hosts)}개). 첫 번째 호스트를 사용합니다.")

        # 스냅샷 업데이트 (감지된 호스트를 이전 목록에 추가)
        for host in new_hosts:
            self.previous_hosts.add(host['ip'])

        return new_hosts[0]


if __name__ == '__main__':
    # 테스트 코드
    scanner = NetworkScanner("192.168.219.0/24")

    print("초기 네트워크 스냅샷 생성 중...")
    scanner.take_snapshot()
    print(f"현재 감지된 호스트: {len(scanner.previous_hosts)}개")

    print("\n새 호스트를 연결하고 Enter를 누르세요...")
    new_host = scanner.wait_for_new_host()

    if new_host:
        print(f"\n✓ 새 호스트 감지:")
        print(f"  IP: {new_host['ip']}")
        print(f"  MAC: {new_host['mac']}")
        print(f"  Hostname: {new_host['hostname']}")
