#!/usr/bin/env bash
#
# Behavioural test for ../docker-maintenance-dependabot.yml.
#
# The workflow merges a Dependabot PR only after its CI has passed, without
# rulesets or required status checks:
#
#   guard  (id: guard) - update type against merge-update-types / allow-major,
#                        input validation
#   wait   (id: ci)    - polls check runs, check suites, commit statuses and
#                        workflow runs of the PR head commit, leaves out its own
#                        runs, waits for a complete and quiet state, decides
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
# between polls. `date` and `sleep` are replaced by a simulated clock, so the
# wait runs with its real intervals (30 s polls, 300 s settle time, 180 s quiet
# period) in no time, and a case can say at which second a check appears.
#
# Poll n happens at: n=1..11 -> 0, 30, ..., 300 s; then every 60 s up to 900 s
# (n=21); then every 180 s.
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
static_has   "own workflow run is passed in"     'RUN_ID: ${{ github.run_id }}'
# shellcheck disable=SC2016 # literal workflow text
static_has   "one run per PR"                    'group: docker-maintenance-dependabot-pr-${{ github.event.pull_request.number }}'
static_lacks "no native auto-merge"              'enable-pull-request-automerge|gh pr merge .*--auto'
# Declaring checks/statuses would make GitHub reject every caller that does not
# grant them; declaring only contents/pull-requests would take away the read
# access a private repository's caller grants. So: none at all.
static_lacks "no permissions of its own"         '^ *permissions:'
# The job timeout has to cover the longest allowed wait (60 min), the last poll
# interval (3 min) and the merge.
TIMEOUT=$(sed -n 's/^    timeout-minutes: \([0-9]*\)$/\1/p' "$WORKFLOW_FILE")
if [ -n "$TIMEOUT" ] && [ "$TIMEOUT" -ge 65 ]; then pass "job timeout covers the wait ($TIMEOUT min)"; else fail "job timeout '$TIMEOUT' < 65"; fi
# The self filter keys on the job's display name and on the file name in the
# callers' referenced_workflows.
static_has   "self filter matches the job name"  'SELF_JOB_NAME: Docker Maintenance'
static_has   "job name is what the filter uses"  '    name: Docker Maintenance'
static_has   "module filter matches this file"   "contains(\"/.github/workflows/$(basename "$WORKFLOW_FILE")@\")"

# --- gh, date and sleep stubs -------------------------------------------------------
mkdir -p "$WORK/bin"
cat > "$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
# gh api [--paginate] <path> --jq <filter>: answers from $FAKE/<kind>.<n>.json, n
# counting the calls per kind (the highest file is reused once n runs past it).
# A file holding HTTP403, HTTP404, HTTP500 or RATELIMIT simulates that error.
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
  repos/*/pulls/*)                 kind=pr ;;
  repos/*/commits/*/check-runs*)   kind=runs ;;
  repos/*/commits/*/check-suites*) kind=suites ;;
  repos/*/commits/*/status\?*)     kind=status ;;
  repos/*/actions/runs\?*)         kind=actions ;;
  *) echo "unexpected path: $path" >&2; exit 2 ;;
esac
n=$(( $(cat "$FAKE/$kind.count" 2>/dev/null || echo 0) + 1 ))
echo "$n" > "$FAKE/$kind.count"
file="$FAKE/$kind.$n.json"
while [ ! -f "$file" ] && [ "$n" -gt 1 ]; do n=$((n - 1)); file="$FAKE/$kind.$n.json"; done
[ -f "$file" ] || { echo "no fixture for $kind" >&2; exit 2; }
case "$(cat "$file")" in
  HTTP403) echo "gh: Resource not accessible by integration (HTTP 403)" >&2; exit 1 ;;
  HTTP404) echo "gh: Not Found (HTTP 404)" >&2; exit 1 ;;
  HTTP500) echo "gh: Server Error (HTTP 500)" >&2; exit 1 ;;
  RATELIMIT) echo "gh: API rate limit exceeded for installation ID 1. (HTTP 403)" >&2; exit 1 ;;
esac
jq -r "$filter" < "$file"
STUB
# Simulated clock: `date +%s` prints $FAKE/clock, `sleep N` adds N to it.
cat > "$WORK/bin/date" <<'STUB'
#!/usr/bin/env bash
[ "${1:-}" = "+%s" ] || { echo "unexpected date call: $*" >&2; exit 2; }
cat "$FAKE/clock"
STUB
cat > "$WORK/bin/sleep" <<'STUB'
#!/usr/bin/env bash
echo $(( $(cat "$FAKE/clock") + $1 )) > "$FAKE/clock"
STUB
chmod +x "$WORK/bin/gh" "$WORK/bin/date" "$WORK/bin/sleep"

