# AnnoGrid Service Deployments

This directory contains **ready-to-deploy service configurations** for common applications on your AnnoGrid cluster.

---

## 📦 Available Deployments

### 1. **Voice Assistant (LVA)** - Local Voice Control
- **File**: `voice-assistant-lva.md`
- **Node**: `anno-app-opi3bp-01` (Orange Pi)
- **Purpose**: Offline, privacy-respecting voice assistant
- **Features**:
  - Wake word detection
  - Speech-to-text (STT)
  - Text-to-speech (TTS)
  - REST API for automation
  - Home Assistant integration
- **Resources**: ~30% CPU, 150-300MB RAM

**Deploy**:
```bash
cd services/deployments/voice-assistant
docker compose up -d
```

### 2. **Database Stack** (PostgreSQL + Redis)
- **File**: `database-stack.yml`
- **Node**: `anno-nas-rpi3bp-01` (Raspberry Pi NAS)
- **Purpose**: Stateful data storage
- **Features**:
  - PostgreSQL for relational data
  - Redis for caching
  - Persistent volumes
  - Automatic backups
- **Resources**: ~20% CPU, 200-400MB RAM

**Deploy**:
```bash
docker compose -f database-stack.yml up -d
```

### 3. **Backup Automation** (Rsync + Cron)
- **File**: `backup-automation.yml`
- **Node**: `anno-nas-rpi3bp-01` (NAS)
- **Purpose**: Automated incremental backups
- **Features**:
  - Hourly incremental backups
  - Retention policies
  - Compression
  - Cloud upload support
- **Resources**: ~5% CPU (when running), 50MB RAM

**Deploy**:
```bash
docker compose -f backup-automation.yml up -d
```

### 4. **Media Server** (Jellyfin)
- **File**: `media-server.yml`
- **Node**: `anno-app-opi3bp-01` (App Server)
- **Purpose**: Personal streaming media
- **Features**:
  - Movies, TV shows, music
  - Multi-user support
  - Transcoding (may be slow on Orange Pi)
  - Mobile app support
- **Resources**: ~50% CPU (if transcoding), 300-500MB RAM

**Deploy**:
```bash
docker compose -f media-server.yml up -d
```

### 5. **Home Automation** (Home Assistant)
- **File**: `home-automation-ha.yml`
- **Node**: `anno-app-opi3bp-01` (App Server)
- **Purpose**: Central home automation hub
- **Features**:
  - Device automation
  - Automation rules
  - Voice assistant integration
  - Mobile app
- **Resources**: ~40% CPU, 250-400MB RAM

**Deploy**:
```bash
docker compose -f home-automation-ha.yml up -d
```

---

## 🚀 Quick Deploy Guide

### Prerequisites

```bash
# SSH to target node
ssh pi@anno-app-opi3bp-01.local  # or anno-nas-rpi3bp-01

# Update system
sudo apt update && sudo apt upgrade -y

# Verify Docker is running
docker ps
```

### Deploy Any Service

```bash
# 1. Navigate to service directory
cd /path/to/services/deployments/[service-name]

# 2. Create environment file (if needed)
cp .env.example .env
nano .env  # Edit as needed

# 3. Deploy
docker compose pull
docker compose up -d

# 4. Verify
docker compose ps
docker compose logs -f

# 5. Check health
curl http://localhost:PORT/health  # If available
```

### Access Deployed Services

**Local Network**:
```
Voice Assistant:   http://anno-app-opi3bp-01.local:8080
Media Server:      http://anno-app-opi3bp-01.local:8096
Home Assistant:    http://anno-app-opi3bp-01.local:8123
Database:          localhost:5432 (PostgreSQL)
```

**Via Tailscale**:
```
tailscale ip -4  # Get your Tailscale IP
# Then connect to 100.x.x.x:PORT
```

**External (Cloudflare Tunnel)**:
```
https://media.yourdomain.com
https://home.yourdomain.com
https://voice.yourdomain.com
```

---

## 📋 Common Tasks

### Check Service Status

```bash
# All services on node
docker compose ps

# Specific service logs
docker compose logs -f voice-assistant

# Service health
docker compose exec voice-assistant curl localhost:8080/health

# Resource usage
docker stats
```

### Update Service

```bash
# Pull latest images
docker compose pull

# Restart with updates
docker compose up -d

# Verify
docker compose ps
docker compose logs -f
```

### Backup Service Data

```bash
# Backup all volumes
docker compose exec service-name bash -c 'tar czf - /app/data' > backup.tar.gz

# Restore
docker compose exec service-name bash -c 'tar xzf /dev/stdin -C /' < backup.tar.gz
```

### Stop Service

```bash
# Stop (preserve data)
docker compose down

# Stop and remove data (⚠️ Destructive)
docker compose down -v
```

### Scale Service

```bash
# Increase replica count
docker compose up -d --scale service=2

# Note: Not all services support scaling
# Stateful services (DB, etc.) need special setup
```

