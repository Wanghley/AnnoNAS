# anno-gw-mon-rpi3bp-01: Gateway & Monitoring Node

**Hardware**: Raspberry Pi 3B+  
**Role**: Central gateway, monitoring, alerting  
**Services**: Prometheus, Grafana, Alert Manager, Tailscale, Cloudflare  
**Status**: 🟢 Active

---

## Quick Start

```bash
# SSH into node
ssh pi@anno-gw-mon-rpi3bp-01.local

# Deploy monitoring stack
docker compose up -d

# Check all services
docker compose ps

# Access Grafana
# Local: http://anno-gw-mon-rpi3bp-01.local:3000
# External: https://grafana.yourdomain.com
```

---

## Monitoring Dashboard

**Grafana**: http://localhost:3000
- **Username**: admin
- **Password**: (check docker-compose.yml)

**Prometheus**: http://localhost:9090
- View metrics directly
- Check scrape targets status
- Test PromQL queries

---

## Alerting

Alerts are configured in `prometheus-config/rules/`

**Trigger Alert**:
```bash
# Simulate CPU alert (for testing)
stress --cpu 4 --timeout 2m

# Check if alert fires in Prometheus UI
# http://localhost:9090/alerts
```

---

## Network Services

### Tailscale VPN

```bash
# Check Tailscale status
tailscale status

# View Tailscale IP
tailscale ip -4

# Add new node
tailscale up
```

### Cloudflare Tunnel

```bash
# Check tunnel status
cloudflared tunnel list

# View tunnel logs
docker compose logs cloudflared
```

---

## Useful Commands

```bash
# Prometheus health
curl http://localhost:9090/-/healthy

# Grafana health
curl http://localhost:3000/api/health

# Query Prometheus metrics
curl 'http://localhost:9090/api/v1/query?query=up'

# Check all targets
curl http://localhost:9090/api/v1/targets

# View scrape config
curl http://localhost:9090/api/v1/config
```

---

## Scaling Monitoring

For Phase 2, add:
- Remote backup Prometheus
- Long-term metrics storage (Thanos)
- Distributed tracing (Jaeger)
- Log aggregation (Loki/ELK)

---

**For detailed documentation see**: [../../docs/architecture/nodes-inventory.md](../../docs/architecture/nodes-inventory.md)
