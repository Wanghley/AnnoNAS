# File Migration & Reorganization Guide

**Date**: April 2026  
**Status**: ✅ Complete

---

## 📁 What Was Moved

This document tracks all files that were migrated from old locations to the new professional structure.

---

## Docker Files Migration

### Gateway/Monitoring Configurations

**From**: `docker/gateway-monitoring-server/`  
**To**: `nodes/anno-gw-mon-rpi3bp-01/`

```
docker/gateway-monitoring-server/
├── prometheus.yml           → nodes/anno-gw-mon-rpi3bp-01/prometheus-config/
├── promtail-config.yml      → nodes/anno-gw-mon-rpi3bp-01/loki-config/
└── docker-compose.yml       → (Already at new location)
```

### Application Server

**From**: `docker/application-server/`  
**To**: `nodes/anno-app-opi3bp-01/` + examples/

```
docker/application-server/
├── docker-compose.app.yml   → examples/docker-compose-examples/app-server.yml
├── docker-compose.db.yml    → examples/docker-compose-examples/database-stack.yml
├── docker-compose.mon.yml   → examples/docker-compose-examples/monitoring.yml
├── manage.sh                → scripts/deployment/
├── setup.sh                 → nodes/anno-app-opi3bp-01/setup.sh
└── configs/                 → nodes/anno-app-opi3bp-01/config/
```

### WPPConnect Service

**From**: `docker/wppconnect/`  
**To**: `services/deployments/wppconnect/`

```
docker/wppconnect/
├── docker-compose.yml
├── Dockerfile
└── config.ts
   → All copied to services/deployments/wppconnect/
```

### Node Exporter Deployment

**From**: `docker/start-node-exporter.sh`  
**To**: `scripts/cluster/deploy-node-exporter.sh`

### Monitoring References (Archived)

**From**: `docker/monitoring/` and `docker/canary/`  
**To**: `examples/prometheus-configs/`

These are kept as reference configurations:
- `examples/prometheus-configs/monitoring-stack-prometheus.yml`
- `examples/prometheus-configs/canary-prometheus.yml`

---

## Scripts Migration

### Cluster Management Scripts

| Old Location | New Location | Purpose |
|--------------|--------------|---------|
| `scripts/network-check.sh` | `scripts/cluster/network-check.sh` | Network diagnostics |
| `scripts/orange-pi-diagnose.sh` | `scripts/cluster/system-diagnostics.sh` | System diagnostics |
| `docker/general/setup-node.sh` | `scripts/deployment/setup-node-generic.sh` | Generic node setup |
| `docker/start-node-exporter.sh` | `scripts/cluster/deploy-node-exporter.sh` | Node exporter deployment |

### Node-Specific Setup Scripts

| Old Location | New Location | Node |
|--------------|--------------|------|
| `scripts/NAS/setup.sh` | `nodes/anno-nas-rpi3bp-01/setup.sh` | NAS Node |
| `scripts/gateway-monitoring/gateway-node-setup.sh` | `nodes/anno-gw-mon-rpi3bp-01/setup.sh` | Gateway Node |

### Utility Scripts

| Old Location | New Location | Purpose |
|--------------|--------------|---------|
| `scripts/setup-samba-mountpoint.sh` | `scripts/cluster/setup-samba-shares.sh` | Samba configuration |
| `scripts/button-action.sh` | `scripts/maintenance/button-action.sh` | Hardware button actions |

---

## Configuration Files Migration

### Prometheus Configs

**Primary Gateway Node**:
```
Old: docker/gateway-monitoring-server/prometheus.yml
New: nodes/anno-gw-mon-rpi3bp-01/prometheus-config/prometheus.yml
Purpose: Main cluster monitoring
```

**Staging/Reference Configs**:
```
docker/canary/prometheus.yml
  → examples/prometheus-configs/canary-prometheus.yml

docker/monitoring/prometheus.yml
  → examples/prometheus-configs/monitoring-stack-prometheus.yml
```

### Loki/Promtail Configs

```
Old: docker/gateway-monitoring-server/promtail-config.yml
New: nodes/anno-gw-mon-rpi3bp-01/loki-config/promtail-config.yml
Purpose: Log aggregation setup
```

---

## What Should Be Archived/Removed

### Directories to Archive

The following old directories can be safely archived (all contents have been migrated):

```
docker/                          ← Consolidate into nodes/ and services/
├── application-server/          (Migrated)
├── canary/                      (Reference copy kept)
├── gateway-monitoring-server/   (Migrated)
├── general/                     (Migrated)
├── monitoring/                  (Reference copy kept)
└── wppconnect/                  (Migrated)

scripts/                         ← Reorganized into nodes/ and scripts/
├── NAS/                         (Migrated)
├── button-action.sh             (Migrated)
├── gateway-monitoring/          (Migrated)
├── network-check.sh             (Migrated)
├── orange-pi-diagnose.sh        (Migrated)
├── setup-gateway-monitoring.sh  (Migrated)
└── setup-samba-mountpoint.sh    (Migrated)

arlo/                           ← Moved to services/
└── (All contents migrated)
```

### Files to Keep

```
✓ docker/start-node-exporter.sh  (Already copied, can remove)
✓ Root level files (README, etc.)
✓ docs/
✓ nodes/
✓ services/
✓ infrastructure/
✓ monitoring/
✓ backup/
✓ examples/
```

---

## 🚀 Post-Migration Steps

### 1. Archive Old Directories

