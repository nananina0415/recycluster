#!/usr/bin/env python3
"""
노드 매퍼 모듈
감지된 호스트를 클러스터 설정 파일의 노드와 매핑하고 대화형 UI를 제공합니다.
"""

import yaml
from typing import List, Dict, Optional
from pathlib import Path


class NodeMapper:
    """클러스터 설정과 감지된 호스트를 매핑하는 클래스"""

    def __init__(self, config_path: str):
        """
        Args:
            config_path: cluster_config.yml 파일 경로
        """
        self.config_path = Path(config_path)
        self.cluster_config = self._load_config()
        self.node_mappings: List[Dict] = []

    def _load_config(self) -> Dict:
        """클러스터 설정 파일을 로드합니다."""
        try:
            with open(self.config_path, 'r', encoding='utf-8') as f:
                config = yaml.safe_load(f)
            return config
        except FileNotFoundError:
            print(f"오류: 설정 파일을 찾을 수 없습니다: {self.config_path}")
            raise
        except yaml.YAMLError as e:
            print(f"오류: YAML 파싱 실패 - {e}")
            raise

    def get_machines(self) -> List[Dict]:
        """설정 파일에 정의된 머신 목록을 반환합니다."""
        return self.cluster_config.get('machines', [])

    def get_network_config(self) -> Dict:
        """네트워크 설정을 반환합니다."""
        return self.cluster_config.get('network_config', {})

    def display_node_info(self, node: Dict, index: int, total: int) -> None:
        """
        노드 정보를 예쁘게 포맷하여 출력합니다.

        Args:
            node: 노드 설정 딕셔너리
            index: 현재 노드 인덱스 (1부터 시작)
            total: 전체 노드 수
        """
        print("\n┌─────────────────────────────────────────────────────────────────┐")
        print(f"│ [{index}/{total}] 다음 노드를 네트워크에 연결해주세요" + " " * 22 + "│")
        print("├─────────────────────────────────────────────────────────────────┤")
        print(f"│ 노드명:       {node['name']:<48}│")
        print(f"│ 할당 IP:      {node['ip']:<48}│")
        print(f"│ 역할:         {node['role']:<48}│")

        # 컨테이너 목록 출력
        containers = node.get('containers', [])
        if containers:
            print(f"│ 컨테이너:     - {containers[0]:<46}│")
            for container in containers[1:]:
                print(f"│              - {container:<46}│")
        else:
            print(f"│ 컨테이너:     (없음){' ' * 42}│")

        print("└─────────────────────────────────────────────────────────────────┘")

    def map_host_to_node(self, node: Dict, detected_host: Dict) -> Dict:
        """
        감지된 호스트를 노드 설정과 매핑합니다.

        Args:
            node: 노드 설정 딕셔너리
            detected_host: 감지된 호스트 정보

        Returns:
            매핑 정보 딕셔너리
        """
        mapping = {
            'node_name': node['name'],
            'configured_ip': node['ip'],
            'detected_ip': detected_host['ip'],
            'mac': detected_host['mac'],
            'hostname': detected_host['hostname'],
            'role': node['role'],
            'containers': node.get('containers', [])
        }

        # IP가 설정과 다른 경우 경고
        if node['ip'] != detected_host['ip']:
            print(f"\n⚠ 경고: 감지된 IP ({detected_host['ip']})가 설정 파일의 IP ({node['ip']})와 다릅니다.")
            print(f"   → 감지된 IP를 사용합니다: {detected_host['ip']}")
            mapping['ip_mismatch'] = True
        else:
            mapping['ip_mismatch'] = False

        self.node_mappings.append(mapping)
        return mapping

    def confirm_mapping(self, mapping: Dict) -> bool:
        """
        매핑 결과를 사용자에게 확인받습니다.

        Args:
            mapping: 매핑 정보

        Returns:
            사용자가 확인한 경우 True
        """
        print(f"\n✓ 새 호스트 감지: {mapping['detected_ip']} (MAC: {mapping['mac']})")
        print(f"✓ {mapping['node_name']} → {mapping['detected_ip']} 매핑 완료")
        return True

    def display_summary(self) -> None:
        """전체 매핑 결과를 요약하여 출력합니다."""
        print("\n" + "=" * 67)
        print("클러스터 노드 매핑 완료!")
        print("=" * 67)
        print("\n감지된 노드 요약:")

        for i, mapping in enumerate(self.node_mappings, 1):
            print(f"  {i}. {mapping['node_name']} ({mapping['detected_ip']}) - {mapping['role']}")
            containers = mapping.get('containers', [])
            if containers:
                print(f"     └─ {', '.join(containers)}")

        print()

    def generate_inventory(self) -> str:
        """
        Ansible 동적 인벤토리를 생성합니다.

        Returns:
            인벤토리 내용 (YAML 형식)
        """
        inventory = {
            'all': {
                'hosts': {},
                'children': {
                    'managers': {'hosts': {}},
                    'workers': {'hosts': {}}
                }
            }
        }

        for mapping in self.node_mappings:
            host_vars = {
                'ansible_host': mapping['detected_ip'],
                'ansible_user': 'root',  # 필요에 따라 수정
                'node_role': mapping['role'],
                'containers': mapping.get('containers', [])
            }

            # all.hosts에 추가
            inventory['all']['hosts'][mapping['node_name']] = host_vars

            # 역할별 그룹에 추가
            if mapping['role'] == 'manager':
                inventory['all']['children']['managers']['hosts'][mapping['node_name']] = None
            elif mapping['role'] == 'worker':
                inventory['all']['children']['workers']['hosts'][mapping['node_name']] = None

        return yaml.dump(inventory, default_flow_style=False, allow_unicode=True)

    def save_inventory(self, output_path: str = 'inventory.yml') -> None:
        """
        생성된 인벤토리를 파일로 저장합니다.

        Args:
            output_path: 저장할 파일 경로
        """
        inventory_content = self.generate_inventory()

        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(inventory_content)

        print(f"✓ 인벤토리 파일 저장 완료: {output_path}")


if __name__ == '__main__':
    # 테스트 코드
    mapper = NodeMapper('cluster_config.yml')

    print("클러스터 설정:")
    machines = mapper.get_machines()
    for i, machine in enumerate(machines, 1):
        mapper.display_node_info(machine, i, len(machines))

    # 테스트 매핑
    test_host = {
        'ip': '192.168.219.201',
        'mac': 'aa:bb:cc:dd:ee:ff',
        'hostname': 'test-device'
    }

    if machines:
        mapping = mapper.map_host_to_node(machines[0], test_host)
        mapper.confirm_mapping(mapping)

    mapper.display_summary()

    # 인벤토리 생성 테스트
    print("\n생성된 인벤토리:")
    print(mapper.generate_inventory())
