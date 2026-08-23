#!/usr/bin/env bash
#
# Regression test for the 'Resolve Build Platforms' step in ../action.yml.
#
# Guards against the class of bug reported in issue #76: a requested platform list
# being silently narrowed, so a caller asking for linux/amd64,linux/arm64 published an
# amd64-only image with a green pipeline and a step summary that agreed with the wrong
# outcome. The resolver is now the single place that decides what gets built - the
# buildx setup, the push build and the summary all read its output - so asserting on
# the resolver is enough to pin the behaviour end to end.
#
# The step body is extracted from action.yml at runtime rather than duplicated here:
# a copied-out script would keep passing after the real one regressed.
#
# Usage: bash .github/actions/docker-build/tests/resolve-platforms.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION_FILE="$SCRIPT_DIR/../action.yml"
STEP_ID="resolve-platforms"

if [ ! -f "$ACTION_FILE" ]; then
  echo "FATAL: action.yml not found at $ACTION_FILE"
  exit 1
fi

# Extract the `run:` block of the step with id: $STEP_ID and strip its 8-space indent.
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

PASSED=0
FAILED=0

# assert_platforms <description> <platforms> <multi-platform> <RUNNER_ARCH> <RUNNER_OS> <key=value>...
assert_platforms() {
  local desc="$1" platforms="$2" multi="$3" arch="$4" os="$5"
  shift 5

  local out_file stdout_file rc problems=()
  out_file=$(mktemp)
  stdout_file=$(mktemp)

  REQUESTED_PLATFORMS="$platforms" \
  MULTI_PLATFORM="$multi" \
  RUNNER_ARCH="$arch" \
  RUNNER_OS="$os" \
  GITHUB_OUTPUT="$out_file" \
    bash -eo pipefail -c "$STEP_BODY" > "$stdout_file" 2>&1
  rc=$?

  if [ "$rc" -ne 0 ]; then
    problems+=("step exited $rc: $(tr '\n' ' ' < "$stdout_file")")
  fi

  local expectation key want got
  for expectation in "$@"; do
    key="${expectation%%=*}"
    want="${expectation#*=}"
    if [ "$key" = "log" ]; then
      if ! grep -qF -- "$want" "$stdout_file"; then
        problems+=("expected log containing '$want'")
      fi
      continue
    fi
    got=$(grep -m1 -- "^$key=" "$out_file" | cut -d= -f2-)
    if [ "$got" != "$want" ]; then
      problems+=("$key: expected '$want', got '$got'")
    fi
  done

  rm -f "$out_file" "$stdout_file"

  if [ ${#problems[@]} -eq 0 ]; then
    PASSED=$((PASSED + 1))
    printf 'ok   %s\n' "$desc"
  else
    FAILED=$((FAILED + 1))
    printf 'FAIL %s\n' "$desc"
    printf '       %s\n' "${problems[@]}"
  fi
}

echo "Testing '$STEP_ID' from $(basename "$ACTION_FILE")"
echo

#                 description                              platforms                              multi  arch   os
assert_platforms "default single platform" \
  "linux/amd64" "false" "X64" "Linux" \
  "list=linux/amd64" "count=1" "needs-qemu=false" "scan-platform=linux/amd64"

# The regression itself: this used to resolve to linux/amd64 alone.
assert_platforms "issue #76: multi-arch without the multi-platform flag" \
  "linux/amd64,linux/arm64" "false" "X64" "Linux" \
  "list=linux/amd64,linux/arm64" "count=2" "needs-qemu=true" "scan-platform=linux/amd64"

assert_platforms "existing callers passing multi-platform: true still work" \
  "linux/amd64,linux/arm64" "true" "X64" "Linux" \
  "list=linux/amd64,linux/arm64" "needs-qemu=true" "log=multi-platform is deprecated"

assert_platforms "a single foreign platform still needs QEMU" \
  "linux/arm64" "false" "X64" "Linux" \
  "list=linux/arm64" "needs-qemu=true" "scan-platform=linux/arm64"

assert_platforms "whitespace and stray separators are normalized" \
  "linux/amd64, linux/arm64,," "false" "X64" "Linux" \
  "list=linux/amd64,linux/arm64" "count=2"

assert_platforms "three platforms" \
  "linux/amd64,linux/arm64,linux/arm/v7" "false" "X64" "Linux" \
  "list=linux/amd64,linux/arm64,linux/arm/v7" "count=3" "needs-qemu=true"

assert_platforms "arm64 runner building only arm64 skips QEMU" \
  "linux/arm64" "false" "ARM64" "Linux" \
  "needs-qemu=false" "scan-platform=linux/arm64"

assert_platforms "arm64 runner scans its own architecture" \
  "linux/amd64,linux/arm64" "false" "ARM64" "Linux" \
  "needs-qemu=true" "scan-platform=linux/arm64"

assert_platforms "empty input falls back to linux/amd64" \
  "" "false" "X64" "Linux" \
  "list=linux/amd64" "count=1" "needs-qemu=false"

assert_platforms "windows target does not attempt QEMU" \
  "windows/amd64" "false" "X64" "Windows" \
  "list=windows/amd64" "needs-qemu=false" "scan-platform=windows/amd64"

assert_platforms "multi-platform: true with one platform warns loudly" \
  "linux/amd64" "true" "X64" "Linux" \
  "list=linux/amd64" "count=1" "log=Only one platform will be built"

echo
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
