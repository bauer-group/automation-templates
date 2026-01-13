#!/usr/bin/env bash
# =============================================================================
# GitHub Self-Hosted Runner Uninstallation Script
# =============================================================================
set -euo pipefail

BASE_DIR="${BASE_DIR:-/opt/gha}"
REPO_DIR="${REPO_DIR:-$BASE_DIR/runner}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[+]${NC} $*"; }
warn() { echo -e "${YELLOW}[!]${NC} $*"; }
err()  { echo -e "${RED}[✗]${NC} $*" >&2; }

log "Stopping runners..."
systemctl stop gha-runners.service 2>/dev/null || true
systemctl disable gha-runners.service 2>/dev/null || true

log "Removing Docker containers..."
if [[ -f "$REPO_DIR/docker-compose.yml" ]]; then
  docker compose -f "$REPO_DIR/docker-compose.yml" down --remove-orphans 2>/dev/null || true
fi

log "Removing systemd service..."
rm -f /etc/systemd/system/gha-runners.service
systemctl daemon-reload

# Optional: Remove runner directory
if [[ "${REMOVE_FILES:-false}" == "true" ]]; then
  log "Removing runner files..."
  rm -rf "$REPO_DIR"
fi

# Optional: Prune Docker
if [[ "${PRUNE_DOCKER:-false}" == "true" ]]; then
  log "Pruning Docker..."
  docker container prune -f
  docker image prune -f
fi

log "Uninstallation complete!"
echo ""
echo "Optional cleanup commands:"
echo "  rm -rf $REPO_DIR           # Remove runner files"
echo "  docker system prune -af    # Remove all unused Docker data"
