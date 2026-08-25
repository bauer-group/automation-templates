#!/usr/bin/env bash
#
# Structural test: every action output a workflow reads must actually be declared.
#
# This catches the root cause of the "Secrets Found | false" bug, which no behavioural
# test could have found. modules-security-scan.yml read
# `steps.security.outputs.secrets-found`, but security-scan/action.yml only ever
# declared `gitleaks-secrets-found`. An undeclared output is not an error in GitHub
# Actions - it silently expands to the empty string. The summary then rendered
# `${{ ... || 'false' }}` as "false", so the security report structurally could not
# report a secret, no matter what the scanner found.
#
# The failure mode is what makes it worth a test: it is completely silent, it always
# reads as the reassuring answer, and it survives every scan-logic test you write.
#
# Usage: bash .github/actions/security-scan/tests/declared-outputs.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
ACTION_FILE="$REPO_ROOT/.github/actions/security-scan/action.yml"
WORKFLOW_FILE="$REPO_ROOT/.github/workflows/modules-security-scan.yml"
STEP_ID="security"

for f in "$ACTION_FILE" "$WORKFLOW_FILE"; do
  if [ ! -f "$f" ]; then
    echo "FATAL: $f not found"
    exit 1
  fi
done

# Output names declared by the action: keys at two-space indent inside `outputs:`,
# up to the next top-level block.
DECLARED=$(awk '
  /^outputs:/ { in_outputs = 1; next }
  /^[a-z]/    { in_outputs = 0 }
  in_outputs && /^  [a-zA-Z0-9_-]+:/ {
    line = $0
    sub(/^  /, "", line)
    sub(/:.*/, "", line)
    print line
  }
' "$ACTION_FILE" | sort -u)

# Output names the workflow reads from that step.
REFERENCED=$(grep -o "steps\.${STEP_ID}\.outputs\.[a-zA-Z0-9_-]*" "$WORKFLOW_FILE" \
  | sed "s/^steps\.${STEP_ID}\.outputs\.//" | sort -u)

if [ -z "$REFERENCED" ]; then
  echo "FATAL: found no 'steps.${STEP_ID}.outputs.*' references in $(basename "$WORKFLOW_FILE")."
  echo "       The step id changed - update this test."
  exit 1
fi

if [ -z "$DECLARED" ]; then
  echo "FATAL: could not parse the outputs block of $(basename "$ACTION_FILE")."
  exit 1
fi

PASSED=0
FAILED=0

echo "Checking $(basename "$WORKFLOW_FILE") against the outputs of $(basename "$ACTION_FILE")"
echo

while IFS= read -r name; do
  [ -n "$name" ] || continue
  if printf '%s\n' "$DECLARED" | grep -qxF -- "$name"; then
    PASSED=$((PASSED + 1))
    printf 'ok   %s is declared\n' "$name"
  else
    FAILED=$((FAILED + 1))
    printf 'FAIL %s is READ but never declared\n' "$name"
    printf '       It expands to the empty string, silently. Declared outputs are: %s\n' \
      "$(printf '%s' "$DECLARED" | tr '\n' ' ')"
  fi
done <<< "$REFERENCED"

echo
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
