# AnnoGrid Repository Organization Guide

## 🎯 Overview

This document explains the new professional repository structure for AnnoGrid, organized around your actual 4-node cluster with proper naming conventions and clear responsibilities.

---

## 📁 Directory Structure

### Root Level Documentation

```
README.md                  → Main project overview (start here)
ARCHITECTURE.md           → Technical architecture & design decisions
NODES.md                  → Node inventory & detailed specifications
CHANGELOG.md              → Version history
CONTRIBUTING.md           → Contribution guidelines
LICENSE.md                → MIT License
Makefile                  → Convenient cluster management commands
.gitignore                → What to exclude from version control
.env.example              → Template for environment variables
```

### `/docs` - Comprehensive Documentation

```
docs/
├── GETTING_STARTED.md           → User guide & setup instructions
├── DEPLOYMENT.md                → Service deployment procedures
├── NETWORK.md                   → Network topology & configuration
├── SECURITY.md                  → Security practices & hardening
├── MAINTENANCE.md               → Operational procedures
├── TROUBLESHOOTING.md           → Common issues & solutions
└── diagrams/                    → Architecture diagrams & visuals
```

### `/nodes` - Per-Node Configuration

Each node has identical structure:

```
nodes/
├── anno-app-opi3bp-01/
│   ├── README.md                → Node-specific docs
│   ├── docker-compose.yml       → Services deployed on this node
│   ├── setup.sh                 → Automated setup script
│   └── config/
│       ├── hostname.conf
│       ├── network.conf
│       └── docker-daemon.json
│
├── anno-ai-jetson-orin-nano-01/
│   ├── README.md                → GPU-specific docs
│   ├── docker-compose.yml
│   ├── setup.sh
│   ├── config/
│   │   ├── jetson-specific.conf
│   │   └── ...
│   └── scripts/
│       └── gpu-health-check.py
│
├── anno-nas-rpi3bp-01/
│   ├── README.md                → NAS operations docs
│   ├── docker-compose.yml       → Samba, NFS, Rsync
│   ├── setup.sh
│   ├── config/
│   │   ├── samba.conf
│   │   ├── nfs.conf
│   │   └── ...
│   └── scripts/
│       ├── backup.sh
│       └── health-check.sh
│
└── anno-gw-mon-rpi3bp-01/
    ├── README.md                → Monitoring docs
    ├── docker-compose.yml       → Prometheus, Grafana, AlertManager
    ├── setup.sh
    ├── config/
    │   └── monitoring-stack.conf
    ├── prometheus-config/
    │   ├── prometheus.yml       → Scrape configuration
    │   ├── rules/
    │   │   ├── alerts.yml
    │   │   └── recording-rules.yml
    │   └── targets.d/
    │       ├── app-node.yml
    │       ├── ai-node.yml
    │       ├── nas-node.yml
    │       └── gateway-node.yml
    ├── grafana-provisioning/
    │   ├── datasources/
    │   │   └── prometheus.yml
    │   ├── dashboards/
    │   │   ├── cluster-overview.json
    │   │   ├── node-details.json
    │   │   └── ...
    │   └── notifiers/
    └── scripts/
        ├── health-check.sh
        └── tunnel-status.sh
```

### `/infrastructure` - Infrastructure as Code

```
infrastructure/
├── network/
│   ├── tailscale-config.md      → VPN mesh setup
│   ├── cloudflare-tunnel-config.md  → External access
│   └── networking-setup.sh       → Network initialization
│
├── hardware/
│   ├── HARDWARE_SPECS.md        → Components & specifications
│   ├── power-budget.md          → Power consumption analysis
│   └── cooling-strategy.md      → Thermal management
│
└── security/
    ├── ssh-keys-setup.md        → SSH key management
    ├── firewall-rules.nft       → nftables configuration
    └── backup-strategy.md       → 3-2-1 backup plan
```

### `/services` - Shared Services & Deployments

```
services/
├── shared/
│   ├── node-exporter/          → Deployed on all nodes
│   │   ├── docker-compose.yml
│   │   └── deploy.sh
│   │
│   ├── vector/                 → Centralized logging
│   │   ├── docker-compose.yml
│   │   └── vector.toml
│   │
│   └── docker-registry/        → Private image registry
│       ├── docker-compose.yml
│       └── config/
│
└── deployments/
    ├── README.md               → Service deployment guide
    ├── database-stack.yml      → PostgreSQL + Redis example
    ├── media-server.yml        → Jellyfin example
    ├── backup-automation.yml   → Backup example
    └── sample-app.yml          → Example application
```

### `/scripts` - Automation & Operations

