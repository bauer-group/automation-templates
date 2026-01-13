#!/usr/bin/env bash
# =============================================================================
# GitHub Self-Hosted Runner Management Script
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log()   { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*" >&2; }
info()  { echo -e "${BLUE}[i]${NC} $*"; }

# Load environment
if [[ -f .env ]]; then
  set -a
  source .env
  set +a
fi

RUNNER_COUNT="${RUNNER_COUNT:-8}"

usage() {
  cat <<EOF
GitHub Self-Hosted Runner Management

Usage: $(basename "$0") <command>

Commands:
  start       Start runners (uses RUNNER_COUNT from .env)
  stop        Stop all runners
  restart     Restart all runners
  status      Show runner status
  scale <n>   Scale to n runners
  logs        Show runner logs (follow mode)
  update      Pull latest images and restart
  cleanup     Remove stopped containers and unused images
  help        Show this help message

Examples:
  $(basename "$0") start
  $(basename "$0") scale 4
  $(basename "$0") logs
EOF
}

cmd_start() {
  log "Starting runners..."
  docker compose pull
  docker compose up -d
  docker compose up -d --scale runner="${RUNNER_COUNT}"
  log "Started ${RUNNER_COUNT} runner(s)"
  cmd_status
}

cmd_stop() {
  log "Stopping runners..."
  docker compose down
  log "All runners stopped"
}

cmd_restart() {
  log "Restarting runners..."
  docker compose down
  docker compose pull
  docker compose up -d
  docker compose up -d --scale runner="${RUNNER_COUNT}"
  log "Restarted ${RUNNER_COUNT} runner(s)"
  cmd_status
}

cmd_status() {
  echo ""
  info "Runner Status:"
  echo "----------------------------------------"
  docker compose ps
  echo ""
  info "Active runner containers:"
  docker ps --filter "ancestor=myoung34/github-runner:latest" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || true
}

cmd_scale() {
  local count="${1:-}"
  if [[ -z "$count" || ! "$count" =~ ^[0-9]+$ ]]; then
    error "Usage: $(basename "$0") scale <number>"
    exit 1
  fi
  log "Scaling to ${count} runner(s)..."
  docker compose up -d --scale runner="${count}"
  log "Scaled to ${count} runner(s)"
  cmd_status
}

cmd_logs() {
  log "Showing runner logs (Ctrl+C to exit)..."
  docker compose logs -f runner
}

cmd_update() {
  log "Updating runners..."
  docker compose pull
  docker compose up -d
  docker compose up -d --scale runner="${RUNNER_COUNT}"
  log "Update complete"
  cmd_status
}

cmd_cleanup() {
  log "Cleaning up..."
  docker compose down --remove-orphans 2>/dev/null || true
  docker container prune -f
  docker image prune -f
  log "Cleanup complete"
}

# Main
case "${1:-help}" in
  start)   cmd_start ;;
  stop)    cmd_stop ;;
  restart) cmd_restart ;;
  status)  cmd_status ;;
  scale)   cmd_scale "${2:-}" ;;
  logs)    cmd_logs ;;
  update)  cmd_update ;;
  cleanup) cmd_cleanup ;;
  help|--help|-h) usage ;;
  *)
    error "Unknown command: $1"
    usage
    exit 1
    ;;
esac
