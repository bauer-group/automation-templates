#!/usr/bin/env bash
#
# Behavioural test for the 'Setup Security Scan' step (id: engine) in ../action.yml.
#
# GitGuardian was removed, but the engine names callers already pass must keep working
# without silently changing what a caller asked for:
#
#   gitleaks     -> gitleaks
#   both         -> gitleaks, plus a notice (the gitleaks half of what 'both' ran)
#   gitguardian  -> NO secret scanner, plus a warning. Mapping it to gitleaks would
#                   switch gitleaks on for a caller that chose 'gitguardian' to keep it
#                   off (bauer-group/OT-CAN2IP-WebUI does exactly that, because the
#                   Gitleaks licence is not available to Dependabot runs).
#   anything else, including '' -> no secret scanner, plus a warning. Before, an
#                   unknown value silently skipped every engine; now it says so.
#
# The step body is extracted from action.yml at runtime rather than duplicated here:
# a copied-out script would keep passing after the real one regressed.
#
# Usage: bash .github/actions/security-scan/tests/scan-engine.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION_FILE="$SCRIPT_DIR/../action.yml"
STEP_ID="engine"

if [ ! -f "$ACTION_FILE" ]; then
  echo "FATAL: action.yml not found at $ACTION_FILE"
  exit 1
fi

STEP_BODY=$(awk -v step="      id: $STEP_ID" '
  $0 == step        { found = 1; next }
  found && /^      run: \|$/ { collecting = 1; next }
  collecting {
    if ($0 == "") { print ""; next }
    if ($0 ~ /^        /) { sub(/^        /, ""); print; next }
    exit
  }
' "$ACTION_FILE")

if [ -z "$STEP_BODY" ]; then
  echo "FATAL: could not extract the '$STEP_ID' run block from action.yml."
  echo "       The step was renamed, removed, or re-indented - update this test."
  exit 1
fi

if grep -q 'gitguardian-scan' "$ACTION_FILE"; then
  echo "FAIL action.yml still references the removed gitguardian-scan action"
  exit 1
fi

PASSED=0
FAILED=0
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# run_case <name> <scan-engine> <expected secret-engine> <expected annotation or ->
run_case() {
  local name="$1" engine="$2" expected="$3" annotation="$4"
  local dir="$WORK/$name"
  mkdir -p "$dir"
  : > "$dir/output"

  ( cd "$dir" && SCAN_ENGINE="$engine" SCAN_TYPE="all" FAIL_ON_FINDINGS="true" \
      EXCLUDE_PATHS=".git" GITHUB_OUTPUT="$dir/output" bash -c "$STEP_BODY" ) > "$dir/log" 2>&1
  local rc=$?

  local got
  got=$(sed -n 's/^secret-engine=//p' "$dir/output")
  local ok=true
  [ "$rc" -eq 0 ] || ok=false
  [ "$got" = "$expected" ] || ok=false
  if [ "$annotation" = "-" ]; then
    grep -q '^::\(notice\|warning\)' "$dir/log" && ok=false
  else
    grep -q "^::${annotation}" "$dir/log" || ok=false
  fi
  [ -d "$dir/security-reports" ] || ok=false

  if [ "$ok" = true ]; then
    PASSED=$((PASSED + 1))
    printf 'ok   %-22s scan-engine=%-12s -> %s\n' "$name" "'$engine'" "$got"
  else
    FAILED=$((FAILED + 1))
    printf 'FAIL %-22s scan-engine=%-12s -> got %s (rc %s), expected %s with annotation %s\n' \
      "$name" "'$engine'" "${got:-<none>}" "$rc" "$expected" "$annotation"
    sed 's/^/       | /' "$dir/log"
  fi
}

run_case gitleaks      gitleaks     gitleaks -
run_case both          both         gitleaks notice
run_case gitguardian   gitguardian  none     warning
run_case unknown-value gitguardain  none     warning
run_case empty-value   ''           none     warning

echo
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
