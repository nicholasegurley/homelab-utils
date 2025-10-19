#!/bin/bash
# ================================================================
# install-github-key-tools.sh
# Installs Nick's unified GitHub SSH key management system for Proxmox.
#
# Components:
#   - github_ssh_hook_full.sh  (single hook: create + cleanup)
#   - list-github-keys.sh      (overview utility)
#   - show-github-key.sh       (single key display)
#   - sync-github-keys-to-backup.sh (archives /var/lib/vz/ssh_keys)
#
# Safe to re-run; overwrites old files.
# ================================================================

set -e

SNIPPET_DIR="/var/lib/vz/snippets"
KEY_DIR="/var/lib/vz/ssh_keys"
BIN_DIR="/usr/local/bin"

echo "------------------------------------------------------------"
echo "[Installer] Setting up directories..."
mkdir -p "$SNIPPET_DIR" "$KEY_DIR" "$BIN_DIR"

# ================================================================
# Unified Hook: github_ssh_hook_full.sh
# ================================================================
cat > "${SNIPPET_DIR}/github_ssh_hook_full.sh" <<"EOF"
#!/bin/bash
# ================================================================
# Unified Proxmox Hook Script for GitHub SSH Key Lifecycle
# Handles both provisioning (post-start) and cleanup (pre-delete)
# ================================================================
set -e
VMID="$1"
PHASE="$2"
KEY_DIR="/var/lib/vz/ssh_keys"
KEY_PATH="${KEY_DIR}/vm-${VMID}-id_ed25519"
mkdir -p "$KEY_DIR"

case "$PHASE" in
  post-start)
    echo "------------------------------------------------------------"
    echo "[Hook] Running GitHub SSH provisioning for VM ${VMID}"
    if [ ! -f "${KEY_PATH}" ]; then
      ssh-keygen -t ed25519 -f "${KEY_PATH}" -N "" -C "vm${VMID}@proxmox"
      echo "[Hook] Generated new SSH keypair for VM ${VMID}"
    else
      echo "[Hook] SSH key already exists for VM ${VMID}"
    fi
    PUB_KEY=$(cat "${KEY_PATH}.pub")
    echo
    echo "[Hook] Public key for VM ${VMID}:"
    echo "${PUB_KEY}"
    echo
    echo "[Hook] Paste this into GitHub → Settings → SSH and GPG keys"
    echo "Title suggestion: vm${VMID}@proxmox"
    echo
    echo "[Hook] To copy key into VM:"
    echo "   scp ${KEY_PATH} ngurley@<vm-ip>:~/.ssh/id_ed25519"
    echo "   scp ${KEY_PATH}.pub ngurley@<vm-ip>:~/.ssh/id_ed25519.pub"
    echo "------------------------------------------------------------"
    ;;
  pre-delete)
    echo "------------------------------------------------------------"
    echo "[Hook] VM ${VMID} is being deleted — cleaning up GitHub SSH keys"
    if [ -f "${KEY_PATH}" ] || [ -f "${KEY_PATH}.pub" ]; then
      rm -f "${KEY_PATH}" "${KEY_PATH}.pub"
      echo "[Hook] Removed ${KEY_PATH} and ${KEY_PATH}.pub"
    else
      echo "[Hook] No GitHub SSH keys found for VM ${VMID}"
    fi
    echo "------------------------------------------------------------"
    ;;
esac
EOF
chmod +x "${SNIPPET_DIR}/github_ssh_hook_full.sh"

# ================================================================
# Utility: list-github-keys.sh
# ================================================================
cat > "${BIN_DIR}/list-github-keys.sh" <<"EOF"
#!/bin/bash
KEY_DIR="/var/lib/vz/ssh_keys"
if [ ! -d "$KEY_DIR" ]; then
  echo "[Info] No GitHub SSH keys directory found at $KEY_DIR"
  exit 0