```bash
# Create archive for reference
cd /Users/wanghley/Workspace/projects/AnnoGrid

# Backup old structure (optional)
tar czf archive/old-docker-structure.tar.gz docker/
tar czf archive/old-scripts-structure.tar.gz scripts/
tar czf archive/old-arlo-structure.tar.gz arlo/

# Or simply document before removing
ls -la docker/ > archive/docker-directory-manifest.txt
ls -la scripts/ > archive/scripts-directory-manifest.txt
```

### 2. Remove Old Directories

```bash
# Option A: Full cleanup (after backup)
rm -rf docker/
rm -rf arlo/

# Option B: Keep for reference
# Just mark as legacy in repo
# Add to .gitignore
```

### 3. Update Git

```bash
# Remove old files from version control
git rm -r docker/
git rm -r arlo/
git rm -r scripts/

# Commit the migration
git commit -m "refactor: migrate remaining files to new structure

- Move docker configs to nodes/
- Move scripts to scripts/ and nodes/
- Archive Arlo to services/deployments/
- Consolidate all configurations
- Keep examples/ for reference

All functionality preserved in new locations."
```

### 4. Update Any References

Search for any hardcoded references to old paths:

```bash
# Find references to old docker/ paths
grep -r "docker/" --include="*.md" --include="*.sh" --include="*.yml"

# Find references to old scripts/ paths
grep -r "scripts/" --include="*.md" --include="*.sh"

# Find references to arlo/
grep -r "arlo/" --include="*.md" --include="*.sh"
```

Update found references to new paths.

---

## 📋 Migration Verification Checklist

- [x] All docker/ files moved to appropriate locations
- [x] All scripts/ files moved to organized structure
- [x] All arlo/ files moved to services/deployments/
- [x] Prometheus configs moved to gateway node
- [x] Node-specific configs in node directories
- [x] Examples preserved in examples/
- [x] References saved for staging/canary configs
- [x] Directory structure created where needed
- [x] File permissions preserved
- [x] Symbolic links updated (if any)

---

## 🔍 What's in Each New Location

### `/nodes/anno-*/`

Each node directory now contains:
```
nodes/anno-[role]-[hardware]-[id]/
├── README.md                    ← Node documentation
├── docker-compose.yml           ← Services for this node
├── setup.sh                     ← Automated setup script
├── config/                      ← Node-specific configs
│   ├── hostname.conf
│   ├── network.conf
│   ├── docker-daemon.json
│   └── [service-specific configs]
├── prometheus-config/           ← For gateway node
├── grafana-provisioning/        ← For gateway node
└── loki-config/                 ← For gateway node
```

### `/services/deployments/`

Service deployment templates:
```
services/deployments/
├── README.md                    ← Deployment guide
├── voice-assistant-lva.md       ← Voice assistant guide
├── voice-assistant/             ← Voice assistant (from arlo/)
├── wppconnect/                  ← WhatsApp service
├── database-stack.yml           ← PostgreSQL + Redis
├── media-server.yml             ← Jellyfin
└── [more services...]
```

### `/scripts/`

Organized scripts:
```
scripts/
├── cluster/                     ← Cluster-wide operations
│   ├── health-check-all.sh
│   ├── update-all.sh
│   ├── network-check.sh
│   └── system-diagnostics.sh
├── deployment/                  ← Deployment helpers
│   ├── deploy-node.sh
│   ├── setup-node-generic.sh
│   └── deploy-node-exporter.sh
└── maintenance/                 ← Maintenance tasks
    ├── logs-cleanup.sh
    ├── disk-cleanup.sh
    └── button-action.sh
```

### `/examples/`

Reference configurations:
```
examples/
├── docker-compose-examples/     ← Service templates
│   ├── app-server.yml
│   ├── database-stack.yml
│   ├── monitoring.yml
│   └── ...
├── prometheus-configs/          ← Reference prometheus setups
│   ├── canary-prometheus.yml
│   ├── monitoring-stack-prometheus.yml
│   └── ...
└── configuration-examples/      ← Config templates
    ├── nginx.conf
    ├── samba.conf
    └── ...
```

---

## 📖 Updated Documentation

These files have been created to document the new structure:

- **README.md** - Professional project overview
- **ARCHITECTURE.md** - Design decisions
- **NODES.md** - Node inventory
- **REPOSITORY_ORGANIZATION.md** - How to use repo
- **ARLO_REORGANIZATION.md** - Voice assistant guide
- **MIGRATION_GUIDE.md** - This file

---

## 🚨 Important Notes

### File Integrity

All files have been **copied** (not moved) to ensure nothing is lost during migration. Original files remain in old locations until you explicitly remove them.

### Permissions

File permissions and executable bits are preserved during migration.

### References

Some configurations reference other files. These have been maintained:
- Prometheus scrape targets reference node IPs
- Docker compose files reference volumes and networks
- Scripts reference absolute paths (update as needed)

### Testing

After migration, test:
```bash
# Verify node setups work
make deploy-app
make deploy-gateway

# Verify scripts work
bash scripts/cluster/network-check.sh
bash scripts/cluster/system-diagnostics.sh

# Verify monitoring works
docker compose logs -f prometheus
```

---

## 📞 Questions?

Refer to:
- **REPOSITORY_ORGANIZATION.md** - How to use new structure
- **NODES.md** - Node-specific details
- **README.md** - Project overview
- **ARCHITECTURE.md** - Design decisions

---

**Migration Status**: ✅ COMPLETE  
**Last Updated**: April 2026  
**Ready for**: Archive old directories and commit migration

