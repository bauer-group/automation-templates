#!/usr/bin/env bash
#
# Regression test for the repository's /.gitleaks.toml allowlist.
#
# Why this exists: `gitleaks detect` scans git HISTORY, not the working tree. On a
# push it is given a commit range and only looks at what changed, but on a
# workflow_dispatch it gets no range and scans everything ever committed. The release
# pipeline is dispatchable, so a single false positive anywhere in history blocks
# every manual release - which is exactly what happened with a documented
# `Authorization: Bearer YOUR_TOKEN` example from December 2025.
#
# An allowlist is a hole in secret scanning, so it has to be provably narrow. Every
# "flagged" case below is a token that MUST still be caught; they are generated at
# runtime rather than written literally, so this file never itself contains a string
# shaped like a credential for the next scan to trip over.
#
# Usage: bash .github/actions/gitleaks-scan/tests/allowlist.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
CONFIG="$REPO_ROOT/.gitleaks.toml"

if [ ! -f "$CONFIG" ]; then
  echo "FATAL: .gitleaks.toml not found at $CONFIG"
  exit 1
fi

if ! command -v gitleaks >/dev/null 2>&1; then
  echo "FATAL: gitleaks is not on PATH."
  echo "       Install it (https://github.com/gitleaks/gitleaks/releases) or run this"
  echo "       through the Workflow Validation job, which installs the pinned version."
  exit 1
fi

PASSED=0
FAILED=0

# Generated so that no literal credential-shaped string is committed in this file.
rand() { head -c 2000 /dev/urandom | tr -dc "$1" | head -c "$2"; }
FAKE_PAT="ghp_$(rand 'a-zA-Z0-9' 36)"
FAKE_AWS="AKIA$(rand 'A-Z0-9' 16)"
FAKE_BEARER="$(rand 'a-zA-Z0-9' 40)"

# assert_scan <description> clean|flagged <content>
assert_scan() {
  local desc="$1" expect="$2" content="$3"
  local dir report count problems=()
  dir=$(mktemp -d)
  report="$dir/report.json"
  printf '%s\n' "$content" > "$dir/sample.md"

  gitleaks detect \
    --no-git \
    --source "$dir" \
    --config "$CONFIG" \
    --no-banner \
    --exit-code=0 \
    --report-format=json \
    --report-path="$report" >/dev/null 2>&1

  # Counted with grep rather than a JSON parser: neither jq nor python is guaranteed
  # on every runner or in Git Bash, and every finding object carries exactly one
  # "RuleID" key. An empty report is `[]`, which counts as zero.
  if [ ! -f "$report" ]; then
    count="ERR"
  else
    count=$(grep -o '"RuleID"' "$report" | wc -l | tr -d '[:space:]')
  fi

  if [ "$count" = "ERR" ]; then
    problems+=("gitleaks wrote no report - the scan itself failed")
  elif [ "$expect" = "clean" ] && [ "$count" != "0" ]; then
    problems+=("expected no finding, got $count - the allowlist does not cover this placeholder")
  elif [ "$expect" = "flagged" ] && [ "$count" = "0" ]; then
    problems+=("expected a finding, got none - THE ALLOWLIST IS TOO BROAD and now hides real secrets")
  fi

  rm -rf "$dir"

  if [ ${#problems[@]} -eq 0 ]; then
    PASSED=$((PASSED + 1))
    printf 'ok   %s\n' "$desc"
  else
    FAILED=$((FAILED + 1))
    printf 'FAIL %s\n' "$desc"
    printf '       %s\n' "${problems[@]}"
  fi
}

echo "Testing $(basename "$CONFIG") with $(gitleaks version)"
echo

# --- Documented placeholders must not block a release ----------------------------
# The exact finding that blocked the v7.1.1 release.
assert_scan "the documented curl example that blocked a release is allowlisted" clean \
  'curl -X GET \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Accept: application/json" \
  "https://coolify.example.com/api/v1/deploy"'

assert_scan "a YOUR_* placeholder in any header is allowlisted" clean \
  'curl -H "Authorization: Bearer YOUR_API_TOKEN" https://example.com'

assert_scan "an angle-bracket placeholder is allowlisted" clean \
  'Authorization: Bearer <COOLIFY_API_TOKEN>'

assert_scan "a GitHub Actions secret expression is allowlisted" clean \
  'curl -H "Authorization: Bearer ${{ secrets.COOLIFY_API_TOKEN }}" https://example.com'

assert_scan "an environment variable reference is allowlisted" clean \
  'curl -H "Authorization: Bearer $COOLIFY_API_TOKEN" https://example.com'

# --- Real credentials must still be caught ---------------------------------------
# If any of these stops failing, the allowlist has been widened too far.
assert_scan "a real-looking bearer token is still detected" flagged \
  "curl -H \"Authorization: Bearer ${FAKE_BEARER}\" https://example.com"

assert_scan "a real-looking GitHub PAT is still detected" flagged \
  "token: ${FAKE_PAT}"

# Proves [extend] useDefault stayed on: this rule comes from the default ruleset,
# so if the config replaced rather than extended it, this goes quiet.
assert_scan "a real-looking AWS access key is still detected" flagged \
  "aws_access_key_id = ${FAKE_AWS}"

echo
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