```
scripts/
├── cluster/
│   ├── health-check-all.sh     → Check all nodes
│   ├── update-all.sh           → Update all nodes
│   ├── backup-all.sh           → Backup all configurations
│   └── network-test.sh         → Network diagnostics
│
├── deployment/
│   ├── deploy-node.sh          → Deploy single node
│   ├── deploy-cluster.sh       → Full cluster deployment
│   ├── rollback.sh             → Rollback changes
│   └── health-check.sh         → Service health verification
│
└── maintenance/
    ├── logs-cleanup.sh         → Clean old logs
    ├── disk-cleanup.sh         → Clean unused files
    ├── update-packages.sh      → Update system packages
    └── docker-prune.sh         → Clean Docker resources
```

### `/monitoring` - Dashboards & Alerts

```
monitoring/
├── dashboards/
│   ├── cluster-overview.json   → All nodes at a glance
│   ├── node-details.json       → Per-node metrics
│   ├── network-health.json     → Network status
│   ├── application-performance.json  → App metrics
│   └── ai-workload-metrics.json     → GPU metrics
│
├── alerts/
│   ├── cpu-alerts.yml
│   ├── memory-alerts.yml
│   ├── disk-alerts.yml
│   ├── network-alerts.yml
│   └── service-alerts.yml
│
└── exporters/
    ├── node-exporter-config.yml
    ├── docker-stats-exporter.yml
    └── custom-metrics-exporter.py
```

### `/backup` - Backup & Recovery

```
backup/
├── backup-strategy.md           → 3-2-1 strategy explanation
├── scripts/
│   ├── backup-configurations.sh → Backup all configs
│   ├── backup-volumes.sh        → Backup Docker volumes
│   └── backup-databases.sh      → Backup databases
│
└── restore-procedures/
    ├── restore-from-backup.sh   → Interactive restore
    └── disaster-recovery.md     → Emergency procedures
```

### `/examples` - Sample Configurations & Services

```
examples/
├── docker-compose-examples/
│   ├── media-server.yml        → Jellyfin setup
│   ├── database-stack.yml      → PostgreSQL example
│   ├── backup-automation.yml   → Rsync + cron
│   └── development-environment.yml  → Dev stack
│
└── configuration-examples/
    ├── nginx-reverse-proxy.conf → Web server config
    ├── samba-shares.conf        → Network share config
    └── firewall-rules.nft       → Firewall template
```

### `/assets` - Media & Branding

```
assets/
├── branding/
│   ├── logo_1024_transparent.png
│   ├── logo-dark.png
│   └── logo-light.png
│
├── architecture/
│   ├── network-topology.png
│   ├── cluster-diagram.png
│   └── deployment-flow.png
│
└── hardware/
    ├── components.md
    └── photos/
```

---

## 🚀 How to Use This Repository

### For New Users

1. **Start with [README.md](README.md)** - Get project overview
2. **Read [ARCHITECTURE.md](ARCHITECTURE.md)** - Understand design decisions
3. **Check [NODES.md](NODES.md)** - See your cluster inventory
4. **Review [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md)** - Set up your nodes
5. **Explore [nodes/](nodes/)** - Node-specific configurations

### For Operations

1. **Use [Makefile](Makefile)** for quick commands
   ```bash
   make health                # Check cluster health
   make status                # Show detailed status
   make deploy-all            # Deploy all services
   make update-all            # Update all nodes
   make backup-configs        # Backup configurations
   ```

2. **Access monitoring** via [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)

