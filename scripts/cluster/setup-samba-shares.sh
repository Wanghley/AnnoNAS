#!/bin/bash

# Define colors for nicer output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}======================================================${NC}"
echo -e "${BLUE}     Interactive Samba (SMB/CIFS) Mount Setup         ${NC}"
echo -e "${BLUE}======================================================${NC}"

# 1. Ensure the script is run as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: Please run this script as root (e.g., sudo ./setup_samba.sh)${NC}"
  exit 1
fi

# 2. Check and install cifs-utils if missing
if ! command -v mount.cifs &> /dev/null; then
    echo -e "${BLUE}[*] cifs-utils not found. Installing...${NC}"
    apt-get update && apt-get install -y cifs-utils
fi

# 3. Gather information interactively
echo ""
read -p "1. Enter Samba Server IP or Hostname (e.g., 192.168.1.100): " SMB_SERVER
read -p "2. Enter Share Name (e.g., shared_folder): " SMB_SHARE
read -p "3. Enter Local Mount Point (e.g., /mnt/app_data): " MOUNT_POINT
read -p "4. Enter Samba Username: " SMB_USER
read -s -p "5. Enter Samba Password: " SMB_PASS
echo ""
echo ""
read -p "6. Enter UID to own the mount [Default: 1000]: " SMB_UID
SMB_UID=${SMB_UID:-1000}
read -p "7. Enter GID to own the mount [Default: 1000]: " SMB_GID
SMB_GID=${SMB_GID:-1000}

# Remove leading/trailing slashes from user input to prevent formatting errors
SMB_SERVER=$(echo "$SMB_SERVER" | sed 's:/*$::' | sed 's:^/*::')
SMB_SHARE=$(echo "$SMB_SHARE" | sed 's:/*$::' | sed 's:^/*::')

# 4. Create Mount Point
if [ ! -d "$MOUNT_POINT" ]; then
    echo -e "${BLUE}[*] Creating mount point at $MOUNT_POINT...${NC}"
    mkdir -p "$MOUNT_POINT"
fi

# 5. Create Secure Credentials File
CREDS_DIR="/etc/smbcredentials"
mkdir -p "$CREDS_DIR"
# Make the credentials file hidden and secure
CREDS_FILE="$CREDS_DIR/.${SMB_SERVER}_${SMB_SHARE}.creds"

echo "username=$SMB_USER" > "$CREDS_FILE"
echo "password=$SMB_PASS" >> "$CREDS_FILE"
chmod 600 "$CREDS_FILE" # Only root can read this file

# 6. Attempt to Mount
FULL_SHARE_PATH="//$SMB_SERVER/$SMB_SHARE"
echo -e "${BLUE}[*] Attempting to mount $FULL_SHARE_PATH to $MOUNT_POINT...${NC}"

mount -t cifs "$FULL_SHARE_PATH" "$MOUNT_POINT" -o credentials="$CREDS_FILE",uid="$SMB_UID",gid="$SMB_GID",dir_mode=0775,file_mode=0775

# 7. Verify Mount and Handle Persistence
if mount | grep -q "$MOUNT_POINT"; then
    echo -e "${GREEN}[+] Successfully mounted!${NC}"
    
    echo ""
    read -p "Do you want to mount this share automatically on system startup? (y/n): " ON_BOOT
    
    if [[ "$ON_BOOT" =~ ^[Yy]$ ]]; then
        # We use _netdev and x-systemd.automount to prevent the system from hanging if the network is down during boot
        FSTAB_ENTRY="${FULL_SHARE_PATH}  ${MOUNT_POINT}  cifs  credentials=${CREDS_FILE},uid=${SMB_UID},gid=${SMB_GID},dir_mode=0775,file_mode=0775,_netdev,x-systemd.automount 0 0"
        
        if grep -q "$MOUNT_POINT" /etc/fstab; then
            echo -e "${RED}[!] An entry for $MOUNT_POINT already exists in /etc/fstab. Skipping to prevent duplicates.${NC}"
        else
            # Backup fstab just in case
            cp /etc/fstab /etc/fstab.bak
            echo "$FSTAB_ENTRY" >> /etc/fstab
            systemctl daemon-reload
            echo -e "${GREEN}[+] Added to /etc/fstab for persistence across reboots.${NC}"
        fi
    fi
else
    echo -e "${RED}[-] Mount failed. Please check your credentials, IP address, and share name.${NC}"
    # Clean up the credentials file if it failed so we don't leave bad files around
    rm -f "$CREDS_FILE"
fi

echo -e "${BLUE}======================================================${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
