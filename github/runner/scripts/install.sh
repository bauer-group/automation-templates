#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="${BASE_DIR:-/opt/gha}"
REPO_DIR="${REPO_DIR:-$BASE_DIR/runner}"
THIS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"

log(){ echo -e "\033[1;32m[+] $*\033[0m"; }
err(){ echo -e "\033[1;31m[!] $*\033[0m" >&2; }

[[ $EUID -eq 0 ]] || { err "Bitte als root/sudo ausführen."; exit 1; }

install -m 0755 -d /etc/apt/keyrings
if ! [ -f /etc/apt/keyrings/docker.gpg ]; then
  log "Docker-Repo hinzufügen & Engine installieren…"
  apt-get update -y
  apt-get install -y ca-certificates curl gnupg lsb-release jq git
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg
  . /etc/os-release
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $VERSION_CODENAME stable" > /etc/apt/sources.list.d/docker.list
  apt-get update -y
  apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  systemctl enable --now docker
fi

log "Zielverzeichnis vorbereiten: $REPO_DIR"
mkdir -p "$REPO_DIR"
rsync -a --delete "$THIS_DIR"/ "$REPO_DIR"/

cd "$REPO_DIR"
if [[ ! -f .env ]]; then
  cp .env.example .env
fi

# Optionale Zufuhr eines Base64-kodierten GitHub-App-Keys (Cloud-Init)
if [[ -n "${APP_PRIVATE_KEY_BASE64:-}" ]]; then
  CLEANED="$(echo "$APP_PRIVATE_KEY_BASE64" | base64 -d | sed ':a;N;$!ba;s/\n/\\n/g')"
  sed -i "s|^APP_PRIVATE_KEY=.*|APP_PRIVATE_KEY=${CLEANED}|" .env
fi

install -d /etc/systemd/system
install -m 0644 systemd/gha-runners.service /etc/systemd/system/gha-runners.service

log "Stack starten & auf 8 Runner skalieren…"
export $(grep -v '^#' .env | xargs -d '\n' -I{} echo {})
docker compose pull
docker compose up -d
docker compose up -d --scale runner="${RUNNER_COUNT}"

systemctl daemon-reload
systemctl enable --now gha-runners.service

log "Fertig! Aktive Runner-Container:"
docker ps --filter "name=$(basename "$REPO_DIR")_runner"
