#!/usr/bin/env bash
# GM node bootstrap — run ONCE on the device Jarred places at Growing Mindfully.
# Turns any always-on box (Linux mini PC / Raspberry Pi / Mac mini) into an
# agent-reachable Tailscale subnet router on the GM LAN.
# Works on Debian/Ubuntu/Raspberry Pi OS and macOS. Safe to re-run.
set -euo pipefail

CONTROL_PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEQgppWEG8Bg30gGiExT6bXHWkJEgmi0wxII6MCgDpqv gm-node-control (clawd@mini)"
HOSTNAME_TAG="gm-node"

echo "== GM node bootstrap =="
OS="$(uname -s)"

# 1) Install Tailscale
if ! command -v tailscale >/dev/null 2>&1; then
  echo "[1/5] installing Tailscale..."
  if [ "$OS" = "Darwin" ]; then
    echo "  macOS: install the Tailscale app from https://tailscale.com/download/mac then re-run." ; exit 2
  else
    curl -fsSL https://tailscale.com/install.sh | sh
  fi
else echo "[1/5] Tailscale already installed"; fi

# 2) Detect the LAN subnet this device sits on (to advertise as a route)
if [ "$OS" = "Darwin" ]; then
  IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)
else
  IP=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')
fi
SUBNET="$(echo "$IP" | awk -F. '{print $1"."$2"."$3".0/24"}')"
echo "[2/5] this device IP=$IP  -> advertising subnet $SUBNET"

# 3) Enable IP forwarding (subnet router requirement, Linux)
if [ "$OS" != "Darwin" ]; then
  echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/99-tailscale.conf >/dev/null
  echo "net.ipv6.conf.all.forwarding=1" | sudo tee -a /etc/sysctl.d/99-tailscale.conf >/dev/null
  sudo sysctl -p /etc/sysctl.d/99-tailscale.conf >/dev/null 2>&1 || true
fi

# 4) Install the agent control SSH key
echo "[4/5] installing control SSH key..."
mkdir -p ~/.ssh && chmod 700 ~/.ssh
grep -qF "$CONTROL_PUBKEY" ~/.ssh/authorized_keys 2>/dev/null || echo "$CONTROL_PUBKEY" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
[ "$OS" = "Darwin" ] && sudo systemsetup -setremotelogin on >/dev/null 2>&1 || true

# 5) Join the tailnet as a subnet router (prints an auth URL for Jarred to approve ONCE)
echo "[5/5] joining tailnet winn.solutions as subnet router..."
sudo tailscale up --hostname="$HOSTNAME_TAG" --advertise-routes="$SUBNET" --accept-dns=false
echo
echo "== DONE. Tailscale IP: $(tailscale ip -4 2>/dev/null | head -1) =="
echo "Tell the agent: gm-node is up, advertising $SUBNET."
