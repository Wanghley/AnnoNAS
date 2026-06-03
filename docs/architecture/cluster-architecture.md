# AnnoGrid: Technical Architecture & Design Decisions

---

## 🏛️ Architecture Overview

### Design Philosophy

AnnoGrid is built on **three core principles**:

1. **Modularity** - Each node has a single, well-defined purpose
2. **Observability** - Metrics and logs from day one
3. **Scalability** - Design patterns that scale from 3 nodes to 30+

### Architectural Layers

```
┌─────────────────────────────────────────────────────┐
│         Application Layer (Services)                 │
│  Web Servers | APIs | Databases | AI Models | Media │
└──────────────────┬──────────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────────┐
│      Container Layer (Docker & Compose)             │
│  Isolation | Resource Limits | Volume Management    │
└──────────────────┬──────────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────────┐
│      Operating System Layer (Linux)                 │
│  Armbian | Raspberry Pi OS | Ubuntu (Jetson)       │
└──────────────────┬──────────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────────┐
│      Hardware Layer (SBCs)                          │
│  Orange Pi | Raspberry Pi | Jetson Orin Nano       │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│      CROSS-CUTTING CONCERNS                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐          │
│  │Monitoring│  │Networking│  │ Security │          │
│  └──────────┘  └──────────┘  └──────────┘          │
│  Prometheus   Tailscale VPN   SSH Keys + Firewall  │
└─────────────────────────────────────────────────────┘
```

---

## 🔌 Node Roles & Responsibilities

### Application Node (anno-app-opi3bp-01)
**Purpose**: Run user-facing services and applications

**Responsibilities:**
- Host web servers (nginx, Apache)
- Run API services
- Execute scheduled jobs
- Serve dynamic content

**Design Decisions:**
- Dedicated to app workloads (no storage)
- Fast microSD for container boot times
- Sufficient RAM for multiple containers
- Connected to NAS for persistent data

**Failure Impact**: Medium (applications offline, data safe on NAS)

---

### AI/ML Node (anno-ai-jetson-orin-nano-01)
**Purpose**: GPU-accelerated machine learning workloads

**Responsibilities:**
- Model inference (TensorFlow, PyTorch)
- Computer vision tasks
- Real-time data processing
- Edge analytics

**Design Decisions:**
- Separate from general compute (GPU resources)
- Large RAM for model loading (8GB)
- Fast NVMe storage for model files
- CUDA toolkit and cuDNN pre-installed
- Direct GPU metrics in monitoring

**Failure Impact**: Low (optional workload, cluster continues)

---

### Storage Node (anno-nas-rpi3bp-01)
**Purpose**: Centralized persistent storage

**Responsibilities:**
- File server (SMB/NFS)
- Backup destination
- Database storage (if applicable)
- Media library

**Design Decisions:**
- Large external USB drives (2× 2TB)
- Samba server for cross-platform access
- NFS for Linux clients
- Rsync for backup automation
- Separate from compute nodes

**Failure Impact**: Critical (data loss risk, must backup)

---

### Gateway & Monitoring Node (anno-gw-mon-rpi3bp-01)
**Purpose**: Central nervous system of the cluster

**Responsibilities:**
- Prometheus metrics collection
- Grafana visualization
- Alert management
- Tailscale VPN endpoint
- Cloudflare Tunnel ingress
- SSH bastion for management

**Design Decisions:**
- Single point of monitoring truth
- Central alerting and decision point
- Network ingress/egress point
- Run metrics collection locally (no remote scraping)
- Redundancy planned for Phase 2

**Failure Impact**: Critical (lose observability, lose external access)

---

## 🌐 Network Architecture

### Physical Network

```
┌─────────────────────────────────────────────┐
│         TP-Link AX1500 Router               │
│  • DHCP Server (192.168.1.0/24)             │
│  • WiFi & Ethernet gateway                  │
│  • DNS delegation (1.1.1.1, 8.8.8.8)        │
└────────────────┬────────────────────────────┘
                 │ Ethernet (1 Gbps)
                 │
         ┌───────▼────────┐
         │  TP-Link       │
         │  TL-SG608      │
         │  8-Port Switch │
         │  (Managed)     │
         └┬──┬──┬────┬────┘
      ┌──┘  │  │    └────┬─────┐
      │     │  │         │     │
   ┌──▼──┐┌─▼──┐┌───────┘┐┌───▼──┐
   │App  ││ AI ││  NAS   ││Gate/ │
   │Node ││Node││ Node   ││Mon   │
   └─────┘└────┘└────────┘└──────┘
```

