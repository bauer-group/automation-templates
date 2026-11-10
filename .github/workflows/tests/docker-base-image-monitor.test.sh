#!/usr/bin/env bash
#
# Behavioural test for the check, release commit, dispatch and persist steps
# of ../modules-docker-base-image-monitor.yml.
#
# The monitor used to store a new digest as soon as it had dispatched the
# release. When that release failed - a red backup round-trip gate, for
# example - the next check read the new digest back, reported "No update" and
# the consumer silently stayed on the old base image. With a target workflow
# the digest now counts as handled only once the dispatched run succeeded:
#
#   digest unchanged                        -> nothing to do
#   new digest                              -> commit + dispatch, run recorded in <var>_PENDING
#   recorded run still running / unreadable -> wait, nothing dispatched
#   recorded run succeeded                  -> digest stored, record removed
#   recorded run failed or deleted          -> dispatched again
#     ... before it tagged the release      -> no new commit, the run releases the old one
#     ... after it tagged the release       -> new release commit, else nothing to release
#     ... for the max-release-attempts'th time -> not dispatched again, the job fails
#   no target workflow (commit mode)        -> digest stored after the push, as before
#
# A fixed 'tag' also drifted: Dependabot bumps the FROM line, never
# base-images.json, and the monitor kept watching the old tag (2026-11-10:
# eight repositories). An entry with 'dockerfile' is watched on the tag of its
# FROM line, resolved by the docker-base-image-resolve action:
#
#   no entry with 'dockerfile'              -> no resolved list, no Python, check as before
#   'dockerfile' set                        -> the FROM line's tag is checked, a stale 'tag' noted
#   tag not readable (another image, a      -> that entry is not checked and its state is left
#     renamed stage, no python3)               alone; every other image is checked, released
#                                              and stored, and the job fails in its last step
#   two entries, one variable, two tags     -> left out as well
#   exhausted retries and such an entry     -> both last steps fail the job, each naming its images
#   check never ran (e.g. missing secret)   -> the summary says so, never "up to date"
#   Dependabot bumps the FROM tag           -> one release for the new tag, then only it counts
#
# The step bodies are extracted from the workflow and the action at runtime
# rather than duplicated here and run the way a `shell: bash` step runs
# (-eo pipefail).
# `gh` and `docker` are replaced by stubs that keep repository variables and
# workflow runs in a directory; `gh api --jq` filters are applied with jq.
# Each scenario gets a real git repository with a local bare origin, so the
# release commit is really pushed and release tags are real tags.
#
# Usage: bash .github/workflows/tests/docker-base-image-monitor.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_FILE="$SCRIPT_DIR/../modules-docker-base-image-monitor.yml"
ACTION_DIR="$(cd "$SCRIPT_DIR/../../actions/docker-base-image-resolve" 2>/dev/null && pwd)"
ACTION_FILE="$ACTION_DIR/action.yml"

for FILE in "$WORKFLOW_FILE" "$ACTION_FILE"; do
  if [ ! -f "$FILE" ]; then
    echo "FATAL: $(basename "$FILE") not found at $FILE"
    exit 1
  fi
done
for TOOL in jq git python3; do
  if ! command -v "$TOOL" > /dev/null; then
    echo "FATAL: $TOOL is required"
    exit 1
  fi
done

# Prints the run block of the step with the given id, de-indented.
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

for STEP in check release dispatch persist summary fail-exhausted fail-unresolved; do
  extract_step "$STEP" > "$WORK/$STEP.sh"
  if [ ! -s "$WORK/$STEP.sh" ]; then
    echo "FATAL: could not extract the '$STEP' run block from the workflow."
    echo "       The step was renamed, removed, or re-indented - update this test."
    exit 1
  fi
done

# The resolve step of the action: a composite step, indented two less.
awk '
  $0 == "      id: resolve" { found = 1; next }
  found && /^      run: \|$/ { collecting = 1; next }
  collecting {
    if ($0 == "") { print ""; next }
    if ($0 ~ /^        /) { sub(/^        /, ""); print; next }
    exit
  }
' "$ACTION_FILE" > "$WORK/resolve.sh"
if [ ! -s "$WORK/resolve.sh" ]; then
  echo "FATAL: could not extract the 'resolve' run block from $ACTION_FILE - update this test."
  exit 1
fi

PASSED=0
FAILED=0
pass() { echo "PASS $1"; PASSED=$((PASSED + 1)); }
fail() { echo "FAIL $1: $2"; FAILED=$((FAILED + 1)); }

# --- the steps must be wired the way the tests below assume -------------------
static_check() {
  local name="$1" pattern="$2"
  if grep -qF -- "$pattern" "$WORKFLOW_FILE"; then
    pass "$name"
  else
    fail "$name" "'$pattern' not found"
  fi
}
static_check "the release commit follows the check's decision" \
  "if: steps.check.outputs.commit-needed == 'true' && inputs.commit-and-release == true && inputs.dry-run != true"
static_check "the commit names the images the check chose" "UPDATED_IMAGES_JSON: \${{ steps.check.outputs.commit-images }}"
static_check "state is persisted only after every earlier step succeeded" \
  "if: success() && steps.check.outputs.state-changed == 'true' && inputs.dry-run != true"
static_check "persist reads the dispatched run id" "RUN_ID: \${{ steps.dispatch.outputs.run-id }}"
static_check "persist reads the attempt numbers" "DISPATCH_ATTEMPTS: \${{ steps.check.outputs.dispatch-attempts }}"
static_check "exhausted retries fail the job" \
  "if: steps.check.outputs.exhausted-images != '' && steps.check.outputs.exhausted-images != '[]'"
static_check "job has a timeout" "    timeout-minutes: "
static_check "the resolve step is the template's action" \
  "uses: bauer-group/automation-templates/.github/actions/docker-base-image-resolve@main"
static_check "the resolve step reads the same config file" "          config-file: \${{ inputs.config-file }}"
static_check "the resolve step reads the same inline images" "          images: \${{ inputs.images }}"
static_check "the check reads the tags resolved from Dockerfiles" "RESOLVED_IMAGES: \${{ steps.resolve.outputs.images }}"
static_check "the check reads the entries whose tag was not read" "UNRESOLVED_IMAGES: \${{ steps.resolve.outputs.unresolved }}"
static_check "the summary lists them" "UNRESOLVED_JSON: \${{ steps.resolve.outputs.unresolved }}"
static_check "the job reports them, also when the check did not run" \
  "unresolved-images: \${{ steps.resolve.outputs.unresolved-names || '[]' }}"
static_check "an entry whose tag was not read fails the job, also after a failed step" \
  "if: \${{ !cancelled() && steps.resolve.outputs.unresolved != '' && steps.resolve.outputs.unresolved != '[]' }}"
if awk '$0 == "        id: resolve" { r = NR } $0 == "        id: check" { c = NR } END { exit !(r && c && r < c) }' "$WORKFLOW_FILE"; then
  pass "the tags are resolved before the check"
else
  fail "the tags are resolved before the check" "the resolve step is missing or comes after the check"
fi
# Failing any earlier would hold back the releases and stored digests of
# every other image, as failing the resolve step itself did.
if awk '$0 == "        id: persist" { p = NR } $0 == "        id: summary" { s = NR } $0 == "        id: fail-unresolved" { f = NR }
        END { exit !(p && s && f && p < f && s < f) }' "$WORKFLOW_FILE"; then
  pass "an entry whose tag was not read fails the job only after persist and summary"
else
  fail "an entry whose tag was not read fails the job only after persist and summary" "the fail-unresolved step is missing or too early"
fi

# --- stubs --------------------------------------------------------------------
# State lives in $FAKE: vars/<NAME> (repository variables), runs/<ID> (run JSON),
# runs/<ID>.error (stderr of a failing read), manifests/<ref with / and : as _>,
# dispatch-response, workflows.json, fail-set/<NAME>. Every call is logged.
mkdir -p "$WORK/bin"
cat > "$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
echo "gh $*" >> "$FAKE/calls.log"
case "$1 $2" in
  "variable get")
    [ -f "$FAKE/vars/$3" ] || { echo "variable $3 was not found" >&2; exit 1; }
    cat "$FAKE/vars/$3"; exit 0 ;;
  "variable set")
    [ "$4" = "--body" ] || { echo "unexpected: $*" >&2; exit 2; }
    [ ! -f "$FAKE/fail-set/$3" ] || { echo "HTTP 500" >&2; exit 1; }
    printf '%s' "$5" > "$FAKE/vars/$3"; exit 0 ;;
  "variable delete")
    [ -f "$FAKE/vars/$3" ] || { echo "HTTP 404: Not Found" >&2; exit 1; }
    rm -f "$FAKE/vars/$3"; exit 0 ;;
esac
[ "$1" = "api" ] || { echo "unexpected gh call: $*" >&2; exit 2; }
shift
method=GET; path=""; filter=""; input=""
while [ $# -gt 0 ]; do
  case "$1" in
    --method) method="$2"; shift 2 ;;
    --jq) filter="$2"; shift 2 ;;
    --input) input="$2"; shift 2 ;;
    --paginate) shift ;;
    *) path="$1"; shift ;;
  esac