# --- fixtures, shaped like GitHub's responses -------------------------------------
OWN=100
RUN=900
SELF="Auto-merge Dependabot PRs / Docker Maintenance"
MODULE_PATH="bauer-group/automation-templates/.github/workflows/docker-maintenance-dependabot.yml@main"
OTHER_PATH="bauer-group/automation-templates/.github/workflows/docker-build.yml@main"
# run <id> <suite> <status> <conclusion|-> <name>   (a check run)
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
# wfrun <id> <suite> <status> <conclusion|-> <workflow id> <event> <name> <calls this module: 1|0>
wfrun() {
  local c="null" ref="$OTHER_PATH"; [ "$4" = "-" ] || c="\"$4\""; [ "$8" = "1" ] && ref="$MODULE_PATH"
  printf '{"id":%s,"check_suite_id":%s,"status":"%s","conclusion":%s,"workflow_id":%s,"event":"%s","name":"%s","referenced_workflows":[{"path":"%s","sha":"0"}]}' "$1" "$2" "$3" "$c" "$5" "$6" "$7" "$ref"
}
join() { local IFS=,; echo "$*"; }

OWN_RUN=$(run $OWN 10 in_progress - "$SELF")
OWN_SUITE=$(suite 10 in_progress - 1 github-actions)
OWN_WFRUN=$(wfrun $RUN 10 in_progress - 1 pull_request "Docker Maintenance" 1)

# fixture <case dir> <kind> <n> <json items...>: the response from poll n on
fixture() {
  local dir="$1" kind="$2" n="$3"; shift 3
  case "$kind" in
    runs)    echo "{\"total_count\":$#,\"check_runs\":[$(join "$@")]}" > "$dir/runs.$n.json" ;;
    suites)  echo "{\"total_count\":$#,\"check_suites\":[$(join "$@")]}" > "$dir/suites.$n.json" ;;
    status)  echo "{\"state\":\"x\",\"statuses\":[$(join "$@")]}" > "$dir/status.$n.json" ;;
    actions) echo "{\"total_count\":$#,\"workflow_runs\":[$(join "$@")]}" > "$dir/actions.$n.json" ;;
  esac
}
raw() { echo "$3" > "$1/$2"; }

# A PR whose only check so far is this job.
new_case() {
  local dir="$WORK/case-$1"
  mkdir -p "$dir/temp"
  : > "$dir/output"; : > "$dir/calls"; echo 0 > "$dir/clock"
  echo '{"state":"open","head":{"sha":"abc"}}' > "$dir/pr.1.json"
  fixture "$dir" runs 1 "$OWN_RUN"
  fixture "$dir" suites 1 "$OWN_SUITE"
  fixture "$dir" status 1
  fixture "$dir" actions 1 "$OWN_WFRUN"
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
# decided_at <name> <dir> <second>: the decision fell at that simulated second
decided_at() {
  local got; got=$(cat "$2/clock")
  if [ "$got" -eq "$3" ]; then pass "$1: decided at ${3}s"; else fail "$1: decided at ${got}s, want ${3}s"; fi
}
# listed <name> <dir> <text>: the job summary's check list has the line
listed() {
  if grep -qF -- "$3" "$2/temp/dependabot-ci-checks.md" 2>/dev/null; then pass "$1: lists '$3'"; else fail "$1: summary lacks '$3'"; fi
}
calls_to() { grep -c -- "$2" "$1/calls"; }

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
guard_case wait-nine              "$P"  "patch"               false 1 ""    ""                   error squash 9
guard_case wait-ten               "$P"  "patch"               false 0 true  patch                -     squash 10
guard_case wait-too-long          "$P"  "patch"               false 1 ""    ""                   error squash 61
guard_case wait-not-a-number      "$P"  "patch"               false 1 ""    ""                   error squash abc

# --- wait for CI ----------------------------------------------------------------
# run_ci <dir> [VAR=value ...]
run_ci() {
  local dir="$1"; shift
  ( cd "$dir" && env PATH="$WORK/bin:$PATH" FAKE="$dir" GITHUB_OUTPUT="$dir/output" RUNNER_TEMP="$dir/temp" \
      GH_TOKEN=test REPO=o/r PR_NUMBER=7 HEAD_SHA=abc RUN_ID=$RUN OWN_CHECK_RUN_ID=$OWN SELF_JOB_NAME="Docker Maintenance" \
      WAIT_MINUTES=60 "$@" \
      bash --noprofile --norc -eo pipefail -c "$CI_BODY" ) > "$dir/log" 2>&1
}
CI_RUN=$(wfrun 20 20 in_progress - 2 pull_request "CI" 0)
CI_DONE=$(wfrun 20 20 completed success 2 pull_request "CI" 0)

# CI finishes at 30 s. Green needs 300 s since the start and 180 s without a
# change: the poll at 300 s.
D=$(new_case green-after-wait)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 in_progress - build)"
fixture "$D" suites 1 "$OWN_SUITE" "$(suite 20 in_progress - 1 github-actions)"
fixture "$D" actions 1 "$OWN_WFRUN" "$CI_RUN"
fixture "$D" runs 2 "$OWN_RUN" "$(run 200 20 completed success build)"
fixture "$D" suites 2 "$OWN_SUITE" "$(suite 20 completed success 1 github-actions)"
fixture "$D" actions 2 "$OWN_WFRUN" "$CI_DONE"
run_ci "$D"; check ci/green-after-wait "$D" $? 0 result green - "checks: 1, passed: 1, pending: 0, failed: 0"
decided_at ci/green-after-wait "$D" 300
listed ci/green-after-wait "$D" "OK check: build (success)"

