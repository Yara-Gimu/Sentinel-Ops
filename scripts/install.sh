#!/usr/bin/env bash
# install.sh - Installs base packages and Docker on Ubuntu
# Usage: sudo ./scripts/install.sh

set -euo pipefail

log() { echo "[$(date '+%F %T')] $*"; }

# 1) Must run as root
if [[ $EUID -ne 0 ]]; then
  echo "Please run with sudo: sudo $0"
  exit 1
fi

# 2) Must be Ubuntu
if ! grep -qi ubuntu /etc/os-release; then
  echo "This script supports Ubuntu only"
  exit 1
fi

# 3) Base packages
log "Installing base packages..."
apt-get update -y
apt-get install -y ca-certificates curl gnupg jq openssl

# 4) Docker (skip if already installed)
if command -v docker >/dev/null 2>&1; then
  log "Docker already installed: $(docker --version)"
else
  log "Installing Docker..."
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  chmod a+r /etc/apt/keyrings/docker.asc
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
fi

# 5) Start Docker now and on every boot
systemctl enable --now docker

# 6) Allow the normal user to use docker without sudo
usermod -aG docker "${SUDO_USER:-$USER}"

log "Done: $(docker --version) | $(docker compose version)"

# 7) Self-verification
log "Verifying installation..."
docker --version >/dev/null || { echo "Docker verification failed"; exit 1; }
docker compose version >/dev/null || { echo "Compose verification failed"; exit 1; }
systemctl is-active --quiet docker || { echo "Docker service is not running"; exit 1; }
log "Verification passed"
log "Log out and log back in so the docker group takes effect."