done
case "$method $path" in
  "POST repos/"*"/dispatches")
    [ "$input" = "-" ] && cat > "$FAKE/dispatch-body.json"
    echo "$path" > "$FAKE/dispatch-path"
    [ -f "$FAKE/dispatch-response" ] && cat "$FAKE/dispatch-response"
    exit 0 ;;
  "GET repos/"*"/actions/workflows")
    cat "$FAKE/workflows.json"; exit 0 ;;
  "GET repos/"*"/actions/runs/"*)
    id="${path##*/}"
    if [ -f "$FAKE/runs/$id.error" ]; then cat "$FAKE/runs/$id.error" >&2; exit 1; fi
    [ -f "$FAKE/runs/$id" ] || { echo "gh: Not Found (HTTP 404)" >&2; exit 1; }
    if [ -n "$filter" ]; then jq -r "$filter" "$FAKE/runs/$id"; else cat "$FAKE/runs/$id"; fi
    exit 0 ;;
esac
echo "unexpected gh api call: $method $path" >&2
exit 2
STUB
cat > "$WORK/bin/docker" <<'STUB'
#!/usr/bin/env bash
[ "$1 $2" = "manifest inspect" ] || { echo "unexpected docker call: $*" >&2; exit 2; }
f="$FAKE/manifests/$(printf '%s' "$3" | tr '/:' '__')"
[ -f "$f" ] || { echo "manifest unknown" ; exit 1; }
cat "$f"
STUB
# Git must not pick up the identity, signing or hooks of the machine.
printf '[user]\n\tname = test\n\temail = test@example.invalid\n[init]\n\tdefaultBranch = main\n[commit]\n\tgpgsign = false\n[tag]\n\tgpgsign = false\n' > "$WORK/gitconfig"
export GIT_CONFIG_GLOBAL="$WORK/gitconfig" GIT_CONFIG_NOSYSTEM=1
# The persist step backs off between attempts; the test does not wait.
printf '#!/usr/bin/env bash\nexit 0\n' > "$WORK/bin/sleep"
chmod +x "$WORK/bin/gh" "$WORK/bin/docker" "$WORK/bin/sleep"
# Put first on PATH, this python3 records that it was called and fails.
# $* and $FAKE are the stub's, expanded when it runs.
mkdir -p "$WORK/nopy"
# shellcheck disable=SC2016
printf '#!/usr/bin/env bash\necho "python3 $*" >> "$FAKE/python-calls"\nexit 1\n' > "$WORK/nopy/python3"
chmod +x "$WORK/nopy/python3"
# As the only PATH entry: a runner without python3 at all.
mkdir -p "$WORK/nopython"
for TOOL in bash jq; do ln -s "$(command -v "$TOOL")" "$WORK/nopython/$TOOL"; done

REPO="acme/app"
SERVER="https://github.com"
D_OLD="sha256:1111111111111111111111111111111111111111111111111111111111111111"
D_NEW="sha256:2222222222222222222222222222222222222222222222222222222222222222"
D_NEWER="sha256:3333333333333333333333333333333333333333333333333333333333333333"
IMAGES='[{"name": "app", "image": "ghcr.io/acme/base", "tag": "stable", "variable": "APP_DIGEST"}]'
TWO_IMAGES='[{"name": "app", "image": "ghcr.io/acme/base", "tag": "stable", "variable": "APP_DIGEST"},
             {"name": "engine", "image": "ghcr.io/acme/engine", "tag": "latest", "variable": "ENGINE_DIGEST"}]'

# Fresh fake repository for a scenario: a checkout ($FAKE/repo) with one
# commit, pushed to a bare origin, no tags.
reset() {
  FAKE="$WORK/fake-$1"
  rm -rf "$FAKE"
  mkdir -p "$FAKE/vars" "$FAKE/runs" "$FAKE/manifests" "$FAKE/fail-set"
  : > "$FAKE/calls.log"
  git init -q --bare "$FAKE/origin.git"
  git init -q "$FAKE/repo"
  git -C "$FAKE/repo" remote add origin "$FAKE/origin.git"
  commit "feat: initial"
  git -C "$FAKE/repo" push -q origin HEAD
  export FAKE
}
commit() { git -C "$FAKE/repo" commit -q --allow-empty -m "$1"; }
# What semantic-release leaves behind: a release commit with its tag.
release_tagged() { commit "chore(release): $1"; git -C "$FAKE/repo" tag "v$1"; }
# The base image commit of an earlier check.
base_commit() { commit "chore(deps): update base image $1 [skip ci]"; }
origin_subject() { git -C "$FAKE/origin.git" log -1 --format=%s; }
origin_count() { git -C "$FAKE/origin.git" rev-list --count HEAD; }
# UPDATE_DETAILS as the check wrote it to GITHUB_ENV.
details() { awk 'NR == 1 { d = substr($0, index($0, "<<") + 2); next } $0 == d { exit } { print }' "$1"; }
set_var() { printf '%s' "$2" > "$FAKE/vars/$1"; }
var() { cat "$FAKE/vars/$1" 2>/dev/null; }
has_var() { [ -f "$FAKE/vars/$1" ]; }
manifest() { printf '{"schemaVersion": 2, "config": {"digest": "%s"}}' "$2" > "$FAKE/manifests/$(printf '%s' "$1" | tr '/:' '__')"; }
run_fixture() { printf '{"id": %s, "status": "%s", "conclusion": %s, "html_url": "%s/%s/actions/runs/%s"}' \
  "$1" "$2" "$3" "$SERVER" "$REPO" "$1" > "$FAKE/runs/$1"; }
# pending VARIABLE DIGEST RUN_ID [ATTEMPT] - without ATTEMPT the record has none.
pending() { jq -nc --arg d "$2" --argjson r "$3" --arg a "${4:-}" \
  '{digest: $d, run_id: $r, run_url: "x"} + (if $a == "" then {} else {attempt: ($a | tonumber)} end)' > "$FAKE/vars/$1_PENDING"; }
out() { grep "^$1=" "$FAKE/output" | tail -n 1 | cut -d= -f2-; }

# Runs a step with the environment of the workflow. Extra VAR=value pairs
# before the step name override the defaults.
run_step() {
  local step="$1"; shift
  : > "$FAKE/output"; : > "$FAKE/env"
  (cd "$FAKE/repo" && env PATH="$WORK/bin:$PATH" GH_TOKEN=dummy \
    GITHUB_OUTPUT="$FAKE/output" GITHUB_ENV="$FAKE/env" \
    GITHUB_REPOSITORY="$REPO" GITHUB_SERVER_URL="$SERVER" \
    CONFIG_FILE="" INLINE_IMAGES="$IMAGES" RESOLVED_IMAGES="" UNRESOLVED_IMAGES="" COMMIT_PREFIX_INPUT="chore(deps)" \
    DRY_RUN=false FAIL_ON_UNREACHABLE=true TARGET_WORKFLOW="docker-release.yml" MAX_ATTEMPTS=3 \
    TARGET_REF=main TARGET_INPUTS='{"force-release": "true"}' \
    COMMIT_PREFIX="chore(deps)" UPDATED_IMAGES_JSON='[]' UPDATE_DETAILS="" \
    VARIABLE_UPDATES='{}' DISPATCH_UPDATES='{}' DISPATCH_ATTEMPTS='{}' PENDING_DELETES='[]' RUN_ID="" RUN_URL="" \
    "$@" bash -eo pipefail "$WORK/$step.sh") > "$FAKE/log" 2>&1
}

# Runs the action's resolve step in the checkout, as the job runs it before
# the check. Extra VAR=value pairs override the defaults.
run_resolve() {
  : > "$FAKE/output"; mkdir -p "$FAKE/tmp"
  (cd "$FAKE/repo" && env PATH="$WORK/bin:$PATH" GITHUB_OUTPUT="$FAKE/output" RUNNER_TEMP="$FAKE/tmp" \
    GITHUB_ACTION_PATH="$ACTION_DIR" CONFIG_FILE="" INLINE_IMAGES="$IMAGES" \
    "$@" bash -eo pipefail "$WORK/resolve.sh") > "$FAKE/log" 2>&1
}
# Whether GitHub runs a step, from its `if:` - for the expressions the last
# steps use: !cancelled(), always(), success(), failure() and
# steps.<id>.outputs.<name> compared with a string, joined by &&. Without a
# status function GitHub adds success(): the step is skipped once an earlier
# step failed. Usage:
#   step_runs <step id> <true after a failed step> [steps.<id>.outputs.<name>=<value>]...
step_runs() {
  local id="$1" failed="$2" cond rest term status=success name op want got pair
  local compare="^(steps\.[a-z0-9_-]+\.outputs\.[a-z0-9_-]+) (==|!=) '([^']*)'$"
  shift 2
  cond=$(awk -v id="        id: $id" '$0 == id { found = 1; next }
    found && /^        if: / { sub(/^        if: /, ""); print; exit } found && /^      - / { exit }' "$WORKFLOW_FILE")
  if [ -z "$cond" ]; then echo "FATAL: no 'if:' after 'id: $id' in the workflow - update this test"; exit 1; fi
  cond="${cond#"\${{ "}"; rest="${cond%" }}"}"
  while [ -n "$rest" ]; do
    term="${rest%% && *}"
    if [ "$term" = "$rest" ]; then rest=""; else rest="${rest#* && }"; fi
    if [ "$term" = "!cancelled()" ] || [ "$term" = "always()" ]; then
      status=always
    elif [ "$term" = "success()" ] || [ "$term" = "failure()" ]; then
      status="${term%()}"
    elif [[ $term =~ $compare ]]; then
      name="${BASH_REMATCH[1]}"; op="${BASH_REMATCH[2]}"; want="${BASH_REMATCH[3]}"; got=""
      for pair in "$@"; do if [ "${pair%%=*}" = "$name" ]; then got="${pair#*=}"; fi; done
      if [ "$op" = "==" ]; then [ "$got" = "$want" ] || return 1; else [ "$got" != "$want" ] || return 1; fi
    else
      echo "FATAL: step_runs cannot evaluate '$term' of step $id - update this test"; exit 1
    fi
  done
  case "$status" in
    always) return 0 ;;
    failure) [ "$failed" = true ] ;;
    *) [ "$failed" = false ] ;;
  esac
}

