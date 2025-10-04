#!/bin/bash
#
# Proxmox Host Config Backup Script
# Saves critical config files to a timestamped tar.gz archive
# Destination must be a mounted path (works with Proxmox /mnt/pve NFS storage)

# Default backup destination (override with first argument)
DEST="${1:-/root/proxmox-backups}"

# How many days to keep backups
RETENTION_DAYS=30

# Timestamp for this backup
DATESTAMP=$(date +%Y-%m-%d_%H-%M-%S)

# Backup filename
BACKUP_FILE="${DEST}/proxmox-config-${DATESTAMP}.tar.gz"

# Critical directories/files to include
INCLUDE_PATHS=(
  "/etc/pve"
  "/etc/network/interfaces"
  "/etc/hosts"
  "/etc/resolv.conf"
  "/etc/hostname"
  "/etc/passwd"
  "/etc/shadow"
  "/etc/group"
  "/etc/ssh"
  "/etc/fstab"
  /etc/cron*                 # wildcard left unquoted so shell expands it
  "/etc/apt"
  "/root"
  "/var/lib/pve-cluster"
)

echo "[INFO] Starting Proxmox config backup..."
echo "[INFO] Destination: $DEST"

# Ensure destination exists
if [ ! -d "$DEST" ]; then
  echo "[INFO] Destination does not exist, creating: $DEST"
  mkdir -p "$DEST"
fi

# Smarter mount check: verify DEST lives on a mounted filesystem
MOUNT_ROOT=$(df --output=target "$DEST" 2>/dev/null | tail -n 1)

if [[ -z "$MOUNT_ROOT" || "$MOUNT_ROOT" == "/" ]]; then
  echo "[ERROR] Destination $DEST is not on a mounted filesystem. Aborting!"
  exit 1
else
  echo "[INFO] Destination is on mount: $MOUNT_ROOT"
fi

# Create backup archive
echo "[INFO] Creating backup: $BACKUP_FILE"
tar -czf "$BACKUP_FILE" --warning=no-file-changed ${INCLUDE_PATHS[@]}

if [ $? -eq 0 ]; then
  echo "[INFO] Backup created successfully: $BACKUP_FILE"
else
  echo "[ERROR] Backup failed!"
  exit 1
fi

# Rotate old backups
echo "[INFO] Pruning backups older than $RETENTION_DAYS days..."
find "$DEST" -name "proxmox-config-*.tar.gz" -type f -mtime +$RETENTION_DAYS -exec rm -f {} \;

echo "[INFO] Backup and cleanup complete."
exit 0
