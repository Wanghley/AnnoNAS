# anno-nas-rpi3bp-01: Network Attached Storage (NAS) Node

**Hardware**: Raspberry Pi 3B+  
**Role**: Centralized persistent storage, backups  
**Storage**: 2× 2TB USB 3.0 external drives  
**Status**: 🟢 Active

---

## Quick Start

```bash
# SSH into node
ssh pi@anno-nas-rpi3bp-01.local

# Check storage
df -h

# Deploy services
docker compose up -d

# Monitor storage
docker compose logs -f
```

---

## Storage Access

### Samba/SMB (Windows & Mac)

```
Open file explorer/Finder:
\\anno-nas-rpi3bp-01\media
\\anno-nas-rpi3bp-01\backups

Username: pi
Password: your-password
```

### NFS (Linux)

```bash
# Mount NFS share
sudo mount -t nfs anno-nas-rpi3bp-01:/mnt/storage1 /mnt/nas
```

---

## Storage Management

**Total Capacity**: ~4TB (2× 2TB)

```bash
# Check usage
df -h /mnt/storage*

# Find large files
du -sh /mnt/storage1/* | sort -h

# Clean old backups
find /mnt/storage1/backups -name "*.tar.gz" -mtime +30 -delete
```

---

## Backup Operations

Automated daily backups from app node to this NAS.

```bash
# Manual backup trigger
docker compose exec backup /backup/backup.sh

# Check backup status
ls -lh /mnt/storage1/backups/ | tail -20

# Restore from backup
# See ../../backup/restore-procedures/
```

---

## Troubleshooting

### Drive Not Recognized

```bash
# List all drives
lsblk
sudo fdisk -l

# Check USB connection
dmesg | tail -20
```

### SMB Connection Refused

```bash
# Restart Samba
docker compose restart samba

# Check Samba status
docker compose logs samba
```

### Storage Space Issues

```bash
# Archive old backups
tar czf /mnt/storage1/backups/archive-2026-04.tar.gz /mnt/storage1/backups/old/
```

---

**For detailed documentation see**: [../../docs/architecture/nodes-inventory.md](../../docs/architecture/nodes-inventory.md)
