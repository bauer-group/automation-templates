#!/usr/bin/env bash
#
# Behavioural test for ../docker-maintenance-dependabot.yml.
#
# The workflow merges a Dependabot PR only after its CI has passed, without
# rulesets or required status checks:
#
#   guard  (id: guard) - GitHub Actions updates (never merged), required-
#                        workflows (empty: nothing is merged), update type
#                        against merge-update-types / allow-major (a minor
#                        update of 0.y.z and a patch update of 0.0.z count as
#                        major, per dependency), input validation
#   wait   (id: ci)    - checks that every commit is a verified Dependabot
#                        commit and that no changed file is under .github/,
#                        polls check runs, check suites, commit statuses
#                        and workflow runs of the PR head commit, leaves out its
#                        own runs, waits for a complete and quiet state, checks
#                        that every required workflow ran and passed, decides
#                        green / failed / not-tested / timeout / unreadable / ...
#   merge  (id: merge) - reads the PR again, optional approval of the checked
#                        commit (a rejection is only a notice), then gh pr merge
#                        pinned to the head commit
#
# Without this, `gh pr merge --auto` on a branch without required checks merged
# at once - bauer-group/CS-BillingStack#12 three seconds after its label check
# went red. That PR was the redpanda 26.1 -> 26.2 bump: a semver-minor, which
# is why only patch updates are merged by default. And "any passed check" is
# not a test: bauer-group/CI-GitHubRunner#13 had only GitGuardian (success) and
# CodeQL (neutral), CS-GitHubBackup#1 only notification and AI-summary jobs -
# their build workflows never ran, which is why the named required workflows
# must have passed. And a PR that changes CI is not tested by its CI: the PR's
# run of a changed workflow uses the PR's own version, and a changed push-only
# workflow never runs before the merge. GitHub does not stop such a merge -
# bauer-group/XPD-SonarQube#6, an actions/checkout bump of docker-release.yml
# alone, was merged by github-actions[bot] - which is why the module never
# merges a PR that changes CI.
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
# shellcheck disable=SC2016 # literal workflow text
static_has   "guard reads required-workflows"    'REQUIRED_WORKFLOWS: ${{ inputs.required-workflows }}'
# shellcheck disable=SC2016 # literal workflow text
static_has   "guard reads the ecosystem"         'PACKAGE_ECOSYSTEM: ${{ steps.metadata.outputs.package-ecosystem }}'
# shellcheck disable=SC2016 # literal workflow text
static_has   "guard reads every dependency's versions" 'UPDATED_DEPENDENCIES_JSON: ${{ steps.metadata.outputs.updated-dependencies-json }}'
# shellcheck disable=SC2016 # literal workflow text
static_has   "summary shows a 0.x update counted as major" 'TYPE_NOTE: ${{ steps.guard.outputs.type-note }}'
# shellcheck disable=SC2016 # literal workflow text
static_has   "wait gets the checked list"        'REQUIRED: ${{ steps.guard.outputs.required }}'
static_has   "merge is gated by green CI"        "if: steps.ci.outputs.result == 'green'"
# shellcheck disable=SC2016 # literal workflow text
static_has   "merge is pinned to the head"       '--match-head-commit "$HEAD_SHA"'
# shellcheck disable=SC2016 # literal workflow text
static_has   "approval is pinned to the head"    '-f commit_id="$HEAD_SHA"'
static_lacks "no gh pr review (it approves the latest commit)" 'gh pr review'
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
# Only Dependabot's PRs, and only events Dependabot raised.
static_has   "job runs for Dependabot's PRs and events only" "if: github.event.pull_request.user.login == 'dependabot[bot]' && github.actor == 'dependabot[bot]'"
# fetch-metadata's own author and signature checks stay on.
static_lacks "fetch-metadata verification is not skipped" 'skip-verification|skip-commit-verification'
# The job runs with a write token: nothing from the PR is checked out or run.
static_lacks "nothing is checked out"            'actions/checkout|git (clone|fetch|checkout)'
# Event data (PR title, branch, labels, ...) reaches the scripts only through
# env, never as an expression inside a run block, where it would become code.
EXPR_IN_RUN=$(awk '
  /^ *run: \|$/ { match($0, /^ */); ind = RLENGTH; inrun = 1; next }
  inrun {
    if ($0 ~ /^ *$/) next
    match($0, /^ */)
    if (RLENGTH <= ind) inrun = 0
    else if (index($0, "${{")) print NR ": " $0
  }
' "$WORKFLOW_FILE")
if [ -z "$EXPR_IN_RUN" ]; then pass "no expressions inside run blocks"; else fail "expressions inside run blocks: $EXPR_IN_RUN"; fi

# --- gh, date and sleep stubs -------------------------------------------------------
mkdir -p "$WORK/bin"
cat > "$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
# gh api [--paginate] <path> --jq <filter>: answers from $FAKE/<kind>.<n>.json, n
# counting the calls per kind (the highest file is reused once n runs past it).
# A file holding HTTP403, HTTP404, HTTP500 or RATELIMIT simulates that error.
# gh api --method POST .../reviews and gh pr merge: logged to $FAKE/calls;
# FAKE_REVIEW_FAIL / FAKE_MERGE_FAIL fail them.
echo "$*" >> "$FAKE/calls"
if [ "${1:-}" = "pr" ] && [ "${2:-}" = "merge" ]; then
  [ -n "${FAKE_MERGE_FAIL:-}" ] && { echo "X Pull request o/r#7 is not mergeable: the base branch policy prohibits the merge." >&2; exit 1; }
  exit 0
fi
[ "${1:-}" = "api" ] || { echo "unexpected gh call: $*" >&2; exit 2; }
shift
path="" filter="." method=GET
while [ $# -gt 0 ]; do
  case "$1" in
    --jq) filter="$2"; shift 2 ;;
    --method) method="$2"; shift 2 ;;
    -f) shift 2 ;;
    --paginate|--silent) shift ;;
    *) path="$1"; shift ;;
  esac
done
case "$method $path" in
  "POST repos/"*"/pulls/"*"/reviews")
    [ -n "${FAKE_REVIEW_FAIL:-}" ] && { echo "gh: GitHub Actions is not permitted to approve pull requests. (HTTP 422)" >&2; exit 1; }
    exit 0 ;;
  "GET "*) ;;
  *) echo "unexpected gh api call: $*" >&2; exit 2 ;;
esac
case "$path" in
  repos/*/pulls/*/commits*)        kind=commits ;;
  repos/*/pulls/*/files*)          kind=files ;;
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
# wfrun <id> <suite> <status> <conclusion|-> <workflow id> <event> <name> <calls this module: 1|0> [attempt] [head repository]
# Its workflow file is the name in lower case, spaces as dashes: "Docker
# Release" -> .github/workflows/docker-release.yml (GitHub's `path`).
wfrun() {
  local c="null" ref="$OTHER_PATH" file="${7,,}"; [ "$4" = "-" ] || c="\"$4\""; [ "$8" = "1" ] && ref="$MODULE_PATH"
  file=".github/workflows/${file// /-}.yml"
  printf '{"id":%s,"check_suite_id":%s,"status":"%s","conclusion":%s,"workflow_id":%s,"event":"%s","name":"%s","path":"%s","run_attempt":%s,"head_repository":{"full_name":"%s"},"referenced_workflows":[{"path":"%s","sha":"0"}]}' \
    "$1" "$2" "$3" "$c" "$5" "$6" "$7" "$file" "${9:-1}" "${10:-o/r}" "$ref"
}
join() { local IFS=,; echo "$*"; }

