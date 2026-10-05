#!/usr/bin/env bash
# harden.sh - OS-level security hardening for the Sentinel-Ops VM
# Usage: sudo ./scripts/harden.sh
#
# SAFETY: allows SSH (22) BEFORE enabling the firewall.
# Keep a second SSH session open while running this.

set -euo pipefail

# Ports to allow. Mirrors the Azure NSG rules.
ALLOWED_TCP=(22 3000 9090)

log()  { echo "[$(date '+%F %T')] $*"; }
fail() { echo "[FAIL] $*" >&2; exit 1; }

[[ $EUID -eq 0 ]] || fail "Run with sudo: sudo $0"
grep -qi ubuntu /etc/os-release || fail "This script supports Ubuntu only"

# --- 1) Firewall ---
log "Configuring UFW..."
command -v ufw >/dev/null 2>&1 || apt-get install -y ufw

ufw default deny incoming
ufw default allow outgoing

for port in "${ALLOWED_TCP[@]}"; do
  ufw allow "${port}/tcp"
  log "Allowed ${port}/tcp"
done

ufw --force enable
log "UFW enabled"

# --- 2) SSH hardening ---
log "Hardening SSH..."
DROPIN=/etc/ssh/sshd_config.d/99-sentinel-hardening.conf
install -d -m 0755 /etc/ssh/sshd_config.d

cat > "$DROPIN" <<'EOF'
# Sentinel-Ops hardening - managed by scripts/harden.sh
PermitRootLogin no
PermitEmptyPasswords no
X11Forwarding no
MaxAuthTries 3
LoginGraceTime 30
ClientAliveInterval 300
ClientAliveCountMax 2
EOF
chmod 0644 "$DROPIN"

sshd -t || fail "sshd config is invalid - not reloading. Check $DROPIN"
systemctl reload ssh
log "SSH hardened and reloaded"

# --- 3) Automatic security updates ---
log "Enabling unattended security upgrades..."
apt-get install -y unattended-upgrades
dpkg-reconfigure -f noninteractive unattended-upgrades

# --- 4) Report ---
echo ""
echo "=============================================="
echo " Hardening summary"
echo "=============================================="
ufw status verbose
echo ""
echo "Effective SSH settings:"
sshd -T | grep -Ei '^(permitrootlogin|passwordauthentication|maxauthtries|permitemptypasswords)'
echo "=============================================="
log "Hardening complete"