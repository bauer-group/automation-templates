#!/usr/bin/env bash
#
# Behavioural test for the release retry of ../modules-auto-maintenance.yml
# (issue #137).
#
# The module dispatched the release with `gh workflow run`, which only queues it,
# and stored the new base image digests right after. A release that then failed
# was never dispatched again: the next run saw no new digest and nothing to
# commit. CS-n8n lost two days of releases that way and was only rescued by an
# unrelated upstream digest change. The `release-state` step now reads the last
# workflow_dispatch run of the trigger workflow and asks for a retry when it
# failed. This pins:
#
#   - failure, timed_out and startup_failure retry; success, cancelled, a run
#     still queued or in progress, no run at all and an unreadable run list do
#     not, and the step never fails;
#   - the query is restricted to workflow_dispatch runs of the trigger workflow
#     on the target branch, so a green push run cannot clear a failed release;
#   - the check only runs when nothing was committed, and the single dispatch
#     step opens on a commit or a retry, so a run dispatches at most once.
#
# The step body is extracted from the workflow at runtime and run the way a
# `shell: bash` step runs. `gh` is stubbed on PATH and applies the step's own
# --jq expression to a scripted run list, so the expression is tested too.
#
# Usage: bash .github/workflows/tests/auto-maintenance-release-retry.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_FILE="$SCRIPT_DIR/../modules-auto-maintenance.yml"
[ -f "$WORKFLOW_FILE" ] || { echo "FATAL: workflow not found at $WORKFLOW_FILE"; exit 1; }
command -v jq > /dev/null || { echo "FATAL: jq is required"; exit 1; }

extract_step() {
  awk -v id="        id: $1" '
    $0 == id { found = 1; next }
    found && /^        run: \|$/ { collecting = 1; next }
    collecting {
      if ($0 == "") { print ""; next }
      if ($0 ~ /^          /) { sub(/^          /, ""); print; next }
      exit
    }
  ' "$WORKFLOW_FILE"
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

extract_step release-state > "$WORK/release-state.sh"
if [ ! -s "$WORK/release-state.sh" ]; then
  echo "FATAL: could not extract the 'release-state' run block from the workflow."
  exit 1
fi

mkdir -p "$WORK/bin"
cat > "$WORK/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "$*" > "$STATE/gh-args"
if [ -n "${GH_FAILS:-}" ]; then
  echo "HTTP 403: Resource not accessible by integration" >&2
  exit 1
fi
expr=""
while [ "$#" -gt 0 ]; do
  [ "$1" = "--jq" ] && { expr="$2"; shift; }
  shift
done
printf '%s' "$RUNS" | jq -r "$expr" | tr -d '\r'
EOF
chmod +x "$WORK/bin/gh"

PASSED=0
FAILED=0
pass() { echo "PASS $1"; PASSED=$((PASSED + 1)); }
fail() { echo "FAIL $1: $2"; FAILED=$((FAILED + 1)); }
check() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "expected '$3', got '$2'"; fi; }

# run_case <name> <runs-json> <expected retry> [expected url, checked on a retry]
run_case() {
  export STATE="$WORK/state.$RANDOM" RUNS="$2"
  mkdir -p "$STATE"
  export GITHUB_OUTPUT="$STATE/output" TRIGGER_WORKFLOW=docker-release.yml TRIGGER_REF=main
  : > "$GITHUB_OUTPUT"
  if ! PATH="$WORK/bin:$PATH" bash -eo pipefail "$WORK/release-state.sh" > "$STATE/out" 2>&1; then
    fail "$1" "step failed: $(cat "$STATE/out")"
    return
  fi
  check "$1: retry" "$(sed -n 's/^retry=//p' "$GITHUB_OUTPUT")" "$3"
  if [ "$3" = "true" ]; then
    check "$1: failed run url" "$(sed -n 's/^failed-run-url=//p' "$GITHUB_OUTPUT")" "${4:-}"
    check "$1: warning annotation" "$(grep -c '^::warning title=Release retried::' "$STATE/out")" 1
  fi
}

run() { printf '[{"status":"%s","conclusion":"%s","url":"https://github.com/o/r/actions/runs/%s"}]' "$1" "$2" "$3"; }

run_case "failed release" "$(run completed failure 1)" true "https://github.com/o/r/actions/runs/1"
run_case "timed out release" "$(run completed timed_out 2)" true "https://github.com/o/r/actions/runs/2"
run_case "release that never started" "$(run completed startup_failure 3)" true "https://github.com/o/r/actions/runs/3"
run_case "green release" "$(run completed success 4)" false
run_case "cancelled release" "$(run completed cancelled 5)" false
run_case "release still running" "$(run in_progress "" 6)" false
run_case "release still queued" "$(run queued "" 7)" false
run_case "no dispatched release yet" "[]" false

ARGS="$(cat "$STATE/gh-args")"
case "$ARGS" in
  *"--event workflow_dispatch"*) pass "only workflow_dispatch runs count" ;;
  *) fail "only workflow_dispatch runs count" "gh was called with: $ARGS" ;;
esac
case "$ARGS" in
  *"--workflow docker-release.yml --branch main"*) pass "trigger workflow on the target branch" ;;
  *) fail "trigger workflow on the target branch" "gh was called with: $ARGS" ;;
esac

GH_FAILS=1 run_case "run list cannot be read" "[]" false
check "run list cannot be read: warning annotation" "$(grep -c '^::warning title=Release state unknown::' "$STATE/out")" 1

# shellcheck disable=SC2016 # literal workflow text
if grep -qxF "        if: steps.commit.outputs.committed != 'true' && steps.config.outputs.trigger-workflow != ''" "$WORKFLOW_FILE" \
  && [ "$(grep -B2 -xF '        id: release-state' "$WORKFLOW_FILE" | grep -c 'Check the last release run')" -eq 1 ]; then
  pass "the release state is only checked when nothing was committed"
else
  fail "the release state is only checked when nothing was committed" "gate not found"
fi
if grep -qF "if: (steps.commit.outputs.committed == 'true' || steps.release-state.outputs.retry == 'true') && steps.config.outputs.trigger-workflow != '' && inputs.dry-run != true" "$WORKFLOW_FILE"; then
  pass "the dispatch opens on a commit or a retry, never in a dry run"
else
  fail "the dispatch opens on a commit or a retry, never in a dry run" "gate not found"
fi
if [ "$(grep -c '^        id: dispatch$' "$WORKFLOW_FILE")" -eq 1 ]; then
  pass "exactly one dispatch step"
else
  fail "exactly one dispatch step" "found $(grep -c '^        id: dispatch$' "$WORKFLOW_FILE")"
fi

echo
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