# A commit of the PR as GET pulls/{n}/commits returns it (verified: Dependabot
# commits are signed by GitHub).
DEPENDABOT_COMMIT='{"sha":"abc","author":{"login":"dependabot[bot]"},"commit":{"verification":{"verified":true}}}'
# A changed file as GET pulls/{n}/files returns it.
DOCKERFILE_CHANGE='{"filename":"src/Dockerfile","status":"modified"}'

OWN_RUN=$(run $OWN 10 in_progress - "$SELF")
OWN_SUITE=$(suite 10 in_progress - 1 github-actions)
OWN_WFRUN=$(wfrun $RUN 10 in_progress - 1 pull_request "Docker Maintenance" 1)
# The required workflow of most cases (REQUIRED below): .github/workflows/ci.yml,
# its jobs in check suite 20.
REQ_CI=".github/workflows/ci.yml"
CI_RUN=$(wfrun 20 20 in_progress - 2 pull_request "CI" 0)
CI_DONE=$(wfrun 20 20 completed success 2 pull_request "CI" 0)

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

# A PR that changes src/Dockerfile, whose only check so far is this job, with
# the required CI workflow run done - its jobs (check runs in suite 20) are up
# to each case.
new_case() {
  local dir="$WORK/case-$1"
  mkdir -p "$dir/temp"
  : > "$dir/output"; : > "$dir/calls"; echo 0 > "$dir/clock"
  echo '{"state":"open","head":{"sha":"abc"}}' > "$dir/pr.1.json"
  echo "[$DEPENDABOT_COMMIT]" > "$dir/commits.1.json"
  echo "[$DOCKERFILE_CHANGE]" > "$dir/files.1.json"
  fixture "$dir" runs 1 "$OWN_RUN"
  fixture "$dir" suites 1 "$OWN_SUITE"
  fixture "$dir" status 1
  fixture "$dir" actions 1 "$OWN_WFRUN" "$CI_DONE"
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
# logged / not_logged <name> <dir> <text>: the log has / does not have the text
logged() {
  if grep -qF -- "$3" "$2/log"; then pass "$1: log has '$3'"; else fail "$1: log lacks '$3'"; fi
}
not_logged() {
  if grep -qF -- "$3" "$2/log"; then fail "$1: log has '$3'"; else pass "$1: log lacks '$3'"; fi
}
calls_to() { grep -c -- "$2" "$1/calls"; }

# --- guard ----------------------------------------------------------------------
# dep <name> <previous version> <new version> <update type>: one dependency as
# dependabot/fetch-metadata (v3) lists it in updated-dependencies-json
dep() {
  printf '{"dependencyName":"%s","dependencyType":"direct:production","updateType":"%s","directory":"/","packageEcosystem":"docker","targetBranch":"main","prevVersion":"%s","newVersion":"%s","compatScore":0,"maintainerChanges":false,"dependencyGroup":"","alertState":"","ghsaId":"","cvss":0}' \
    "$1" "$4" "$2" "$3"
}
deps() { echo "[$(join "$@")]"; }

# guard_case <name> <update-type> <merge-update-types> <allow-major> <want rc> <ok> <reason> <annotation|-> [merge-method] [wait-minutes]
# required-workflows is $GUARD_REQUIRED, if set (also empty), else ci.yml; the
# ecosystem is $GUARD_ECOSYSTEM, if set (also empty), else docker; the updated
# dependencies are $GUARD_DEPS, if set (also empty), else one 7.2.4 -> 7.2.5
# update of the given type (1.0.0 or later: the 0.x rule does not apply).
# $GUARD_PATH replaces PATH (to take jq away).
guard_case() {
  local name="$1" dir="$WORK/guard-$1"
  mkdir -p "$dir"; : > "$dir/output"
  ( cd "$dir" && PATH="${GUARD_PATH-$PATH}" GITHUB_OUTPUT="$dir/output" PACKAGE_ECOSYSTEM="${GUARD_ECOSYSTEM-docker}" \
      UPDATE_TYPE="$2" MERGE_UPDATE_TYPES="$3" ALLOW_MAJOR="$4" \
      UPDATED_DEPENDENCIES_JSON="${GUARD_DEPS-$(deps "$(dep redis 7.2.4 7.2.5 "$2")")}" \
      MERGE_METHOD="${9:-squash}" WAIT_MINUTES="${10:-60}" REQUIRED_WORKFLOWS="${GUARD_REQUIRED-$REQ_CI}" \
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

# required-workflows: empty means nothing is merged - a notice, the job stays
# green, and no wait (no runner minutes for a PR that cannot be merged).
GUARD_REQUIRED=""         guard_case required-empty        "$P"  "patch" false 0 false no-required-workflows notice
GUARD_REQUIRED=" , "      guard_case required-blank        "$P"  "patch" false 0 false no-required-workflows notice
GUARD_REQUIRED=""         guard_case required-empty-major  "$MA" "patch" true  0 false no-required-workflows notice
if grep -qF "required-workflows: .github/workflows/docker-release.yml" "$WORK/guard-required-empty/log"; then pass "guard/required-empty: notice says how to set it"; else fail "guard/required-empty: notice lacks the example"; fi
# Workflow files as GitHub names them in a run's `path`, directly in
# .github/workflows - anything else is a typo that would never match.
GUARD_REQUIRED="docker-release.yml"                       guard_case required-bare-name   "$P" "patch" false 1 "" "" error
GUARD_REQUIRED=".github/workflows/ci/build.yml"           guard_case required-subdirectory "$P" "patch" false 1 "" "" error
GUARD_REQUIRED=".github/workflows/ci.json"                guard_case required-not-yaml    "$P" "patch" false 1 "" "" error
GUARD_REQUIRED=$' .github/workflows/ci.yml ,\n\t.github/workflows/docker-release.yaml \n' \
                                                          guard_case required-list        "$P" "patch" false 0 true patch -
got=$(sed -n 's/^required=//p' "$WORK/guard-required-list/output")
if [ "$got" = ".github/workflows/ci.yml,.github/workflows/docker-release.yaml" ]; then pass "guard/required-list: normalized"; else fail "guard/required-list: required='$got'"; fi

# A GitHub Actions update changes the CI itself: never merged, whatever the
# update type and required-workflows say - and without a wait. fetch-metadata
# names the ecosystem as the branch name does: dependabot/github_actions/...
GUARD_ECOSYSTEM=github_actions                   guard_case actions-update             "$P"  "patch"             false 0 false ci-change notice
GUARD_ECOSYSTEM=github_actions                   guard_case actions-update-all-types   "$MA" "patch,minor,major" false 0 false ci-change notice
GUARD_ECOSYSTEM=github_actions GUARD_REQUIRED="" guard_case actions-update-no-required "$P"  "patch"             false 0 false ci-change notice
if grep -qF "GitHub Actions updates change the CI itself" "$WORK/guard-actions-update/log"; then pass "guard/actions-update: notice says why"; else fail "guard/actions-update: notice lacks the reason"; fi
# Invalid input is still an error for a GitHub Actions update.
GUARD_ECOSYSTEM=github_actions                   guard_case actions-update-bad-input   "$P"  "pach"              false 1 ""    ""        error
# Other ecosystems, or none known: the wait checks the changed files.
GUARD_ECOSYSTEM=docker_compose                   guard_case compose-update             "$P"  "patch"             false 0 true  patch     -
GUARD_ECOSYSTEM=""                               guard_case ecosystem-unknown          "$P"  "patch"             false 0 true  patch     -

# --- guard: versions below 1.0.0 -------------------------------------------------
# SemVer 4: a 0.y.z version may break on any change. Dependabot (and
# fetch-metadata) call 0.3.1 -> 0.4.0 semver-minor; like npm's caret ranges the
# guard counts a minor update of a 0.y.z version and a patch update of a 0.0.z
# version as major. Per dependency, the strictest one decides.
# type_note_is <name> <want>: the guard's type-note output
type_note_is() {
  local got; got=$(sed -n 's/^type-note=//p' "$WORK/guard-$1/output")
  if [ "$got" = "$2" ]; then pass "guard/$1: type-note '$2'"; else fail "guard/$1: type-note '$got', want '$2'"; fi
}
glogged()     { logged "guard/$1" "$WORK/guard-$1" "$2"; }
gnot_logged() { not_logged "guard/$1" "$WORK/guard-$1" "$2"; }

# 0.3.1 -> 0.4.0: what a caller that merges minor updates used to merge.
GUARD_DEPS=$(deps "$(dep lib 0.3.1 0.4.0 "$MI")") guard_case zero-minor-minor-allowed  "$MI" "patch,minor"       false 0 false update-type notice
glogged     zero-minor-minor-allowed "0.x minor treated as major: lib 0.3.1 -> 0.4.0"
glogged     zero-minor-minor-allowed "semver-major update (0.x minor treated as major: lib 0.3.1 -> 0.4.0) - left open for review"
type_note_is zero-minor-minor-allowed "0.x minor treated as major: lib 0.3.1 -> 0.4.0"
GUARD_DEPS=$(deps "$(dep lib 0.3.1 0.4.0 "$MI")") guard_case zero-minor-all-allowed    "$MI" "patch,minor,major" false 0 true  major       -
glogged     zero-minor-all-allowed "0.x minor treated as major: lib 0.3.1 -> 0.4.0"
GUARD_DEPS=$(deps "$(dep lib 0.3.1 0.4.0 "$MI")") guard_case zero-minor-allow-major    "$MI" "patch"             true  0 true  major       -
GUARD_DEPS=$(deps "$(dep lib 0.3.1 0.4.0 "$MI")") guard_case zero-minor-default        "$MI" "patch"             false 0 false update-type notice
# 0.0.3 -> 0.0.4: merged by the default (patch) before - now left open.
GUARD_DEPS=$(deps "$(dep lib 0.0.3 0.0.4 "$P")")  guard_case zero-zero-patch-default   "$P"  "patch"             false 0 false update-type notice
glogged     zero-zero-patch-default "0.0.x patch treated as major: lib 0.0.3 -> 0.0.4"
type_note_is zero-zero-patch-default "0.0.x patch treated as major: lib 0.0.3 -> 0.0.4"
GUARD_DEPS=$(deps "$(dep lib 0.0.3 0.0.4 "$P")")  guard_case zero-zero-patch-all       "$P"  "patch,minor,major" false 0 true  major       -
GUARD_DEPS=$(deps "$(dep lib 0.0.3 0.1.0 "$MI")") guard_case zero-zero-minor           "$MI" "patch,minor"       false 0 false update-type notice
glogged     zero-zero-minor "0.x minor treated as major: lib 0.0.3 -> 0.1.0"
# Within the caret range: a patch update of 0.y.z (y > 0) stays a patch.
GUARD_DEPS=$(deps "$(dep lib 0.3.1 0.3.2 "$P")")  guard_case zero-patch-stays-patch    "$P"  "patch"             false 0 true  patch       -
gnot_logged zero-patch-stays-patch "treated as major"
type_note_is zero-patch-stays-patch ""
# Already major, and 1.0.0 or later: as Dependabot reported.
GUARD_DEPS=$(deps "$(dep lib 0.9.2 1.0.0 "$MA")") guard_case zero-to-one-major         "$MA" "patch,minor"       false 0 false update-type notice
gnot_logged zero-to-one-major "treated as major"
GUARD_DEPS=$(deps "$(dep lib 1.2.3 1.3.0 "$MI")") guard_case one-minor-stays-minor     "$MI" "patch,minor"       false 0 true  minor       -
GUARD_DEPS=$(deps "$(dep lib 1.0.0 1.0.1 "$P")")  guard_case one-zero-zero-patch       "$P"  "patch"             false 0 true  patch       -
# Plain X.Y.Z, with a leading v and a pre-release or build suffix.
GUARD_DEPS=$(deps "$(dep redpanda v0.3.1 v0.4.0 "$MI")")                guard_case zero-minor-v-prefix  "$MI" "patch,minor" false 0 false update-type notice
glogged     zero-minor-v-prefix "0.x minor treated as major: redpanda v0.3.1 -> v0.4.0"
GUARD_DEPS=$(deps "$(dep lib 0.3.1-rc.1 0.4.0+build.7 "$MI")")         guard_case zero-minor-suffixes  "$MI" "patch,minor" false 0 false update-type notice
GUARD_DEPS=$(deps "$(dep app 0.3.1-alpine3.20 0.4.0-alpine3.20 "$MI")") guard_case zero-minor-tag-variant "$MI" "patch,minor" false 0 false update-type notice
# Anything else keeps the type Dependabot reported - and never fails the job:
# a two-part tag, a tag like 18-alpine, leading zeros, a date, a digest, a
# missing version, a new version that is not plain semver.
for v in "0.3 0.4" "0.3-alpine 0.4-alpine" "0.03.1 0.04.0" "2024-01-15 2024-02-01" "- 0.4.0" "0.3.1 0.4" "0.3.1 0.4.0.1" "V0.3.1 V0.4.0" "0.3.1 sha256:0123abcd"; do
  read -r prev new <<< "$v"; [ "$prev" = "-" ] && prev=""
  name="not-plain-semver-${prev:-none}-$new"; name="${name//[^A-Za-z0-9.-]/_}"
  GUARD_DEPS=$(deps "$(dep lib "$prev" "$new" "$MI")") guard_case "$name" "$MI" "patch,minor" false 0 true minor -
  gnot_logged "$name" "treated as major"
done
GUARD_DEPS='[{"dependencyName":"lib","updateType":"version-update:semver-minor","prevVersion":null}]' \
                                                 guard_case versions-missing          "$MI" "patch,minor"       false 0 true  minor       -
# The update type of each dependency is the one fetch-metadata lists for it;
# without one (no versions it could compare) the dependency changes nothing.
GUARD_DEPS=$(deps "$(dep lib 0.3.1 0.4.0 "")")   guard_case dependency-type-unknown   "$MI" "patch,minor"       false 0 true  minor       -

# A grouped update: the strictest dependency decides.
GUARD_DEPS=$(deps "$(dep redis 7.2.4 7.2.5 "$P")" "$(dep lib 0.3.1 0.4.0 "$MI")") \
                                                 guard_case group-zero-minor          "$MI" "patch,minor"       false 0 false update-type notice
glogged     group-zero-minor "0.x minor treated as major: lib 0.3.1 -> 0.4.0"
gnot_logged group-zero-minor "redis 7.2.4 -> 7.2.5"
GUARD_DEPS=$(deps "$(dep redis 7.2.4 7.3.0 "$MI")" "$(dep lib 0.0.3 0.0.4 "$P")") \
                                                 guard_case group-zero-zero-patch     "$MI" "patch,minor"       false 0 false update-type notice
glogged     group-zero-zero-patch "0.0.x patch treated as major: lib 0.0.3 -> 0.0.4"
GUARD_DEPS=$(deps "$(dep a 0.3.1 0.4.0 "$MI")" "$(dep b 0.0.1 0.0.2 "$P")") \
                                                 guard_case group-two-zero            "$MI" "patch,minor,major" false 0 true  major       -
type_note_is group-two-zero "0.x minor treated as major: a 0.3.1 -> 0.4.0; 0.0.x patch treated as major: b 0.0.1 -> 0.0.2"
GUARD_DEPS=$(deps "$(dep redis 7.2.4 7.2.5 "$P")" "$(dep lib 0.3.1 0.3.2 "$P")") \
                                                 guard_case group-within-caret        "$P"  "patch"             false 0 true  patch       -
GUARD_DEPS=$(deps "$(dep redis 7.2.4 7.2.5 "$P")" "$(dep app 0.3-alpine 0.4-alpine "$MI")") \
                                                 guard_case group-not-plain-semver    "$MI" "patch,minor"       false 0 true  minor       -

# Per-dependency data that cannot be read: a warning, the job stays green and
# the update type is the one Dependabot reported.
GUARD_DEPS="not json"  guard_case deps-not-json  "$MI" "patch,minor" false 0 true minor warning
glogged     deps-not-json "a 0.x update could not be checked. The update type is taken as Dependabot reported it: semver-minor"
GUARD_DEPS=""          guard_case deps-empty     "$P"  "patch"       false 0 true patch warning
GUARD_DEPS="[]"        guard_case deps-none      "$P"  "patch"       false 0 true patch warning
GUARD_DEPS='{"a":1}'   guard_case deps-not-list  "$P"  "patch"       false 0 true patch warning
mkdir -p "$WORK/nojq"
printf '#!/usr/bin/env bash\necho "jq: command not found" >&2\nexit 127\n' > "$WORK/nojq/jq"; chmod +x "$WORK/nojq/jq"
GUARD_PATH="$WORK/nojq:$PATH" GUARD_DEPS=$(deps "$(dep lib 0.3.1 0.4.0 "$MI")") \
                       guard_case jq-missing     "$MI" "patch,minor" false 0 true minor warning

# The order stays: a GitHub Actions update, a missing required-workflows and
# an unknown update type decide before the versions are looked at.
GUARD_ECOSYSTEM=github_actions GUARD_DEPS=$(deps "$(dep actions/checkout 0.3.1 0.4.0 "$MI")") \
                                                 guard_case zero-actions-update       "$MI" "patch,minor"       false 0 false ci-change notice
GUARD_REQUIRED="" GUARD_DEPS=$(deps "$(dep lib 0.3.1 0.4.0 "$MI")") \
                                                 guard_case zero-required-empty       "$MI" "patch,minor"       false 0 false no-required-workflows notice
GUARD_DEPS=$(deps "$(dep lib 0.3.1 0.4.0 "")")  guard_case zero-unknown-update-type  ""    "patch,minor,major" false 0 false unknown-update-type notice
gnot_logged zero-unknown-update-type "treated as major"

# --- wait for CI ----------------------------------------------------------------
# run_ci <dir> [VAR=value ...]   (REQUIRED: the guard's checked list)
run_ci() {
  local dir="$1"; shift
  ( cd "$dir" && env PATH="$WORK/bin:$PATH" FAKE="$dir" GITHUB_OUTPUT="$dir/output" RUNNER_TEMP="$dir/temp" \
      GH_TOKEN=test REPO=o/r PR_NUMBER=7 HEAD_SHA=abc RUN_ID=$RUN OWN_CHECK_RUN_ID=$OWN SELF_JOB_NAME="Docker Maintenance" \
      WAIT_MINUTES=60 REQUIRED="$REQ_CI" "$@" \
      bash --noprofile --norc -eo pipefail -c "$CI_BODY" ) > "$dir/log" 2>&1
}

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
listed ci/green-after-wait "$D" "OK required: .github/workflows/ci.yml (run 20, attempt 1: success)"

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
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
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

# Nothing ran at all: the required workflow did not run - decided once the
# settle time is over (a workflow GitHub starts late is still waited for).
D=$(new_case nothing-ran)
fixture "$D" actions 1 "$OWN_WFRUN"
run_ci "$D"; check ci/nothing-ran "$D" $? 0 result not-tested notice "Required workflow .github/workflows/ci.yml did not run for this change - not tested"
decided_at ci/nothing-ran "$D" 300

# neutral and skipped are no failure, but nothing passed either. A workflow
# run whose jobs were all skipped concludes "skipped" (seen on
# bauer-group/CS-BackupHelper run 37917566835) - not a test.
D=$(new_case all-skipped)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed skipped deploy)" "$(run 201 21 completed neutral CodeQL)"
fixture "$D" actions 1 "$OWN_WFRUN" "$(wfrun 20 20 completed skipped 2 pull_request "CI" 0)"
run_ci "$D"; check ci/required-workflow-skipped "$D" $? 0 result not-tested notice ".github/workflows/ci.yml (run 20, attempt 1: skipped) - not tested"

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
# on the strength of lint alone. Here it is the required workflow.
D=$(new_case queued-workflow-run)
fixture "$D" runs 1 "$OWN_RUN" "$(run 201 21 completed success lint)"
fixture "$D" actions 1 "$OWN_WFRUN" "$(wfrun 40 40 queued - 4 pull_request "Release" 0)"
fixture "$D" runs 13 "$OWN_RUN" "$(run 201 21 completed success lint)" "$(run 400 40 completed success build)"
fixture "$D" suites 13 "$OWN_SUITE" "$(suite 40 completed success 1 github-actions)"
fixture "$D" actions 13 "$OWN_WFRUN" "$(wfrun 40 40 completed success 4 pull_request "Release" 0)"
run_ci "$D" REQUIRED=.github/workflows/release.yml; check ci/queued-workflow-run-is-waited-for "$D" $? 0 result green - "pending: 1"
decided_at ci/queued-workflow-run-is-waited-for "$D" 600

# The check suite of a workflow run whose jobs do not exist yet - and that
# the workflow runs do not list yet - keeps the wait going until it is done
# at 420 s.
D=$(new_case workflow-without-jobs-yet)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success labels)"
fixture "$D" suites 1 "$OWN_SUITE" "$(suite 20 completed success 1 github-actions)" "$(suite 50 queued - 0 github-actions)"
fixture "$D" runs 13 "$OWN_RUN" "$(run 200 20 completed success labels)" "$(run 500 50 completed success build)"
fixture "$D" suites 13 "$OWN_SUITE" "$(suite 20 completed success 1 github-actions)" "$(suite 50 completed success 1 github-actions)"
run_ci "$D"; check ci/waits-for-workflow-without-jobs "$D" $? 0 result green - "checks: 2,"
decided_at ci/waits-for-workflow-without-jobs "$D" 600

# Without the workflow runs (private repository, no actions: read) nothing
# shows that the required workflows ran: closed at once, not after the wait.
D=$(new_case actions-not-readable)
raw "$D" actions.1.json HTTP403
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/workflow-runs-403-fails-closed "$D" $? 0 result unreadable notice "'actions: read'"
decided_at ci/workflow-runs-403-fails-closed "$D" 0
if [ "$(calls_to "$D" actions/runs)" -eq 1 ]; then pass "ci/workflow-runs-403-asked-once"; else fail "ci/workflow-runs-403-asked-once: $(calls_to "$D" actions/runs) calls"; fi

D=$(new_case actions-not-found)
raw "$D" actions.1.json HTTP404
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/workflow-runs-404-fails-closed "$D" $? 0 result unreadable notice "HTTP 404"

# Other runs of this module - another caller workflow, queued without a job yet
# or running - are not waited for.
D=$(new_case siblings-ignored)
fixture "$D" runs 1 "$OWN_RUN" "$(run 300 30 in_progress - "Other caller / Docker Maintenance")" "$(run 200 20 completed success build)"
fixture "$D" suites 1 "$OWN_SUITE" "$(suite 30 in_progress - 1 github-actions)" "$(suite 31 queued - 0 github-actions)" "$(suite 20 completed success 1 github-actions)"
fixture "$D" actions 1 "$OWN_WFRUN" "$(wfrun 30 30 in_progress - 3 pull_request "Actions Maintenance" 1)" "$(wfrun 31 31 queued - 3 pull_request "Actions Maintenance" 1)" "$CI_DONE"
run_ci "$D"; check ci/other-runs-of-this-module-ignored "$D" $? 0 result green - "checks: 1,"

# A workflow runs list without this run is not trusted (not complete yet): the
# job names decide which checks are this module's, and the required workflows
# count as pending until the list has this run.
D=$(new_case siblings-by-name)
fixture "$D" runs 1 "$OWN_RUN" "$(run 300 30 in_progress - "Other caller / Docker Maintenance")" "$(run 400 40 queued - "$SELF")" "$(run 200 20 completed success build)"
fixture "$D" suites 1 "$OWN_SUITE" "$(suite 30 in_progress - 1 github-actions)" "$(suite 40 queued - 1 github-actions)" "$(suite 20 completed success 1 github-actions)"
fixture "$D" actions 1 "$CI_DONE"
fixture "$D" actions 2 "$OWN_WFRUN" "$(wfrun 30 30 in_progress - 3 pull_request "Actions Maintenance" 1)" "$(wfrun 40 40 queued - 1 pull_request "Docker Maintenance" 1)" "$CI_DONE"
run_ci "$D"; check ci/other-runs-ignored-by-job-name "$D" $? 0 result green - "checks: 1, passed: 1, pending: 1, failed: 0"

D=$(new_case runs-without-own-run)
fixture "$D" runs 1 "$OWN_RUN" "$(run 300 30 in_progress - "Other caller / Docker Maintenance")" "$(run 200 20 completed success build)"
fixture "$D" suites 1 "$OWN_SUITE" "$(suite 30 in_progress - 1 github-actions)" "$(suite 20 completed success 1 github-actions)"
fixture "$D" actions 1 "$CI_DONE"
run_ci "$D" WAIT_MINUTES=10; check ci/runs-without-this-run-not-trusted "$D" $? 0 result timeout notice "checks: 1, passed: 1, pending: 1, failed: 0"
listed ci/runs-without-this-run-not-trusted "$D" "PENDING required: .github/workflows/ci.yml (the workflow runs do not list this run yet)"

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

# The same seen from its check suite alone (the run not listed yet).
D=$(new_case startup-failure-suites-only)
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

# A cancelled suite whose run the workflow runs do not list cannot be told
# from a stopped run: failed.
D=$(new_case cancelled-suites-only)
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
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
raw "$D" status.1.json RATELIMIT
fixture "$D" status 2
run_ci "$D"; check ci/rate-limit-is-retried "$D" $? 0 result green - "API error 1/3"

D=$(new_case persistent-error)
raw "$D" runs.1.json HTTP500
run_ci "$D"; check ci/three-errors-give-up "$D" $? 0 result api-error warning

# Every commit of the PR must be a verified commit by Dependabot -
# fetch-metadata checks only the first one. Asked once per run.
D=$(new_case commits-checked-once)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/commits-checked-once "$D" $? 0 result green -
if [ "$(calls_to "$D" pulls/7/commits)" -eq 1 ]; then pass "ci/commits-asked-once"; else fail "ci/commits-asked-once: $(calls_to "$D" pulls/7/commits) calls"; fi
if [ "$(calls_to "$D" pulls/7/files)" -eq 1 ]; then pass "ci/changed-files-asked-once"; else fail "ci/changed-files-asked-once: $(calls_to "$D" pulls/7/files) calls"; fi

D=$(new_case foreign-commit)
echo "[$DEPENDABOT_COMMIT,{\"sha\":\"0123456789abcdef\",\"author\":{\"login\":\"mallory\"},\"commit\":{\"verification\":{\"verified\":true}}}]" > "$D/commits.1.json"
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/commit-by-someone-else "$D" $? 0 result foreign-commits notice "0123456789ab (mallory, verified: true)"
decided_at ci/commit-by-someone-else "$D" 0

D=$(new_case unverified-commit)
echo '[{"sha":"abc","author":{"login":"dependabot[bot]"},"commit":{"verification":{"verified":false}}}]' > "$D/commits.1.json"
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/unverified-commit "$D" $? 0 result foreign-commits notice "(dependabot[bot], verified: false)"

D=$(new_case unknown-author)
echo '[{"sha":"abc","author":null,"commit":{"verification":{"verified":true}}}]' > "$D/commits.1.json"
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/commit-without-github-author "$D" $? 0 result foreign-commits notice "(-, verified: true)"

D=$(new_case pr-closed)
echo '{"state":"closed","head":{"sha":"abc"}}' > "$D/pr.1.json"
run_ci "$D"; check ci/pr-closed "$D" $? 0 result closed notice

# Dependabot rebased the PR during the wait: the run for the new commit decides.
D=$(new_case superseded)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 in_progress - build)"
echo '{"state":"open","head":{"sha":"def"}}' > "$D/pr.4.json"
run_ci "$D"; check ci/new-head-commit "$D" $? 0 result superseded notice
decided_at ci/new-head-commit "$D" 90

