#!/usr/bin/env bash
# =============================================================================
# Mutate: delete what seed.sh wrote, so the restore has to bring it back.
# Contract: docs/workflows/modules-backup-roundtrip-test.md#script-contract
# =============================================================================
set -euo pipefail
: "${ROUNDTRIP_MARKER:?set by the round-trip module}"

docker compose exec -T database psql -q -v ON_ERROR_STOP=1 -v marker="$ROUNDTRIP_MARKER" -U app -d app <<'SQL'
DELETE FROM roundtrip_marker WHERE marker = :'marker';
SQL

docker compose exec -T app rm -f "/srv/files/roundtrip/$ROUNDTRIP_MARKER.txt"

echo "deleted row and file for $ROUNDTRIP_MARKER"
