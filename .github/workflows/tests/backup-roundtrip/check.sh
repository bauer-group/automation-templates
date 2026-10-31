#!/usr/bin/env bash
# =============================================================================
# Check: exit 0 when the seeded row and file are in the state ROUNDTRIP_EXPECT
# names - "present" (both there, file content intact) or "absent" (both gone).
# Every item is checked on its own, so "absent" proves the mutation removed
# each of them and "present" proves the restore brought each of them back.
# Contract: docs/workflows/modules-backup-roundtrip-test.md#script-contract
# =============================================================================
set -euo pipefail
: "${ROUNDTRIP_MARKER:?set by the round-trip module}"

case "${ROUNDTRIP_EXPECT:?set by the round-trip module}" in
  present) WANT_ROWS=1 ;;
  absent)  WANT_ROWS=0 ;;
  *) echo "unknown ROUNDTRIP_EXPECT '$ROUNDTRIP_EXPECT'" >&2; exit 2 ;;
esac
FAILED=0

ROWS=$(docker compose exec -T database psql -tA -v ON_ERROR_STOP=1 -v marker="$ROUNDTRIP_MARKER" -U app -d app <<'SQL'
SELECT count(*) FROM roundtrip_marker WHERE marker = :'marker';
SQL
)
if [ "$ROWS" = "$WANT_ROWS" ]; then
  echo "ok   database row: $ROWS (expected $WANT_ROWS)"
else
  echo "FAIL database row: $ROWS (expected $WANT_ROWS)"; FAILED=1
fi

FILE="/srv/files/roundtrip/$ROUNDTRIP_MARKER.txt"
CONTENT=$(docker compose exec -T app sh -c 'cat "$1" 2>/dev/null || true' _ "$FILE")
if [ "$ROUNDTRIP_EXPECT" = "present" ] && [ "$CONTENT" = "$ROUNDTRIP_MARKER" ]; then
  echo "ok   file present with the seeded content"
elif [ "$ROUNDTRIP_EXPECT" = "absent" ] && [ -z "$CONTENT" ]; then
  echo "ok   file absent"
else
  echo "FAIL file $FILE: content '${CONTENT:-<missing>}' (expected $ROUNDTRIP_EXPECT)"; FAILED=1
fi

exit "$FAILED"