# --- required workflows -----------------------------------------------------------
REQ_REL=".github/workflows/docker-release.yml"
REL_DONE=$(wfrun 50 50 completed success 5 pull_request "Docker Release" 0)

# B1 regression, the shape of bauer-group/CI-GitHubRunner#13 (semver-patch):
# GitGuardian passed, CodeQL neutral, nothing else - the build workflow has no
# pull_request trigger. Any-passed-check would have merged it at 300 s.
D=$(new_case b1-gitguardian-only)
fixture "$D" runs 1 "$OWN_RUN" "$(run 800 80 completed success "GitGuardian Security Checks")" "$(run 810 81 completed neutral CodeQL)"
fixture "$D" suites 1 "$OWN_SUITE" "$(suite 80 completed success 1 gitguardian)" "$(suite 81 completed neutral 1 github-advanced-security)"
fixture "$D" actions 1 "$OWN_WFRUN"
run_ci "$D" REQUIRED="$REQ_REL"; check ci/b1-only-gitguardian-passed-not-merged "$D" $? 0 result not-tested notice "Required workflow .github/workflows/docker-release.yml did not run for this change - not tested"
decided_at ci/b1-only-gitguardian-passed-not-merged "$D" 300
logged ci/b1-only-gitguardian-passed-not-merged "$D" "checks: 2, passed: 1, pending: 0, failed: 0"

