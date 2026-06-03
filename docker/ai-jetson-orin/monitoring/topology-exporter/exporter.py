import subprocess, json, time, os
from prometheus_client import start_http_server, Gauge

EDGE = Gauge('annogrid_topology_edge', 'Network edge between containers',
             ['source', 'target', 'source_node', 'target_node', 'network'])
NODE_INFO = Gauge('annogrid_topology_node', 'Container node info',
                  ['id', 'nodename', 'role'])

NODES = {
    'anno-app-opi3b-01':     os.getenv('OPI_IP',  '100.123.183.36'),
    'anno-nas-rpi3b-01':     os.getenv('NAS_IP',  '100.114.225.52'),
    'anno-gw-mon-rpi3b-01':  os.getenv('GW_IP',   '100.101.178.87'),
    'anno-ai-jetson-orin-01':os.getenv('ORIN_IP', '100.85.193.50'),
}

def get_containers(node, ip):
    try:
        r = subprocess.run(
            ['ssh', '-o', 'StrictHostKeyChecking=no',
             '-o', 'ConnectTimeout=5', '-o', 'BatchMode=yes',
             f'wanghley@{ip}',
             'docker ps -q | xargs -r docker inspect 2>/dev/null || echo "[]"'],
            capture_output=True, text=True, timeout=15)
        raw = r.stdout.strip()
        if not raw or raw == '[]':
            return []
        return json.loads(raw)
    except Exception as e:
        print(f"[{node}] SSH error: {e}")
        return []

def build_topology():
    EDGE.clear()
    NODE_INFO.clear()
    networks = {}

    for node, ip in NODES.items():
        for c in get_containers(node, ip):
            name = c.get('Name', '').lstrip('/')
            NODE_INFO.labels(id=name, nodename=node, role='container').set(1)
            for net, data in c.get('NetworkSettings', {}).get('Networks', {}).items():
                net_id = data.get('NetworkID', net)[:12]
                networks.setdefault(net_id, []).append((name, node, net))

    for net_id, members in networks.items():
        net_label = members[0][2] if members else net_id
        for i, (src, sn, _) in enumerate(members):
            for tgt, tn, _ in members[i+1:]:
                EDGE.labels(source=src, target=tgt,
                            source_node=sn, target_node=tn,
                            network=net_label).set(1)

    try:
        ts = subprocess.run(['tailscale', 'status', '--json'],
                            capture_output=True, text=True, timeout=5)
        peers = json.loads(ts.stdout).get('Peer', {})
        for _, p in peers.items():
            hn = p.get('HostName', '')
            if not hn:
                continue
            NODE_INFO.labels(id=hn, nodename=hn, role='node').set(1)
            EDGE.labels(source='anno-ai-jetson-orin-01', target=hn,
                        source_node='anno-ai-jetson-orin-01',
                        target_node=hn, network='tailscale').set(1)
    except Exception as e:
        print(f"Tailscale error: {e}")

if __name__ == '__main__':
    start_http_server(9200)
    print("Topology exporter on :9200")
    while True:
        build_topology()
        time.sleep(30)
