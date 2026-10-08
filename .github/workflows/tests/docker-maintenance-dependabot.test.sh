#!/usr/bin/env bash
#
# Behavioural test for ../docker-maintenance-dependabot.yml.
#
# The workflow merges a Dependabot PR only after its CI has passed, without
# rulesets or required status checks:
#
#   guard  (id: guard) - update type against merge-update-types / allow-major,
#                        input validation
#   wait   (id: ci)    - polls check runs, check suites and commit statuses of the
#                        PR head commit, leaves out its own job, decides
#                        green / failed / no-checks / timeout / unreadable / ...
#   merge  (id: merge) - optional approval (a rejection is only a notice), then
#                        gh pr merge pinned to the head commit
#
# Without this, `gh pr merge --auto` on a branch without required checks merged
# at once - bauer-group/CS-BillingStack#12 three seconds after its label check
# went red. That PR was the redpanda 26.1 -> 26.2 bump: a semver-minor, which
# is why only patch updates are merged by default.
#
# Each step body is extracted from the workflow at runtime rather than duplicated
# here and run the way a `shell: bash` step runs (-eo pipefail). `gh` is replaced
# by a stub that applies the step's real --jq filters (with jq) to API responses
# shaped like GitHub's, one response file per call so a case can change state
# between polls.
#
# Usage: bash .github/workflows/tests/docker-maintenance-dependabot.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_FILE="$SCRIPT_DIR/../docker-maintenance-dependabot.yml"

if [ ! -f "$WORKFLOW_FILE" ]; then
  echo "FATAL: workflow not found at $WORKFLOW_FILE"
  exit 1
fi
if ! command -v jq > /dev/null; then
  echo "FATAL: jq is required to evaluate the steps' --jq filters"
  exit 1
fi

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

GUARD_BODY=$(extract_step guard)
CI_BODY=$(extract_step ci)
MERGE_BODY=$(extract_step merge)
for step in GUARD_BODY CI_BODY MERGE_BODY; do
  if [ -z "${!step}" ]; then
    echo "FATAL: could not extract the run block for $step from the workflow."
    echo "       The step was renamed, removed, or re-indented - update this test."
    exit 1
  fi
done

PASSED=0
FAILED=0
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass() { echo "PASS $1"; PASSED=$((PASSED + 1)); }
fail() { echo "FAIL $1"; FAILED=$((FAILED + 1)); }

# --- static: what the steps must be wired to ------------------------------------
static_has() {
  if grep -qF -- "$2" "$WORKFLOW_FILE"; then pass "$1"; else fail "$1: '$2' not found"; fi
}
static_lacks() {
  if grep -qE -- "$2" "$WORKFLOW_FILE"; then fail "$1: '$2' found"; else pass "$1"; fi
}
static_has   "wait is gated by the guard"        "if: steps.guard.outputs.ok == 'true'"
static_has   "merge is gated by green CI"        "if: steps.ci.outputs.result == 'green'"
# shellcheck disable=SC2016 # literal workflow text
static_has   "merge is pinned to the head"       '--match-head-commit "$HEAD_SHA"'
# shellcheck disable=SC2016 # literal workflow text
static_has   "own check run is passed in"        'OWN_CHECK_RUN_ID: ${{ job.check_run_id }}'
# shellcheck disable=SC2016 # literal workflow text
static_has   "one run per PR"                    'group: docker-maintenance-dependabot-pr-${{ github.event.pull_request.number }}'
static_lacks "no native auto-merge"              'enable-pull-request-automerge|gh pr merge .*--auto'
# Declaring checks/statuses would make GitHub reject every caller that does not
# grant them; declaring only contents/pull-requests would take away the read
# access a private repository's caller grants. So: none at all.
static_lacks "no permissions of its own"         '^ *permissions:'
# The job timeout has to cover the longest allowed wait (60 min) plus setup.
TIMEOUT=$(sed -n 's/^    timeout-minutes: \([0-9]*\)$/\1/p' "$WORKFLOW_FILE")
if [ -n "$TIMEOUT" ] && [ "$TIMEOUT" -ge 65 ]; then pass "job timeout covers the wait ($TIMEOUT min)"; else fail "job timeout '$TIMEOUT' < 65"; fi
# The self filter keys on the job's display name.
static_has   "self filter matches the job name"  'SELF_JOB_NAME: Docker Maintenance'
static_has   "job name is what the filter uses"  '    name: Docker Maintenance'