---

## 🔧 Customization

### Environment Variables

Each service has `.env.example`. Copy and modify:

```bash
cp .env.example .env
nano .env
```

Common variables:
```env
# Access Control
USERNAME=admin
PASSWORD=securepassword

# Storage
DATA_DIR=/var/lib/app
BACKUP_DIR=/mnt/backups

# Network
PORT=8080
DOMAIN=yourdomain.com

# Resource Limits
MEMORY_LIMIT=512m
CPU_SHARES=1024
```

### Port Mappings

Change ports in `docker-compose.yml`:

```yaml
services:
  app:
    ports:
      - "8080:8080"  # External:Internal
      # Change 8080 to any free port
```

Check available ports:
```bash
netstat -tlnp
```

### Volume Mounting

Attach additional storage:

```yaml
volumes:
  - /mnt/storage1/media:/app/media  # Mount NAS storage
  - app-data:/app/data               # Named volume
```

Mount NAS shares:
```bash
# Mount SMB
sudo mount -t cifs //anno-nas-rpi3bp-01/media /mnt/media \
  -o username=pi,password=yourpass

# Mount NFS
sudo mount -t nfs anno-nas-rpi3bp-01:/exports/media /mnt/media
```

---

## 📊 Performance Considerations

### Orange Pi 3B+ (anno-app-opi3bp-01)

**Total Capacity**:
- CPU: 4 cores @ 2.0 GHz
- RAM: 2GB
- Storage: 64GB

**Recommended**:
- Voice Assistant + Light app (Max 70% usage)
- OR Media Server (without transcoding)
- OR Home Assistant (without heavy automations)

**Not Recommended**:
- Multiple CPU-intensive services
- Transcoding video
- Complex machine learning

### Jetson Orin Nano (anno-ai-jetson-orin-nano-01)

**Perfect For**:
- Voice Assistant with GPU acceleration
- Computer vision workloads
- Model inference
- Real-time processing

### NAS Node (anno-nas-rpi3bp-01)

**Good For**:
- Database servers (PostgreSQL)
- Backup services
- File servers
- Redis caching (light usage)

**Not Recommended**:
- Compute-intensive tasks
- Video encoding
- Multiple concurrent services

---

## 🔒 Security Best Practices

### Before Deploying

```bash
# 1. Create strong passwords
openssl rand -base64 32 > .password

# 2. Check for exposed ports
sudo ufw status

# 3. Review environment variables
grep -i password .env

# 4. Set proper file permissions
chmod 600 .env
chmod 600 docker-compose.yml
```

### Firewall Rules

Allow only needed ports:

```bash
# Allow only local network
sudo ufw allow from 192.168.1.0/24 to any port 8080

# Allow only from Tailscale
sudo ufw allow from 100.0.0.0/8 to any port 8080

# Deny external access
sudo ufw deny from any to any port 8080
```

### Network Isolation

Use separate networks for sensitive services:

```yaml
networks:
  app-net:
    driver: bridge
  db-net:
    driver: bridge

services:
  app:
    networks:
      - app-net
  database:
    networks:
      - db-net
      - app-net  # Only if app needs DB access
```

---

## 🆘 Troubleshooting

### Service Won't Start

```bash
# 1. Check logs
docker compose logs --tail=50

# 2. Verify image exists
docker images | grep service-name

# 3. Check port conflicts
netstat -tlnp | grep PORT

# 4. Check permissions
ls -la .env docker-compose.yml
```

### Out of Memory

```bash
# Check usage
docker stats

# Reduce resource limits
# In docker-compose.yml:
deploy:
  resources:
    limits:
      memory: 256m
    reservations:
      memory: 128m

# Restart
docker compose up -d
```

### Network Issues

```bash
# Test connectivity
docker compose exec service ping 8.8.8.8

# Check DNS
docker compose exec service nslookup google.com

# View container network
docker inspect service | grep NetworkSettings
```

---

## 📚 Learn More

- **Voice Assistant**: See `voice-assistant-lva.md`
- **Cluster Monitoring**: See `../../nodes/anno-gw-mon-rpi3bp-01/`
- **Networking**: See `../../docs/NETWORK.md`
- **Troubleshooting**: See `../../docs/TROUBLESHOOTING.md`

---

## 📝 Adding New Services

To add a new service deployment:

1. **Create directory**:
   ```bash
   mkdir services/deployments/my-service
   ```

2. **Add files**:
   - `README.md` - Service documentation
   - `docker-compose.yml` - Service definition
   - `.env.example` - Environment template

3. **Document in this file**:
   - Add to "Available Deployments"
   - Include purpose and resources

4. **Test on staging**:
   - Deploy to test node first
   - Verify functionality
   - Check resource usage

5. **Commit to git**:
   ```bash
   git add services/deployments/my-service
   git commit -m "Add: my-service deployment"
   ```

---

**Last Updated**: April 2026  
**Next Review**: Q3 2026 (add more examples)
