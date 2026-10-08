#!/usr/bin/env bash
# =============================================================================
# Prepare: fill a secret whose format generated-secrets cannot produce.
# Stands in for a repository's own generator (python3 scripts/generate-env.py
# --update in several consumers). Runs before the stack exists; the module
# masks every value this script adds or changes.
# Contract: docs/workflows/modules-backup-roundtrip-test.md#script-contract
# =============================================================================
set -euo pipefail

KEY=$(openssl rand -base64 32)
# Replaced in place, like the generators do; '|' never occurs in base64.
sed -i "s|^APP_SIGNING_KEY=.*|APP_SIGNING_KEY=${KEY}|" .env
grep -q '^APP_SIGNING_KEY=.\{44\}$' .env || { echo "APP_SIGNING_KEY was not written" >&2; exit 1; }
echo "filled APP_SIGNING_KEY"