# Everything was done before the job started (e.g. a re-run): the settle time
# still applies.
D=$(new_case done-before-start)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/done-before-start "$D" $? 0 result green -
decided_at ci/done-before-start "$D" 300

D=$(new_case failed-check)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed failure "🔍 Validate Base Image Labels")" "$(run 201 21 in_progress - build)"
run_ci "$D"; check ci/failed-check-stops-at-once "$D" $? 0 result failed notice "🔍 Validate Base Image Labels (failure)"
decided_at ci/failed-check-stops-at-once "$D" 0

D=$(new_case failed-status)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
fixture "$D" status 1 "$(status failure ci/external)"
run_ci "$D"; check ci/failed-status "$D" $? 0 result failed notice "ci/external (failure)"

D=$(new_case status-pending-then-success)
fixture "$D" status 1 "$(status pending ci/external)"
fixture "$D" status 2 "$(status success ci/external)"
run_ci "$D"; check ci/status-pending-then-success "$D" $? 0 result green -
decided_at ci/status-pending-then-success "$D" 300

D=$(new_case timeout)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 in_progress - build)"
run_ci "$D" WAIT_MINUTES=10; check ci/timeout "$D" $? 0 result timeout notice
decided_at ci/timeout "$D" 600

# 60 min of polling: 36 polls of 5 requests - a few PRs at once stay below the
# job token's 1,000 requests per hour and repository.
D=$(new_case poll-budget)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 in_progress - build)"
run_ci "$D"; check ci/poll-budget-timeout "$D" $? 0 result timeout notice
decided_at ci/poll-budget-timeout "$D" 3600
POLLS=$(calls_to "$D" check-runs)
if [ "$POLLS" -le 36 ]; then pass "ci/poll-budget: $POLLS polls in 60 min"; else fail "ci/poll-budget: $POLLS polls in 60 min, want <= 36"; fi

D=$(new_case no-checks)
run_ci "$D"; check ci/no-checks "$D" $? 0 result no-checks notice "No check ran"
decided_at ci/no-checks "$D" 300

# neutral and skipped are no failure, but nothing passed either.
D=$(new_case all-skipped)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed skipped deploy)" "$(run 201 21 completed neutral CodeQL)"
run_ci "$D"; check ci/all-skipped-or-neutral "$D" $? 0 result no-checks notice "all 2 checks skipped or neutral"

D=$(new_case neutral-skipped)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed neutral lint)" "$(run 201 20 completed skipped deploy)" "$(run 202 20 completed success build)"
run_ci "$D"; check ci/neutral-and-skipped-pass "$D" $? 0 result green - "checks: 3, passed: 1"