# put <path> <content>: a file in the checkout.
put() { mkdir -p "$(dirname "$FAKE/repo/$1")"; printf '%s' "$2" > "$FAKE/repo/$1"; }
CFG=".github/config/docker-base-image-monitor/base-images.json"
config() { put "$CFG" "{\"images\": [$1], \"settings\": {\"commit-prefix\": \"chore(deps)\"}}"; }

expect_eq() {
  local name="$1" got="$2" want="$3"
  if [ "$got" = "$want" ]; then pass "$name"; else fail "$name" "got '$got', want '$want'"; fi
}
expect_rc() {
  local name="$1" got="$2" want="$3"
  if [ "$got" -eq "$want" ]; then pass "$name"; else fail "$name" "exit $got, want $want - log: $(tr '\n' ' ' < "$FAKE/log" | cut -c1-400)"; fi
}

# === check ====================================================================

reset unchanged
manifest ghcr.io/acme/base:stable "$D_OLD"; set_var APP_DIGEST "$D_OLD"
run_step check; expect_rc "unchanged: step succeeds" $? 0
expect_eq "unchanged: no update" "$(out updates-found)" false
expect_eq "unchanged: nothing to store" "$(out state-changed)" false
if grep -q "APP_DIGEST_PENDING" "$FAKE/calls.log"; then
  fail "unchanged: no pending lookup" "read APP_DIGEST_PENDING although the digest did not change"
else
  pass "unchanged: no pending lookup"
fi

reset new
manifest ghcr.io/acme/base:stable "$D_NEW"; set_var APP_DIGEST "$D_OLD"
run_step check; expect_rc "new: step succeeds" $? 0
expect_eq "new: update found" "$(out updates-found)" true
expect_eq "new: release commit needed" "$(out commit-needed)" true
expect_eq "new: new-images" "$(out new-images)" '["app"]'
expect_eq "new: committed images" "$(out commit-images)" '["app"]'
expect_eq "new: dispatched, not stored" "$(out dispatch-updates)" "{\"APP_DIGEST\":\"$D_NEW\"}"
expect_eq "new: digest not stored yet" "$(out variable-updates)" '{}'
expect_eq "new: first attempt" "$(out dispatch-attempts)" '{"APP_DIGEST":1}'
expect_eq "new: no retry" "$(out retried-images)" '[]'
if grep -q "New: $D_NEW" "$FAKE/env"; then pass "new: commit details"; else fail "new: commit details" "UPDATE_DETAILS lacks the new digest"; fi
expect_eq "new: details start with the heading" "$(details "$FAKE/env" | head -n 1)" "Base image digest changed:"
if grep -q "Release retried" "$FAKE/env"; then fail "new: no retry section" "present"; else pass "new: no retry section"; fi

reset commit-mode
manifest ghcr.io/acme/base:stable "$D_NEW"; set_var APP_DIGEST "$D_OLD"
run_step check TARGET_WORKFLOW=""; expect_rc "commit mode: step succeeds" $? 0
expect_eq "commit mode: digest stored after push" "$(out variable-updates)" "{\"APP_DIGEST\":\"$D_NEW\"}"
expect_eq "commit mode: nothing dispatched" "$(out dispatch-updates)" '{}'
if grep -q "_PENDING" "$FAKE/calls.log"; then fail "commit mode: no pending lookup" "read a _PENDING variable"; else pass "commit mode: no pending lookup"; fi

reset running
manifest ghcr.io/acme/base:stable "$D_NEW"; set_var APP_DIGEST "$D_OLD"
pending APP_DIGEST "$D_NEW" 101; run_fixture 101 in_progress null
run_step check; expect_rc "running: step succeeds" $? 0
expect_eq "running: no update" "$(out updates-found)" false
expect_eq "running: pending" "$(out pending-images)" '["app"]'
expect_eq "running: nothing to store" "$(out state-changed)" false

reset confirmed
manifest ghcr.io/acme/base:stable "$D_NEW"; set_var APP_DIGEST "$D_OLD"
pending APP_DIGEST "$D_NEW" 102; run_fixture 102 completed '"success"'
run_step check; expect_rc "confirmed: step succeeds" $? 0
expect_eq "confirmed: no update" "$(out updates-found)" false
expect_eq "confirmed: digest stored" "$(out variable-updates)" "{\"APP_DIGEST\":\"$D_NEW\"}"
expect_eq "confirmed: record removed" "$(out pending-deletes)" '["APP_DIGEST"]'
expect_eq "confirmed: state changed" "$(out state-changed)" true
expect_eq "confirmed: listed" "$(out confirmed | jq -r '.[0].url')" "$SERVER/$REPO/actions/runs/102"

# The run failed before it tagged (e.g. a red release gate): the base image
# commit of the first check is still unreleased and is released by the retry.
reset failed
manifest ghcr.io/acme/base:stable "$D_NEW"; set_var APP_DIGEST "$D_OLD"
release_tagged 1.0.0; base_commit app
pending APP_DIGEST "$D_NEW" 103; run_fixture 103 completed '"failure"'
run_step check; expect_rc "failed: step succeeds" $? 0
expect_eq "failed: release needed" "$(out updates-found)" true
expect_eq "failed before the tag: no new commit" "$(out commit-needed)" false
expect_eq "failed before the tag: retry-commit" "$(out retry-commit)" false
expect_eq "failed: a record without attempt counts as the first" "$(out dispatch-attempts)" '{"APP_DIGEST":2}'
expect_eq "failed: failed attempt reported" "$(out retried | jq -r '.[0].attempt')" 1
expect_eq "failed: retried" "$(out retried-images)" '["app"]'
expect_eq "failed: conclusion reported" "$(out retried | jq -r '.[0].conclusion')" failure
expect_eq "failed: dispatched again" "$(out dispatch-updates)" "{\"APP_DIGEST\":\"$D_NEW\"}"
expect_eq "failed: digest still not stored" "$(out variable-updates)" '{}'
if grep -q "::warning::The release dispatched for app" "$FAKE/log"; then pass "failed: warning annotation"; else fail "failed: warning annotation" "missing"; fi

# The run tagged its release and then failed (a build, scan or push job): a
# bare dispatch would find nothing to release, skip every build and end
# "success". The retry needs a release commit of its own.
reset failed-after-tag
manifest ghcr.io/acme/base:stable "$D_NEW"; set_var APP_DIGEST "$D_OLD"
release_tagged 1.0.0; base_commit app; release_tagged 1.0.1
pending APP_DIGEST "$D_NEW" 110; run_fixture 110 completed '"failure"'
run_step check; expect_rc "failed after the tag: step succeeds" $? 0
expect_eq "failed after the tag: dispatched again" "$(out dispatch-updates)" "{\"APP_DIGEST\":\"$D_NEW\"}"
expect_eq "failed after the tag: new commit" "$(out commit-needed)" true
expect_eq "failed after the tag: committed images" "$(out commit-images)" '["app"]'
expect_eq "failed after the tag: retry-commit" "$(out retry-commit)" true
expect_eq "failed after the tag: details heading" "$(details "$FAKE/env" | head -n 1)" \
  "Release retried - the previous run failed after its release was tagged:"
if details "$FAKE/env" | grep -qF "Failed run: $SERVER/$REPO/actions/runs/110 (failure)"; then
  pass "failed after the tag: failed run in the details"
else
  fail "failed after the tag: failed run in the details" "$(details "$FAKE/env" | tr '\n' '|')"
fi
if details "$FAKE/env" | grep -q "Base image digest changed"; then fail "failed after the tag: no digest-change section" "present"; else pass "failed after the tag: no digest-change section"; fi

# Write-back consumers push "chore: update Dockerfile version" after the
# tag. That is not a base image commit, so the retry still gets its own.
reset failed-after-write-back
manifest ghcr.io/acme/base:stable "$D_NEW"; set_var APP_DIGEST "$D_OLD"
base_commit app; release_tagged 1.0.1; commit "chore: update Dockerfile version to 1.0.1"
pending APP_DIGEST "$D_NEW" 111; run_fixture 111 completed '"failure"'
run_step check
expect_eq "failed after a write-back commit: new commit" "$(out commit-needed)" true

# No tag at all: the whole history counts as unreleased.
reset failed-untagged
manifest ghcr.io/acme/base:stable "$D_NEW"; set_var APP_DIGEST "$D_OLD"
base_commit app
pending APP_DIGEST "$D_NEW" 112; run_fixture 112 completed '"failure"'
run_step check
expect_eq "failed without any tag: no new commit" "$(out commit-needed)" false

# Attempt 2 of 3 failed: one more.
reset attempt-2
manifest ghcr.io/acme/base:stable "$D_NEW"; set_var APP_DIGEST "$D_OLD"
pending APP_DIGEST "$D_NEW" 120 2; run_fixture 120 completed '"failure"'
run_step check
expect_eq "attempt 2 failed: dispatched as attempt 3" "$(out dispatch-attempts)" '{"APP_DIGEST":3}'
if grep -q "attempt 3 of 3" "$FAKE/log"; then pass "attempt 2 failed: warning names the attempt"; else fail "attempt 2 failed: warning names the attempt" "missing"; fi

