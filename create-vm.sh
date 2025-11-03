#!/bin/bash
# -------------------------------------------------------
# create-vm.sh
# Clone from base or Docker template and auto-configure networking
#
# Install instructions
# Place this script in /root/scripts/
# chmod +x /root/scripts/create-vm.sh
#
# Usage:
#   ./create-vm.sh [--docker] [VMID] <Name> <Bridge> <Memory_MB>
#
# Examples:
#   ./create-vm.sh dev-nginx vmbr4 4096
#   ./create-vm.sh 120 staging-api vmbr0 8192
#   ./create-vm.sh --docker webstack vmbr0 4096
# -------------------------------------------------------

set -e

# Default template IDs
BASE_TEMPLATE_ID=9000
DOCKER_TEMPLATE_ID=9001
TEMPLATE_ID=$BASE_TEMPLATE_ID

# Parse optional --docker flag
if [ "$1" == "--docker" ]; then
  TEMPLATE_ID=$DOCKER_TEMPLATE_ID
  shift
  echo "🐳 Using Docker template ($DOCKER_TEMPLATE_ID)"
fi

# Handle optional VMID argument (numeric check)
if [[ $1 =~ ^[0-9]+$ ]]; then
  NEW_VM_ID=$1
  shift
else
  NEW_VM_ID=$(pvesh get /cluster/nextid)
  echo "🧮 Auto-assigned next available VMID: $NEW_VM_ID"
fi

# Remaining arguments
NEW_VM_NAME=$1
BRIDGE=$2
MEMORY=$3

# Validation
if [ -z "$NEW_VM_NAME" ] || [ -z "$BRIDGE" ] || [ -z "$MEMORY" ]; then
  echo "Usage: $0 [--docker] [VMID] <Name> <Bridge> <Memory_MB>"
  exit 1
fi

# 🧩 Clone and configure
echo "🧩 Cloning VM from template $TEMPLATE_ID..."
qm clone $TEMPLATE_ID $NEW_VM_ID --name "$NEW_VM_NAME" --full

echo "🌐 Configuring network: bridge=$BRIDGE, IP=DHCP"
qm set $NEW_VM_ID --net0 virtio,bridge=$BRIDGE --ipconfig0 ip=dhcp

echo "👤 Setting user and SSH key..."
qm set $NEW_VM_ID --ciuser ngurley --sshkey /root/.ssh/id_rsa.pub

echo "💾 Setting memory to ${MEMORY}MB..."
qm set $NEW_VM_ID --memory $MEMORY

echo "🚀 Starting VM $NEW_VM_ID ($NEW_VM_NAME)..."
qm start $NEW_VM_ID

echo "✅ VM $NEW_VM_NAME ($NEW_VM_ID) created and started successfully."
