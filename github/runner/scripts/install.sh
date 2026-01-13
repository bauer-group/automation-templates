#!/usr/bin/env bash
# =============================================================================
# GitHub Self-Hosted Runner Installation Script
# =============================================================================
# Installs Docker and sets up self-hosted GitHub Actions runners
#
# Note: For production environments with full Docker isolation, consider the
# Docker-in-Docker solution: https://github.com/bauer-group/GitHubRunner
# =============================================================================
set -euo pipefail

BASE_DIR="${BASE_DIR:-/opt/gha}"
REPO_DIR="${REPO_DIR:-$BASE_DIR/runner}"
THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*" >&2; }

# Check root
[[ $EUID -eq 0 ]] || { err "Please run as root/sudo."; exit 1; }

# Install Docker if not present
install -m 0755 -d /etc/apt/keyrings
if ! [ -f /etc/apt/keyrings/docker.gpg ]; then
  log "Adding Docker repository and installing Docker Engine..."
  apt-get update -y
  apt-get install -y ca-certificates curl gnupg lsb-release jq git rsync
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  . /etc/os-release
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $VERSION_CODENAME stable" > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
  log "Docker installed successfully"
else
  log "Docker already installed"
fi

# Prepare target directory
log "Preparing target directory: $REPO_DIR"
mkdir -p "$REPO_DIR"
rsync -a --delete "$THIS_DIR"/ "$REPO_DIR"/

cd "$REPO_DIR"

# Create .env from example if not exists
if [[ ! -f .env ]]; then
  cp .env.example .env
  warn "Created .env from template - please configure before starting runners"
fi

# Handle Base64-encoded GitHub App private key (for cloud-init)
if [[ -n "${APP_PRIVATE_KEY_BASE64:-}" ]]; then
  log "Decoding GitHub App private key..."
  CLEANED="$(echo "$APP_PRIVATE_KEY_BASE64" | base64 -d | sed ':a;N;$!ba;s/\n/\\n/g')"
  sed -i "s|^APP_PRIVATE_KEY=.*|APP_PRIVATE_KEY=${CLEANED}|" .env
fi

# Install systemd service
log "Installing systemd service..."
install -d /etc/systemd/system
install -m 0644 systemd/gha-runners.service /etc/systemd/system/gha-runners.service

# Load environment and start runners
log "Starting runners..."
set -a
source .env
set +a

RUNNER_COUNT="${RUNNER_COUNT:-8}"

docker compose pull
docker compose up -d
docker compose up -d --scale runner="${RUNNER_COUNT}"

systemctl daemon-reload
systemctl enable --now gha-runners.service

log "Installation complete!"
echo ""
log "Active runner containers:"
docker ps --filter "ancestor=myoung34/github-runner:latest" --format "table {{.Names}}\t{{.Status}}"
echo ""
log "Management commands:"
echo "  ./scripts/manage.sh status   - Show runner status"
echo "  ./scripts/manage.sh logs     - View runner logs"
echo "  ./scripts/manage.sh scale N  - Scale to N runners"
echo "  ./scripts/manage.sh restart  - Restart all runners"