# Attempt 3 of 3 failed: give up, loudly.
reset exhausted
manifest ghcr.io/acme/base:stable "$D_NEW"; set_var APP_DIGEST "$D_OLD"
release_tagged 1.0.0; base_commit app; release_tagged 1.0.1
pending APP_DIGEST "$D_NEW" 121 3; run_fixture 121 completed '"failure"'
run_step check; expect_rc "exhausted: the check itself succeeds" $? 0
expect_eq "exhausted: reported" "$(out exhausted-images)" '["app"]'
expect_eq "exhausted: attempt reported" "$(out exhausted | jq -r '.[0].attempt')" 3
expect_eq "exhausted: not dispatched" "$(out dispatch-updates)" '{}'
expect_eq "exhausted: no release needed" "$(out updates-found)" false
expect_eq "exhausted: no commit" "$(out commit-needed)" false
expect_eq "exhausted: nothing stored" "$(out state-changed)" false
if grep -q "::error::The release for app" "$FAKE/log"; then pass "exhausted: error annotation"; else fail "exhausted: error annotation" "missing"; fi

reset unlimited
manifest ghcr.io/acme/base:stable "$D_NEW"; set_var APP_DIGEST "$D_OLD"
pending APP_DIGEST "$D_NEW" 122 50; run_fixture 122 completed '"failure"'
run_step check MAX_ATTEMPTS=0
expect_eq "no limit: dispatched again" "$(out dispatch-attempts)" '{"APP_DIGEST":51}'
expect_eq "no limit: not exhausted" "$(out exhausted-images)" '[]'

reset bad-max
manifest ghcr.io/acme/base:stable "$D_NEW"; set_var APP_DIGEST "$D_OLD"
run_step check MAX_ATTEMPTS=-1; expect_rc "max-release-attempts not a whole number: fails" $? 1

reset cancelled
manifest ghcr.io/acme/base:stable "$D_NEW"; set_var APP_DIGEST "$D_OLD"
pending APP_DIGEST "$D_NEW" 104; run_fixture 104 completed '"cancelled"'
run_step check
expect_eq "cancelled: counts as failed" "$(out retried-images)" '["app"]'

reset deleted
manifest ghcr.io/acme/base:stable "$D_NEW"; set_var APP_DIGEST "$D_OLD"
pending APP_DIGEST "$D_NEW" 105
run_step check
expect_eq "deleted run: dispatched again" "$(out retried | jq -r '.[0].conclusion')" deleted

reset unreadable
manifest ghcr.io/acme/base:stable "$D_NEW"; set_var APP_DIGEST "$D_OLD"
pending APP_DIGEST "$D_NEW" 106; echo "gh: Server Error (HTTP 502)" > "$FAKE/runs/106.error"
run_step check; expect_rc "unreadable run: step succeeds" $? 0
expect_eq "unreadable run: not dispatched again" "$(out updates-found)" false
expect_eq "unreadable run: reported as pending" "$(out pending | jq -r '.[0].state')" unknown

reset older-record
manifest ghcr.io/acme/base:stable "$D_NEWER"; set_var APP_DIGEST "$D_OLD"
pending APP_DIGEST "$D_NEW" 107; run_fixture 107 in_progress null
run_step check
expect_eq "record for an older digest: a newer digest is a new update" "$(out new-images)" '["app"]'
expect_eq "record for an older digest: attempts start over" "$(out dispatch-attempts)" '{"APP_DIGEST":1}'
if grep -q "actions/runs/107" "$FAKE/calls.log"; then fail "older record: run not read" "read run 107"; else pass "older record: run not read"; fi

reset garbage-record
manifest ghcr.io/acme/base:stable "$D_NEW"; set_var APP_DIGEST "$D_OLD"
set_var APP_DIGEST_PENDING "not json"
run_step check; expect_rc "garbage record: step succeeds" $? 0
expect_eq "garbage record: treated as no record" "$(out new-images)" '["app"]'

reset injected-run-id
manifest ghcr.io/acme/base:stable "$D_NEW"; set_var APP_DIGEST "$D_OLD"
set_var APP_DIGEST_PENDING "{\"digest\": \"$D_NEW\", \"run_id\": \"1/../../x\"}"
run_step check
expect_eq "non-numeric run id: ignored" "$(out new-images)" '["app"]'
if grep -q '\.\./' "$FAKE/calls.log"; then fail "non-numeric run id: not used in a path" "used"; else pass "non-numeric run id: not used in a path"; fi

reset mixed
manifest ghcr.io/acme/base:stable "$D_NEW"; set_var APP_DIGEST "$D_OLD"
manifest ghcr.io/acme/engine:latest "$D_NEWER"; set_var ENGINE_DIGEST "$D_OLD"
release_tagged 1.0.0; base_commit app
pending APP_DIGEST "$D_NEW" 108; run_fixture 108 completed '"failure"'
run_step check INLINE_IMAGES="$TWO_IMAGES"
expect_eq "mixed: both need a release" "$(out updated-images)" '["app","engine"]'
expect_eq "mixed, retry unreleased: only the new one is committed" "$(out commit-images)" '["engine"]'
if grep -q "app (ghcr.io/acme/base:stable)" "$FAKE/env"; then
  fail "mixed, retry unreleased: commit details" "the retried image is in the commit message"
else
  pass "mixed, retry unreleased: commit details"
fi

reset mixed-released
manifest ghcr.io/acme/base:stable "$D_NEW"; set_var APP_DIGEST "$D_OLD"
manifest ghcr.io/acme/engine:latest "$D_NEWER"; set_var ENGINE_DIGEST "$D_OLD"
base_commit app; release_tagged 1.0.1
pending APP_DIGEST "$D_NEW" 113; run_fixture 113 completed '"failure"'
run_step check INLINE_IMAGES="$TWO_IMAGES"
expect_eq "mixed, retry released: both committed" "$(out commit-images)" '["engine","app"]'
expect_eq "mixed, retry released: both sections" \
  "$(details "$FAKE/env" | grep -cE '^(Base image digest changed|Release retried)')" 2

reset unreachable
set_var APP_DIGEST "$D_OLD"
run_step check; expect_rc "unreachable: fails the job" $? 1
expect_eq "unreachable: reported" "$(out unreachable-images)" '["ghcr.io/acme/base:stable"]'

reset dry-run
manifest ghcr.io/acme/base:stable "$D_NEW"; set_var APP_DIGEST "$D_OLD"
pending APP_DIGEST "$D_NEW" 109; run_fixture 109 completed '"failure"'
run_step check DRY_RUN=true; expect_rc "dry run: step succeeds" $? 0
expect_eq "dry run: retry reported" "$(out retried-images)" '["app"]'
if grep -qE "^gh variable (set|delete)" "$FAKE/calls.log"; then fail "dry run: writes nothing" "wrote a variable"; else pass "dry run: writes nothing"; fi

# === tag from the Dockerfile ==================================================

reset resolve-none
run_resolve PATH="$WORK/nopy:$WORK/bin:$PATH"; expect_rc "no dockerfile: the resolve step succeeds" $? 0
expect_eq "no dockerfile: no resolved list, the check keeps its own" "$(out images)" ""
expect_eq "no dockerfile: nothing unresolved" "$(out unresolved)$(out unresolved-names)" ""
if [ -f "$FAKE/python-calls" ]; then fail "no dockerfile: python is not needed" "$(cat "$FAKE/python-calls")"; else pass "no dockerfile: python is not needed"; fi

reset resolve-none-config
config '{"name": "app", "image": "ghcr.io/acme/base", "tag": "stable", "variable": "APP_DIGEST"}'
run_resolve PATH="$WORK/nopy:$WORK/bin:$PATH" CONFIG_FILE="$CFG"; expect_rc "no dockerfile, config file: the resolve step succeeds" $? 0
expect_eq "no dockerfile, config file: no resolved list" "$(out images)" ""

# A config that cannot be loaded is left to the check, which reports it as before.
reset resolve-missing-config
run_resolve CONFIG_FILE="missing.json"; expect_rc "missing config file: the resolve step leaves it to the check" $? 0
RESOLVED=$(out images)
run_step check CONFIG_FILE="missing.json" RESOLVED_IMAGES="$RESOLVED"; expect_rc "missing config file: the check fails as before" $? 1
if grep -qF "::error::Config file not found: missing.json" "$FAKE/log"; then pass "missing config file: same error as before"; else fail "missing config file: same error as before" "$(tr '\n' ' ' < "$FAKE/log" | cut -c1-300)"; fi

# The drift of 2026-11-10: the Dockerfile moved to 3.15-alpine, the config
# still says 3.14-alpine, and only 3.15-alpine has a new digest.
reset resolve-drift
put src/app/Dockerfile $'ARG PYTHON_VERSION=3.15\nFROM python:${PYTHON_VERSION}-alpine AS prod\n'
config '{"name": "python", "image": "python", "tag": "3.14-alpine", "dockerfile": "src/app/Dockerfile", "variable": "PYTHON_DIGEST"}'
manifest python:3.14-alpine "$D_OLD"; manifest python:3.15-alpine "$D_NEW"; set_var PYTHON_DIGEST "$D_OLD"
run_step check CONFIG_FILE="$CFG"
expect_eq "drift, configured tag only: the move of the real tag is missed" "$(out updates-found)" false
run_resolve CONFIG_FILE="$CFG"; expect_rc "drift: the resolve step succeeds" $? 0
RESOLVED=$(out images)
expect_eq "drift: tag of the FROM line" "$(printf '%s' "$RESOLVED" | jq -r '.[0].tag')" "3.15-alpine"
expect_eq "drift: the rest of the entry is kept" "$(printf '%s' "$RESOLVED" | jq -c '.[0] | del(.tag)')" \
  '{"name":"python","image":"python","dockerfile":"src/app/Dockerfile","variable":"PYTHON_DIGEST"}'
