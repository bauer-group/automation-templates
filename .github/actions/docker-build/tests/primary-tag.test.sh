#!/usr/bin/env bash
#
# Regression test for how the 'Security Vulnerability Scan', 'Collect Build
# Information' and 'Generate SBOM' steps in ../action.yml pick their image, and for
# the image's org.opencontainers.image.created label.
#
# All three steps used `PRIMARY_TAG=$(echo "<tags>" | head -1)`. Composite steps run
# under `bash -eo pipefail`, and head exits after the first line: when it did so
# before echo had written the remaining tags, echo failed with "write error: Broken
# pipe" and took the step down with it - OT-CAN2IP-WebUI, 2026-10-05, 0.1s after its
# image had been pushed. The steps now read the tags from env and cut the first line
# with parameter expansion, which has no pipe to break.
#
# The created label used to be overridden with a Go reference-time layout that
# docker/metadata-action reads as a Moment.js format, so every image claimed
# 2006-01-02T15:04:05+00:0007:00 (issue #107). metadata-action's own label carries
# the real build time; nothing may override it with a {{date}} expression again.
#
# Usage: bash .github/actions/docker-build/tests/primary-tag.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION_FILE="$SCRIPT_DIR/../action.yml"

if [ ! -f "$ACTION_FILE" ]; then
  echo "FATAL: action.yml not found at $ACTION_FILE"
  exit 1
fi

PASSED=0
FAILED=0

pass() { PASSED=$((PASSED + 1)); printf 'ok   %s\n' "$1"; }
fail() { FAILED=$((FAILED + 1)); printf 'FAIL %s\n' "$1"; shift; printf '       %s\n' "$@"; }

# The step's own lines, from its `id:` up to the next step.
step_block() {
  awk -v step="      id: $1" '
    $0 == step            { found = 1; print; next }
    found && /^    - /    { exit }
    found                 { print }
  ' "$ACTION_FILE"
}

FIRST="ghcr.io/bauer-group/example/app:1.10.1"
FIVE_TAGS=$(printf '%s\n' "$FIRST" ghcr.io/bauer-group/example/app:1.10 ghcr.io/bauer-group/example/app:1 \
  ghcr.io/bauer-group/example/app:latest docker.io/bauergroup/app:1.10.1)
# More than a pipe buffer holds: with `echo | head -1` this fails every time instead
# of now and then, so a pipe creeping back in cannot pass by luck.
LONG_TAGS=$( { echo "$FIRST"; for i in $(seq 1400); do echo "ghcr.io/bauer-group/example/app:tag-$i"; done; } )

# assert_first_tag <step> <PRIMARY_TAG line> <description> <tags>
assert_first_tag() {
  local got rc
  # SIGPIPE ignored, as under the runner - a broken pipe then surfaces as an error.
  got=$( trap '' PIPE; META_TAGS="$4" bash --noprofile --norc -eo pipefail -c "$2"$'\nprintf %s "$PRIMARY_TAG"' 2>&1 )
  rc=$?
  if [ "$rc" -eq 0 ] && [ "$got" = "$FIRST" ]; then
    pass "$1: first tag of $3"
  else
    fail "$1: first tag of $3" "exit $rc, got '${got:0:200}', expected '$FIRST'"
  fi
}

echo "Testing the primary tag in $(basename "$ACTION_FILE")"
echo

for STEP_ID in security build-info sbom; do
  BLOCK=$(step_block "$STEP_ID")
  if [ -z "$BLOCK" ]; then
    fail "$STEP_ID: step found" "no step with id '$STEP_ID' - renamed or removed? update this test"
    continue
  fi

  # shellcheck disable=SC2016 # the literal workflow expression, not a shell expansion
  if printf '%s\n' "$BLOCK" | grep -qxF -- '        META_TAGS: ${{ steps.meta.outputs.tags }}'; then
    pass "$STEP_ID: reads the tags through env"
  else
    fail "$STEP_ID: reads the tags through env" "expected the line: META_TAGS: \${{ steps.meta.outputs.tags }}"
  fi

  LINE=$(printf '%s\n' "$BLOCK" | grep -E '^ +PRIMARY_TAG=' | sed -E 's/^ +//')
  if [ "$(printf '%s\n' "$LINE" | grep -c .)" -ne 1 ]; then
    fail "$STEP_ID: one PRIMARY_TAG assignment" "found: $LINE"
    continue
  fi
  case "$LINE" in
    *'|'*|*'steps.meta'*) fail "$STEP_ID: PRIMARY_TAG without a pipe" "found: $LINE" ;;
    *) pass "$STEP_ID: PRIMARY_TAG without a pipe" ;;
  esac

  assert_first_tag "$STEP_ID" "$LINE" "five tags" "$FIVE_TAGS"
  assert_first_tag "$STEP_ID" "$LINE" "1400 tags" "$LONG_TAGS"
  assert_first_tag "$STEP_ID" "$LINE" "a single tag" "$FIRST"
done

OVERRIDES=$(grep -nE '^[^#]*org\.opencontainers\.image\.created=' "$ACTION_FILE")
if [ -z "$OVERRIDES" ]; then
  pass "created label is left to docker/metadata-action"
else
  fail "created label is left to docker/metadata-action" "found an override: $OVERRIDES"
fi

echo
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
