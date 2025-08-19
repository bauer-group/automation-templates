#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

export $(grep -v '^#' .env | xargs -d '\n' -I{} echo {})

docker compose pull

docker compose up -d
docker compose up -d --scale runner="${RUNNER_COUNT}"

echo "Manage Completed!"