**Design Decisions:**
- Managed switch enables future VLANs
- Gigabit Ethernet (no WiFi for production nodes)
- WiFi option available as backup
- Star topology (resilient to cable issues)

### Logical Network Layers

**Layer 1: Local Network**
- Standard Ethernet connectivity
- Static IPs for all AnnoGrid nodes
- DHCP pool for temporary/guest devices
- Multicast DNS (mDNS) for .local names

**Layer 2: Tailscale VPN**
- Encrypted mesh network between all nodes
- 100.x.x.x address space
- Works through NAT and firewalls
- MagicDNS for service discovery
- Exit node disabled (internal only)

**Layer 3: Cloudflare Tunnel**
- Secure ingress from internet
- No port forwarding needed
- Custom domain (yourdomain.com)
- DDoS protection included
- SSL/TLS automatically managed

### Network Security Model

```
┌────────────────────────────────────────┐
│  Internet / Untrusted Network          │
│         (WAN)                          │
└──────────────┬─────────────────────────┘
               │
        ┌──────▼──────────────┐
        │ Cloudflare Tunnel   │
        │ (TLS Encrypted)     │
        │ DDoS Protection     │
        └──────┬──────────────┘
               │
        ┌──────▼──────────────────────────┐
        │ Gateway Node External Interface │
        │ (Restricted Ports Only)         │
        └──────┬──────────────────────────┘
               │
        ┌──────▼──────────────────────────┐
        │  Tailscale VPN Mesh             │
        │  (Encrypted End-to-End)         │
        │  MagicDNS Service Discovery     │
        └──────┬──────────────────────────┘
               │
    ┌──────────┼──────────┬─────────┐
    │          │          │         │
 ┌──▼───┐  ┌──▼───┐  ┌───▼──┐  ┌──▼───┐
 │ App  │  │ AI   │  │ NAS  │  │ Gate/│
 │ Node │  │ Node │  │ Node │  │ Mon  │
 └──────┘  └──────┘  └──────┘  └──────┘
    ↑        ↑         ↑          ↑
    └────────┴─────────┴──────────┘
       Local Network (192.168.1.0/24)
       Ethernet via Switch
```

**Design Decisions:**
- **No direct internet exposure** - Tailscale always encrypted
- **Cloudflare as WAF** - Protects against DDoS and attacks
- **SSH key authentication** - No password-based access
- **Per-node firewall rules** - Defense in depth
- **Network segmentation ready** - VLANs can be added later

---

## 🐳 Container Architecture

### Docker Compose Strategy

**Per-Node Deployment Model:**
```
Each node runs its own docker-compose.yml

anno-app-opi3bp-01/docker-compose.yml
├── App service 1
├── App service 2
└── Supporting services

anno-ai-jetson-orin-nano-01/docker-compose.yml
├── AI/ML service 1
├── Model serving
└── GPU monitoring

anno-nas-rpi3bp-01/docker-compose.yml
├── Samba (SMB)
├── NFS server
└── Backup automation

anno-gw-mon-rpi3bp-01/docker-compose.yml
├── Prometheus
├── Grafana
├── Alert Manager
├── Loki (optional)
└── Tailscale/Cloudflare agents
```

**Design Decisions:**
- Decentralized deployment (no Kubernetes yet)
- Each node independent
- Shared services only via network
- Easy to troubleshoot (logs per node)
- Simple to understand (no abstraction)

### Volume Strategy

**Container Data Persistence:**

```
Named Volumes (Docker managed):
├── Container-specific data
├── Lives in /var/lib/docker/volumes/
├── Backed up as group
└── Easy to migrate

Bind Mounts (Host filesystem):
├── /etc/docker/ → Docker daemon config
├── /var/log/ → Container logs
├── /mnt/storage/ → NAS mounts
└── Configuration files

NFS/SMB Mounts (Network):
├── /mnt/shared-data/
├── /mnt/backups/
└── /media/ (for media server)
```

