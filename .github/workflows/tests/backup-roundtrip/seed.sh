#!/usr/bin/env bash
# =============================================================================
# Seed: one database row and one file, both carrying the run's marker.
# Contract: docs/workflows/modules-backup-roundtrip-test.md#script-contract
# =============================================================================
set -euo pipefail
: "${ROUNDTRIP_MARKER:?set by the round-trip module}"

# The marker goes in as a psql variable, never pasted into SQL text.
docker compose exec -T database psql -q -v ON_ERROR_STOP=1 -v marker="$ROUNDTRIP_MARKER" -U app -d app <<'SQL'
CREATE TABLE IF NOT EXISTS roundtrip_marker (
  marker     text PRIMARY KEY,
  created_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO roundtrip_marker (marker) VALUES (:'marker');
SQL

# Written by the application container (uid 1000), as real uploads would be.
docker compose exec -T app sh -c \
  'mkdir -p /srv/files/roundtrip && printf "%s\n" "$1" > "/srv/files/roundtrip/$1.txt"' _ "$ROUNDTRIP_MARKER"

echo "seeded row and file for $ROUNDTRIP_MARKER"
