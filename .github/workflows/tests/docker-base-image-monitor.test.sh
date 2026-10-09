#!/usr/bin/env bash
#
# Behavioural test for the check, dispatch and persist steps of
# ../modules-docker-base-image-monitor.yml.
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
#   recorded run failed or deleted          -> dispatched again, no new commit
#   no target workflow (commit mode)        -> digest stored after the push, as before
#
# The step bodies are extracted from the workflow at runtime rather than
# duplicated here and run the way a `shell: bash` step runs (-eo pipefail).
# `gh` and `docker` are replaced by stubs that keep repository variables and
# workflow runs in a directory; `gh api --jq` filters are applied with jq.
#
# Usage: bash .github/workflows/tests/docker-base-image-monitor.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_FILE="$SCRIPT_DIR/../modules-docker-base-image-monitor.yml"

if [ ! -f "$WORKFLOW_FILE" ]; then
  echo "FATAL: workflow not found at $WORKFLOW_FILE"
  exit 1
fi
if ! command -v jq > /dev/null; then
  echo "FATAL: jq is required"
  exit 1
fi

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

for STEP in check dispatch persist; do
  extract_step "$STEP" > "$WORK/$STEP.sh"
  if [ ! -s "$WORK/$STEP.sh" ]; then
    echo "FATAL: could not extract the '$STEP' run block from the workflow."
    echo "       The step was renamed, removed, or re-indented - update this test."
    exit 1
  fi
done

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
static_check "a retry creates no release commit" \
  "if: steps.check.outputs.new-updates-found == 'true' && inputs.commit-and-release == true && inputs.dry-run != true"
static_check "the commit names only new images" "UPDATED_IMAGES_JSON: \${{ steps.check.outputs.new-images }}"
static_check "state is persisted only after every earlier step succeeded" \
  "if: success() && steps.check.outputs.state-changed == 'true' && inputs.dry-run != true"
static_check "persist reads the dispatched run id" "RUN_ID: \${{ steps.dispatch.outputs.run-id }}"
static_check "job has a timeout" "    timeout-minutes: "

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
# The persist step backs off between attempts; the test does not wait.
printf '#!/usr/bin/env bash\nexit 0\n' > "$WORK/bin/sleep"
chmod +x "$WORK/bin/gh" "$WORK/bin/docker" "$WORK/bin/sleep"

REPO="acme/app"
SERVER="https://github.com"
D_OLD="sha256:1111111111111111111111111111111111111111111111111111111111111111"
D_NEW="sha256:2222222222222222222222222222222222222222222222222222222222222222"
D_NEWER="sha256:3333333333333333333333333333333333333333333333333333333333333333"
IMAGES='[{"name": "app", "image": "ghcr.io/acme/base", "tag": "stable", "variable": "APP_DIGEST"}]'
TWO_IMAGES='[{"name": "app", "image": "ghcr.io/acme/base", "tag": "stable", "variable": "APP_DIGEST"},
             {"name": "engine", "image": "ghcr.io/acme/engine", "tag": "latest", "variable": "ENGINE_DIGEST"}]'

# Fresh fake repository for a scenario.
reset() {
  FAKE="$WORK/fake-$1"
  rm -rf "$FAKE"
  mkdir -p "$FAKE/vars" "$FAKE/runs" "$FAKE/manifests" "$FAKE/fail-set"
  : > "$FAKE/calls.log"
  export FAKE
}
set_var() { printf '%s' "$2" > "$FAKE/vars/$1"; }
var() { cat "$FAKE/vars/$1" 2>/dev/null; }
has_var() { [ -f "$FAKE/vars/$1" ]; }
manifest() { printf '{"schemaVersion": 2, "config": {"digest": "%s"}}' "$2" > "$FAKE/manifests/$(printf '%s' "$1" | tr '/:' '__')"; }
run_fixture() { printf '{"id": %s, "status": "%s", "conclusion": %s, "html_url": "%s/%s/actions/runs/%s"}' \
  "$1" "$2" "$3" "$SERVER" "$REPO" "$1" > "$FAKE/runs/$1"; }
pending() { jq -nc --arg d "$2" --argjson r "$3" '{digest: $d, run_id: $r, run_url: "x"}' > "$FAKE/vars/$1_PENDING"; }
out() { grep "^$1=" "$FAKE/output" | tail -n 1 | cut -d= -f2-; }

# Runs a step with the environment of the workflow. Extra VAR=value pairs
# before the step name override the defaults.
run_step() {
  local step="$1"; shift
  : > "$FAKE/output"; : > "$FAKE/env"
  env PATH="$WORK/bin:$PATH" GH_TOKEN=dummy \
    GITHUB_OUTPUT="$FAKE/output" GITHUB_ENV="$FAKE/env" \
    GITHUB_REPOSITORY="$REPO" GITHUB_SERVER_URL="$SERVER" \
    CONFIG_FILE="" INLINE_IMAGES="$IMAGES" COMMIT_PREFIX_INPUT="chore(deps)" \
    DRY_RUN=false FAIL_ON_UNREACHABLE=true TARGET_WORKFLOW="docker-release.yml" \
    TARGET_REF=main TARGET_INPUTS='{"force-release": "true"}' \
    VARIABLE_UPDATES='{}' DISPATCH_UPDATES='{}' PENDING_DELETES='[]' RUN_ID="" RUN_URL="" \
    "$@" bash -eo pipefail "$WORK/$step.sh" > "$FAKE/log" 2>&1
}

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
expect_eq "new: counts as new (commit)" "$(out new-updates-found)" true
expect_eq "new: new-images" "$(out new-images)" '["app"]'
expect_eq "new: dispatched, not stored" "$(out dispatch-updates)" "{\"APP_DIGEST\":\"$D_NEW\"}"
expect_eq "new: digest not stored yet" "$(out variable-updates)" '{}'
expect_eq "new: no retry" "$(out retried-images)" '[]'
if grep -q "New: $D_NEW" "$FAKE/env"; then pass "new: commit details"; else fail "new: commit details" "UPDATE_DETAILS lacks the new digest"; fi

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

