#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${BASE_DIR:-/opt/gha}"
REPO_DIR="${REPO_DIR:-$BASE_DIR/runner}"

systemctl stop gha-runners.service || true
systemctl disable gha-runners.service || true

docker compose -f "$REPO_DIR/docker-compose.yml" down || true

rm -f /etc/systemd/system/gha-runners.service

systemctl daemon-reload

echo "Uninstall Completed!"
