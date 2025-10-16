#!/bin/bash
# ================================================================
# install-github-key-tools.sh
# Installs Nick's GitHub SSH key management system for Proxmox.
#
# Includes:
#   - github_ssh_hook.sh (provisioning)
#   - github_ssh_cleanup.sh (deletion cleanup)
#   - list-github-keys.sh (overview)
#   - show-github-key.sh (single key readout)
#
# Safe to re-run; existing files will be overwritten.
#
# Run using:
#   bash /root/install-github-key-tools.sh
# ================================================================

set -e

# Paths
SNIPPET_DIR="/var/lib/vz/snippets"
KEY_DIR="/var/lib/vz/ssh_keys"
BIN_DIR="/usr/local/bin"

echo "------------------------------------------------------------"
echo "[Installer] Setting up directories..."
mkdir -p "$SNIPPET_DIR" "$KEY_DIR" "$BIN_DIR"

# ---------------------------------------------------------------
# Hook: github_ssh_hook.sh
# ---------------------------------------------------------------
cat > "${SNIPPET_DIR}/github_ssh_hook.sh" <<"EOF"
#!/bin/bash
set -e
VMID="$1"
PHASE="$2"
if [ "$PHASE" != "post-start" ]; then exit 0; fi

KEY_DIR="/var/lib/vz/ssh_keys"
mkdir -p "$KEY_DIR"
KEY_PATH="${KEY_DIR}/vm-${VMID}-id_ed25519"

echo "------------------------------------------------------------"
echo "[Hook] Running GitHub SSH provisioning for VM ${VMID}"
if [ ! -f "${KEY_PATH}" ]; then
  echo "[Hook] Generating new SSH keypair for VM ${VMID}"
  ssh-keygen -t ed25519 -f "${KEY_PATH}" -N "" -C "vm${VMID}@proxmox"
else
  echo "[Hook] Keypair already exists for VM ${VMID}"
fi
PUB_KEY=$(cat "${KEY_PATH}.pub")

echo
echo "------------------------------------------------------------"
echo "[Hook] Public key for VM ${VMID}:"
echo "${PUB_KEY}"
echo
echo "[Hook] Paste this public key into GitHub:"
echo "   https://github.com/settings/keys"
echo
echo "[Hook] To copy the key into your VM (adjust user/IP as needed):"
echo "   scp ${KEY_PATH} ngurley@<vm-ip>:~/.ssh/id_ed25519"
echo "   scp ${KEY_PATH}.pub ngurley@<vm-ip>:~/.ssh/id_ed25519.pub"
echo
echo "Then inside the VM, set permissions:"
echo "   chmod 600 ~/.ssh/id_ed25519"
echo "   chmod 644 ~/.ssh/id_ed25519.pub"
echo
echo "Test connection from inside VM with:"
echo "   ssh -T git@github.com"
echo "------------------------------------------------------------"
EOF
chmod +x "${SNIPPET_DIR}/github_ssh_hook.sh"

# ---------------------------------------------------------------
# Hook: github_ssh_cleanup.sh
# ---------------------------------------------------------------
cat > "${SNIPPET_DIR}/github_ssh_cleanup.sh" <<"EOF"
#!/bin/bash
set -e
VMID="$1"
PHASE="$2"
KEY_DIR="/var/lib/vz/ssh_keys"
KEY_PREFIX="${KEY_DIR}/vm-${VMID}-id_ed25519"

# Only clean up on VM deletion
if [ "$PHASE" == "pre-delete" ]; then
    echo "------------------------------------------------------------"
    echo "[Hook] Cleaning up GitHub SSH keys for VM ${VMID} (pre-delete phase)"
    if [ -f "${KEY_PREFIX}" ] || [ -f "${KEY_PREFIX}.pub" ]; then
        rm -f "${KEY_PREFIX}" "${KEY_PREFIX}.pub"
        echo "[Hook] Removed: ${KEY_PREFIX} and ${KEY_PREFIX}.pub"
    else
        echo "[Hook] No GitHub SSH keys found for VM ${VMID} — nothing to clean."
    fi
    echo "------------------------------------------------------------"
fi
EOF
chmod +x "${SNIPPET_DIR}/github_ssh_cleanup.sh"

# ---------------------------------------------------------------
# Utility: list-github-keys.sh
# ---------------------------------------------------------------
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

# ---------------------------------------------------------------
# Utility: show-github-key.sh
# ---------------------------------------------------------------
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
  echo "Check that the provisioning hook ran successfully."
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
echo "Paste this public key into GitHub (Settings → SSH and GPG keys):"
echo "Title suggestion: ${VM_NAME}@proxmox"
echo
cat "$KEY_PATH"
echo "------------------------------------------------------------"
EOF
chmod +x "${BIN_DIR}/show-github-key.sh"

# ---------------------------------------------------------------
# Wrap-up
# ---------------------------------------------------------------
echo "------------------------------------------------------------"
echo "[Installer] Installation complete!"
echo "Hooks installed to: $SNIPPET_DIR"
echo "Utilities installed to: $BIN_DIR"
echo
echo "Attach hooks to templates with:"
echo "  qm set 9000 --hookscript local:snippets/github_ssh_hook.sh"
echo "  qm set 9000 --hookscript local:snippets/github_ssh_cleanup.sh"
echo
echo "Test utilities:"
echo "  list-github-keys.sh"
echo "  show-github-key.sh <vmid>"
echo "------------------------------------------------------------"