# B1 regression, the shape of bauer-group/CS-GitHubBackup#1 (root Dockerfile,
# not in the release workflow's paths): Teams notification, AI summary and
# GitGuardian passed, all on pull_request.
D=$(new_case b1-notifications-only)
fixture "$D" runs 1 "$OWN_RUN" "$(run 820 82 completed success "Notify")" "$(run 821 82 completed skipped "Notify Teams (closed)")" \
  "$(run 830 83 completed success "Generate AI Summary")" "$(run 800 80 completed success "GitGuardian Security Checks")"
fixture "$D" suites 1 "$OWN_SUITE" "$(suite 82 completed success 2 github-actions)" "$(suite 83 completed success 1 github-actions)" "$(suite 80 completed success 1 gitguardian)"
fixture "$D" actions 1 "$OWN_WFRUN" "$(wfrun 82 82 completed success 8 pull_request "Pull Request Notifications" 0)" "$(wfrun 83 83 completed success 9 pull_request "AI Summary" 0)"
run_ci "$D" REQUIRED="$REQ_REL"; check ci/b1-only-notifications-passed-not-merged "$D" $? 0 result not-tested notice "docker-release.yml did not run for this change"
logged ci/b1-only-notifications-passed-not-merged "$D" "checks: 4, passed: 3, pending: 0, failed: 0"
listed ci/b1-only-notifications-passed-not-merged "$D" "UNTESTED required: .github/workflows/docker-release.yml did not run for this change"

