# AnnoGrid: Professional Multi-Node Home & Edge Infrastructure

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Cluster Status](https://img.shields.io/badge/Cluster-4--Node%20Active-brightgreen)]()
[![Python 3.8+](https://img.shields.io/badge/Python-3.8+-blue.svg)](https://www.python.org/downloads/)
[![Docker](https://img.shields.io/badge/Docker-20.10+-blue.svg)](https://www.docker.com/)

<div align="center">
  <img src="assets/branding/logo_1024_transparent.png" alt="AnnoGrid Logo" width="200">
  
  **A production-grade home infrastructure platform built on affordable single-board computers**
</div>

---

## 📋 Project Overview

AnnoGrid is a **professionally organized, scalable infrastructure platform** designed for:
- **Students & Educators** learning cloud infrastructure
- **Hobbyists & Makers** building home automation
- **Developers** needing a testing/staging environment
- **Organizations** deploying edge computing workloads

Built with 4 dedicated nodes, each optimized for specific workloads, AnnoGrid demonstrates **enterprise-grade patterns at hobby scale**.

---

## 🏗️ Cluster Architecture

### Hardware Composition

| Node | Hardware | Role | CPU | RAM | Storage | Status |
|------|----------|------|-----|-----|---------|--------|
| **anno-app-opi3bp-01** | Orange Pi 3B+ | Application Server | 4× ARM A53 | 2GB | 64GB microSD | 🟢 Active |
| **anno-ai-jetson-orin-nano-01** | Jetson Orin Nano | AI/ML Workloads | 6× ARM A78 | 8GB | 128GB | 🟢 Active |
| **anno-nas-rpi3bp-01** | Raspberry Pi 3B+ | Storage (NAS) | 4× ARM A53 | 1GB | 2×2TB USB | 🟢 Active |
| **anno-gw-mon-rpi3bp-01** | Raspberry Pi 3B+ | Gateway + Monitoring | 4× ARM A53 | 1GB | 32GB microSD | 🟢 Active |

### Network Infrastructure

```
┌─────────────────────────────────┐
│   TP-Link AX1500 WiFi Router    │
│      (Gateway: 192.168.1.1)     │
└──────────────┬──────────────────┘
               │ Ethernet (1 Gbps)
        ┌──────▼──────┐
        │  TP-Link    │
        │ TL-SG608    │
        │ 8-Port      │
        │ Managed     │
        │ Switch      │
        └──┬──┬──┬────┘
           │  │  │
    ┌──────┘  │  └────────┐
    │         │           │
 ┌──▼──┐  ┌──▼──┐  ┌──────▼──┐  ┌─────────┐
 │App  │  │ AI  │  │  NAS   │  │Gateway/ │
 │Node │  │Node │  │  Node  │  │Monitoring
 └─────┘  └─────┘  └────────┘  └─────────┘

192.168.1.10  192.168.1.11  192.168.1.12  192.168.1.13

        ┌─────────────────────┐
        │  Tailscale VPN      │
        │  (Encrypted Mesh)   │
        │  100.x.x.x/24       │
        └──────────┬──────────┘
                   │
        ┌──────────▼──────────┐
        │ Cloudflare Tunnel   │
        │ (Safe External      │
        │  Access)            │
        └─────────────────────┘
```

### Service Architecture

**Per-Node Services:**
- **App Node**: Web servers, APIs, application containers
- **AI Node**: CUDA/ML workloads, inference engines, TensorFlow
- **NAS Node**: Storage, backups, media server
- **Gateway/Monitor**: Prometheus, Grafana, Tailscale, Cloudflare Tunnel

**Shared Services:**
- Node Exporter (metrics on all nodes)
- Centralized logging (Vector)
- Tailscale VPN (encrypted mesh network)
- Cloudflare Tunnel (safe external access)

---

## 🚀 Quick Start

### Prerequisites
- Basic Linux knowledge
- SSH client
- Network connectivity (Ethernet recommended)
- Tailscale account (free)
- Cloudflare account (free)

### 1-Minute Setup Checklist
```bash
# 1. SSH into gateway node
ssh pi@anno-gw-mon-rpi3bp-01.local

# 2. Verify cluster is up
./scripts/cluster/health-check-all.sh

# 3. Access monitoring
# Local: http://anno-gw-mon-rpi3bp-01.local:3000 (Grafana)
# External: https://grafana.yourdomain.com (via Cloudflare)
```

For detailed setup, see [GETTING_STARTED.md](docs/GETTING_STARTED.md)

---

## 📚 Documentation

| Document | Purpose |
|----------|---------|
| **[ARCHITECTURE.md](ARCHITECTURE.md)** | Cluster design and technical decisions |
| **[NODES.md](NODES.md)** | Node specifications and inventory |
| **[docs/GETTING_STARTED.md](docs/GETTING_STARTED.md)** | Installation and initial setup |
| **[docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)** | Service deployment procedures |
| **[docs/NETWORK.md](docs/NETWORK.md)** | Network configuration details |
| **[docs/SECURITY.md](docs/SECURITY.md)** | Security best practices |
| **[docs/MAINTENANCE.md](docs/MAINTENANCE.md)** | Operations and maintenance |
| **[docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)** | Common issues and solutions |

---

## 🔧 Common Commands

```bash
# Cluster Health
./scripts/cluster/health-check-all.sh

# Update all nodes
./scripts/cluster/update-all.sh

# Network diagnostics
./scripts/cluster/network-test.sh

# Deploy a service
./scripts/deployment/deploy-node.sh anno-app-opi3bp-01

# Backup all configurations
./scripts/cluster/backup-all.sh

# Check logs across cluster
docker compose logs -f  # on each node
```

More commands in [Makefile](Makefile)

---

## 📊 Monitoring & Observability

### Dashboards Available
- **Cluster Overview**: Total resources, all nodes status
- **Node Details**: Per-node CPU, memory, disk, network
- **Network Health**: Bandwidth, packet loss, latency
- **Application Performance**: Request rates, response times
- **AI Workload Metrics**: GPU utilization, model inference time

### Access Points
- **Local Network**: `http://anno-gw-mon-rpi3bp-01.local:3000`
- **Tailscale VPN**: `http://100.x.x.x:3000` (secure tunnel)
- **External**: `https://grafana.yourdomain.com` (Cloudflare Tunnel)

---

## 🔐 Security Features

✅ **Tailscale VPN** - Encrypted mesh network between all nodes  
✅ **Cloudflare Tunnel** - Safe external access without port forwarding  
✅ **SSH Key Authentication** - Passwordless, secure access  
✅ **Firewall Rules** - nftables configuration per node  
✅ **Network Segmentation** - Optional VLANs for isolation  
✅ **Encrypted Backups** - All backups encrypted at rest  

See [docs/SECURITY.md](docs/SECURITY.md) for detailed security setup.

---

## 🎯 Use Cases

### Production-Ready
- **Media Server** (Jellyfin, Plex)
- **Home Automation Hub** (Home Assistant)
- **Personal Cloud** (Nextcloud, Syncthing)
- **Development Staging** (test deployments)

### AI/ML Specific (Jetson Node)
- **Model Inference** (TensorFlow, PyTorch)
- **Computer Vision** (object detection, pose estimation)
- **Edge Analytics** (real-time data processing)
- **GPU Acceleration** (CUDA workloads)

### Enterprise Learning
- **Container Orchestration** (Docker Compose → Kubernetes)
- **Observability** (Prometheus, Grafana, Loki)
- **Infrastructure as Code** (Terraform, Ansible)
- **CI/CD Pipelines** (GitHub Actions on small scale)

---

## 📈 Roadmap

### Phase 1 (Q2 2026) - Current
- [x] 4-node cluster operational
- [x] Monitoring stack (Prometheus + Grafana)
- [x] Network security (Tailscale + Cloudflare)
- [x] Professional documentation

### Phase 2 (Q3 2026)
- [ ] Kubernetes on cluster (lightweight)
- [ ] Helm charts for deployments
- [ ] Advanced monitoring (distributed tracing)
- [ ] Automated backup to cloud storage

### Phase 3 (Q4 2026)
- [ ] Additional nodes (more compute/storage)
- [ ] Edge ML model optimization
- [ ] Advanced networking (VLANs, QoS)
- [ ] Community examples library

See [CHANGELOG.md](CHANGELOG.md) for version history.

---

## 💰 Cost Analysis

| Component | Cost | Notes |
|-----------|------|-------|
| Hardware (4 nodes) | $450 | Orange Pi, Jetson, 2× Raspberry Pi |
| Network Equipment | $80 | Switch, cables, adapters |
| Storage (2TB USB) | $120 | External drives for NAS |
| **Total Initial** | **$650** | Complete cluster |
| **Annual Operating** | ~$45 | Electricity only |
| **5-Year TCO** | ~$875 | vs $5,000+ traditional server |

---

## 🤝 Contributing

Contributions welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

Areas for contribution:
- Documentation improvements
- New service examples
- Monitoring dashboards
- Deployment automation
- Bug reports and fixes

---

## 📞 Support & Community

- **Issues**: [GitHub Issues](https://github.com/wanghley/anno-grid/issues)
- **Discussions**: [GitHub Discussions](https://github.com/wanghley/anno-grid/discussions)
- **Documentation**: See `/docs` directory
- **Community**: r/HomeServer, r/raspberry_pi, Raspberry Pi Forums

---

## 📄 License

This project is licensed under the **MIT License** - see [LICENSE.md](LICENSE.md) for details.

---

## 🙏 Acknowledgments

Built as part of **Duke University's CoLab Initiative** - making infrastructure education accessible to everyone.

### Key Technologies
- [Docker](https://www.docker.com/) - Containerization
- [Prometheus](https://prometheus.io/) - Metrics collection
- [Grafana](https://grafana.com/) - Visualization
- [Tailscale](https://tailscale.com/) - VPN mesh network
- [Cloudflare Tunnel](https://www.cloudflare.com/products/tunnel/) - Safe external access

---

<div align="center">

**Built with ❤️ for infrastructure enthusiasts worldwide**

[⬆ Back to Top](#annogrid-professional-multi-node-home--edge-infrastructure)

</div>
