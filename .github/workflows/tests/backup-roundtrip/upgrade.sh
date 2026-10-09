#!/usr/bin/env bash
# =============================================================================
# Upgrade hook: what the release notes tell an operator to do before the
# upgrade (upgrade-script). Runs after the previous release took its snapshot
# and before the module switches to the images and compose files of this
# commit.
#
# Proves the state the module promises at this point, then migrates the .env
# the way release notes do: the previous release ran on the previous image,
# from previous-release.yml, with the snapshot id and the previous images
# exported.
# Contract: docs/workflows/modules-backup-roundtrip-test.md#upgrade-from-a-previous-release
# =============================================================================
set -euo pipefail
: "${ROUNDTRIP_SNAPSHOT_ID:?set by the round-trip module after the backup}"
: "${ROUNDTRIP_PREVIOUS_IMAGES:?set by the round-trip module (upgrade-from)}"
SERVICE="${ROUNDTRIP_BACKUP_SERVICE:?set by the round-trip module}"
FAILED=0

[ "${ROUNDTRIP_PHASE:-}" = "upgrade" ] || { echo "FAIL ROUNDTRIP_PHASE is '${ROUNDTRIP_PHASE:-}', expected upgrade"; FAILED=1; }

PREVIOUS=$(jq -r --arg s "$SERVICE" '.[$s] // empty' <<< "$ROUNDTRIP_PREVIOUS_IMAGES")
CONTAINER=$(docker compose ps -q "$SERVICE")
RUNNING=$(docker inspect --format '{{.Image}}' "$CONTAINER")
WANT=$(docker image inspect --format '{{.Id}}' "$PREVIOUS")
if [ -n "$PREVIOUS" ] && [ "$RUNNING" = "$WANT" ]; then
  echo "ok   $SERVICE runs the previous release $PREVIOUS"
else
  echo "FAIL $SERVICE runs $RUNNING, expected the previous release '${PREVIOUS:-<none>}' ($WANT)"; FAILED=1
fi

LABEL=$(docker inspect --format '{{index .Config.Labels "roundtrip.release"}}' "$CONTAINER")
if [ "$LABEL" = "previous" ]; then
  echo "ok   the previous release was started from previous-release.yml"
else
  echo "FAIL label roundtrip.release is '$LABEL', expected previous (upgrade-from-compose-files)"; FAILED=1
fi

# The snapshot the restore will read is one of the previous release's.
if docker compose exec -T "$SERVICE" backuphelper list | awk -v id="$ROUNDTRIP_SNAPSHOT_ID" '$1 == id && $2 > 0 {f = 1} END {exit !f}'; then
  echo "ok   snapshot $ROUNDTRIP_SNAPSHOT_ID is in the previous release's data dir"
else
  echo "FAIL snapshot $ROUNDTRIP_SNAPSHOT_ID is not listed by the previous release"; FAILED=1
fi

[ "$FAILED" -eq 0 ] || exit 1

# The migration: a setting the new release reads differently. The module
# recreates the application with it at 'up -d'.
sed -i 's/^APP_MODE=.*/APP_MODE=upgraded/' .env
grep -qx 'APP_MODE=upgraded' .env
echo "migrated APP_MODE in .env"
