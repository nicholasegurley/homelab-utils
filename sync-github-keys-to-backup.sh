#!/bin/bash
#
# GitHub SSH Key Backup Script
# Mirrors the structure and logic of proxmox-backup.sh
#
# Purpose:
#   - Archives all /var/lib/vz/ssh_keys entries (GitHub VM identities)
#   - Saves to a timestamped .tar.gz archive
#   - Retains backups for a defined number of days
#   - Allows override of backup destination as first argument
#
# Example:
#   ./sync-github-keys-to-backup.sh /mnt/pve/backups
#

# ================================================================
# Configuration
# ================================================================
# Default backup destination (override with first argument)
DEST="${1:-/root/proxmox-backups}"

# Number of days to retain old backups
RETENTION_DAYS=30

# Timestamp for this backup
DATESTAMP=$(date +%Y-%m-%d_%H-%M-%S)

# Backup filename
BACKUP_FILE="${DEST}/github-ssh-keys-${DATESTAMP}.tar.gz"

# Source directory
SRC_DIR="/var/lib/vz/ssh_keys"

# ================================================================
# Pre-checks
# ================================================================
echo "------------------------------------------------------------"
echo "[GitHub Key Backup] Starting backup at $(date)"
echo "Destination: ${DEST}"
echo "Source: ${SRC_DIR}"
echo "Retention: ${RETENTION_DAYS} days"

if [ ! -d "$SRC_DIR" ]; then
  echo "[Warning] No SSH key directory found at $SRC_DIR — nothing to back up."
  exit 0
fi

mkdir -p "$DEST"

# ================================================================
# Backup operation
# ================================================================
echo "[GitHub Key Backup] Creating archive..."
tar -czf "$BACKUP_FILE" -C "$SRC_DIR" .

if [ $? -eq 0 ]; then
  echo "[GitHub Key Backup] Backup successful: $BACKUP_FILE"
else
  echo "[Error] Backup failed."
  exit 1
fi

# ================================================================
# Retention cleanup
# ================================================================
echo "[GitHub Key Backup] Cleaning up backups older than ${RETENTION_DAYS} days..."
find "$DEST" -type f -name "github-ssh-keys-*.tar.gz" -mtime +${RETENTION_DAYS} -print -delete

echo "[GitHub Key Backup] Completed successfully at $(date)"
echo "------------------------------------------------------------"
exit 0
