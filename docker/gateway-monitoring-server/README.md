# 🌐 AnnoGrid: Gateway & Monitoring Node

This directory contains the configuration for the **Gateway and Monitoring Node**, the "brain" of the AnnoGrid cluster. This node manages external access via Zero Trust tunnels and centralizes observability for all other nodes in the grid.

## 🏗 Architecture

The Gateway is deployed on a **Raspberry Pi 3B+** acting as a secure ingress point. It uses a **Dockerized stack** to isolate services and maintains a "Default Deny" posture, requiring identity verification for all incoming traffic.

### Key Components

* **Ingress**: Cloudflare Tunnel (`cloudflared`) for secure, port-less public access.
* **Identity**: Cloudflare Access (ZTA) to enforce OIDC/Email verification.
* **Mesh VPN**: Tailscale for encrypted P2P communication between SBCs.
* **Observability**: Prometheus (metrics), Loki (logs), and Grafana (visualization).
* **Real-time Stats**: Netdata for per-second hardware telemetry.

---

## 🛠 Setup & Installation

### 1. Prerequisites

* **Hardware**: Raspberry Pi 3B+ (or equivalent).
* **OS**: Armbian or Raspberry Pi OS (64-bit recommended).
* **Tools**: Docker, Docker Compose, Tailscale.
* **Optimization**: **ZRAM** enabled to handle memory pressure on 1GB RAM.

### 2. Environment Variables

Create a `.env` file in this directory:

```bash
CF_TUNNEL_TOKEN=your_cloudflare_tunnel_token
GF_SECURITY_ADMIN_PASSWORD=your_secure_password

```

### 3. Deployment

```bash
# Clone the repo and navigate to the gateway folder
cd AnnoGrid/docker/gateway-monitoring-server

# Deploy the stack
docker compose up -d

```

---

## 📊 Monitoring Configuration

### Prometheus (`prometheus.yml`)

The gateway scrapes data from itself and external nodes using their **Tailscale IPs** to ensure data stays within the encrypted mesh.

```yaml
global:
  scrape_interval: 30s

scrape_configs:
  - job_name: 'netdata-local'
    metrics_path: '/api/v1/allmetrics'
    params:
      format: ['prometheus']
    static_configs:
      - targets: ['netdata:19999']

  - job_name: 'nodes'
    static_configs:
      - targets:
          - 'anno-app-opi3b-01:9100'
          - 'anno-ai-jetson-01:9100'
          - 'anno-nas-rpi3b-01:9100'

```

### Log Aggregation (Loki)

Logs are centralized via Loki. Each edge node runs a **Promtail** agent (or uses the Loki Docker Driver) to ship logs to `http://<gateway-tailscale-ip>:3100`.

---

## 🔐 Zero Trust Implementation

1. **No Open Ports**: The router firewall remains closed. All traffic flows through the outbound `cloudflared` tunnel.
2. **Identity Layer**: Access to Grafana (`grid.yourdomain.com`) requires a one-time password (OTP) sent to a pre-approved email via Cloudflare Access.
3. **Encrypted Backhaul**: All internal scrape traffic between the Gateway and nodes (Orange Pi / Jetson Nano) is encrypted via Tailscale.

---

## ⚡ Performance Optimizations for RPi 3B+

To maintain "velocity" on a 1GB device, the following tweaks were applied:

* **ZRAM**: Compressed swap in memory to prevent SD card thrashing.
* **Scrape Intervals**: Set to 30s to reduce CPU overhead.
* **Retention Policy**: Prometheus TSDB retention limited to 7 days to preserve storage health.
* **Docker Non-Root Access**: Non-root group management for improved security posture without the overhead of full rootless mode.

---

## 🚀 Next Steps

* [ ] Set up automated alerts via Uptime Kuma for node downtime.
* [ ] Integrate **Grafana Alloy** for a unified agent experience.
* [ ] Deploy AI inference dashboards for the Jetson Nano node.
