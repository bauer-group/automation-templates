#!/usr/bin/env bash
#
# Structural test: Gitleaks is opt-in in every template that can run it.
#
# The templates also serve repositories that have GitHub secret scanning and push
# protection. There Gitleaks duplicates them and needs a licence secret that
# Dependabot runs do not receive, so a default of 'gitleaks' fails every Dependabot
# pull request of an organization repository on "missing gitleaks license". The
# decision (2026-10) is: Gitleaks stays implemented, a caller enables it explicitly.
#
# Two ways the default can silently flip back, both checked here:
#   1. an engine input's default goes back to 'gitleaks' (or 'both');
#   2. a reusable workflow hard-codes the engine when it calls the scan, so its own
#      callers get Gitleaks without asking for it - esp32, stm32, platformio and
#      zephyr-build did exactly that with scan-engine: 'gitleaks'.
# Workflows that only run for this repository (no workflow_call) may enable it: they
# are callers, not templates.
#
# Usage: bash .github/actions/security-scan/tests/opt-in-defaults.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

PASSED=0
FAILED=0

# input_default <file> <input name>: the default of the first key named exactly
# "<name>:" with nothing after the colon (a definition, not a `with:` value).
input_default() {
  awk -v name="$2" '
    !found && $0 ~ ("^ +" name ":[[:space:]]*$") {
      match($0, /^ +/); ind = RLENGTH; found = 1; next
    }
    found {
      if ($0 ~ /^[[:space:]]*$/) next
      match($0, /^ */)
      if (RLENGTH <= ind) exit
      if ($0 ~ /^ +default:/) {
        sub(/^ +default:[[:space:]]*/, "")
        gsub(/["\047]/, "")
        print
        exit
      }
    }
  ' "$1"
}

check_default() {
  local rel="$1" name="$2" file="$REPO_ROOT/$1" got
  if [ ! -f "$file" ]; then
    FAILED=$((FAILED + 1))
    printf 'FAIL %s: file not found\n' "$rel"
    return
  fi
  got="$(input_default "$file" "$name")"
  if [ "$got" = "none" ]; then
    PASSED=$((PASSED + 1))
    printf 'ok   %-52s %-22s default none\n' "$rel" "$name"
  else
    FAILED=$((FAILED + 1))
    printf 'FAIL %-52s %-22s default %s, expected none\n' "$rel" "$name" "'${got:-<missing>}'"
  fi
}

check_default .github/actions/security-scan/action.yml          scan-engine
check_default .github/actions/security-scan-meta/action.yml     scan-engine
check_default .github/workflows/modules-security-scan.yml       scan-engine
check_default .github/workflows/modules-pr-validation.yml       security-scan-engine
check_default .github/workflows/python-semantic-release.yml     security-engine
check_default .github/workflows/esp32-build.yml                 security-scan-engine
check_default .github/workflows/stm32-build.yml                 security-scan-engine
check_default .github/workflows/platformio-build.yml            security-scan-engine
check_default .github/workflows/zephyr-build.yml                security-scan-engine

# No reusable workflow may pass a literal engine that runs Gitleaks.
HARDCODED_ENGINE="^[[:space:]]+(scan-engine|security-scan-engine|security-engine):[[:space:]]*[\"']?(gitleaks|both)[\"']?[[:space:]]*(#.*)?$"
REUSABLE=0
HARDCODED=0
for file in "$REPO_ROOT"/.github/workflows/*.yml; do
  grep -qE '^[[:space:]]+workflow_call:' "$file" || continue
  REUSABLE=$((REUSABLE + 1))
  rel="${file#"$REPO_ROOT"/}"
  if hits="$(grep -nE "$HARDCODED_ENGINE" "$file")"; then
    HARDCODED=$((HARDCODED + 1))
    printf 'FAIL %s hard-codes a Gitleaks engine for its callers:\n' "$rel"
    printf '%s\n' "$hits" | sed 's/^/       | /'
  fi
done
if [ "$REUSABLE" -eq 0 ]; then
  FAILED=$((FAILED + 1))
  echo "FAIL found no reusable workflow (workflow_call) - the check above checked nothing"
elif [ "$HARDCODED" -eq 0 ]; then
  PASSED=$((PASSED + 1))
  echo "ok   none of the ${REUSABLE} reusable workflows hard-codes a Gitleaks engine"
else
  FAILED=$((FAILED + HARDCODED))
fi

echo
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
