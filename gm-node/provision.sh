#!/usr/bin/env bash
# GM node bootstrap — run ONCE on the always-on device Jarred places at Growing Mindfully.
# Turns the box (iMac/macOS, or a Linux mini PC / Raspberry Pi) into an agent-reachable
# Tailscale subnet router on the GM LAN. Safe to re-run.
set -euo pipefail

CONTROL_PUBKEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEQgppWEG8Bg30gGiExT6bXHWkJEgmi0wxII6MCgDpqv gm-node-control (clawd@mini)"
HOSTNAME_TAG="gm-node"
echo "== GM node bootstrap =="
OS="$(uname -s)"

if [ "$OS" = "Darwin" ]; then
  # ---- macOS / iMac path (Homebrew tailscaled = the variant that can be a subnet router) ----
  if ! command -v brew >/dev/null 2>&1; then
    echo "[1/5] installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
  fi
  command -v tailscale >/dev/null 2>&1 || { echo "[1/5] brew install tailscale..."; brew install tailscale; }
  echo "[2/5] starting tailscaled service..."
  sudo brew services start tailscale >/dev/null 2>&1 || brew services start tailscale
  IP=$(ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null)
  echo "[3/5] enabling IP forwarding..."
  sudo sysctl -w net.inet.ip.forwarding=1 >/dev/null 2>&1 || true
  echo "[4/5] enabling Remote Login (SSH) + installing control key..."
  sudo systemsetup -setremotelogin on >/dev/null 2>&1 || true
else
  # ---- Linux path (mini PC / Raspberry Pi) ----
  command -v tailscale >/dev/null 2>&1 || { echo "[1/5] installing Tailscale..."; curl -fsSL https://tailscale.com/install.sh | sh; }
  IP=$(ip -4 route get 1.1.1.1 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="src"){print $(i+1); exit}}')
  echo "[3/5] enabling IP forwarding..."
  echo "net.ipv4.ip_forward=1" | sudo tee /etc/sysctl.d/99-tailscale.conf >/dev/null
  echo "net.ipv6.conf.all.forwarding=1" | sudo tee -a /etc/sysctl.d/99-tailscale.conf >/dev/null
  sudo sysctl -p /etc/sysctl.d/99-tailscale.conf >/dev/null 2>&1 || true
fi

SUBNET="$(echo "$IP" | awk -F. '{print $1"."$2"."$3".0/24"}')"
echo "    device IP=$IP  ->  advertising subnet $SUBNET"
mkdir -p ~/.ssh && chmod 700 ~/.ssh
grep -qF "$CONTROL_PUBKEY" ~/.ssh/authorized_keys 2>/dev/null || echo "$CONTROL_PUBKEY" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

echo "[5/5] joining tailnet winn.solutions as subnet router (approve the printed URL once)..."
sudo tailscale up --hostname="$HOSTNAME_TAG" --advertise-routes="$SUBNET" --accept-dns=false
echo
echo "== DONE. Tailscale IP: $(tailscale ip -4 2>/dev/null | head -1) =="
echo "Tell the agent: gm-node is up, advertising $SUBNET."