# Runs of the required workflow that do not test this PR: a push run on the
# Dependabot branch, and a fork PR's pull_request run on the same commit.
D=$(new_case required-push-run-only)
fixture "$D" runs 1 "$OWN_RUN" "$(run 500 50 completed success build)"
fixture "$D" actions 1 "$OWN_WFRUN" "$(wfrun 50 50 completed success 5 push "Docker Release" 0)"
run_ci "$D" REQUIRED="$REQ_REL"; check ci/required-push-run-does-not-count "$D" $? 0 result not-tested notice "docker-release.yml did not run for this change"

D=$(new_case required-fork-run-only)
fixture "$D" runs 1 "$OWN_RUN" "$(run 500 50 completed success build)"
fixture "$D" actions 1 "$OWN_WFRUN" "$(wfrun 50 50 completed success 5 pull_request "Docker Release" 0 1 mallory/r)"
run_ci "$D" REQUIRED="$REQ_REL"; check ci/required-fork-pr-run-does-not-count "$D" $? 0 result not-tested notice "docker-release.yml did not run for this change"

# The required workflow appears late (GitHub started it with a delay): waited
# for, then green.
D=$(new_case required-late)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success lint)"
fixture "$D" runs 8 "$OWN_RUN" "$(run 200 20 completed success lint)" "$(run 500 50 in_progress - build)"
fixture "$D" actions 8 "$OWN_WFRUN" "$CI_DONE" "$(wfrun 50 50 in_progress - 5 pull_request "Docker Release" 0)"
fixture "$D" runs 10 "$OWN_RUN" "$(run 200 20 completed success lint)" "$(run 500 50 completed success build)"
fixture "$D" actions 10 "$OWN_WFRUN" "$CI_DONE" "$REL_DONE"
run_ci "$D" REQUIRED="$REQ_REL"; check ci/required-workflow-started-late "$D" $? 0 result green -
decided_at ci/required-workflow-started-late "$D" 480