if grep -qF "::notice file=src/app/Dockerfile,line=2::python: the configured tag '3.14-alpine' is stale" "$FAKE/log"; then
  pass "drift: the stale tag is reported"
else
  fail "drift: the stale tag is reported" "$(tr '\n' ' ' < "$FAKE/log" | cut -c1-300)"
fi
run_step check CONFIG_FILE="$CFG" RESOLVED_IMAGES="$RESOLVED"; expect_rc "drift, resolved: the check succeeds" $? 0
expect_eq "drift, resolved: the real tag's new digest is an update" "$(out new-images)" '["python"]'
if details "$FAKE/env" | grep -qF -- "- python (python:3.15-alpine)"; then pass "drift, resolved: the commit names the real tag"; else fail "drift, resolved: the commit names the real tag" "$(details "$FAKE/env" | tr '\n' '|')"; fi
if grep -qF "python: python:3.15-alpine (FROM in src/app/Dockerfile)" "$FAKE/log"; then pass "drift, resolved: the log names the Dockerfile"; else fail "drift, resolved: the log names the Dockerfile" "missing"; fi

# The step does not fail for an entry: the job fails in its last step, after
# the other images were checked (see "one entry not resolved" below).
reset resolve-mismatch
put Dockerfile $'FROM golang:1.26-alpine\n'
run_resolve INLINE_IMAGES='[{"name": "python", "image": "python", "dockerfile": "Dockerfile", "variable": "PYTHON_DIGEST"}]'
expect_rc "FROM line of another image: the resolve step succeeds" $? 0
if grep -qF "::error file=Dockerfile::python: no FROM line in Dockerfile uses 'python'" "$FAKE/log"; then pass "FROM line of another image: error annotation"; else fail "FROM line of another image: error annotation" "$(tr '\n' ' ' < "$FAKE/log" | cut -c1-300)"; fi
expect_eq "FROM line of another image: not in the list for the check" "$(out images)" "[]"
expect_eq "FROM line of another image: listed as unresolved" "$(out unresolved | jq -c 'map([.name, .dockerfile])')" '[["python","Dockerfile"]]'
expect_eq "FROM line of another image: named for the job output" "$(out unresolved-names)" '["python"]'

# Without python3, or when the resolver itself fails, every entry with
# 'dockerfile' is unresolved - never checked on its configured tag - and the
# entries without one are still checked.
MIXED='[{"name": "app", "image": "ghcr.io/acme/base", "tag": "stable", "variable": "APP_DIGEST"},
        {"name": "python", "image": "python", "tag": "3.14-alpine", "dockerfile": "Dockerfile", "variable": "PYTHON_DIGEST"}]'
reset resolve-no-python
put Dockerfile $'FROM python:3.15-alpine\n'
run_resolve PATH="$WORK/nopython" INLINE_IMAGES="$MIXED"; expect_rc "no python3: the resolve step succeeds" $? 0
if grep -qF "::error::The entries with 'dockerfile' are not checked in this run: python3 is not installed on the runner" "$FAKE/log"; then
  pass "no python3: error annotation"
else
  fail "no python3: error annotation" "$(tr '\n' ' ' < "$FAKE/log" | cut -c1-300)"
fi
expect_eq "no python3: the entry without dockerfile is checked" "$(out images | jq -c 'map(.name)')" '["app"]'
expect_eq "no python3: the entry with dockerfile is unresolved, not checked on its configured tag" \
  "$(out unresolved | jq -c 'map(.name)') $(out unresolved-names)" '["python"] ["python"]'
reset resolve-crash
put Dockerfile $'FROM python:3.15-alpine\n'
run_resolve PATH="$WORK/nopy:$WORK/bin:$PATH" INLINE_IMAGES="$MIXED"; expect_rc "resolver fails: the resolve step succeeds" $? 0
if grep -qF "not checked in this run: the resolver failed" "$FAKE/log"; then pass "resolver fails: error annotation"; else fail "resolver fails: error annotation" "$(tr '\n' ' ' < "$FAKE/log" | cut -c1-300)"; fi
expect_eq "resolver fails: the entry without dockerfile is checked" "$(out images | jq -c 'map(.name)')" '["app"]'
expect_eq "resolver fails: the entry with dockerfile is unresolved" "$(out unresolved | jq -c 'map(.name)')" '["python"]'

reset resolve-inline-mixed
put Dockerfile $'FROM python:3.15-alpine\n'
run_resolve INLINE_IMAGES='[{"name": "app", "image": "ghcr.io/acme/base", "tag": "stable", "variable": "APP_DIGEST"},
                            {"name": "python", "image": "python", "dockerfile": "Dockerfile", "variable": "PYTHON_DIGEST"}]'
expect_rc "inline, mixed: the resolve step succeeds" $? 0
expect_eq "inline, mixed: tags" "$(out images | jq -c 'map(.tag)')" '["stable","3.15-alpine"]'
expect_eq "inline, mixed: an entry without dockerfile is unchanged" "$(out images | jq -c '.[0]')" \
  '{"name":"app","image":"ghcr.io/acme/base","tag":"stable","variable":"APP_DIGEST"}'

# An entry copied for a second Dockerfile, its variable left as it was. Both
# checked, each would find the other's digest new and release every time.
reset resolve-shared-variable
put src/a/Dockerfile $'FROM python:3.15-alpine\n'
put src/b/Dockerfile $'FROM python:3.14-alpine\n'
run_resolve INLINE_IMAGES='[{"name": "a", "image": "python", "dockerfile": "src/a/Dockerfile", "variable": "PYTHON_DIGEST"},
                            {"name": "b", "image": "python", "dockerfile": "src/b/Dockerfile", "variable": "PYTHON_DIGEST"}]'
expect_rc "shared variable, two tags: the resolve step succeeds" $? 0
expect_eq "shared variable, two tags: neither entry is checked" "$(out images) $(out unresolved-names)" '[] ["a","b"]'
if grep -qF "::error file=src/b/Dockerfile,line=1::b: 'variable' PYTHON_DIGEST is used by entries checked on different images" "$FAKE/log"; then
  pass "shared variable, two tags: error annotation"
else
  fail "shared variable, two tags: error annotation" "$(tr '\n' ' ' < "$FAKE/log" | cut -c1-300)"
fi

# A step before the check that fails - a missing secret, say - or a check
# that fails before its outputs (a config file not found) leaves every
# output empty. The summary runs anyway (if: always()) and must not call that
# "up to date".
reset summary-not-run
run_step summary GITHUB_STEP_SUMMARY="$FAKE/summary"; expect_rc "check never ran: the summary step succeeds" $? 0
if grep -qF "### ❌ The check did not run" "$FAKE/summary"; then pass "check never ran: the summary says so"; else fail "check never ran: the summary says so" "$(tr '\n' '|' < "$FAKE/summary")"; fi
if grep -qF "All base images are up to date" "$FAKE/summary"; then fail "check never ran: not reported as up to date" "it is"; else pass "check never ran: not reported as up to date"; fi
# The resolve step ran and found an entry it could not resolve, then the check failed.
reset summary-not-run-unresolved
run_step summary GITHUB_STEP_SUMMARY="$FAKE/summary" \
  UNRESOLVED_JSON='[{"name":"worker","image":"python","dockerfile":"src/worker/Dockerfile","error":"no stage"}]'
if grep -qF "### ❌ The check did not run" "$FAKE/summary"; then pass "check never ran, entry unresolved: the check did not run"; else fail "check never ran, entry unresolved: the check did not run" "$(tr '\n' '|' < "$FAKE/summary")"; fi
if grep -qF "No updates among the images that could be read" "$FAKE/summary"; then fail "check never ran, entry unresolved: no claim about read images" "claimed"; else pass "check never ran, entry unresolved: no claim about read images"; fi
reset summary-unresolved
run_step summary GITHUB_STEP_SUMMARY="$FAKE/summary" IMAGES_CONFIGURED=2 IMAGES_CHECKED=1 UPDATES_FOUND=false \
  RETRIED_JSON='[]' PENDING_JSON='[]' CONFIRMED_JSON='[]' EXHAUSTED_JSON='[]' UNREACHABLE_JSON='[]' \
  UNRESOLVED_JSON='[{"name":"worker","image":"python","dockerfile":"src/worker/Dockerfile","error":"no stage"}]'
if grep -qF "**not** a clean result - 1 image(s) were never checked" "$FAKE/summary"; then pass "entry unresolved, no updates: not a clean result"; else fail "entry unresolved, no updates: not a clean result" "$(tr '\n' '|' < "$FAKE/summary")"; fi
if grep -qF "All base images are up to date" "$FAKE/summary"; then fail "entry unresolved, no updates: not reported as up to date" "it is"; else pass "entry unresolved, no updates: not reported as up to date"; fi
reset summary-clean
run_step summary GITHUB_STEP_SUMMARY="$FAKE/summary" IMAGES_CONFIGURED=1 IMAGES_CHECKED=1 UPDATES_FOUND=false \
  RETRIED_JSON='[]' PENDING_JSON='[]' CONFIRMED_JSON='[]' EXHAUSTED_JSON='[]' UNREACHABLE_JSON='[]'