**Design Decisions:**
- Named volumes for stateful services (databases, caches)
- Bind mounts for configuration (version controlled)
- Network mounts for shared data (redundancy)
- Regular volume backups (automated scripts)

### Networking Model

**Container-to-Container Communication:**

```
Same Node:
  Container A ──(docker network)──> Container B
  Fast (~1ms latency)

Different Nodes:
  App Container ──(Tailscale VPN)──> Storage Service
  Encrypted, ~5-10ms latency

External Access:
  Internet ──(Cloudflare Tunnel)──> Gateway Container
  TLS encrypted, ~100ms latency
```

**Design Decisions:**
- Bridge network for same-node services
- Host network for VPN daemons (Tailscale)
- Explicit port mappings (security)
- Service names via Tailscale MagicDNS

---

## 📊 Monitoring & Observability Architecture

### Metrics Collection Stack

```
┌───────────────────────────────────────────┐
│  Each Node (4×)                           │
│  ├── Node Exporter (port :9100)           │
│  │   └─ System metrics (CPU, RAM, disk)   │
│  │                                        │
│  └── Docker Stats (via daemon)            │
│      └─ Container metrics                 │
└────────────────┬────────────────────────┤
                 │                         │
            (Tailscale VPN)                │
                 │                         │
        ┌────────▼──────────┐              │
        │  Prometheus       │              │
        │  (Gateway Node)   │              │
        │                  │              │
        │  Scrape Interval: 15s            │
        │  Retention: 30 days              │
        │  Storage: ~500MB/month           │
        └────────┬──────────┘              │
                 │                         │
        ┌────────▼──────────┐              │
        │  Alert Manager    │              │
        │  Rules evaluation │              │
        │  Notification     │              │
        └────────┬──────────┘              │
                 │                         │
        ┌────────▼──────────┐              │
        │  Grafana          │              │
        │  Dashboards       │              │
        │  Visualization    │              │
        └───────────────────┘              │
```

**Metrics Categories:**
- **System**: CPU, memory, disk, network, temperature
- **Docker**: Container count, running status, resource limits
- **Application**: Request rates, latency, errors (custom)
- **GPU** (AI node): Utilization, memory, temperature, model inference
- **Network**: Bandwidth, packet loss, latency
- **Storage**: I/O operations, free space, replication status

### Alerting Rules

**Critical Alerts** (Immediate action):
- Node down (no metrics for 5 minutes)
- Disk full (>95%)
- Out of memory (>95%)
- High temperature (>75°C)

**Warning Alerts** (Investigate soon):
- High CPU (>80% for 5+ min)
- Disk usage >80%
- Reachability issues
- High error rates (>5%)

**Informational Alerts** (Track trends):
- Capacity utilization increases
- Performance degradation
- Backup failures

---

## 🔐 Security Architecture

### Defense in Depth Model

```
Layer 1: Network Perimeter
├── No ports open to internet
├── Cloudflare DDoS protection
└── Rate limiting

Layer 2: Encryption
├── Tailscale VPN (everything encrypted)
├── SSH with keys (no password)
└── TLS for web services

Layer 3: Access Control
├── SSH key authentication
├── Firewall rules per node
└── Service isolation (containers)

Layer 4: Monitoring
├── All access logged
├── Network traffic monitored
└── File integrity checks (optional)

Layer 5: Data Protection
├── Regular backups
├── Off-site storage
└── Encryption at rest (optional)
```

### SSH Key Architecture

**Centralized Key Management:**
```
~/.ssh/
├── id_rsa (private key, local machine)
├── id_rsa.pub (public key)
└── authorized_keys (deployed to all nodes)

On Each Node:
~/.ssh/authorized_keys
├── Your public key
├── Admin key
└── Automation keys (for scripts)

Key Rotation:
├── Quarterly rotation
├── Old key revocation
└── Emergency key replacement procedure
```