# The required workflow failed or was cancelled: failed at once.
for c in failure cancelled; do
  D=$(new_case "required-$c")
  fixture "$D" runs 1 "$OWN_RUN" "$(run 500 50 completed "$c" build)"
  fixture "$D" actions 1 "$OWN_WFRUN" "$(wfrun 50 50 completed "$c" 5 pull_request "Docker Release" 0)"
  run_ci "$D" REQUIRED="$REQ_REL"; check "ci/required-workflow-$c" "$D" $? 0 result failed notice "Docker Release (pull_request, $c)"
  decided_at "ci/required-workflow-$c" "$D" 0
done

# Its pull_request run was cancelled and a push run of the same workflow
# replaced it: no failure, but the PR is still not tested.
D=$(new_case required-replaced-by-push)
fixture "$D" runs 1 "$OWN_RUN" "$(run 500 50 completed cancelled build)" "$(run 510 51 completed success build)"
fixture "$D" actions 1 "$OWN_WFRUN" "$(wfrun 50 50 completed cancelled 5 pull_request "Docker Release" 0)" "$(wfrun 51 51 completed success 5 push "Docker Release" 0)"
run_ci "$D" REQUIRED="$REQ_REL"; check ci/required-replaced-by-push-run "$D" $? 0 result not-tested notice "docker-release.yml (run 50, attempt 1: cancelled) - not tested"

# Still running: the PR is not merged before it is done.
D=$(new_case required-running)
fixture "$D" runs 1 "$OWN_RUN" "$(run 500 50 in_progress - build)"
fixture "$D" actions 1 "$OWN_WFRUN" "$(wfrun 50 50 in_progress - 5 pull_request "Docker Release" 0)"
run_ci "$D" REQUIRED="$REQ_REL" WAIT_MINUTES=10; check ci/required-workflow-still-running "$D" $? 0 result timeout notice
decided_at ci/required-workflow-still-running "$D" 600
listed ci/required-workflow-still-running "$D" "PENDING required: .github/workflows/docker-release.yml (run 50, attempt 1: in_progress)"

# A re-run: attempt 1 failed, attempt 2 runs and passes. The runs list shows
# the run with its latest attempt (seen on bauer-group/CS-ZAMMAD run
# 37835873163: run_attempt 2, same check suite), the new jobs are newer check
# runs in the same suite.
D=$(new_case required-rerun)
fixture "$D" runs 1 "$OWN_RUN" "$(run 500 50 completed failure build)" "$(run 501 50 in_progress - build)"
fixture "$D" actions 1 "$OWN_WFRUN" "$(wfrun 50 50 in_progress - 5 pull_request "Docker Release" 0 2)"
fixture "$D" runs 3 "$OWN_RUN" "$(run 500 50 completed failure build)" "$(run 501 50 completed success build)"
fixture "$D" actions 3 "$OWN_WFRUN" "$(wfrun 50 50 completed success 5 pull_request "Docker Release" 0 2)"
run_ci "$D" REQUIRED="$REQ_REL"; check ci/required-rerun-latest-attempt-wins "$D" $? 0 result green -
decided_at ci/required-rerun-latest-attempt-wins "$D" 300
listed ci/required-rerun-latest-attempt-wins "$D" "OK required: .github/workflows/docker-release.yml (run 50, attempt 2: success)"