if grep -qF "All base images are up to date" "$FAKE/summary"; then pass "clean check: still reported as up to date"; else fail "clean check: still reported as up to date" "$(tr '\n' '|' < "$FAKE/summary")"; fi

# === release commit ===========================================================

reset release
run_step release UPDATED_IMAGES_JSON='["app","engine"]' UPDATE_DETAILS=$'Base image digest changed:\n\n- app (x)'
expect_rc "release: step succeeds" $? 0
expect_eq "release: pushed" "$(origin_subject)" "chore(deps): update base image app, engine [skip ci]"
expect_eq "release: commit-sha is the pushed commit" "$(out commit-sha)" "$(git -C "$FAKE/origin.git" rev-parse HEAD)"
if git -C "$FAKE/origin.git" log -1 --format=%B | grep -q "^- app (x)$"; then pass "release: details in the body"; else fail "release: details in the body" "missing"; fi

reset release-commit-mode
run_step release TARGET_WORKFLOW="" UPDATED_IMAGES_JSON='["app"]' UPDATE_DETAILS="x"
expect_eq "release, commit mode: no [skip ci]" "$(origin_subject)" "chore(deps): update base image app"

# === dispatch =================================================================

reset dispatch
printf '{"workflow_run_id": 4711, "run_url": "x", "html_url": "%s/%s/actions/runs/4711"}' "$SERVER" "$REPO" > "$FAKE/dispatch-response"
run_step dispatch TARGET_INPUTS='{"force-release": "true", "count": 2}'; expect_rc "dispatch: step succeeds" $? 0
expect_eq "dispatch: endpoint" "$(cat "$FAKE/dispatch-path")" "repos/$REPO/actions/workflows/docker-release.yml/dispatches"
expect_eq "dispatch: asks for the run" "$(jq -r '.return_run_details' "$FAKE/dispatch-body.json")" true
expect_eq "dispatch: ref" "$(jq -r '.ref' "$FAKE/dispatch-body.json")" main
expect_eq "dispatch: inputs as strings" "$(jq -c '.inputs' "$FAKE/dispatch-body.json")" '{"force-release":"true","count":"2"}'
expect_eq "dispatch: run id" "$(out run-id)" 4711
expect_eq "dispatch: run url" "$(out run-url)" "$SERVER/$REPO/actions/runs/4711"
expect_eq "dispatch: triggered" "$(out triggered)" true

reset dispatch-no-run
run_step dispatch; expect_rc "no run id: step succeeds" $? 0
expect_eq "no run id: triggered" "$(out triggered)" true
expect_eq "no run id: no run-id output" "$(out run-id)" ""
if grep -q "::warning::The dispatch did not return a run id" "$FAKE/log"; then pass "no run id: warning"; else fail "no run id: warning" "missing"; fi

reset dispatch-no-inputs
run_step dispatch TARGET_INPUTS=""
expect_eq "no inputs: empty object" "$(jq -c '.inputs' "$FAKE/dispatch-body.json")" '{}'

reset dispatch-path
run_step dispatch TARGET_WORKFLOW=".github/workflows/docker-release.yml"
expect_eq "workflow path: file name used" "$(cat "$FAKE/dispatch-path")" "repos/$REPO/actions/workflows/docker-release.yml/dispatches"

reset dispatch-name
echo '{"workflows": [{"id": 1, "name": "CI"}, {"id": 42, "name": "Release & Docker Build"}]}' > "$FAKE/workflows.json"
run_step dispatch TARGET_WORKFLOW="Release & Docker Build"; expect_rc "workflow name: step succeeds" $? 0
expect_eq "workflow name: resolved to its id" "$(cat "$FAKE/dispatch-path")" "repos/$REPO/actions/workflows/42/dispatches"

reset dispatch-unknown-name
echo '{"workflows": [{"id": 1, "name": "CI"}]}' > "$FAKE/workflows.json"
run_step dispatch TARGET_WORKFLOW="Nope"; expect_rc "unknown workflow name: fails" $? 1

reset dispatch-bad-inputs
run_step dispatch TARGET_INPUTS='["force-release"]'; expect_rc "inputs not an object: fails" $? 1
if [ -f "$FAKE/dispatch-path" ]; then fail "inputs not an object: nothing dispatched" "dispatched"; else pass "inputs not an object: nothing dispatched"; fi

# === persist ==================================================================

reset persist-pending
set_var APP_DIGEST "$D_OLD"
run_step persist DISPATCH_UPDATES="{\"APP_DIGEST\": \"$D_NEW\"}" RUN_ID=4711 RUN_URL="$SERVER/$REPO/actions/runs/4711"
expect_rc "persist pending: step succeeds" $? 0
expect_eq "persist pending: digest untouched" "$(var APP_DIGEST)" "$D_OLD"
expect_eq "persist pending: record" "$(var APP_DIGEST_PENDING | jq -c '[.digest, .run_id, .attempt]')" "[\"$D_NEW\",4711,1]"

reset persist-attempt
run_step persist DISPATCH_UPDATES="{\"APP_DIGEST\": \"$D_NEW\"}" DISPATCH_ATTEMPTS='{"APP_DIGEST": 2}' RUN_ID=4712 RUN_URL="u"
expect_eq "persist: attempt recorded" "$(var APP_DIGEST_PENDING | jq -r .attempt)" 2

reset persist-untracked
set_var APP_DIGEST "$D_OLD"; pending APP_DIGEST "$D_NEW" 1
run_step persist DISPATCH_UPDATES="{\"APP_DIGEST\": \"$D_NEW\"}"
expect_rc "persist without run id: step succeeds" $? 0
expect_eq "persist without run id: digest stored" "$(var APP_DIGEST)" "$D_NEW"
if has_var APP_DIGEST_PENDING; then fail "persist without run id: old record removed" "still there"; else pass "persist without run id: old record removed"; fi

reset persist-confirmed
set_var APP_DIGEST "$D_OLD"; pending APP_DIGEST "$D_NEW" 1
run_step persist VARIABLE_UPDATES="{\"APP_DIGEST\": \"$D_NEW\", \"ENGINE_DIGEST\": \"$D_NEW\"}" PENDING_DELETES='["APP_DIGEST","ENGINE_DIGEST"]'
expect_rc "persist confirmed: step succeeds (missing record is fine)" $? 0
expect_eq "persist confirmed: digest stored" "$(var APP_DIGEST)" "$D_NEW"
if has_var APP_DIGEST_PENDING; then fail "persist confirmed: record removed" "still there"; else pass "persist confirmed: record removed"; fi

reset persist-failure
set_var APP_DIGEST "$D_OLD"; pending APP_DIGEST "$D_NEW" 1; touch "$FAKE/fail-set/APP_DIGEST"
run_step persist VARIABLE_UPDATES="{\"APP_DIGEST\": \"$D_NEW\"}" PENDING_DELETES='["APP_DIGEST"]'
expect_rc "persist failure: fails the job" $? 1
expect_eq "persist failure: three attempts" "$(grep -c '^gh variable set APP_DIGEST ' "$FAKE/calls.log")" 3
if has_var APP_DIGEST_PENDING; then pass "persist failure: record kept"; else fail "persist failure: record kept" "removed although the digest was not stored"; fi

# === the whole cycle ==========================================================
# Runs the steps the way the job chains them: each step's `if:` as in the
# workflow, success() gates persist. VAR=value pairs go to the check.
cycle() {
  run_step check "$@" || return 1
  # Kept for the assertions: the later steps overwrite the step output files.
  cp "$FAKE/output" "$FAKE/check-output"; cp "$FAKE/env" "$FAKE/check-env"; cp "$FAKE/log" "$FAKE/check-log"
  local dispatch_updates dispatch_attempts variable_updates pending_deletes run_id="" run_url=""
  dispatch_updates=$(out dispatch-updates); variable_updates=$(out variable-updates)
  pending_deletes=$(out pending-deletes); dispatch_attempts=$(out dispatch-attempts)
  local updates_found commit_needed commit_images
  updates_found=$(out updates-found); commit_needed=$(out commit-needed); commit_images=$(out commit-images)
  if [ "$commit_needed" = "true" ]; then
    run_step release UPDATED_IMAGES_JSON="$commit_images" UPDATE_DETAILS="$(details "$FAKE/check-env")" || return 1
  fi
  if [ "$updates_found" = "true" ]; then
    run_step dispatch || return 1
    run_id=$(out run-id); run_url=$(out run-url)
  fi
  run_step persist DISPATCH_UPDATES="$dispatch_updates" DISPATCH_ATTEMPTS="$dispatch_attempts" \
    VARIABLE_UPDATES="$variable_updates" PENDING_DELETES="$pending_deletes" RUN_ID="$run_id" RUN_URL="$run_url"
}
dispatch_returns() {
  printf '{"workflow_run_id": %s, "html_url": "%s/%s/actions/runs/%s"}' "$1" "$SERVER" "$REPO" "$1" > "$FAKE/dispatch-response"
  rm -f "$FAKE/dispatch-path"
}