**Design Decisions:**
- SSH keys only (no passwords on nodes)
- Central key file (git-tracked, .gitignore protection)
- Separate automation keys
- Easy revocation (edit authorized_keys)

### Firewall Strategy

**Per-Node Rules (nftables):**

```
App Node (anno-app-opi3bp-01):
├── Allow SSH (port 22, local network only)
├── Allow Docker services (specific ports)
├── Allow Tailscale (UDP 41641)
└── Deny everything else

AI Node (anno-ai-jetson-orin-nano-01):
├── Allow SSH (local network)
├── Allow GPU metrics (port 9100)
├── Allow Tailscale
├── Allow API services (as configured)
└── Deny everything else

NAS Node (anno-nas-rpi3bp-01):
├── Allow SSH (local network)
├── Allow SMB (445, local network only)
├── Allow NFS (111, 2049, local network only)
├── Allow metrics (9100)
└── Deny everything else

Gateway Node (anno-gw-mon-rpi3bp-01):
├── Allow SSH (local network)
├── Allow Prometheus (9090, local network)
├── Allow Grafana (3000, Tailscale + Cloudflare)
├── Allow Tailscale (UDP 41641)
├── Allow Cloudflare (as defined in tunnel config)
└── Deny everything else
```

---

## 📦 Backup & Recovery Architecture

### 3-2-1 Backup Strategy

```
Local Copies (3):
├── Primary data (NAS drive 1)
├── Backup copy (NAS drive 2)
└── Weekly sync to USB external drive

Offsite Backup (1):
└── Monthly encrypted upload to cloud storage
```

**Backup Timeline:**
```
Hourly:   Docker volumes snapshot (optional)
Daily:    Incremental backup to secondary drive
Weekly:   Full backup to USB external drive
Monthly:  Cloud backup (encrypted)
Quarterly: Full restore test
```

### Recovery Procedures

**Recovery Priority:**
1. Restore monitoring (know cluster status)
2. Restore applications (service availability)
3. Restore data (application data)
4. Restore configuration (cluster settings)

**Recovery Time Objectives (RTO):**
- App node: 30 minutes (redeploy from image)
- NAS node: 2 hours (restore from backup)
- Gateway node: 15 minutes (redeploy monitoring)
- AI node: 1 hour (redeploy from image)

**Recovery Point Objectives (RPO):**
- Application data: 24 hours (daily backup)
- Configuration: 1 hour (automated git commits)
- Media/Archives: 1 week (weekly USB backup)
- Off-site: 1 month (monthly cloud sync)

---

## 🚀 Deployment Strategy

### Version Control Model

```
GitHub Repository Structure:
├── main (production, always stable)
├── staging (test before production)
├── feature/your-feature (development)
└── hotfix/critical-issue (emergency fixes)

Configuration as Code:
├── docker-compose.yml (version controlled)
├── prometheus.yml (version controlled)
├── grafana dashboards (exported JSON)
├── nginx configs (version controlled)
└── deployment scripts (version controlled)
```

**Design Decisions:**
- All infrastructure in git
- Immutable deployments (no manual changes)
- Automated testing on PR
- Change tracking for compliance

### Deployment Process

```
1. Code Change
   └─> Commit to feature branch

2. Pull Request Review
   └─> Peer review required
       └─> CI/CD tests run (linting, syntax)

3. Merge to Staging
   └─> Automated deployment to staging
       └─> Manual testing

4. Merge to Main
   └─> Automated deployment to production
       └─> Gradual rollout (one node at a time)

5. Monitoring & Alerts
   └─> Verify metrics
       └─> Rollback if issues detected
```

---

## 🔄 Scaling Plan

### Horizontal Scaling (Add Nodes)

**Phase 2 (Q3 2026):**
```
+anno-app-opi3bp-02     → Redundant app servers
                           Load balancer on gateway
+anno-nas-rpi5-01       → Faster storage with Pi 5
                           Data replication between NAS nodes
Upgrade anno-gw-mon     → Raspberry Pi 5 (more headroom)
```

**Phase 3 (Q4 2026):**
```
+anno-cache-rpi4        → Redis for caching
+anno-db-rpi5           → PostgreSQL database
+anno-backup-opi3b      → Dedicated backup node
```