# Two runs of the required workflow for the commit (e.g. reopened): the newest
# counts - here it is still running, so the older success is not enough.
D=$(new_case required-newest-run)
fixture "$D" runs 1 "$OWN_RUN" "$(run 500 50 completed success build)" "$(run 520 52 in_progress - build)"
fixture "$D" actions 1 "$OWN_WFRUN" "$REL_DONE" "$(wfrun 52 52 in_progress - 5 pull_request "Docker Release" 0)"
fixture "$D" runs 13 "$OWN_RUN" "$(run 500 50 completed success build)" "$(run 520 52 completed success build)"
fixture "$D" actions 13 "$OWN_WFRUN" "$REL_DONE" "$(wfrun 52 52 completed success 5 pull_request "Docker Release" 0)"
run_ci "$D" REQUIRED="$REQ_REL"; check ci/required-newest-run-counts "$D" $? 0 result green -
decided_at ci/required-newest-run-counts "$D" 600
listed ci/required-newest-run-counts "$D" "OK required: .github/workflows/docker-release.yml (run 52, attempt 1: success)"

# Several required workflows: all of them must have passed.
D=$(new_case required-two-passed)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success lint)" "$(run 500 50 completed success build)"
fixture "$D" actions 1 "$OWN_WFRUN" "$CI_DONE" "$REL_DONE"
run_ci "$D" REQUIRED="$REQ_CI,$REQ_REL"; check ci/required-two-both-passed "$D" $? 0 result green -
listed ci/required-two-both-passed "$D" "OK required: .github/workflows/ci.yml (run 20, attempt 1: success)"
listed ci/required-two-both-passed "$D" "OK required: .github/workflows/docker-release.yml (run 50, attempt 1: success)"

D=$(new_case required-two-one-missing)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success lint)"
run_ci "$D" REQUIRED="$REQ_CI,$REQ_REL"; check ci/required-two-one-missing "$D" $? 0 result not-tested notice "Required workflow .github/workflows/docker-release.yml did not run for this change - not tested"
not_logged ci/required-two-one-missing "$D" "ci.yml did not run"

# Without a required workflow the wait does not start (the guard stops first;
# the step is closed on its own too).
D=$(new_case required-none)
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D" REQUIRED=""; check ci/no-required-workflow-not-merged "$D" $? 0 result not-tested notice "required-workflows"
if [ ! -s "$D/calls" ]; then pass "ci/no-required-workflow: no API call"; else fail "ci/no-required-workflow: $(wc -l < "$D/calls") API calls"; fi

# The required run passed, but its jobs are not listed (the check runs lag
# behind): nothing passed that shows it - left open.
D=$(new_case required-jobs-not-listed)
run_ci "$D"; check ci/required-passed-without-listed-jobs "$D" $? 0 result not-tested notice "No check passed"

# --- CI files ---------------------------------------------------------------------
# A PR like bauer-group/XPD-SonarQube#6 (dependabot/github_actions/actions/
# checkout-7), which changed only docker-release.yml - the required workflow,
# whose pull_request paths now include its own file. Its run uses the PR's own
# version and passes: it vouches for itself - left open at once, before any
# wait.
D=$(new_case ci-change-required-workflow)
echo '[{"filename":".github/workflows/docker-release.yml","status":"modified"}]' > "$D/files.1.json"
fixture "$D" runs 1 "$OWN_RUN" "$(run 500 50 completed success build)"
fixture "$D" actions 1 "$OWN_WFRUN" "$REL_DONE"
run_ci "$D" REQUIRED="$REQ_REL"; check ci/ci-change-required-workflow-not-merged "$D" $? 0 result ci-change notice "This PR changes CI files (.github/workflows/docker-release.yml)"
decided_at ci/ci-change-required-workflow-not-merged "$D" 0
if [ "$(calls_to "$D" check-runs)" -eq 0 ]; then pass "ci/ci-change: no CI read"; else fail "ci/ci-change: $(calls_to "$D" check-runs) CI reads"; fi

# A composite action changed together with a Dockerfile: only the CI file is
# named.
D=$(new_case ci-change-action)
echo "[$DOCKERFILE_CHANGE,{\"filename\":\".github/actions/setup/action.yml\",\"status\":\"modified\"}]" > "$D/files.1.json"
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/ci-change-composite-action "$D" $? 0 result ci-change notice "CI files (.github/actions/setup/action.yml)"

# Moved out of .github/: the old path counts.
D=$(new_case ci-change-renamed)
echo '[{"filename":"ci/release.yml","status":"renamed","previous_filename":".github/workflows/release.yml"}]' > "$D/files.1.json"
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/ci-change-renamed-out-of-github "$D" $? 0 result ci-change notice "CI files (.github/workflows/release.yml)"

# Two pages (gh --paginate applies the filter to each): a CI file on the
# second one counts too.
D=$(new_case ci-change-second-page)
printf '[%s]\n[{"filename":".github/workflows/ci.yml","status":"modified"}]\n' "$DOCKERFILE_CHANGE" > "$D/files.1.json"
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/ci-change-on-second-page "$D" $? 0 result ci-change notice "CI files (.github/workflows/ci.yml)"

# Names that only contain .github, not under it: tested as usual.
D=$(new_case not-ci-similar-name)
echo '[{"filename":"docs/.github/notes.md","status":"modified"},{"filename":"src/.github.Dockerfile","status":"added"}]' > "$D/files.1.json"
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/similar-names-are-no-ci-change "$D" $? 0 result green -

# No file listed, or 3000 - GitHub's maximum, so the list may be cut off: a
# CI change cannot be ruled out.
D=$(new_case files-none)
echo '[]' > "$D/files.1.json"
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/no-changed-file-listed "$D" $? 0 result ci-change notice "could not be listed in full (0 listed)"

D=$(new_case files-cut-off)
jq -cn '[range(3000) | {filename: "src/f\(.)", status: "added"}]' > "$D/files.1.json"
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/changed-files-cut-off "$D" $? 0 result ci-change notice "could not be listed in full (3000 listed)"

D=$(new_case files-2999)
jq -cn '[range(2999) | {filename: "src/f\(.)", status: "added"}]' > "$D/files.1.json"
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/changed-files-below-the-limit "$D" $? 0 result green -

# The changed files not readable: closed at once. A server error is retried.
D=$(new_case files-unreadable)
raw "$D" files.1.json HTTP403
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/changed-files-403-fails-closed "$D" $? 0 result unreadable notice
decided_at ci/changed-files-403-fails-closed "$D" 0