# The race this wait is built for: build is done at 240 s, the settle time is
# over at 300 s - and at 360 s a check appears that was not there before (a
# code scanning result posted after its analysis job, a workflow GitHub started
# late). The quiet period has not passed (240 + 180 s), so it is waited for;
# done at 420 s, green at 420 + 180 s = 600 s. A wait with only the settle
# time would have merged at 300 s, before the check existed.
D=$(new_case late-check)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 in_progress - build)"
fixture "$D" runs 9 "$OWN_RUN" "$(run 200 20 completed success build)"
fixture "$D" runs 12 "$OWN_RUN" "$(run 200 20 completed success build)" "$(run 300 30 in_progress - CodeQL)"
fixture "$D" suites 12 "$OWN_SUITE" "$(suite 30 in_progress - 1 github-advanced-security)"
fixture "$D" runs 13 "$OWN_RUN" "$(run 200 20 completed success build)" "$(run 300 30 completed success CodeQL)"
fixture "$D" suites 13 "$OWN_SUITE" "$(suite 30 completed success 1 github-advanced-security)"
run_ci "$D"; check ci/late-check-is-waited-for "$D" $? 0 result green - "checks: 2, passed: 2"
decided_at ci/late-check-is-waited-for "$D" 600
listed ci/late-check-is-waited-for "$D" "OK check: CodeQL (success)"

D=$(new_case late-check-fails)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 in_progress - build)"
fixture "$D" runs 9 "$OWN_RUN" "$(run 200 20 completed success build)"
fixture "$D" runs 12 "$OWN_RUN" "$(run 200 20 completed success build)" "$(run 300 30 in_progress - CodeQL)"
fixture "$D" runs 13 "$OWN_RUN" "$(run 200 20 completed success build)" "$(run 300 30 completed failure CodeQL)"
run_ci "$D"; check ci/late-check-failure-counts "$D" $? 0 result failed notice "CodeQL (failure)"
decided_at ci/late-check-failure-counts "$D" 420

# A result that arrives already finished (a status posted by an external
# service) also restarts the quiet period: changed at 150 s -> green at 330 s
# at the earliest, i.e. the poll at 360 s instead of 300 s.
D=$(new_case late-result-restarts-quiet)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
fixture "$D" status 6 "$(status success codecov/patch)"
run_ci "$D"; check ci/late-result-restarts-quiet-period "$D" $? 0 result green - "checks: 2, passed: 2"
decided_at ci/late-result-restarts-quiet-period "$D" 360

# A workflow run that is queued shows in the workflow runs before it has any
# check run: pending until it is done at 420 s -> green at 600 s, not at 300 s
# on the strength of lint alone.
D=$(new_case queued-workflow-run)
fixture "$D" runs 1 "$OWN_RUN" "$(run 201 21 completed success lint)"
fixture "$D" actions 1 "$OWN_WFRUN" "$(wfrun 40 40 queued - 4 pull_request "Release" 0)"
fixture "$D" runs 13 "$OWN_RUN" "$(run 201 21 completed success lint)" "$(run 400 40 completed success build)"
fixture "$D" suites 13 "$OWN_SUITE" "$(suite 40 completed success 1 github-actions)"
fixture "$D" actions 13 "$OWN_WFRUN" "$(wfrun 40 40 completed success 4 pull_request "Release" 0)"
run_ci "$D"; check ci/queued-workflow-run-is-waited-for "$D" $? 0 result green - "pending: 1"
decided_at ci/queued-workflow-run-is-waited-for "$D" 600

# Without workflow runs (no actions: read): the check suite of a workflow run
# whose jobs do not exist yet keeps the wait going until it is done at 420 s.
D=$(new_case workflow-without-jobs-yet)
raw "$D" actions.1.json HTTP403
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success labels)"
fixture "$D" suites 1 "$OWN_SUITE" "$(suite 20 completed success 1 github-actions)" "$(suite 50 queued - 0 github-actions)"
fixture "$D" runs 13 "$OWN_RUN" "$(run 200 20 completed success labels)" "$(run 500 50 completed success build)"
fixture "$D" suites 13 "$OWN_SUITE" "$(suite 20 completed success 1 github-actions)" "$(suite 50 completed success 1 github-actions)"
run_ci "$D"; check ci/waits-for-workflow-without-jobs "$D" $? 0 result green - "checks: 2,"
decided_at ci/waits-for-workflow-without-jobs "$D" 600

D=$(new_case actions-not-readable)
raw "$D" actions.1.json HTTP403
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/no-actions-read-falls-back "$D" $? 0 result green - "actions: read"
if [ "$(calls_to "$D" actions/runs)" -eq 1 ]; then pass "ci/no-actions-read-asked-once"; else fail "ci/no-actions-read-asked-once: $(calls_to "$D" actions/runs) calls"; fi