fi
printf "%-8s %-25s %-60s %-20s\n" "VMID" "VM Name" "Fingerprint" "Last Modified"
printf "%-8s %-25s %-60s %-20s\n" "----" "--------" "------------" "--------------"
for KEYFILE in "${KEY_DIR}"/vm-*-id_ed25519; do
  [ -e "$KEYFILE" ] || continue
  VMID=$(basename "$KEYFILE" | sed -E 's/vm-([0-9]+)-id_ed25519/\1/')
  VM_NAME=$(qm config "$VMID" 2>/dev/null | grep -E "^name:" | awk '{print $2}')
  VM_NAME=${VM_NAME:-"[unknown]"}
  FINGERPRINT=$(ssh-keygen -lf "$KEYFILE.pub" 2>/dev/null | awk '{print $2}')
  MOD_DATE=$(date -r "$KEYFILE" "+%Y-%m-%d %H:%M")
  printf "%-8s %-25s %-60s %-20s\n" "$VMID" "$VM_NAME" "$FINGERPRINT" "$MOD_DATE"
done
EOF
chmod +x "${BIN_DIR}/list-github-keys.sh"

# ================================================================
# Utility: show-github-key.sh
# ================================================================
cat > "${BIN_DIR}/show-github-key.sh" <<"EOF"
#!/bin/bash
if [ -z "$1" ]; then
  echo "Usage: show-github-key.sh <vmid>"
  exit 1
fi
VMID="$1"
KEY_DIR="/var/lib/vz/ssh_keys"
KEY_PATH="${KEY_DIR}/vm-${VMID}-id_ed25519.pub"
if [ ! -f "$KEY_PATH" ]; then
  echo "[Error] No GitHub SSH key found for VM ${VMID}."
  exit 1
fi
VM_NAME=$(qm config "$VMID" 2>/dev/null | grep -E "^name:" | awk '{print $2}')
VM_NAME=${VM_NAME:-"vm${VMID}"}
FINGERPRINT=$(ssh-keygen -lf "$KEY_PATH" 2>/dev/null | awk '{print $2}')
echo "------------------------------------------------------------"
echo "[GitHub Key Info for VM ${VMID}]"
echo "VM Name: ${VM_NAME}"
echo "Fingerprint: ${FINGERPRINT}"
echo
echo "Paste this public key into GitHub:"
echo "Title suggestion: ${VM_NAME}@proxmox"
echo
cat "$KEY_PATH"
echo "------------------------------------------------------------"
EOF
chmod +x "${BIN_DIR}/show-github-key.sh"

# ================================================================
# Backup Script: sync-github-keys-to-backup.sh
# ================================================================
cat > "/root/sync-github-keys-to-backup.sh" <<"EOF"
#!/bin/bash
#
# GitHub SSH Key Backup Script (modeled on proxmox-backup.sh)
#
DEST="${1:-/root/proxmox-backups}"
RETENTION_DAYS=30
DATESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
BACKUP_FILE="${DEST}/github-ssh-keys-${DATESTAMP}.tar.gz"
SRC_DIR="/var/lib/vz/ssh_keys"

echo "------------------------------------------------------------"
echo "[GitHub Key Backup] Starting backup at $(date)"
echo "Destination: ${DEST}"
echo "Source: ${SRC_DIR}"
echo "Retention: ${RETENTION_DAYS} days"

if [ ! -d "$SRC_DIR" ]; then
  echo "[Warning] No SSH key directory found — nothing to back up."
  exit 0
fi

mkdir -p "$DEST"
tar -czf "$BACKUP_FILE" -C "$SRC_DIR" .
echo "[GitHub Key Backup] Backup successful: $BACKUP_FILE"

echo "[GitHub Key Backup] Cleaning up backups older than ${RETENTION_DAYS} days..."
find "$DEST" -type f -name "github-ssh-keys-*.tar.gz" -mtime +${RETENTION_DAYS} -print -delete

echo "[GitHub Key Backup] Completed successfully at $(date)"
echo "------------------------------------------------------------"
EOF
chmod +x "/root/sync-github-keys-to-backup.sh"

# ================================================================
# Wrap-up
# ================================================================
echo "------------------------------------------------------------"
echo "[Installer] Installation complete!"
echo
echo "Hooks installed:  ${SNIPPET_DIR}/github_ssh_hook_full.sh"
echo "Utilities:        ${BIN_DIR}/list-github-keys.sh, show-github-key.sh"
echo "Backup helper:    /root/sync-github-keys-to-backup.sh"
echo
echo "Attach the unified hook to your templates:"
echo "  qm set 9000 --hookscript local:snippets/github_ssh_hook_full.sh"
echo "  qm set 9001 --hookscript local:snippets/github_ssh_hook_full.sh"
echo
echo "Verify with:"
echo "  qm config 9001 | grep hookscript"
echo "------------------------------------------------------------"