D=$(new_case files-transient)
raw "$D" files.1.json HTTP500
echo "[$DOCKERFILE_CHANGE]" > "$D/files.2.json"
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/changed-files-error-retried "$D" $? 0 result green - "API error 1/3"

D=$(new_case files-transient-ci-change)
raw "$D" files.1.json HTTP500
echo '[{"filename":".github/workflows/ci.yml","status":"modified"}]' > "$D/files.2.json"
fixture "$D" runs 1 "$OWN_RUN" "$(run 200 20 completed success build)"
run_ci "$D"; check ci/ci-change-after-an-error "$D" $? 0 result ci-change notice "CI files (.github/workflows/ci.yml)"

# --- approve and merge ------------------------------------------------------------
# The PR as read again right before merging: $dir/pr.<n>.json, ready by default.
PR_READY='{"state":"open","head":{"sha":"abc"},"draft":false,"mergeable":true,"mergeable_state":"clean"}'
APPROVAL="api --method POST repos/o/r/pulls/7/reviews -f event=APPROVE -f commit_id=abc --silent"
merge_dir() {
  local dir="$WORK/merge-$1"
  mkdir -p "$dir"; : > "$dir/output"; : > "$dir/calls"; echo 0 > "$dir/clock"
  echo "$PR_READY" > "$dir/pr.1.json"
  echo "$dir"
}
# merge_run <dir> <auto-approve> <merge-method> [VAR=value ...]
merge_run() {
  local dir="$1" approve="$2" method="$3"; shift 3
  ( cd "$dir" && env PATH="$WORK/bin:$PATH" FAKE="$dir" GITHUB_OUTPUT="$dir/output" \
      GH_TOKEN=test REPO=o/r PR_NUMBER=7 HEAD_SHA=abc AUTO_APPROVE="$approve" MERGE_METHOD="$method" "$@" \
      bash --noprofile --norc -eo pipefail -c "$MERGE_BODY" ) > "$dir/log" 2>&1
}
reason_is() {
  local got; got=$(sed -n 's/^reason=//p' "$2/output")
  if [ "$got" = "$3" ]; then pass "$1: reason $3"; else fail "$1: reason '$got', want '$3'"; fi
}
called() {
  if grep -qxF -- "$3" "$2/calls"; then pass "$1: called '$3'"; else fail "$1: '$3' not called"; fi
}
not_called() {
  if grep -qF -- "$3" "$2/calls"; then fail "$1: '$3' was called"; else pass "$1: no '$3'"; fi
}

# The approval names the checked commit: without commit_id GitHub approves the
# PR's latest commit, which could be one pushed after CI was checked.
D=$(merge_dir approve-and-merge); merge_run "$D" true squash
check merge/approve-and-merge "$D" $? 0 merged true -
reason_is merge/approve-and-merge "$D" merged
called merge/approve-and-merge "$D" "$APPROVAL"
called merge/approve-and-merge "$D" "pr merge 7 --repo o/r --squash --match-head-commit abc"

D=$(merge_dir approve-rejected); merge_run "$D" true squash FAKE_REVIEW_FAIL=1
check merge/approval-rejected-still-merges "$D" $? 0 merged true notice "not permitted to approve"

D=$(merge_dir no-approve); merge_run "$D" false squash
check merge/no-approve "$D" $? 0 merged true -
not_called merge/no-approve "$D" "pulls/7/reviews"

D=$(merge_dir rebase); merge_run "$D" true rebase
check merge/rebase "$D" $? 0 merged true -
called merge/rebase "$D" "pr merge 7 --repo o/r --rebase --match-head-commit abc"

D=$(merge_dir merge-rejected); merge_run "$D" true squash FAKE_MERGE_FAIL=1
check merge/merge-rejected "$D" $? 0 merged false warning "base branch policy prohibits the merge"
reason_is merge/merge-rejected "$D" merge-failed

# Re-read right before merging: whatever changed since the CI decision wins.
D=$(merge_dir closed); echo '{"state":"closed","head":{"sha":"abc"},"draft":false,"mergeable":null,"mergeable_state":"unknown"}' > "$D/pr.1.json"
merge_run "$D" true squash
check merge/closed-meanwhile "$D" $? 0 merged false notice
reason_is merge/closed-meanwhile "$D" closed
not_called merge/closed-meanwhile "$D" "pulls/7/reviews"
not_called merge/closed-meanwhile "$D" "pr merge"

D=$(merge_dir new-head); echo '{"state":"open","head":{"sha":"def"},"draft":false,"mergeable":true,"mergeable_state":"clean"}' > "$D/pr.1.json"
merge_run "$D" true squash
check merge/new-head-meanwhile "$D" $? 0 merged false notice "new head commit (def)"
reason_is merge/new-head-meanwhile "$D" superseded
not_called merge/new-head-meanwhile "$D" "pulls/7/reviews"
not_called merge/new-head-meanwhile "$D" "pr merge"

D=$(merge_dir draft); echo '{"state":"open","head":{"sha":"abc"},"draft":true,"mergeable":true,"mergeable_state":"draft"}' > "$D/pr.1.json"
merge_run "$D" true squash
check merge/draft "$D" $? 0 merged false notice
reason_is merge/draft "$D" draft
not_called merge/draft "$D" "pr merge"

D=$(merge_dir conflict); echo '{"state":"open","head":{"sha":"abc"},"draft":false,"mergeable":false,"mergeable_state":"dirty"}' > "$D/pr.1.json"
merge_run "$D" true squash
check merge/conflict "$D" $? 0 merged false notice "dirty"
reason_is merge/conflict "$D" not-mergeable
not_called merge/conflict "$D" "pulls/7/reviews"
not_called merge/conflict "$D" "pr merge"

# GitHub computes `mergeable` in the background (null until then).
D=$(merge_dir mergeability-computing)
echo '{"state":"open","head":{"sha":"abc"},"draft":false,"mergeable":null,"mergeable_state":"unknown"}' > "$D/pr.1.json"
echo "$PR_READY" > "$D/pr.3.json"
merge_run "$D" true squash
check merge/waits-for-mergeability "$D" $? 0 merged true -
if [ "$(grep -c 'pulls/7 ' "$D/calls")" -eq 3 ] && [ "$(cat "$D/clock")" -eq 10 ]; then pass "merge/waits-for-mergeability: 3 reads, 10 s"; else fail "merge/waits-for-mergeability: $(grep -c 'pulls/7 ' "$D/calls") reads, $(cat "$D/clock") s"; fi

D=$(merge_dir mergeability-unknown)
echo '{"state":"open","head":{"sha":"abc"},"draft":false,"mergeable":null,"mergeable_state":"unknown"}' > "$D/pr.1.json"
merge_run "$D" true squash
check merge/unknown-mergeability-merge-call-decides "$D" $? 0 merged true - "the merge call decides"
if [ "$(cat "$D/clock")" -eq 30 ]; then pass "merge/unknown-mergeability: gave up after 30 s"; else fail "merge/unknown-mergeability: $(cat "$D/clock") s"; fi

D=$(merge_dir pr-unreadable); raw "$D" pr.1.json HTTP500
merge_run "$D" true squash
check merge/pr-unreadable "$D" $? 0 merged false warning
not_called merge/pr-unreadable "$D" "pr merge"

echo ""
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