reset failed
manifest ghcr.io/acme/base:stable "$D_NEW"; set_var APP_DIGEST "$D_OLD"
pending APP_DIGEST "$D_NEW" 103; run_fixture 103 completed '"failure"'
run_step check; expect_rc "failed: step succeeds" $? 0
expect_eq "failed: release needed" "$(out updates-found)" true
expect_eq "failed: no new commit" "$(out new-updates-found)" false
expect_eq "failed: retried" "$(out retried-images)" '["app"]'
expect_eq "failed: conclusion reported" "$(out retried | jq -r '.[0].conclusion')" failure
expect_eq "failed: dispatched again" "$(out dispatch-updates)" "{\"APP_DIGEST\":\"$D_NEW\"}"
expect_eq "failed: digest still not stored" "$(out variable-updates)" '{}'
if grep -q "::warning::The release dispatched for app" "$FAKE/log"; then pass "failed: warning annotation"; else fail "failed: warning annotation" "missing"; fi

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
pending APP_DIGEST "$D_NEW" 108; run_fixture 108 completed '"failure"'
run_step check INLINE_IMAGES="$TWO_IMAGES"
expect_eq "mixed: both need a release" "$(out updated-images)" '["app","engine"]'
expect_eq "mixed: only the new one is committed" "$(out new-images)" '["engine"]'
if grep -q "app (ghcr.io/acme/base:stable)" "$FAKE/env"; then
  fail "mixed: commit details" "the retried image is in the commit message"
else
  pass "mixed: commit details"
fi

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
expect_eq "persist pending: record" "$(var APP_DIGEST_PENDING | jq -c '[.digest, .run_id]')" "[\"$D_NEW\",4711]"

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
# Runs the three steps the way the job chains them: success() gates persist.
cycle() {
  run_step check || return 1
  # Kept for the assertions: the later steps overwrite the step output file.
  cp "$FAKE/output" "$FAKE/check-output"
  local dispatch_updates variable_updates pending_deletes run_id="" run_url=""
  dispatch_updates=$(out dispatch-updates); variable_updates=$(out variable-updates)
  pending_deletes=$(out pending-deletes)
  if [ "$(out updates-found)" = "true" ]; then
    run_step dispatch || return 1
    run_id=$(out run-id); run_url=$(out run-url)
  fi
  run_step persist DISPATCH_UPDATES="$dispatch_updates" VARIABLE_UPDATES="$variable_updates" \
    PENDING_DELETES="$pending_deletes" RUN_ID="$run_id" RUN_URL="$run_url"
}
dispatch_returns() {
  printf '{"workflow_run_id": %s, "html_url": "%s/%s/actions/runs/%s"}' "$1" "$SERVER" "$REPO" "$1" > "$FAKE/dispatch-response"
  rm -f "$FAKE/dispatch-path"
}

reset cycle
set_var APP_DIGEST "$D_OLD"; manifest ghcr.io/acme/base:stable "$D_NEW"

dispatch_returns 201
cycle; expect_rc "cycle 1 (new digest): succeeds" $? 0
expect_eq "cycle 1: dispatched" "$(cat "$FAKE/dispatch-path" 2>/dev/null)" "repos/$REPO/actions/workflows/docker-release.yml/dispatches"
expect_eq "cycle 1: old digest kept" "$(var APP_DIGEST)" "$D_OLD"
expect_eq "cycle 1: run recorded" "$(var APP_DIGEST_PENDING | jq -r .run_id)" 201

# The release gate is red: the run fails.
run_fixture 201 completed '"failure"'; dispatch_returns 202
cycle; expect_rc "cycle 2 (release failed): succeeds" $? 0
expect_eq "cycle 2: dispatched again" "$(cat "$FAKE/dispatch-path" 2>/dev/null)" "repos/$REPO/actions/workflows/docker-release.yml/dispatches"
expect_eq "cycle 2: old digest still kept" "$(var APP_DIGEST)" "$D_OLD"
expect_eq "cycle 2: new run recorded" "$(var APP_DIGEST_PENDING | jq -r .run_id)" 202

run_fixture 202 in_progress null; dispatch_returns 299
cycle; expect_rc "cycle 3 (release running): succeeds" $? 0
if [ -f "$FAKE/dispatch-path" ]; then fail "cycle 3: nothing dispatched" "dispatched"; else pass "cycle 3: nothing dispatched"; fi
expect_eq "cycle 3: record kept" "$(var APP_DIGEST_PENDING | jq -r .run_id)" 202

run_fixture 202 completed '"success"'
cycle; expect_rc "cycle 4 (release succeeded): succeeds" $? 0
expect_eq "cycle 4: digest stored" "$(var APP_DIGEST)" "$D_NEW"
if has_var APP_DIGEST_PENDING; then fail "cycle 4: record removed" "still there"; else pass "cycle 4: record removed"; fi

cycle; expect_rc "cycle 5 (nothing new): succeeds" $? 0
expect_eq "cycle 5: up to date" "$(grep '^updates-found=' "$FAKE/check-output" | cut -d= -f2-)" false
if [ -f "$FAKE/dispatch-path" ]; then fail "cycle 5: nothing dispatched" "dispatched"; else pass "cycle 5: nothing dispatched"; fi

echo ""
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
