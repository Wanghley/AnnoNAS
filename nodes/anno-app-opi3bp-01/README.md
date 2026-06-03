# anno-app-opi3bp-01: Application Server Node

**Hardware**: Orange Pi 3B+  
**Role**: Run user-facing applications and web services  
**Status**: 🟢 Active

---

## Quick Start

```bash
# SSH into node
ssh pi@anno-app-opi3bp-01.local

# Deploy services
docker compose up -d

# Check status
docker compose ps

# View logs
docker compose logs -f
```

---

## Setup Instructions

See [../../docs/DEPLOYMENT.md](../../docs/DEPLOYMENT.md) for detailed setup.

### First-Time Setup (Automated)

```bash
# SSH into node
ssh pi@anno-app-opi3bp-01.local

# Run setup script
cd /path/to/annogrid
bash nodes/anno-app-opi3bp-01/setup.sh
```

### Manual Setup

1. **Update System**
   ```bash
   sudo apt update && sudo apt upgrade -y
   ```

2. **Install Docker**
   ```bash
   curl -fsSL https://get.docker.com | sh
   sudo usermod -aG docker pi
   newgrp docker
   ```

3. **Deploy Node Exporter**
   ```bash
   docker run -d \
     --name node-exporter \
     --restart always \
     --net host \
     -v /:/host:ro \
     prom/node-exporter:latest \
     --path.rootfs=/host
   ```

4. **Deploy Application Services**
   ```bash
   docker compose up -d
   ```

---

## Configuration

### Environment Variables

Create `.env` file in this directory:

```bash
DOMAIN=yourdomain.com
ENVIRONMENT=production
LOG_LEVEL=info
TIMEZONE=UTC
```

### Docker Compose Override

Create `docker-compose.override.yml` for local customizations:

```yaml
version: '3.8'

services:
  app:
    environment:
      - DEBUG=false
      - WORKERS=4
```

---

## Services Deployed

See `docker-compose.yml` for current services.

---

## Monitoring

**Metrics**: http://localhost:9100/metrics  
**Prometheus Scrape**: `anno-app-opi3bp-01:9100`

**Key Metrics to Monitor**:
- CPU usage (should be <80%)
- Memory usage (available should be >100MB)
- Disk usage (should be <85%)
- Container count and status

---

## Backups

Critical volumes are automatically backed up to NAS node daily.

```bash
# Manual backup
docker compose exec app tar czf /backup/app-$(date +%Y%m%d).tar.gz /app/data
```

---

## Troubleshooting

### Container Won't Start

```bash
# Check logs
docker compose logs app

# Check resources
docker stats

# Restart container
docker compose restart app
```

### Out of Disk Space

```bash
# Check disk usage
df -h

# Clean up Docker
docker system prune -a

# Remove old container logs
docker compose logs --tail 0 -f 2>/dev/null | true
```

### High CPU Usage

```bash
# Check which containers use CPU
docker stats

# Check processes
top

# Restart problematic service
docker compose restart service-name
```

---

## Useful Commands

```bash
# View all services
docker compose ps

# Follow logs
docker compose logs -f

# Restart a service
docker compose restart service-name

# Stop all services
docker compose down

# Start services again
docker compose up -d

# Execute command in container
docker compose exec app bash

# View specific service logs
docker compose logs app

# Pull latest images
docker compose pull

# Update services
docker compose up -d
```

---

## Network Access

**Local Network**: `http://anno-app-opi3bp-01.local`  
**Tailscale**: `http://100.x.x.x` (replace with actual IP)  
**External**: `https://app.yourdomain.com` (via Cloudflare)

---

**For detailed documentation see**: [../../docs/architecture/nodes-inventory.md](../../docs/architecture/nodes-inventory.md)
