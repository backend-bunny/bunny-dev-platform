#!/usr/bin/env bash

set -e

# Usage information
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <IP_ADDRESS> <HOSTNAME>"
    exit 1
fi

IP_ADDRESS=$1
HOSTNAME=$2
KEY_DIR=".tmp/host_keys"
mkdir -p "$KEY_DIR"

echo "Extracting SSH host key from $HOSTNAME ($IP_ADDRESS)..."
ssh -o StrictHostKeyChecking=accept-new k3s@$IP_ADDRESS \
  "sudo ssh-keygen -y -f /etc/ssh/ssh_host_ed25519_key" \
  > "$KEY_DIR/${HOSTNAME}_ed25519.pub"

# Convert SSH public key to age format (requires ssh-to-age tool)
# Install with: go install github.com/Mic92/ssh-to-age@latest
if command -v ssh-to-age >/dev/null 2>&1; then
  cat "$KEY_DIR/${HOSTNAME}_ed25519.pub" | ssh-to-age > "$KEY_DIR/${HOSTNAME}_age.pub"
  AGE_KEY=$(cat "$KEY_DIR/${HOSTNAME}_age.pub")
  echo "Age public key for $HOSTNAME: $AGE_KEY"
  echo "Add this key to your .sops.yaml file and re-encrypt your secrets"
else
  echo "ssh-to-age tool not found. Please install it with: go install github.com/Mic92/ssh-to-age@latest"
  echo "Then convert the SSH key manually:"
  echo "  cat $KEY_DIR/${HOSTNAME}_ed25519.pub | ssh-to-age > $KEY_DIR/${HOSTNAME}_age.pub"
fi