# --- gh stub --------------------------------------------------------------------
mkdir -p "$WORK/bin"
cat > "$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
# gh api [--paginate] <path> --jq <filter>: answers from $FAKE/<kind>.<n>.json, n
# counting the calls per kind (the highest file is reused once n runs past it).
# A file holding HTTP403, HTTP500 or RATELIMIT simulates that error.
# gh pr review|merge: logged to $FAKE/calls; FAKE_REVIEW_FAIL / FAKE_MERGE_FAIL fail them.
echo "$*" >> "$FAKE/calls"
if [ "${1:-}" = "pr" ]; then
  case "${2:-}" in
    review) [ -n "${FAKE_REVIEW_FAIL:-}" ] && { echo "failed to create review: GitHub Actions is not permitted to approve pull requests." >&2; exit 1; } ;;
    merge)  [ -n "${FAKE_MERGE_FAIL:-}" ]  && { echo "X Pull request o/r#7 is not mergeable: the base branch policy prohibits the merge." >&2; exit 1; } ;;
  esac
  exit 0
fi
[ "${1:-}" = "api" ] || { echo "unexpected gh call: $*" >&2; exit 2; }
shift
path="" filter="."
while [ $# -gt 0 ]; do
  case "$1" in
    --jq) filter="$2"; shift 2 ;;
    --paginate) shift ;;
    *) path="$1"; shift ;;
  esac
