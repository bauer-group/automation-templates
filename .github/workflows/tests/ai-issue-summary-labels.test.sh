#!/usr/bin/env bash
#
# Regression test for ../modules-ai-issue-summary.yml (issue #105, rework items).
#
# The label extraction matched label names anywhere in the AI response, so "test"
# was found inside "attest" and #104 was labelled `test`; "bug" inside "debug"
# would have done the same. Pins whole-word matching on the real grep, extracted
# from the workflow at runtime, plus two job guards from the rework list: the job
# skips Dependabot (94% of all triggers) and carries a timeout (org standard).
#
# Usage: bash .github/workflows/tests/ai-issue-summary-labels.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW="$SCRIPT_DIR/../modules-ai-issue-summary.yml"

if [ ! -f "$WORKFLOW" ]; then
  echo "FATAL: modules-ai-issue-summary.yml not found at $WORKFLOW"
  exit 1
fi

# The assignment `SUGGESTED_LABELS=$(grep ... /tmp/ai_response.txt ...)`, verbatim.
EXTRACT=$(grep -m1 -E '^\s*SUGGESTED_LABELS=\$\(grep ' "$WORKFLOW" | sed -E 's/^\s+//')
if [ -z "$EXTRACT" ]; then
  echo "FATAL: SUGGESTED_LABELS extraction not found - it was renamed or reformatted; update this test."
  exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
# The workflow reads a fixed path; point it at a scratch file instead.
EXTRACT="${EXTRACT//\/tmp\/ai_response.txt/$WORK/response.txt}"

FAILED=0
check() {
  if [ "$2" = "$3" ]; then echo "  ok   $1"; else echo "  FAIL $1 (expected '$3', got '$2')"; FAILED=$((FAILED + 1)); fi
}

# labels_for <response text>: what the workflow would suggest for it.
labels_for() {
  printf '%s\n' "$1" > "$WORK/response.txt"
  eval "$EXTRACT"
  printf '%s' "$SUGGESTED_LABELS"
}

echo "label extraction"
check "no label from 'attest' or 'debug'" \
  "$(labels_for 'The attest-sbom input attests the SBOM file; debug output was captured.')" ""
check "whole words still match" \
  "$(labels_for 'Suggested labels: bug, security')" "bug security"
check "hyphenated labels match whole" \
  "$(labels_for 'Labels: help-wanted, good-first-issue')" "good-first-issue help-wanted"
check "'tests' and 'latest' are not 'test'" \
  "$(labels_for 'Adds tests for the latest release.')" ""

echo "job guards"
JOB=$(awk '/^  summarize:$/{f=1; next} f && /^    steps:$/{exit} f' "$WORKFLOW")
check "Dependabot is skipped" "$(printf '%s\n' "$JOB" | grep -c "if: github.actor != 'dependabot\[bot\]'")" 1
check "job has a timeout" "$(printf '%s\n' "$JOB" | grep -cE '^    timeout-minutes: [0-9]+$')" 1

echo
if [ "$FAILED" -gt 0 ]; then
  echo "$FAILED check(s) failed"
  exit 1
fi
echo "all checks passed"