# Other runs of this module - another caller workflow, queued without a job yet
# or running - are not waited for.
D=$(new_case siblings-ignored)
fixture "$D" runs 1 "$OWN_RUN" "$(run 300 30 in_progress - "Other caller / Docker Maintenance")" "$(run 200 20 completed success build)"
fixture "$D" suites 1 "$OWN_SUITE" "$(suite 30 in_progress - 1 github-actions)" "$(suite 31 queued - 0 github-actions)" "$(suite 20 completed success 1 github-actions)"
fixture "$D" actions 1 "$OWN_WFRUN" "$(wfrun 30 30 in_progress - 3 pull_request "Actions Maintenance" 1)" "$(wfrun 31 31 queued - 3 pull_request "Actions Maintenance" 1)" "$CI_DONE"
run_ci "$D"; check ci/other-runs-of-this-module-ignored "$D" $? 0 result green - "checks: 1,"

D=$(new_case siblings-by-name)
raw "$D" actions.1.json HTTP403
fixture "$D" runs 1 "$OWN_RUN" "$(run 300 30 in_progress - "Other caller / Docker Maintenance")" "$(run 400 40 queued - "$SELF")" "$(run 200 20 completed success build)"
fixture "$D" suites 1 "$OWN_SUITE" "$(suite 30 in_progress - 1 github-actions)" "$(suite 40 queued - 1 github-actions)" "$(suite 20 completed success 1 github-actions)"
run_ci "$D"; check ci/other-runs-ignored-by-job-name "$D" $? 0 result green - "checks: 1,"

# Workflow runs list without this run: not trusted, names decide.
D=$(new_case runs-without-own-run)
fixture "$D" runs 1 "$OWN_RUN" "$(run 300 30 in_progress - "Other caller / Docker Maintenance")" "$(run 200 20 completed success build)"
fixture "$D" suites 1 "$OWN_SUITE" "$(suite 30 in_progress - 1 github-actions)" "$(suite 20 completed success 1 github-actions)"
fixture "$D" actions 1 "$CI_DONE"
run_ci "$D"; check ci/runs-without-this-run-not-trusted "$D" $? 0 result green - "checks: 1,"

# With the workflow runs known, the job name alone does not make a check this
# module's: a CI job that happens to be called "... / Docker Maintenance".
D=$(new_case name-outside-module)
fixture "$D" runs 1 "$OWN_RUN" "$(run 600 60 completed failure "Lint / Docker Maintenance")" "$(run 200 20 completed success build)"
fixture "$D" suites 1 "$OWN_SUITE" "$(suite 60 completed failure 1 github-actions)" "$(suite 20 completed success 1 github-actions)"
fixture "$D" actions 1 "$OWN_WFRUN" "$(wfrun 60 60 completed failure 6 pull_request "Lint" 0)" "$CI_DONE"
run_ci "$D"; check ci/job-name-alone-is-not-this-module "$D" $? 0 result failed notice "Lint / Docker Maintenance (failure)"

D=$(new_case own-id-only)
fixture "$D" runs 1 "$(run $OWN 10 in_progress - "renamed job")" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/own-run-found-by-id "$D" $? 0 result green -

D=$(new_case rerun-newest-wins)
fixture "$D" runs 1 "$OWN_RUN" "$(run 201 20 completed success build)" "$(run 200 20 completed failure build)"
run_ci "$D"; check ci/re-run-newest-counts "$D" $? 0 result green -

D=$(new_case rerun-newest-fails)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)" "$(run 201 20 completed failure build)"
run_ci "$D"; check ci/re-run-newest-failure-counts "$D" $? 0 result failed notice

# GitHub returns the latest check run per name *per check suite* (verified:
# 9 Teams Notifications runs on one commit, same job names, all returned).
# Two workflows with a job called "build" are two checks; the newer one
# passing must not hide the older one failing.
D=$(new_case same-name-other-workflow)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed failure build)" "$(run 201 21 completed success build)"
run_ci "$D"; check ci/same-job-name-in-two-workflows "$D" $? 0 result failed notice "build (failure)"

D=$(new_case foreign-idle-suites)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
fixture "$D" suites 1 "$OWN_SUITE" "$(suite 20 completed success 1 github-actions)" "$(suite 60 queued - 0 claude)" "$(suite 61 queued - 0 -)" "$(suite 62 completed stale 0 codecov)"
run_ci "$D"; check ci/idle-app-suites-ignored "$D" $? 0 result green -