3. **Troubleshoot** using [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

### For Development

1. **Branch structure**:
   - `main` - Production (always stable)
   - `staging` - Pre-production
   - `feature/name` - New features

2. **Make changes** to appropriate node directories

3. **Test on staging** before deploying to main

4. **Document changes** in [CHANGELOG.md](CHANGELOG.md)

### For Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

## 📋 Node Naming Convention

All nodes follow this pattern:

```
anno-[role]-[hardware]-[id]

Examples:
  anno-app-opi3bp-01          → Application server (Orange Pi 3B+, first unit)
  anno-ai-jetson-orin-nano-01 → AI workload (Jetson Orin Nano, first unit)
  anno-nas-rpi3bp-01          → Storage (Raspberry Pi 3B+, first unit)
  anno-gw-mon-rpi3bp-01       → Gateway/Monitoring (Raspberry Pi 3B+, first unit)
```

**Benefits:**
- ✅ Identifies node purpose immediately
- ✅ Scales to multiple nodes of same type
- ✅ Matches monitoring labels
- ✅ Clear in documentation

---

## 🔑 Key Files to Know

### Essential Reading

| File | Purpose | Audience |
|------|---------|----------|
| [README.md](README.md) | Project overview | Everyone |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Design decisions | Architects, DevOps |
| [NODES.md](NODES.md) | Node inventory | Operators |
| [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md) | Setup guide | New users |
| [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) | Deployment procedures | Operators |
| [Makefile](Makefile) | Quick commands | Everyone |

### Configuration Files

| File | Purpose | Edit? |
|------|---------|-------|
| `nodes/*/docker-compose.yml` | Service definitions | Yes, regularly |
| `nodes/*/config/*.conf` | Node configuration | Yes, as needed |
| `infrastructure/security/firewall-rules.nft` | Firewall | Yes, carefully |
| `.env.example` | Environment template | Reference only |
| `.gitignore` | What to exclude | Reference only |

### Version Control

| File | Track? | Notes |
|------|--------|-------|
| `docker-compose.yml` | ✅ Yes | Service definitions |
| `prometheus.yml` | ✅ Yes | Monitoring config |
| `grafana dashboards/*.json` | ✅ Yes | Exported dashboards |
| `.env` | ❌ No | Use `.env.example` |
| `volumes/` | ❌ No | Container data |
| `backups/` | ❌ No | Backup files |

---

## 🔄 Workflow Examples

### Adding a New Service to App Node

```bash
# 1. Edit service config
cd nodes/anno-app-opi3bp-01
nano docker-compose.yml
# Add your service

# 2. Test locally
docker compose up -d your-service
docker compose logs -f your-service

# 3. Verify in Prometheus
# http://localhost:9090
# Check if new metrics appear

# 4. Commit to git
git add docker-compose.yml
git commit -m "Add: new service to app node"

# 5. Push & deploy
git push origin feature/new-service
# Create PR, merge to staging, test, merge to main

# 6. Deploy to production
make deploy-app
```

### Scaling: Adding a Second App Node

```bash
# 1. Create new node directory
mkdir nodes/anno-app-opi3bp-02
cp -r nodes/anno-app-opi3bp-01/* nodes/anno-app-opi3bp-02/

# 2. Update node configs
nano nodes/anno-app-opi3bp-02/config/hostname.conf
# Change hostname to: anno-app-opi3bp-02

# 3. Setup monitoring targets
cp nodes/anno-gw-mon-rpi3bp-01/prometheus-config/targets.d/app-node.yml \
   nodes/anno-gw-mon-rpi3bp-01/prometheus-config/targets.d/app-node-02.yml
nano nodes/anno-gw-mon-rpi3bp-01/prometheus-config/targets.d/app-node-02.yml
# Update IP to new node

# 4. Update NODES.md inventory
nano NODES.md
# Add new node to inventory

# 5. Deploy
make deploy-all
```

---

## 🔒 Security Notes

### Secrets Management

```bash
# Files that contain secrets (NEVER commit):
.env                    # Environment variables with passwords
credentials/            # API keys, tokens
nodes/*/.env.local      # Local overrides with secrets
ssh/private/            # Private SSH keys

# Use instead:
.env.example            # Template, safe to commit
SSH keys in ~/.ssh/     # System-wide, not in repo
```

### Sensitive Configurations

Some files need special handling:

```bash
# These are version controlled (safe):
docker-compose.yml      # Service definitions
prometheus.yml          # Monitoring config
nginx.conf              # Web server config

# These need .gitignore protection:
.env files              # Passwords, API keys
Private keys            # SSH, TLS
Credentials files       # Database passwords
```

---

## 📚 Documentation Standards

When adding new files:

1. **Start with clear headings**
   ```markdown
   # Title (H1)
   ## Subtitle (H2)
   ### Details (H3)
   ```

2. **Include code examples**
   ```bash
   # Command with explanation
   docker compose up -d
   ```

3. **Add quick reference tables**
   ```markdown
   | Item | Value | Notes |
   |------|-------|-------|
   | CPU | 4 cores | OK |
   ```

4. **Link to related docs**
   ```markdown
   See [ARCHITECTURE.md](ARCHITECTURE.md) for design decisions.
   ```

---

## ✅ Quality Checklist

Before committing:

- [ ] All paths use relative links
- [ ] Code examples are tested
- [ ] Formatting is consistent
- [ ] No hardcoded secrets
- [ ] Node names follow convention
- [ ] References are up-to-date
- [ ] Files follow .gitignore rules
- [ ] Markdown renders correctly

---

## 🆘 Getting Help

**Find answers in this order:**

1. **Quick answers**: Check [Makefile](Makefile) for commands
2. **Setup issues**: [docs/GETTING_STARTED.md](docs/GETTING_STARTED.md)
3. **Operations**: [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)
4. **Problems**: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
5. **Architecture**: [ARCHITECTURE.md](ARCHITECTURE.md)
6. **Node details**: [NODES.md](NODES.md)
7. **Security**: [docs/SECURITY.md](docs/SECURITY.md)

---

## 📞 Support & Community

- **Issues**: GitHub Issues (link to repo)
- **Discussions**: GitHub Discussions (link to repo)
- **Community**: r/HomeServer, r/raspberry_pi
- **Documentation**: All in `/docs` directory

---

**Last Updated**: April 2026  
**Next Review**: Q3 2026