done
case "$path" in
  repos/*/pulls/*)                kind=pr ;;
  repos/*/commits/*/check-runs*)  kind=runs ;;
  repos/*/commits/*/check-suites*) kind=suites ;;
  repos/*/commits/*/status\?*)    kind=status ;;
  *) echo "unexpected path: $path" >&2; exit 2 ;;
esac
n=$(( $(cat "$FAKE/$kind.count" 2>/dev/null || echo 0) + 1 ))
echo "$n" > "$FAKE/$kind.count"
file="$FAKE/$kind.$n.json"
while [ ! -f "$file" ] && [ "$n" -gt 1 ]; do n=$((n - 1)); file="$FAKE/$kind.$n.json"; done
[ -f "$file" ] || { echo "no fixture for $kind" >&2; exit 2; }
case "$(cat "$file")" in
  HTTP403) echo "gh: Resource not accessible by integration (HTTP 403)" >&2; exit 1 ;;
  HTTP500) echo "gh: Server Error (HTTP 500)" >&2; exit 1 ;;
  RATELIMIT) echo "gh: API rate limit exceeded for installation ID 1. (HTTP 403)" >&2; exit 1 ;;
esac
jq -r "$filter" < "$file"
STUB
chmod +x "$WORK/bin/gh"

# --- fixtures, shaped like GitHub's responses -------------------------------------
OWN=100
SELF="Auto-merge Dependabot PRs / Docker Maintenance"
# run <id> <suite> <status> <conclusion|-> <name>
run() {
  local c="null"; [ "$4" = "-" ] || c="\"$4\""
  printf '{"id":%s,"name":"%s","status":"%s","conclusion":%s,"check_suite":{"id":%s},"app":{"slug":"github-actions"}}' "$1" "$5" "$3" "$c" "$2"
}
# suite <id> <status> <conclusion|-> <check run count> <app>
suite() {
  local c="null"; [ "$3" = "-" ] || c="\"$3\""
  printf '{"id":%s,"status":"%s","conclusion":%s,"latest_check_runs_count":%s,"app":{"slug":"%s"}}' "$1" "$2" "$c" "$4" "$5"
}
# status <state> <context>
status() { printf '{"state":"%s","context":"%s"}' "$1" "$2"; }
join() { local IFS=,; echo "$*"; }

OWN_RUN=$(run $OWN 10 in_progress - "$SELF")
OWN_SUITE=$(suite 10 in_progress - 1 github-actions)

# fixture <case dir> <kind> <n> <json items...>
fixture() {
  local dir="$1" kind="$2" n="$3"; shift 3
  case "$kind" in
    runs)   echo "{\"total_count\":$#,\"check_runs\":[$(join "$@")]}" > "$dir/runs.$n.json" ;;
    suites) echo "{\"total_count\":$#,\"check_suites\":[$(join "$@")]}" > "$dir/suites.$n.json" ;;
    status) echo "{\"state\":\"x\",\"statuses\":[$(join "$@")]}" > "$dir/status.$n.json" ;;
  esac
}
raw() { echo "$3" > "$1/$2"; }

new_case() {
  local dir="$WORK/case-$1"
  mkdir -p "$dir/temp"
  : > "$dir/output"; : > "$dir/calls"
  echo '{"state":"open","head":{"sha":"abc"}}' > "$dir/pr.1.json"
  fixture "$dir" runs 1 "$OWN_RUN"
  fixture "$dir" suites 1 "$OWN_SUITE"
  fixture "$dir" status 1
  echo "$dir"
}

# check <name> <dir> <rc> <want rc> <key> <want> <annotation|-> [grep-in-log]
check() {
  local name="$1" dir="$2" rc="$3" want_rc="$4" key="$5" want="$6" annotation="$7" needle="${8:-}"
  local ok=true why="" got
  got=$(sed -n "s/^$key=//p" "$dir/output")
  [ "$rc" -eq "$want_rc" ] || { ok=false; why="$why exit $rc"; }
  [ "$got" = "$want" ] || { ok=false; why="$why $key='$got'"; }
  if [ "$annotation" = "-" ]; then
    grep -q '^::\(notice\|warning\|error\)' "$dir/log" && { ok=false; why="$why unexpected annotation"; }
  else
    grep -q "^::${annotation} " "$dir/log" || { ok=false; why="$why missing ::${annotation}"; }
  fi
  if [ -n "$needle" ]; then
    grep -qF -- "$needle" "$dir/log" "$dir/calls" || { ok=false; why="$why missing '$needle'"; }
  fi
  if [ "$ok" = true ]; then
    pass "$name"
  else
    fail "$name:$why"
    sed 's/^/     | /' "$dir/log"
  fi
}

# --- guard ----------------------------------------------------------------------
# guard_case <name> <update-type> <merge-update-types> <allow-major> <want rc> <ok> <reason> <annotation|-> [merge-method] [wait-minutes]
guard_case() {
  local name="$1" dir="$WORK/guard-$1"
  mkdir -p "$dir"; : > "$dir/output"
  ( cd "$dir" && GITHUB_OUTPUT="$dir/output" UPDATE_TYPE="$2" MERGE_UPDATE_TYPES="$3" ALLOW_MAJOR="$4" \
      MERGE_METHOD="${9:-squash}" WAIT_MINUTES="${10:-60}" \
      bash --noprofile --norc -eo pipefail -c "$GUARD_BODY" ) > "$dir/log" 2>&1
  local rc=$?
  check "guard/$name" "$dir" "$rc" "$5" ok "$6" "$8"
  if [ "$5" -eq 0 ]; then
    local got; got=$(sed -n 's/^reason=//p' "$dir/output")
    [ "$got" = "$7" ] || fail "guard/$name: reason='$got', want '$7'"
  fi
}

P="version-update:semver-patch"
MI="version-update:semver-minor"
MA="version-update:semver-major"

guard_case patch-default          "$P"  "patch"               false 0 true  patch                -
guard_case minor-default          "$MI" "patch"               false 0 false update-type          notice
guard_case major-default          "$MA" "patch"               false 0 false update-type          notice
guard_case minor-opted-in         "$MI" "patch,minor"         false 0 true  minor                -
guard_case major-opted-in-spaces  "$MA" "patch, minor, major" false 0 true  major                -
guard_case case-insensitive       "$P"  "Patch"               false 0 true  patch                -
guard_case only-minor-not-patch   "$P"  "minor"               false 0 false update-type          notice
guard_case allow-major-major      "$MA" "patch"               true  0 true  major                -
guard_case allow-major-minor      "$MI" "patch"               true  0 true  minor                -
guard_case unknown-update-type    ""    "patch,minor,major"   false 0 false unknown-update-type  notice
guard_case bad-type               "$P"  "pach"                false 1 ""    ""                   error
guard_case empty-types            "$P"  ""                    false 1 ""    ""                   error
guard_case empty-types-allow-major "$MA" ""                   true  0 true  major                -
guard_case bad-merge-method       "$P"  "patch"               false 1 ""    ""                   error fast
guard_case wait-zero              "$P"  "patch"               false 1 ""    ""                   error squash 0
guard_case wait-too-long          "$P"  "patch"               false 1 ""    ""                   error squash 61
guard_case wait-not-a-number      "$P"  "patch"               false 1 ""    ""                   error squash abc

# --- wait for CI ----------------------------------------------------------------
# run_ci <dir> [VAR=value ...]: POLL 0 s, SETTLE 0 s, WAIT 10 s unless overridden.
run_ci() {
  local dir="$1"; shift
  ( cd "$dir" && env PATH="$WORK/bin:$PATH" FAKE="$dir" GITHUB_OUTPUT="$dir/output" RUNNER_TEMP="$dir/temp" \
      GH_TOKEN=test REPO=o/r PR_NUMBER=7 HEAD_SHA=abc OWN_CHECK_RUN_ID=$OWN SELF_JOB_NAME="Docker Maintenance" \
      WAIT_MINUTES=60 POLL_SECONDS=0 SETTLE_SECONDS=0 WAIT_SECONDS=10 "$@" \
      bash --noprofile --norc -eo pipefail -c "$CI_BODY" ) > "$dir/log" 2>&1
}
calls_of() { grep -c "check-runs" "$1/calls"; }

D=$(new_case green-after-wait)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 in_progress - build)"
fixture "$D" suites 1 "$OWN_SUITE" "$(suite 20 in_progress - 1 github-actions)"
fixture "$D" runs 2 "$OWN_RUN" "$(run 200 20 completed success build)"
fixture "$D" suites 2 "$OWN_SUITE" "$(suite 20 completed success 1 github-actions)"
run_ci "$D"; check ci/green-after-wait "$D" $? 0 result green - "checks: 1, pending: 0, failed: 0"
[ "$(calls_of "$D")" -eq 2 ] || fail "ci/green-after-wait: expected 2 polls, got $(calls_of "$D")"
grep -q "OK check: build (success)" "$D/temp/dependabot-ci-checks.md" || fail "ci/green-after-wait: summary list missing"

D=$(new_case failed-check)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed failure "🔍 Validate Base Image Labels")" "$(run 201 21 in_progress - build)"
run_ci "$D"; check ci/failed-check-stops-at-once "$D" $? 0 result failed notice "🔍 Validate Base Image Labels (failure)"

D=$(new_case failed-status)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
fixture "$D" status 1 "$(status failure ci/external)"
run_ci "$D"; check ci/failed-status "$D" $? 0 result failed notice "ci/external (failure)"

D=$(new_case status-pending-then-success)
fixture "$D" status 1 "$(status pending ci/external)"
fixture "$D" status 2 "$(status success ci/external)"
run_ci "$D"; check ci/status-pending-then-success "$D" $? 0 result green -

D=$(new_case timeout)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 in_progress - build)"
run_ci "$D" WAIT_SECONDS=0; check ci/timeout "$D" $? 0 result timeout notice

D=$(new_case no-checks)
run_ci "$D"; check ci/no-checks "$D" $? 0 result no-checks notice

D=$(new_case settle-before-deciding)
fixture "$D" runs 2 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D" SETTLE_SECONDS=4; check ci/no-decision-before-settle "$D" $? 0 result green -

D=$(new_case siblings-ignored)
fixture "$D" runs 1 "$OWN_RUN" "$(run 300 30 in_progress - "$SELF")" "$(run 400 40 queued - "Other caller / Docker Maintenance")" "$(run 200 20 completed success build)"
fixture "$D" suites 1 "$OWN_SUITE" "$(suite 30 in_progress - 1 github-actions)" "$(suite 40 queued - 1 github-actions)" "$(suite 20 completed success 1 github-actions)"
run_ci "$D"; check ci/other-runs-of-this-job-ignored "$D" $? 0 result green - "checks: 1,"

D=$(new_case own-id-only)
fixture "$D" runs 1 "$(run $OWN 10 in_progress - "renamed job")" "$(run 200 20 completed success build)"
fixture "$D" suites 1 "$OWN_SUITE" "$(suite 20 completed success 1 github-actions)"
run_ci "$D"; check ci/own-run-found-by-id "$D" $? 0 result green -

D=$(new_case rerun-newest-wins)
fixture "$D" runs 1 "$OWN_RUN" "$(run 201 20 completed success build)" "$(run 200 20 completed failure build)"
run_ci "$D"; check ci/re-run-newest-counts "$D" $? 0 result green -

D=$(new_case rerun-newest-fails)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)" "$(run 201 22 completed failure build)"
run_ci "$D"; check ci/re-run-newest-failure-counts "$D" $? 0 result failed notice

D=$(new_case workflow-without-jobs-yet)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success labels)"
fixture "$D" suites 1 "$OWN_SUITE" "$(suite 20 completed success 1 github-actions)" "$(suite 50 queued - 0 github-actions)"
fixture "$D" runs 2 "$OWN_RUN" "$(run 200 20 completed success labels)" "$(run 500 50 completed success build)"
fixture "$D" suites 2 "$OWN_SUITE" "$(suite 20 completed success 1 github-actions)" "$(suite 50 completed success 1 github-actions)"
run_ci "$D"; check ci/waits-for-workflow-without-jobs "$D" $? 0 result green - "checks: 2,"
[ "$(calls_of "$D")" -eq 2 ] || fail "ci/waits-for-workflow-without-jobs: expected 2 polls, got $(calls_of "$D")"

D=$(new_case foreign-idle-suites)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
fixture "$D" suites 1 "$OWN_SUITE" "$(suite 20 completed success 1 github-actions)" "$(suite 60 queued - 0 claude)" "$(suite 61 queued - 0 -)"
run_ci "$D"; check ci/idle-app-suites-ignored "$D" $? 0 result green -

D=$(new_case startup-failure)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
fixture "$D" suites 1 "$OWN_SUITE" "$(suite 20 completed success 1 github-actions)" "$(suite 70 completed startup_failure 0 github-actions)"
run_ci "$D"; check ci/startup-failure-counts "$D" $? 0 result failed notice

D=$(new_case cancelled-empty-suite)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
fixture "$D" suites 1 "$OWN_SUITE" "$(suite 20 completed success 1 github-actions)" "$(suite 71 completed cancelled 0 github-actions)"
run_ci "$D"; check ci/superseded-empty-run-ignored "$D" $? 0 result green -

D=$(new_case neutral-skipped)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed neutral lint)" "$(run 201 20 completed skipped deploy)" "$(run 202 20 completed success build)"
run_ci "$D"; check ci/neutral-and-skipped-pass "$D" $? 0 result green -

D=$(new_case action-required)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed action_required build)"
run_ci "$D"; check ci/action-required-fails "$D" $? 0 result failed notice

D=$(new_case checks-unreadable)
raw "$D" runs.1.json HTTP403
run_ci "$D"; check ci/checks-403 "$D" $? 0 result unreadable notice "checks: read"

D=$(new_case statuses-unreadable)
raw "$D" status.1.json HTTP403
run_ci "$D"; check ci/statuses-403 "$D" $? 0 result unreadable notice "statuses: read"

D=$(new_case transient-error)
raw "$D" runs.1.json HTTP500
fixture "$D" runs 2 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/transient-error-retried "$D" $? 0 result green - "API error 1/3"

D=$(new_case rate-limit)
raw "$D" status.1.json RATELIMIT
fixture "$D" status 2
run_ci "$D"; check ci/rate-limit-is-retried "$D" $? 0 result no-checks notice "API error 1/3"

D=$(new_case persistent-error)
raw "$D" runs.1.json HTTP500
run_ci "$D"; check ci/three-errors-give-up "$D" $? 0 result api-error warning

D=$(new_case pr-closed)
echo '{"state":"closed","head":{"sha":"abc"}}' > "$D/pr.1.json"
run_ci "$D"; check ci/pr-closed "$D" $? 0 result closed notice

D=$(new_case superseded)
echo '{"state":"open","head":{"sha":"def"}}' > "$D/pr.1.json"
run_ci "$D"; check ci/new-head-commit "$D" $? 0 result superseded notice

# --- approve and merge ------------------------------------------------------------
# merge_case <name> <auto-approve> <merge-method> <merged> <annotation|-> [VAR=value ...]
merge_case() {
  local name="$1" dir="$WORK/merge-$1"; shift
  local approve="$1" method="$2" want="$3" annotation="$4"; shift 4
  mkdir -p "$dir"; : > "$dir/output"; : > "$dir/calls"
  ( cd "$dir" && env PATH="$WORK/bin:$PATH" FAKE="$dir" GITHUB_OUTPUT="$dir/output" \
      GH_TOKEN=test REPO=o/r PR_NUMBER=7 HEAD_SHA=abc AUTO_APPROVE="$approve" MERGE_METHOD="$method" "$@" \
      bash --noprofile --norc -eo pipefail -c "$MERGE_BODY" ) > "$dir/log" 2>&1
  check "merge/$name" "$dir" $? 0 merged "$want" "$annotation" "pr merge 7 --repo o/r --$method --match-head-commit abc"
  if [ "$approve" = "true" ]; then
    grep -qx "pr review 7 --repo o/r --approve" "$dir/calls" || fail "merge/$name: no approval"
  else
    grep -q "pr review" "$dir/calls" && fail "merge/$name: approved although auto-approve is off"
  fi
}
merge_case approve-and-merge   true  squash true  -
merge_case approve-rejected    true  squash true  notice  FAKE_REVIEW_FAIL=1
merge_case no-approve          false squash true  -
merge_case rebase              true  rebase true  -
merge_case merge-rejected      true  squash false warning FAKE_REVIEW_FAIL=1 FAKE_MERGE_FAIL=1

echo ""
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