D=$(new_case startup-failure)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
fixture "$D" suites 1 "$OWN_SUITE" "$(suite 20 completed success 1 github-actions)" "$(suite 70 completed startup_failure 0 github-actions)"
fixture "$D" actions 1 "$OWN_WFRUN" "$CI_DONE" "$(wfrun 70 70 completed startup_failure 7 pull_request_target "Issue AI Summary" 0)"
run_ci "$D"; check ci/startup-failure-counts "$D" $? 0 result failed notice "Issue AI Summary (pull_request_target, startup_failure)"

D=$(new_case startup-failure-suites-only)
raw "$D" actions.1.json HTTP403
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
fixture "$D" suites 1 "$OWN_SUITE" "$(suite 20 completed success 1 github-actions)" "$(suite 70 completed startup_failure 0 github-actions)"
run_ci "$D"; check ci/startup-failure-counts-from-suites "$D" $? 0 result failed notice "startup_failure, no job ran"

# A run cancelled by its concurrency group, replaced by a newer run of the same
# workflow for the same commit: it and its cancelled jobs are left out.
D=$(new_case cancelled-replaced)
fixture "$D" runs 1 "$OWN_RUN" "$(run 700 70 completed cancelled build)" "$(run 710 71 completed success build)"
fixture "$D" suites 1 "$OWN_SUITE" "$(suite 70 completed cancelled 1 github-actions)" "$(suite 72 completed cancelled 0 github-actions)" "$(suite 71 completed success 1 github-actions)"
fixture "$D" actions 1 "$OWN_WFRUN" "$(wfrun 70 70 completed cancelled 5 pull_request "CI" 0)" "$(wfrun 72 72 completed cancelled 5 pull_request "CI" 0)" "$(wfrun 73 71 completed success 5 pull_request "CI" 0)"
run_ci "$D"; check ci/replaced-cancelled-run-ignored "$D" $? 0 result green - "checks: 1, passed: 1"
listed ci/replaced-cancelled-run-ignored "$D" "SKIP workflow: CI (pull_request, cancelled, replaced by a newer run)"

D=$(new_case cancelled-not-replaced)
fixture "$D" runs 1 "$OWN_RUN" "$(run 700 70 completed cancelled build)" "$(run 200 20 completed success lint)"
fixture "$D" actions 1 "$OWN_WFRUN" "$(wfrun 70 70 completed cancelled 5 pull_request "CI" 0)" "$(wfrun 20 20 completed success 2 pull_request "Lint" 0)"
run_ci "$D"; check ci/cancelled-run-fails "$D" $? 0 result failed notice "CI (pull_request, cancelled)"

# Without workflow runs a replaced run cannot be told from a stopped one.
D=$(new_case cancelled-suites-only)
raw "$D" actions.1.json HTTP403
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
fixture "$D" suites 1 "$OWN_SUITE" "$(suite 20 completed success 1 github-actions)" "$(suite 71 completed cancelled 0 github-actions)"
run_ci "$D"; check ci/cancelled-suite-fails-without-runs "$D" $? 0 result failed notice "cancelled, no job ran"

for c in cancelled timed_out action_required startup_failure stale some_new_value; do
  D=$(new_case "conclusion-$c")
  fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed "$c" build)" "$(run 201 21 completed success lint)"
  run_ci "$D"; check "ci/conclusion-$c-fails" "$D" $? 0 result failed notice "build ($c)"
done

D=$(new_case status-error)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
fixture "$D" status 1 "$(status error ci/external)"
run_ci "$D"; check ci/status-error-fails "$D" $? 0 result failed notice "ci/external (error)"

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

D=$(new_case actions-transient)
raw "$D" actions.1.json HTTP500
fixture "$D" actions 2 "$OWN_WFRUN" "$CI_DONE"
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/workflow-runs-error-retried "$D" $? 0 result green - "API error 1/3"
if [ "$(calls_to "$D" actions/runs)" -gt 1 ]; then pass "ci/workflow-runs-asked-again-after-500"; else fail "ci/workflow-runs-asked-again-after-500"; fi

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

# Dependabot rebased the PR during the wait: the run for the new commit decides.
D=$(new_case superseded)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 in_progress - build)"
echo '{"state":"open","head":{"sha":"def"}}' > "$D/pr.4.json"
run_ci "$D"; check ci/new-head-commit "$D" $? 0 result superseded notice
decided_at ci/new-head-commit "$D" 90

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