reset cycle
set_var APP_DIGEST "$D_OLD"; manifest ghcr.io/acme/base:stable "$D_NEW"
release_tagged 1.0.0; git -C "$FAKE/repo" push -q origin HEAD
BASE_SUBJECT="chore(deps): update base image app [skip ci]"

dispatch_returns 201
cycle; expect_rc "cycle 1 (new digest): succeeds" $? 0
expect_eq "cycle 1: base image commit pushed" "$(origin_subject)" "$BASE_SUBJECT"
expect_eq "cycle 1: dispatched" "$(cat "$FAKE/dispatch-path" 2>/dev/null)" "repos/$REPO/actions/workflows/docker-release.yml/dispatches"
expect_eq "cycle 1: old digest kept" "$(var APP_DIGEST)" "$D_OLD"
expect_eq "cycle 1: run recorded" "$(var APP_DIGEST_PENDING | jq -c '[.run_id, .attempt]')" '[201,1]'

# The release gate is red: the run fails before it tags anything.
run_fixture 201 completed '"failure"'; dispatch_returns 202
COMMITS=$(origin_count)
cycle; expect_rc "cycle 2 (failed before the tag): succeeds" $? 0
expect_eq "cycle 2: dispatched again" "$(cat "$FAKE/dispatch-path" 2>/dev/null)" "repos/$REPO/actions/workflows/docker-release.yml/dispatches"
expect_eq "cycle 2: no new commit, the base image commit is still unreleased" "$(origin_count)" "$COMMITS"
expect_eq "cycle 2: old digest still kept" "$(var APP_DIGEST)" "$D_OLD"
expect_eq "cycle 2: new run recorded" "$(var APP_DIGEST_PENDING | jq -c '[.run_id, .attempt]')" '[202,2]'

# Run 202 passes the gate and tags 1.0.1, then a build fails. Dispatching
# again without a commit would find nothing to release.
release_tagged 1.0.1; git -C "$FAKE/repo" push -q origin HEAD
run_fixture 202 completed '"failure"'; dispatch_returns 203
COMMITS=$(origin_count)
cycle; expect_rc "cycle 3 (failed after the tag): succeeds" $? 0
expect_eq "cycle 3: new release commit pushed" "$(origin_count)" "$((COMMITS + 1))"
expect_eq "cycle 3: release commit subject" "$(origin_subject)" "$BASE_SUBJECT"
if git -C "$FAKE/origin.git" log -1 --format=%B | grep -qF "Failed run: $SERVER/$REPO/actions/runs/202 (failure)"; then
  pass "cycle 3: failed run named in the commit"
else
  fail "cycle 3: failed run named in the commit" "$(git -C "$FAKE/origin.git" log -1 --format=%B | tr '\n' '|')"
fi
expect_eq "cycle 3: dispatched after the commit" "$(cat "$FAKE/dispatch-path" 2>/dev/null)" "repos/$REPO/actions/workflows/docker-release.yml/dispatches"
expect_eq "cycle 3: new run recorded" "$(var APP_DIGEST_PENDING | jq -c '[.run_id, .attempt]')" '[203,3]'

run_fixture 203 in_progress null; dispatch_returns 299
cycle; expect_rc "cycle 4 (release running): succeeds" $? 0
if [ -f "$FAKE/dispatch-path" ]; then fail "cycle 4: nothing dispatched" "dispatched"; else pass "cycle 4: nothing dispatched"; fi
expect_eq "cycle 4: record kept" "$(var APP_DIGEST_PENDING | jq -r .run_id)" 203

run_fixture 203 completed '"success"'
cycle; expect_rc "cycle 5 (release succeeded): succeeds" $? 0
expect_eq "cycle 5: digest stored" "$(var APP_DIGEST)" "$D_NEW"
if has_var APP_DIGEST_PENDING; then fail "cycle 5: record removed" "still there"; else pass "cycle 5: record removed"; fi

COMMITS=$(origin_count)
cycle; expect_rc "cycle 6 (nothing new): succeeds" $? 0
expect_eq "cycle 6: up to date" "$(grep '^updates-found=' "$FAKE/check-output" | cut -d= -f2-)" false
if [ -f "$FAKE/dispatch-path" ]; then fail "cycle 6: nothing dispatched" "dispatched"; else pass "cycle 6: nothing dispatched"; fi
expect_eq "cycle 6: no commit" "$(origin_count)" "$COMMITS"

# The last allowed run failed as well: no further release, no commit.
reset cycle-exhausted
set_var APP_DIGEST "$D_OLD"; manifest ghcr.io/acme/base:stable "$D_NEW"
base_commit app; release_tagged 1.0.1; git -C "$FAKE/repo" push -q origin HEAD
pending APP_DIGEST "$D_NEW" 301 3; run_fixture 301 completed '"failure"'; dispatch_returns 302
COMMITS=$(origin_count)
cycle; expect_rc "exhausted cycle: steps succeed (the last step fails the job)" $? 0
expect_eq "exhausted cycle: reported" "$(grep '^exhausted-images=' "$FAKE/check-output" | cut -d= -f2-)" '["app"]'
if [ -f "$FAKE/dispatch-path" ]; then fail "exhausted cycle: nothing dispatched" "dispatched"; else pass "exhausted cycle: nothing dispatched"; fi
expect_eq "exhausted cycle: no commit" "$(origin_count)" "$COMMITS"
expect_eq "exhausted cycle: record kept" "$(var APP_DIGEST_PENDING | jq -r .run_id)" 301
expect_eq "exhausted cycle: digest not stored" "$(var APP_DIGEST)" "$D_OLD"

# A Dependabot tag bump with 'dockerfile'. The bump is a fix(docker) commit
# whose own release already built the image on the new tag. The first check
# after it compares the new tag's digest with the stored digest of the old
# tag and releases once more - attempt 1, confirmed as usual; the state
# variables work as for any new digest. From then on only the new tag counts.
reset cycle-tag-bump
put src/app/Dockerfile $'FROM python:3.14-alpine AS prod\n'
config '{"name": "python", "image": "python", "dockerfile": "src/app/Dockerfile", "variable": "PYTHON_DIGEST"}'
git -C "$FAKE/repo" add -A; commit "feat: app"; release_tagged 1.0.0; git -C "$FAKE/repo" push -q origin HEAD
manifest python:3.14-alpine "$D_OLD"; manifest python:3.15-alpine "$D_NEW"; set_var PYTHON_DIGEST "$D_OLD"
resolved_cycle() {
  run_resolve CONFIG_FILE="$CFG" || return 1
  cp "$FAKE/output" "$FAKE/resolve-output"
  local images unresolved; images=$(out images); unresolved=$(out unresolved)
  cycle CONFIG_FILE="$CFG" RESOLVED_IMAGES="$images" UNRESOLVED_IMAGES="$unresolved"
}
checked() { grep "^$1=" "$FAKE/check-output" | tail -n 1 | cut -d= -f2-; }
resolved() { grep "^$1=" "$FAKE/resolve-output" | tail -n 1 | cut -d= -f2-; }

dispatch_returns 401
resolved_cycle; expect_rc "tag bump cycle 1 (before the bump): succeeds" $? 0
expect_eq "tag bump cycle 1: nothing to do" "$(checked updates-found)" false

put src/app/Dockerfile $'FROM python:3.15-alpine AS prod\n'
git -C "$FAKE/repo" add -A; commit "fix(docker): bump python from 3.14-alpine to 3.15-alpine"
release_tagged 1.0.1; git -C "$FAKE/repo" push -q origin HEAD
COMMITS=$(origin_count)
resolved_cycle; expect_rc "tag bump cycle 2 (after the bump): succeeds" $? 0
expect_eq "tag bump cycle 2: the new tag is one new update" "$(checked new-images)" '["python"]'
expect_eq "tag bump cycle 2: one release commit" "$(origin_count)" "$((COMMITS + 1))"
expect_eq "tag bump cycle 2: one release run, attempt 1" "$(var PYTHON_DIGEST_PENDING | jq -c '[.digest, .run_id, .attempt]')" "[\"$D_NEW\",401,1]"
expect_eq "tag bump cycle 2: old digest kept until confirmed" "$(var PYTHON_DIGEST)" "$D_OLD"

run_fixture 401 completed '"success"'; rm -f "$FAKE/dispatch-path"
resolved_cycle; expect_rc "tag bump cycle 3 (release succeeded): succeeds" $? 0
expect_eq "tag bump cycle 3: the new tag's digest is stored" "$(var PYTHON_DIGEST)" "$D_NEW"
if has_var PYTHON_DIGEST_PENDING; then fail "tag bump cycle 3: record removed" "still there"; else pass "tag bump cycle 3: record removed"; fi
if [ -f "$FAKE/dispatch-path" ]; then fail "tag bump cycle 3: nothing dispatched" "dispatched"; else pass "tag bump cycle 3: nothing dispatched"; fi

# The old tag moves: it is no longer the base, so no rebuild.
manifest python:3.14-alpine "$D_NEWER"
resolved_cycle; expect_rc "tag bump cycle 4 (old tag moved): succeeds" $? 0
expect_eq "tag bump cycle 4: a move of the old tag is ignored" "$(checked updates-found)" false
if [ -f "$FAKE/dispatch-path" ]; then fail "tag bump cycle 4: nothing dispatched" "dispatched"; else pass "tag bump cycle 4: nothing dispatched"; fi

