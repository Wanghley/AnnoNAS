#!/bin/bash

# 1. Ultra-Robust Environment Variable Loader
if [ -f .env ]; then
    while IFS='=' read -r key value; do
        [[ $key =~ ^#.* ]] || [[ -z $key ]] && continue
        value=$(echo "$value" | cut -d'#' -f1 | xargs)
        export "$key=$value"
    done < .env
else
    echo "❌ Error: .env file not found!"
    exit 1
fi

echo "🚀 Initializing Smart NAS Setup (Samba + NFS) for RPI3B+..."

# 2. Install Required Drivers (Including NFS Server)
sudo apt update && sudo apt install -y cockpit cockpit-storaged samba nfs-kernel-server exfat-fuse exfatprogs ntfs-3g

# 3. Smart FSTAB Generator Function
generate_fstab_entry() {
    local uuid=$1
    local mount_point=$2
    if [ -z "$uuid" ]; then return; fi

    local fstype=$(lsblk -no FSTYPE /dev/disk/by-uuid/$uuid 2>/dev/null)
    
    if [ "$fstype" == "exfat" ]; then
        echo "UUID=$uuid  $mount_point  exfat  defaults,uid=1000,gid=1000,umask=000,nofail,noatime  0  0"
    elif [ "$fstype" == "ext4" ]; then
        echo "UUID=$uuid  $mount_point  ext4   defaults,noatime,nofail  0  2"
    else
        echo "UUID=$uuid  $mount_point  auto   defaults,nofail,noatime  0  2"
    fi
}

# 4. Validation: Ensure UUIDs exist
if [ ! -L "/dev/disk/by-uuid/$HDD_1_UUID" ] || [ ! -L "/dev/disk/by-uuid/$HDD_2_UUID" ]; then
    echo "❌ Error: One or more UUIDs from .env not found on system!"
    exit 1
fi

# 5. Prepare Mount Points
sudo mkdir -p "$MOUNT_ROOT/disk1"
sudo mkdir -p "$MOUNT_ROOT/disk2"

# 6. Build and Update /etc/fstab
ENTRY1=$(generate_fstab_entry "$HDD_1_UUID" "$MOUNT_ROOT/disk1")
ENTRY2=$(generate_fstab_entry "$HDD_2_UUID" "$MOUNT_ROOT/disk2")

sudo cp /etc/fstab /etc/fstab.bak
sudo sed -i "/$HDD_1_UUID/d" /etc/fstab
sudo sed -i "/$HDD_2_UUID/d" /etc/fstab
sudo sed -i "/\/disk1/d" /etc/fstab
sudo sed -i "/\/disk2/d" /etc/fstab
echo -e "\n# AnnoGrid Dynamic Mounts\n$ENTRY1\n$ENTRY2" | sudo tee -a /etc/fstab

# 7. Reload and Mount
sudo systemctl daemon-reload
sudo mount -a

# 8. NEW: NFS Exports Configuration
# We export the entire MOUNT_ROOT to the local network and Tailscale
echo "📝 Configuring NFS Exports..."
sudo cp /etc/exports /etc/exports.bak
# Remove old references to our mount root
sudo sed -i "\|^$MOUNT_ROOT|d" /etc/exports

# 'async' improves performance on RPI3B+; 'no_subtree_check' is standard for reliability
# We allow your local subnet (192.168.0.0/24) and Tailscale (100.64.0.0/10)
echo "$MOUNT_ROOT 192.168.0.0/24(rw,async,no_subtree_check,no_root_squash)" | sudo tee -a /etc/exports
echo "$MOUNT_ROOT 100.64.0.0/10(rw,async,no_subtree_check,no_root_squash)" | sudo tee -a /etc/exports

# 9. Configure Samba (Ensuring path exists)
if ! grep -q "\[$SHARE_NAME\]" /etc/samba/smb.conf; then
    cat <<EOF | sudo tee -a /etc/samba/smb.conf
[$SHARE_NAME]
   path = $MOUNT_ROOT
   writeable = yes
   browseable = yes
   valid users = $NAS_USER
   create mask = 0775
   directory mask = 0775
EOF
fi

# 10. Restart Services
sudo exportfs -ra  # Refresh NFS exports
sudo systemctl enable --now cockpit.socket nfs-kernel-server
sudo systemctl restart smbd nfs-kernel-server

echo "------------------------------------------------"
echo "✅ SUCCESS: NAS (Samba + NFS) is configured."
echo "NFS Export: $MOUNT_ROOT"
echo "Samba Share: \\\\$(hostname -I | awk '{print $1})\\$SHARE_NAME"
echo "------------------------------------------------"
