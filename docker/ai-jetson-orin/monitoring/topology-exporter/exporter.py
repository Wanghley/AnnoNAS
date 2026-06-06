import subprocess, json, time, os
import yaml
from prometheus_client import start_http_server, Gauge

CONFIG_PATH = os.getenv('NODES_CONFIG', '/etc/topology/nodes.yml')
SSH_KEY = '/root/.ssh/annogrid_topology'

# Full arc role palette — extend here and in the dashboard when adding new colors
PALETTE = ['host', 'opi3b', 'nas', 'gateway', 'orin', 'rpi4', 'rpi5', 'x86']

EDGE = Gauge('annogrid_topology_edge', 'Network edge between containers',
             ['id', 'source', 'target', 'source_node', 'target_node', 'network'])
NODE_INFO = Gauge('annogrid_topology_node', 'Container node info',
                  ['id', 'title', 'subTitle', 'mainStat'] +
                  [f'arc__{r}' for r in PALETTE])


def load_config():
    with open(CONFIG_PATH) as f:
        cfg = yaml.safe_load(f)
    return cfg.get('hosts', {})


def arc(role):
    known = role if role in PALETTE else 'host'
    return {f'arc__{r}': ('1' if r == known else '0') for r in PALETTE}


def ssh(user, ip, cmd):
    r = subprocess.run(
        ['ssh', '-i', SSH_KEY,
         '-o', 'StrictHostKeyChecking=no',
         '-o', 'ConnectTimeout=5',
         '-o', 'BatchMode=yes',
         f'{user}@{ip}', cmd],
        capture_output=True, text=True, timeout=20)
    return r.stdout.strip(), r.stderr.strip()


def get_containers(node, user, ip):
    try:
        ids_out, _ = ssh(user, ip, 'docker ps -q')
        if not ids_out:
            return []
        containers = []
        for cid in ids_out.splitlines():
            out, _ = ssh(user, ip, f'docker inspect {cid}')
            if out:
                data = json.loads(out)
                if data:
                    containers.append(data[0])
        print(f"[{node}] found {len(containers)} containers")
        return containers
    except Exception as e:
        print(f"[{node}] error: {e}")
        return []


def build_topology():
    try:
        nodes = load_config()
    except Exception as e:
        print(f"Config reload error: {e} — using empty host list")
        nodes = {}

    pending_nodes = []
    pending_edges = []
    networks = {}

    for node, cfg in nodes.items():
        user     = cfg['user']
        ip       = cfg['ip']
        role     = cfg.get('arc_role', 'host')
        display  = cfg.get('display', node)

        pending_nodes.append(dict(
            id=node, title=display, subTitle=ip, mainStat=ip, **arc('host')
        ))

        for c in get_containers(node, user, ip):
            name      = c.get('Name', '').lstrip('/')
            unique_id = f"{node}/{name}"
            pending_nodes.append(dict(
                id=unique_id, title=name, subTitle=display, mainStat=name, **arc(role)
            ))
            pending_edges.append(dict(
                id=f"{node}>{unique_id}",
                source=node, target=unique_id,
                source_node=node, target_node=node,
                network='host',
            ))
            for net, data in c.get('NetworkSettings', {}).get('Networks', {}).items():
                net_id = data.get('NetworkID', net)[:12]
                networks.setdefault(net_id, []).append((unique_id, node, net))

    for net_id, members in networks.items():
        net_label = members[0][2] if members else net_id
        for i, (src, sn, _) in enumerate(members):
            for tgt, tn, _ in members[i+1:]:
                pending_edges.append(dict(
                    id=f"{src}>{tgt}",
                    source=src, target=tgt,
                    source_node=sn, target_node=tn,
                    network=net_label,
                ))

    EDGE.clear()
    NODE_INFO.clear()
    for labels in pending_nodes:
        NODE_INFO.labels(**labels).set(1)
    for labels in pending_edges:
        EDGE.labels(**labels).set(1)

    total = sum(len(m) for m in networks.values())
    print(f"Topology built: {len(nodes)} hosts, {len(pending_nodes)} nodes, "
          f"{len(pending_edges)} edges ({len(networks)} docker networks, {total} memberships)")


if __name__ == '__main__':
    start_http_server(9200)
    print(f"Topology exporter on :9200 — config: {CONFIG_PATH}")
    while True:
        build_topology()
        time.sleep(30)