# The new tag moves: the security rebuild a drifted config missed.
manifest python:3.15-alpine "$D_NEWER"; dispatch_returns 402
resolved_cycle; expect_rc "tag bump cycle 5 (new tag moved): succeeds" $? 0
expect_eq "tag bump cycle 5: a move of the new tag is released" "$(checked new-images)" '["python"]'
expect_eq "tag bump cycle 5: run recorded" "$(var PYTHON_DIGEST_PENDING | jq -c '[.digest, .run_id]')" "[\"$D_NEWER\",402]"

# One entry whose tag cannot be read - a Dockerfile refactor renamed the stage
# it selects - must not hold back the others. They are checked, released and
# stored as usual, the entry's own state is left alone, the summary names it
# and the job fails in its last step.
reset unresolved-entry
put src/app/Dockerfile $'FROM python:3.15-alpine\n'
put src/worker/Dockerfile $'FROM python:3.15-alpine AS runtime\n'
config '{"name": "app", "image": "ghcr.io/acme/base", "tag": "stable", "variable": "APP_DIGEST"},
        {"name": "python", "image": "python", "dockerfile": "src/app/Dockerfile", "variable": "PYTHON_DIGEST"},
        {"name": "worker", "image": "python", "dockerfile": "src/worker/Dockerfile", "stage": "build", "variable": "WORKER_DIGEST"}'
git -C "$FAKE/repo" add -A; commit "feat: app"; release_tagged 1.0.0; git -C "$FAKE/repo" push -q origin HEAD
manifest ghcr.io/acme/base:stable "$D_NEW"; manifest python:3.15-alpine "$D_NEW"
set_var APP_DIGEST "$D_OLD"; set_var PYTHON_DIGEST "$D_OLD"; set_var WORKER_DIGEST "$D_OLD"
run_resolve CONFIG_FILE="$CFG"; expect_rc "one entry not resolved: the resolve step succeeds" $? 0
RESOLVED=$(out images); UNRESOLVED=$(out unresolved)
expect_eq "one entry not resolved: reported for the job output" "$(out unresolved-names)" '["worker"]'
if grep -qF "::error file=src/worker/Dockerfile::worker: src/worker/Dockerfile has no stage 'build' (stages: runtime)" "$FAKE/log"; then
  pass "one entry not resolved: error annotation"
else
  fail "one entry not resolved: error annotation" "$(tr '\n' ' ' < "$FAKE/log" | cut -c1-300)"
fi
expect_eq "one entry not resolved: the others go to the check" "$(printf '%s' "$RESOLVED" | jq -c 'map(.name)')" '["app","python"]'
COMMITS=$(origin_count)
dispatch_returns 501
cycle CONFIG_FILE="$CFG" RESOLVED_IMAGES="$RESOLVED" UNRESOLVED_IMAGES="$UNRESOLVED"
expect_rc "one entry not resolved: the check, release and persist of the others succeed" $? 0
expect_eq "one entry not resolved: the others' updates are released" "$(checked new-images)" '["app","python"]'
expect_eq "one entry not resolved: one release commit" "$(origin_count)" "$((COMMITS + 1))"
expect_eq "one entry not resolved: the others' runs are recorded" \
  "$(var APP_DIGEST_PENDING | jq -r .run_id) $(var PYTHON_DIGEST_PENDING | jq -r .run_id)" "501 501"
expect_eq "one entry not resolved: configured, not checked" "$(checked images-configured) $(checked images-checked)" "3 2"
if grep -q "WORKER_DIGEST" "$FAKE/calls.log"; then fail "one entry not resolved: its state is left alone" "$(grep WORKER_DIGEST "$FAKE/calls.log" | head -1)"; else pass "one entry not resolved: its state is left alone"; fi
if grep -qF -- "- worker: python (FROM in src/worker/Dockerfile) - tag not read, not checked" "$FAKE/check-log"; then
  pass "one entry not resolved: the check's log names it"
else
  fail "one entry not resolved: the check's log names it" "$(tr '\n' ' ' < "$FAKE/check-log" | cut -c1-300)"
fi
run_step summary GITHUB_STEP_SUMMARY="$FAKE/summary" UPDATES_FOUND=true UPDATED_IMAGES_JSON='["app","python"]' NEW_DIGESTS_JSON='{}' \
  IMAGES_CONFIGURED="$(checked images-configured)" IMAGES_CHECKED="$(checked images-checked)" UNREACHABLE_JSON='[]' \
  RETRIED_JSON='[]' PENDING_JSON='[]' CONFIRMED_JSON='[]' EXHAUSTED_JSON='[]' UNRESOLVED_JSON="$UNRESOLVED"
if grep -qF "**Coverage:** 2 of 3 configured image(s) verified" "$FAKE/summary" \
   && grep -qF "### 🛑 Tag not read from the Dockerfile" "$FAKE/summary" \
   && grep -qF -- "- \`worker\` (\`src/worker/Dockerfile\`): src/worker/Dockerfile has no stage 'build'" "$FAKE/summary"; then
  pass "one entry not resolved: the summary names it"
else
  fail "one entry not resolved: the summary names it" "$(tr '\n' '|' < "$FAKE/summary")"
fi
run_step fail-unresolved UNRESOLVED="$UNRESOLVED"; expect_rc "one entry not resolved: the last step fails the job" $? 1
if grep -qF "::error::Not checked because the tag could not be read from the Dockerfile: worker - see the summary" "$FAKE/log"; then pass "one entry not resolved: the last step names it"; else fail "one entry not resolved: the last step names it" "$(cat "$FAKE/log")"; fi

# The stage is fixed: the entry is resolved and checked again. Its tag moved
# while it was not checked, so it is released now.
put src/worker/Dockerfile $'FROM python:3.15-alpine AS build\n'
run_fixture 501 completed '"success"'; dispatch_returns 502
resolved_cycle; expect_rc "entry fixed: succeeds" $? 0
expect_eq "entry fixed: nothing unresolved" "$(resolved unresolved-names)" '[]'
expect_eq "entry fixed: its missed update is released" "$(checked new-images)" '["worker"]'

# Exhausted release retries and an entry whose tag was not read, in one run.
# The exhausted step fails the job first; the last step must still run and
# name the entry - with a plain `if:` GitHub skips it after a failed step.
reset exhausted-and-unresolved
put src/worker/Dockerfile $'FROM python:3.15-alpine AS runtime\n'
config '{"name": "app", "image": "ghcr.io/acme/base", "tag": "stable", "variable": "APP_DIGEST"},
        {"name": "worker", "image": "python", "dockerfile": "src/worker/Dockerfile", "stage": "build", "variable": "WORKER_DIGEST"}'
git -C "$FAKE/repo" add -A; commit "feat: app"; base_commit app; release_tagged 1.0.1; git -C "$FAKE/repo" push -q origin HEAD
set_var APP_DIGEST "$D_OLD"; manifest ghcr.io/acme/base:stable "$D_NEW"
pending APP_DIGEST "$D_NEW" 301 3; run_fixture 301 completed '"failure"'; dispatch_returns 302
resolved_cycle; expect_rc "exhausted and unresolved: the steps before the last two succeed" $? 0
EXHAUSTED=$(checked exhausted-images); UNRESOLVED=$(resolved unresolved)
expect_eq "exhausted and unresolved: both reported" "$EXHAUSTED $(resolved unresolved-names)" '["app"] ["worker"]'
# The last two steps, chained as the job chains them.
JOB_FAILED=false; RAN=""; : > "$FAKE/last-errors"
for STEP in fail-exhausted fail-unresolved; do
  if step_runs "$STEP" "$JOB_FAILED" "steps.check.outputs.exhausted-images=$EXHAUSTED" "steps.resolve.outputs.unresolved=$UNRESOLVED"; then
    RAN="$RAN $STEP"
    run_step "$STEP" EXHAUSTED_IMAGES="$EXHAUSTED" UNRESOLVED="$UNRESOLVED" || JOB_FAILED=true
    grep '^::error::' "$FAKE/log" >> "$FAKE/last-errors"
  fi
done
expect_eq "exhausted and unresolved: both last steps run" "$RAN" " fail-exhausted fail-unresolved"
expect_eq "exhausted and unresolved: the job fails" "$JOB_FAILED" true
if grep -qF "::error::The release of app failed max-release-attempts times" "$FAKE/last-errors"; then
  pass "exhausted and unresolved: the exhausted image is named"
else
  fail "exhausted and unresolved: the exhausted image is named" "$(cat "$FAKE/last-errors")"
fi
if grep -qF "::error::Not checked because the tag could not be read from the Dockerfile: worker" "$FAKE/last-errors"; then
  pass "exhausted and unresolved: the entry is named after the failed step"
else
  fail "exhausted and unresolved: the entry is named after the failed step" "$(cat "$FAKE/last-errors")"
fi
# The same after a check that failed itself (an unreachable image, say), and
# the evaluator's own rules: a plain `if:` is skipped after a failed step.
if step_runs fail-unresolved true "steps.resolve.outputs.unresolved=$UNRESOLVED"; then pass "check failed: the entry is still named"; else fail "check failed: the entry is still named" "skipped"; fi
if step_runs fail-exhausted true "steps.check.outputs.exhausted-images=$EXHAUSTED"; then fail "a plain if: is skipped after a failed step" "ran"; else pass "a plain if: is skipped after a failed step"; fi
if step_runs fail-unresolved false "steps.resolve.outputs.unresolved=[]"; then fail "nothing unresolved: the last step is skipped" "ran"; else pass "nothing unresolved: the last step is skipped"; fi

echo ""
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
