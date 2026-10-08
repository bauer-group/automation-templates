#!/usr/bin/env bash
# =============================================================================
# Prepare: fill a secret whose format generated-secrets cannot produce.
# Stands in for a repository's own generator (python3 scripts/generate-env.py
# in several consumers). Runs before the stack exists; the module masks every
# value this script adds or changes.
# Contract: docs/workflows/modules-backup-roundtrip-test.md#script-contract
# =============================================================================
set -euo pipefail

KEY=$(openssl rand -base64 32)
# Moved to the end and written WITHOUT a trailing newline, as a generator may
# leave it: the module must still mask it and must not glue the next key it
# appends (APP_MODE from env-overrides) onto this line.
sed -i '/^APP_SIGNING_KEY=/d' .env
printf 'APP_SIGNING_KEY=%s' "$KEY" >> .env
grep -q '^APP_SIGNING_KEY=.\{44\}$' .env || { echo "APP_SIGNING_KEY was not written" >&2; exit 1; }
echo "filled APP_SIGNING_KEY"