### Vertical Scaling (Upgrade Components)

**Storage Expansion:**
```
Current: 2× 2TB = 4TB
Phase 2: 4× 2TB = 8TB (add 2 more USB drives)
Phase 3: 2× 4TB = 8TB (replace with larger drives)
```

**Performance Upgrades:**
```
Bottleneck: MicroSD storage
Solution: Cache frequently used data in RAM
Timeline: Q3 2026
```

### Load Balancing

```
Current (Phase 1):
└─> Single app node handles all requests

Phase 2:
└─> HAProxy on gateway distributes load
    ├─> anno-app-opi3bp-01
    └─> anno-app-opi3bp-02

Phase 3:
└─> Consider Kubernetes ingress (K3s)
```

---

## 📈 Performance Characteristics

### Expected Throughput

**Web Server (Nginx):**
```
Requests/sec: ~500-1000 (single app node)
Concurrent connections: 100-200
Response time: 10-50ms (local)
                100-300ms (external via Cloudflare)
```

**Database (if PostgreSQL):**
```
Simple queries: ~1000 req/sec
Complex queries: ~100 req/sec
Concurrent connections: 20-50
```

**AI Inference (Jetson):**
```
FP32 Model: ~21 TFLOPS
INT8 Model: ~21 TFLOPS
Typical model: 10-100ms per inference
Batch processing: 100-1000 inferences/min
```

### Storage Performance

**Network (NFS/SMB):**
```
Sequential read: ~50-100 MB/s
Sequential write: ~30-50 MB/s
Random I/O: ~5-10 MB/s
Latency: ~10-20ms
```

**Docker Volumes:**
```
Read: ~20-50 MB/s
Write: ~10-30 MB/s
Latency: ~1-5ms
Capacity: Limited by microSD
```

---

## 📚 Documentation Standards

### Code Documentation
- README.md per node (setup instructions)
- docker-compose.yml comments (service purpose)
- Configuration files (inline comments)
- Scripts (shebang + description)

### Operational Documentation
- Runbooks for common procedures
- Troubleshooting decision trees
- Alert response playbooks
- Change logs and version history

### Architecture Documentation
- This file (design decisions)
- Diagrams (network, deployment, scaling)
- Decision records (why choices were made)
- Capacity planning spreadsheets

---

## 🔄 Decision Records

### Why Docker Compose Instead of Kubernetes?

**Decision**: Use Docker Compose for orchestration (not Kubernetes)

**Reasoning:**
- Simpler operational model for small cluster
- Lower resource overhead
- Easier to understand and debug
- Kubernetes adds complexity without benefit at this scale
- Plan to migrate to K3s when ready

**Trade-offs:**
- ✗ No automatic scaling
- ✗ Limited service discovery
- ✓ Much simpler (good for learning)
- ✓ Lower resource requirements

---

### Why Separate Monitoring Node?

**Decision**: Dedicated monitoring node (not distributed)

**Reasoning:**
- Single source of truth for metrics
- Simpler alerting rules
- Easier backup and recovery
- Monitoring failure = cluster visibility (important to detect early)

**Future:** Add redundant monitoring in Phase 2

---

### Why Tailscale + Cloudflare (vs OpenVPN/nginx)?

**Decision**: Use Tailscale + Cloudflare for networking

**Reasoning:**
- Tailscale: Easy VPN mesh, no port forwarding needed
- Cloudflare: DDoS protection, free SSL/TLS
- Both have free/generous free tiers
- Easier than self-hosted OpenVPN
- Better than exposing raw SSH/HTTP

**Alternative considered:** Self-hosted HAProxy + OpenVPN (rejected: too complex)

---

## 🎓 Learning Path

Users follow this progression:

1. **Basics**: Single node, SSH access, Docker containers
2. **Networking**: Multiple nodes communicating, local network
3. **Monitoring**: Prometheus + Grafana dashboards
4. **Security**: Tailscale VPN, external access
5. **Operations**: Backups, alerting, disaster recovery
6. **Scaling**: Add nodes, load balancing, high availability

---

**Last Updated**: April 2026  
**Next Review**: Q3 2026 (after Phase 2 implementation)
