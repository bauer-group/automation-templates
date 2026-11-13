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
# A multi-arch index was compared by its first manifest sorted by
# architecture - linux/386 whenever it has one - while the images are amd64.
# 386 lags amd64 or is rebuilt alone. The linux/amd64 manifest is compared now:
#
#   index with 386 and amd64                -> amd64; without a variant first, then any linux/amd64
#   index without linux/amd64               -> the old pick
#   stored digest is the old pick           -> switched without a release only if the amd64
#                                              image is more than 48h older than the latest
#                                              release; built later or within 48h before it,
#                                              build time or release unreadable, no release
#                                              -> released as an update
#   <var>_PENDING records the old pick      -> running: wait; failed: retry for amd64;
#                                              succeeded: switched as above, record dropped
#
# docker-maintenance-dependabot.yml releases a base image update it merged
# itself and hands the digests over in a git note (refs/notes/base-image-monitor):
#
#   note for the current digest, recorded   -> stored, no commit, no dispatch
#     after the variable was last stored
#   stale note, another digest, unreadable  -> released as before (a stored old pick is
#     last update                              still switched, then nothing claims a release)
#   malformed note, commit not on the branch -> ignored (malformed: with a warning)
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

for STEP in handoff check release dispatch persist summary fail-exhausted fail-unresolved; do
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
# The switch of a stored old pick follows the same rule in both modules.
static_check "the switch margin is 48h" "          MIGRATION_MARGIN_HOURS=48"
if grep -qxF "          MIGRATION_MARGIN_HOURS=48" "$SCRIPT_DIR/../modules-auto-maintenance.yml"; then
  pass "the switch margin is the one of modules-auto-maintenance.yml"
else
  fail "the switch margin is the one of modules-auto-maintenance.yml" "MIGRATION_MARGIN_HOURS=48 not found there"
fi
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
static_check "the check reads the releases handed over" "HANDOFFS: \${{ steps.handoff.outputs.handoffs }}"
static_check "the summary reads the switched digests" "MIGRATED_JSON: \${{ steps.check.outputs.migrated }}"
static_check "the summary reads the handed over digests" "HANDED_OFF_JSON: \${{ steps.check.outputs.handed-off }}"
static_check "the job reports the switched digests" "migrated-images: \${{ steps.check.outputs.migrated-images }}"
static_check "the job reports the handed over digests" "handed-off-images: \${{ steps.check.outputs.handed-off-images }}"
static_check "the module reports the switched digests" "value: \${{ jobs.monitor.outputs.migrated-images }}"
static_check "the module reports the handed over digests" "value: \${{ jobs.monitor.outputs.handed-off-images }}"
# Reading the notes must never be what stops the security rebuilds.
if awk '$0 == "        id: handoff" { h = NR } h && NR == h + 1 { exit !($0 == "        continue-on-error: true") }
        END { if (!h) exit 1 }' "$WORKFLOW_FILE"; then
  pass "a failure to read the notes does not stop the check"
else
  fail "a failure to read the notes does not stop the check" "the handoff step is missing or lacks continue-on-error: true"
fi
if awk '$0 == "        id: handoff" { h = NR } $0 == "        id: check" { c = NR } END { exit !(h && c && h < c) }' "$WORKFLOW_FILE"; then
  pass "the notes are read before the check"
else
  fail "the notes are read before the check" "the handoff step is missing or comes after the check"
fi

# --- stubs --------------------------------------------------------------------
# State lives in $FAKE: vars/<NAME> (repository variables), var-updated/<NAME>
# (their updated_at, set by `gh variable set`), var-error/<NAME> (stderr of a
# failing read of the variable's metadata), runs/<ID> (run JSON),
# runs/<ID>.error (stderr of a failing read), manifests/<ref with / and : as _>,
# images/<ref@digest with /, : and @ as _> (image config for
# `docker buildx imagetools inspect`), release-latest (JSON; absent = no
# release), release-latest.error, dispatch-response, workflows.json,
# fail-set/<NAME>. Every gh call and every buildx call is logged.
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
    printf '%s' "$5" > "$FAKE/vars/$3"
    date -u +%Y-%m-%dT%H:%M:%SZ > "$FAKE/var-updated/$3"; exit 0 ;;
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
  "GET repos/"*"/releases/latest")
    if [ -f "$FAKE/release-latest.error" ]; then cat "$FAKE/release-latest.error" >&2; exit 1; fi
    [ -f "$FAKE/release-latest" ] || { echo "gh: Not Found (HTTP 404)" >&2; exit 1; }
    if [ -n "$filter" ]; then jq -r "$filter" "$FAKE/release-latest"; else cat "$FAKE/release-latest"; fi
    exit 0 ;;
  "GET repos/"*"/actions/variables/"*)
    name="${path##*/}"
    if [ -f "$FAKE/var-error/$name" ]; then cat "$FAKE/var-error/$name" >&2; exit 1; fi
    [ -f "$FAKE/vars/$name" ] || { echo "gh: Not Found (HTTP 404)" >&2; exit 1; }
    updated=$(cat "$FAKE/var-updated/$name" 2>/dev/null || echo "2026-11-01T00:00:00Z")
    json=$(jq -nc --arg n "$name" --rawfile v "$FAKE/vars/$name" --arg u "$updated" \
      '{name: $n, value: $v, created_at: "2026-01-01T00:00:00Z", updated_at: $u}')
    if [ -n "$filter" ]; then printf '%s' "$json" | jq -r "$filter"; else printf '%s' "$json"; fi
    exit 0 ;;
esac
echo "unexpected gh api call: $method $path" >&2
exit 2
STUB
cat > "$WORK/bin/docker" <<'STUB'
#!/usr/bin/env bash
if [ "$1 $2 $3" = "buildx imagetools inspect" ]; then
  echo "docker $*" >> "$FAKE/calls.log"
  [ "$5 $6" = "--format {{json .Image}}" ] && [ $# -eq 6 ] || { echo "unexpected docker call: $*" >&2; exit 2; }
  f="$FAKE/images/$(printf '%s' "$4" | tr '/:@' '___')"
  [ -f "$f" ] || { echo "ERROR: $4: not found" >&2; exit 1; }
  cat "$f"; exit 0
fi
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
  mkdir -p "$FAKE/vars" "$FAKE/var-updated" "$FAKE/var-error" "$FAKE/runs" "$FAKE/manifests" "$FAKE/images" "$FAKE/fail-set"
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

# Platform manifests of a multi-arch index: digest_of <hex char>.
digest_of() { printf 'sha256:%s' "$(printf '%064d' 0 | tr 0 "$1")"; }
D_386=$(digest_of 4); D_3862=$(digest_of b); D_AMD=$(digest_of 5); D_AMD2=$(digest_of a)
D_ARM=$(digest_of 6); D_ARMV7=$(digest_of 7); D_V3=$(digest_of 8); D_WIN=$(digest_of 9)
# index REF OS/ARCH[/VARIANT]=DIGEST... - in the given order, as the registry lists them.
index() {
  local ref="$1" entries="[]" pair os arch variant; shift
  for pair in "$@"; do
    IFS=/ read -r os arch variant <<< "${pair%%=*}"
    entries=$(printf '%s' "$entries" | jq -c --arg d "${pair#*=}" --arg os "$os" --arg arch "$arch" --arg v "${variant:-}" \
      '. + [{mediaType: "application/vnd.oci.image.manifest.v1+json", digest: $d, size: 1,
             platform: ({os: $os, architecture: $arch} + (if $v == "" then {} else {variant: $v} end))}]')
  done
  jq -nc --argjson m "$entries" '{schemaVersion: 2, mediaType: "application/vnd.oci.image.index.v1+json", manifests: $m}' \
    > "$FAKE/manifests/$(printf '%s' "$ref" | tr '/:' '__')"
}
# built REF@DIGEST CREATED: the image config `docker buildx imagetools inspect` shows.
built() { jq -nc --arg c "$2" '{created: $c, architecture: "amd64", os: "linux"}' > "$FAKE/images/$(printf '%s' "$1" | tr '/:@' '___')"; }
latest_release() { jq -nc --arg c "$1" '{tag_name: "v1.0.0", created_at: $c}' > "$FAKE/release-latest"; }
var_updated() { printf '%s' "$2" > "$FAKE/var-updated/$1"; }
head_sha() { git -C "$FAKE/repo" rev-parse HEAD; }
has_ref() { git -C "$FAKE/repo" show-ref --verify -q "$1"; }
# handoff VARIABLE DIGEST RECORDED_AT: the handoff step's output for one note.
handoff() {
  jq -nc --arg v "$1" --arg d "$2" --arg r "$3" --argjson e "$(date -u -d "$3" +%s)" --arg u "$SERVER/$REPO/actions/runs/777" \
    '[{variable: $v, digest: $d, recorded_at: $r, recorded_epoch: $e, release: "v1.2.3", release_run_url: $u,
       merge_commit: "0123456789abcdef0123456789abcdef01234567"}]'
}
# note_json COMMIT DIGESTS_JSON RECORDED_AT: a note as docker-maintenance-dependabot.yml writes it.
note_json() {
  jq -nc --arg c "$1" --argjson d "$2" --arg r "$3" --arg u "$SERVER/$REPO/actions/runs/900" \
    '{schema: 1, source: "docker-maintenance-dependabot", recorded_at: $r, merge_commit: $c, release: "v1.0.1", release_run_url: $u, digests: $d}'
}
# note COMMIT CONTENT: attaches a note and pushes the notes ref to origin, as
# the Dependabot module does. The checkout keeps no local ref: a fresh
# checkout has none, and the handoff step has to fetch it.
note() {
  git -C "$FAKE/repo" fetch -q origin "+refs/notes/base-image-monitor:refs/notes/base-image-monitor" 2>/dev/null || true
  git -C "$FAKE/repo" notes --ref=base-image-monitor add -f -m "$2" "$1"
  git -C "$FAKE/repo" push -q -f origin refs/notes/base-image-monitor
  git -C "$FAKE/repo" update-ref -d refs/notes/base-image-monitor
}

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
    VARIABLE_UPDATES='{}' DISPATCH_UPDATES='{}' DISPATCH_ATTEMPTS='{}' PENDING_DELETES='[]' RUN_ID="" RUN_URL="" HANDOFFS="" \
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

# === linux/amd64 digest =======================================================
# A multi-arch index used to be compared by its first manifest sorted by
# architecture: linux/386 whenever it has one. The images are amd64.

reset amd64
index ghcr.io/acme/base:stable linux/amd64="$D_AMD" linux/arm/v7="$D_ARMV7" linux/arm64="$D_ARM" linux/386="$D_386"
set_var APP_DIGEST "$D_AMD"
run_step check; expect_rc "386 and amd64: step succeeds" $? 0
expect_eq "386 and amd64: the stored amd64 digest is unchanged" "$(out updates-found) $(out state-changed)" "false false"
set_var APP_DIGEST "$D_OLD"
run_step check
expect_eq "386 and amd64: the amd64 digest is the new one" "$(out new-digests)" "{\"app\":\"$D_AMD\"}"
if grep -q "docker buildx" "$FAKE/calls.log"; then fail "a stored digest that is not the old pick: no switch considered" "inspected"; else pass "a stored digest that is not the old pick: no switch considered"; fi

reset arm-only
index ghcr.io/acme/base:stable linux/arm64="$D_ARM" linux/arm/v7="$D_ARMV7"
set_var APP_DIGEST "$D_OLD"
run_step check; expect_rc "no linux/amd64: step succeeds" $? 0
expect_eq "no linux/amd64: the old pick is kept" "$(out new-digests)" "{\"app\":\"$D_ARMV7\"}"

reset amd64-variant
index ghcr.io/acme/base:stable windows/amd64="$D_WIN" linux/amd64/v3="$D_V3" linux/amd64="$D_AMD" linux/386="$D_386"
set_var APP_DIGEST "$D_OLD"
run_step check
expect_eq "amd64 variants: linux/amd64 without a variant wins" "$(out new-digests)" "{\"app\":\"$D_AMD\"}"
reset amd64-variant-only
index ghcr.io/acme/base:stable linux/386="$D_386" linux/amd64/v2="$D_V3"
set_var APP_DIGEST "$D_OLD"
run_step check
expect_eq "amd64 with a variant only: that one" "$(out new-digests)" "{\"app\":\"$D_V3\"}"

# --- one-time switch of a stored old pick -------------------------------------
# The stored digest is the 386 manifest of this very index. Switched without
# a release only while the amd64 image is more than 48h older than the latest
# release.
migration_setup() {
  index ghcr.io/acme/base:stable linux/amd64="$D_AMD" linux/arm64="$D_ARM" linux/386="$D_386"
  set_var APP_DIGEST "$D_386"
}

reset migrate
migration_setup; built "ghcr.io/acme/base@$D_AMD" 2026-11-05T19:27:56.890249894Z; latest_release 2026-11-08T08:00:00Z
run_step check; expect_rc "switch: step succeeds" $? 0
expect_eq "switch: listed" "$(out migrated-images)" '["app"]'
expect_eq "switch: stored" "$(out variable-updates)" "{\"APP_DIGEST\":\"$D_AMD\"}"
expect_eq "switch: state changed, so persist stores it" "$(out state-changed)" true
expect_eq "switch: not an update" "$(out updates-found) $(out updated-images) $(out new-images) $(out new-digests)" 'false [] [] {}'
expect_eq "switch: no commit, no dispatch" "$(out commit-needed) $(out commit-images) $(out dispatch-updates)" 'false [] {}'
expect_eq "switch: old and new digest" "$(out migrated | jq -r '.[0] | "\(.old) \(.new)"')" "$D_386 $D_AMD"
expect_eq "switch: the platform manifest is inspected" "$(grep -c "^docker buildx imagetools inspect ghcr.io/acme/base@$D_AMD --format" "$FAKE/calls.log")" 1

reset migrate-newer-amd64
migration_setup; built "ghcr.io/acme/base@$D_AMD" 2026-11-07T10:00:00Z; latest_release 2026-11-06T08:00:00Z
run_step check; expect_rc "amd64 built after the release: step succeeds" $? 0
expect_eq "amd64 built after the release: released" "$(out new-images) $(out dispatch-updates)" "[\"app\"] {\"APP_DIGEST\":\"$D_AMD\"}"
expect_eq "amd64 built after the release: not switched" "$(out migrated-images)" '[]'
if grep -qF "::notice::app (ghcr.io/acme/base:stable): the stored digest is the one an earlier version of this module compared" "$FAKE/log" \
   && grep -qF "(built 2026-11-07T10:00:00Z) is not more than 48h older than the latest release (2026-11-06T08:00:00Z)" "$FAKE/log"; then
  pass "amd64 built after the release: notice names the reason"
else
  fail "amd64 built after the release: notice names the reason" "$(grep '::notice::' "$FAKE/log")"
fi

reset migrate-same-second
migration_setup; built "ghcr.io/acme/base@$D_AMD" 2026-11-06T08:00:00Z; latest_release 2026-11-06T08:00:00Z
run_step check
expect_eq "amd64 built in the second of the release: released" "$(out new-images)" '["app"]'

# "created" is the build time, not the time the image reached the tag:
# python:3.15-alpine on 2026-11-05 - amd64 built 19:27, in the tag at 23:06,
# 386 there since 20:06. A release at 21:00 was built on the OLD amd64 image.
reset migrate-in-margin
migration_setup; built "ghcr.io/acme/base@$D_AMD" 2026-11-05T19:27:56Z; latest_release 2026-11-05T21:00:00Z
run_step check; expect_rc "amd64 built 2h before the release: step succeeds" $? 0
expect_eq "amd64 built 2h before the release: released" "$(out new-images) $(out migrated-images)" '["app"] []'
if grep -qF "(built 2026-11-05T19:27:56Z) is not more than 48h older than the latest release (2026-11-05T21:00:00Z)" "$FAKE/log"; then
  pass "amd64 built 2h before the release: notice names the margin"
else
  fail "amd64 built 2h before the release: notice names the margin" "$(grep '::notice::' "$FAKE/log")"
fi

reset migrate-margin-boundary
migration_setup; built "ghcr.io/acme/base@$D_AMD" 2026-11-05T19:27:56Z; latest_release 2026-11-07T19:27:56Z
run_step check
expect_eq "amd64 exactly 48h older than the release: released" "$(out new-images) $(out migrated-images)" '["app"] []'

reset migrate-margin-past
migration_setup; built "ghcr.io/acme/base@$D_AMD" 2026-11-05T19:27:56Z; latest_release 2026-11-07T19:27:57Z
run_step check
expect_eq "amd64 48h and 1s older than the release: switched" "$(out migrated-images) $(out new-images)" '["app"] []'

# Image build times carry nanoseconds; a date that does not read fractions
# (uutils date on ubuntu-latest may not) must still get a time, or every
# stored old pick would be released at once.
mkdir -p "$WORK/strictdate"
REAL_DATE=$(command -v date)
cat > "$WORK/strictdate/date" <<EOF
#!/usr/bin/env bash
for a in "\$@"; do
  case "\$a" in *T*:*:*.[0-9]*) echo "date: invalid date '\$a'" >&2; exit 1 ;; esac
done
exec "$REAL_DATE" "\$@"
EOF
chmod +x "$WORK/strictdate/date"
STRICT_PATH="$WORK/strictdate:$WORK/bin:$PATH"
reset migrate-strict-date
migration_setup; built "ghcr.io/acme/base@$D_AMD" 2026-11-05T19:27:56.890249894Z; latest_release 2026-11-08T08:00:00Z
run_step check PATH="$STRICT_PATH"; expect_rc "build time in nanoseconds, date without fractions: step succeeds" $? 0
expect_eq "build time in nanoseconds, date without fractions: switched" "$(out migrated-images) $(out new-images)" '["app"] []'

reset migrate-no-created
migration_setup; latest_release 2026-11-06T08:00:00Z
run_step check; expect_rc "build time unreadable: step succeeds" $? 0
expect_eq "build time unreadable: released" "$(out new-images) $(out migrated-images)" '["app"] []'
expect_eq "build time unreadable: one retry" "$(grep -c '^docker buildx imagetools inspect' "$FAKE/calls.log")" 2
if grep -qF "::notice::app (ghcr.io/acme/base:stable)" "$FAKE/log" && grep -qF "the build time of the linux/amd64 image could not be read" "$FAKE/log"; then
  pass "build time unreadable: notice"; else fail "build time unreadable: notice" "$(grep '::notice::' "$FAKE/log")"; fi

reset migrate-epoch-zero
migration_setup; built "ghcr.io/acme/base@$D_AMD" 1970-01-01T00:00:00Z; latest_release 2026-11-06T08:00:00Z
run_step check
expect_eq "build time of a reproducible build (1970): released" "$(out new-images)" '["app"]'
# nixpkgs dockerTools writes 1970-01-01T00:00:01Z; anything before 1980 is a
# placeholder, 1980-01-01 itself the lowest real SOURCE_DATE_EPOCH.
reset migrate-epoch-one
migration_setup; built "ghcr.io/acme/base@$D_AMD" 1970-01-01T00:00:01Z; latest_release 2026-11-08T08:00:00Z
run_step check
expect_eq "build time 1970-01-01T00:00:01Z (nixpkgs): released" "$(out new-images) $(out migrated-images)" '["app"] []'
reset migrate-epoch-1980
migration_setup; built "ghcr.io/acme/base@$D_AMD" 1980-01-01T00:00:00Z; latest_release 2026-11-08T08:00:00Z
run_step check
expect_eq "build time 1980-01-01 (SOURCE_DATE_EPOCH floor): switched" "$(out migrated-images) $(out new-images)" '["app"] []'

reset migrate-garbage-created
migration_setup; built "ghcr.io/acme/base@$D_AMD" "now"; latest_release 2026-11-06T08:00:00Z
run_step check
expect_eq "build time not RFC 3339: released" "$(out new-images)" '["app"]'

reset migrate-no-release
migration_setup; built "ghcr.io/acme/base@$D_AMD" 2026-11-05T19:27:56Z
run_step check; expect_rc "no release yet: step succeeds" $? 0
expect_eq "no release yet: released" "$(out new-images) $(out migrated-images)" '["app"] []'
if grep -qF "the repository has no release" "$FAKE/log"; then pass "no release yet: notice"; else fail "no release yet: notice" "$(grep '::notice::' "$FAKE/log")"; fi

reset migrate-release-unreadable
migration_setup; built "ghcr.io/acme/base@$D_AMD" 2026-11-05T19:27:56Z; echo "gh: Server Error (HTTP 502)" > "$FAKE/release-latest.error"
run_step check
expect_eq "latest release unreadable: released" "$(out new-images)" '["app"]'

# Both images are candidates: the latest release is read once.
reset migrate-two
index ghcr.io/acme/base:stable linux/amd64="$D_AMD" linux/386="$D_386"
index ghcr.io/acme/engine:latest linux/amd64="$D_AMD2" linux/386="$D_3862"
set_var APP_DIGEST "$D_386"; set_var ENGINE_DIGEST "$D_3862"
built "ghcr.io/acme/base@$D_AMD" 2026-11-05T19:27:56Z; built "ghcr.io/acme/engine@$D_AMD2" 2026-11-07T10:00:00Z
latest_release 2026-11-08T08:00:00Z
run_step check INLINE_IMAGES="$TWO_IMAGES"; expect_rc "two candidates: step succeeds" $? 0
expect_eq "two candidates: each decided on its own" "$(out migrated-images) $(out new-images)" '["app"] ["engine"]'
expect_eq "two candidates: only the released one is committed" "$(out commit-images)" '["engine"]'
expect_eq "two candidates: the latest release is read once" "$(grep -c 'releases/latest' "$FAKE/calls.log")" 1

reset migrate-dry-run
migration_setup; built "ghcr.io/acme/base@$D_AMD" 2026-11-05T19:27:56Z; latest_release 2026-11-08T08:00:00Z
run_step check DRY_RUN=true; expect_rc "switch, dry run: step succeeds" $? 0
expect_eq "switch, dry run: reported" "$(out migrated-images)" '["app"]'
if grep -qE "^gh variable (set|delete)" "$FAKE/calls.log"; then fail "switch, dry run: writes nothing" "wrote a variable"; else pass "switch, dry run: writes nothing"; fi
if grep -qF "DRY RUN: nothing is stored (APP_DIGEST would be stored, without a release)" "$FAKE/log"; then pass "switch, dry run: says so"; else fail "switch, dry run: says so" "missing"; fi

reset migrate-commit-mode
migration_setup; built "ghcr.io/acme/base@$D_AMD" 2026-11-05T19:27:56Z; latest_release 2026-11-08T08:00:00Z
run_step check TARGET_WORKFLOW=""; expect_rc "switch, commit mode: step succeeds" $? 0
expect_eq "switch, commit mode: stored, no commit" "$(out migrated-images) $(out variable-updates) $(out commit-needed)" \
  "[\"app\"] {\"APP_DIGEST\":\"$D_AMD\"} false"
if grep -q "_PENDING" "$FAKE/calls.log"; then fail "switch, commit mode: no pending lookup" "read a _PENDING variable"; else pass "switch, commit mode: no pending lookup"; fi

# --- a record of the old pick in <variable>_PENDING ---------------------------
# An earlier version dispatched a release for the 386 digest of this index.
reset legacy-running
index ghcr.io/acme/base:stable linux/amd64="$D_AMD" linux/386="$D_386"; set_var APP_DIGEST "$D_OLD"
pending APP_DIGEST "$D_386" 601; run_fixture 601 in_progress null
run_step check; expect_rc "old pick's release running: step succeeds" $? 0
expect_eq "old pick's release running: waits" "$(out pending-images) $(out updates-found) $(out state-changed)" '["app"] false false'

reset legacy-unreadable
index ghcr.io/acme/base:stable linux/amd64="$D_AMD" linux/386="$D_386"; set_var APP_DIGEST "$D_OLD"
pending APP_DIGEST "$D_386" 606; echo "gh: Server Error (HTTP 502)" > "$FAKE/runs/606.error"
run_step check
expect_eq "old pick's release unreadable: waits" "$(out pending | jq -r '.[0].state') $(out updates-found)" 'unknown false'

reset legacy-failed
index ghcr.io/acme/base:stable linux/amd64="$D_AMD" linux/386="$D_386"; set_var APP_DIGEST "$D_OLD"
release_tagged 1.0.0; base_commit app
pending APP_DIGEST "$D_386" 603 2; run_fixture 603 completed '"failure"'
run_step check; expect_rc "old pick's release failed: step succeeds" $? 0
expect_eq "old pick's release failed: retried" "$(out retried-images)" '["app"]'
expect_eq "old pick's release failed: dispatched for the amd64 digest" "$(out dispatch-updates)" "{\"APP_DIGEST\":\"$D_AMD\"}"
expect_eq "old pick's release failed: next attempt" "$(out dispatch-attempts)" '{"APP_DIGEST":3}'
expect_eq "old pick's release failed before the tag: no new commit" "$(out commit-needed)" false
if grep -q "docker buildx" "$FAKE/calls.log"; then fail "old pick's release failed: no switch considered" "inspected"; else pass "old pick's release failed: no switch considered"; fi

reset legacy-exhausted
index ghcr.io/acme/base:stable linux/amd64="$D_AMD" linux/386="$D_386"; set_var APP_DIGEST "$D_OLD"
pending APP_DIGEST "$D_386" 605 3; run_fixture 605 completed '"failure"'
run_step check
expect_eq "old pick's release failed the last attempt: exhausted" "$(out exhausted-images) $(out dispatch-updates)" '["app"] {}'

reset legacy-confirmed
index ghcr.io/acme/base:stable linux/amd64="$D_AMD" linux/386="$D_386"; set_var APP_DIGEST "$D_OLD"
pending APP_DIGEST "$D_386" 602; run_fixture 602 completed '"success"'
built "ghcr.io/acme/base@$D_AMD" 2026-11-05T19:27:56Z; latest_release 2026-11-08T08:00:00Z
run_step check; expect_rc "old pick's release succeeded: step succeeds" $? 0
expect_eq "old pick's release succeeded: switched" "$(out migrated-images) $(out variable-updates)" "[\"app\"] {\"APP_DIGEST\":\"$D_AMD\"}"
expect_eq "old pick's release succeeded: record dropped" "$(out pending-deletes)" '["APP_DIGEST"]'
expect_eq "old pick's release succeeded: not an update, not confirmed" "$(out updates-found) $(out confirmed)" 'false []'
expect_eq "old pick's release succeeded: run named" "$(out migrated | jq -r '.[0].run_url')" "$SERVER/$REPO/actions/runs/602"
run_step persist VARIABLE_UPDATES="$(grep '^variable-updates=' "$FAKE/output" | cut -d= -f2-)" PENDING_DELETES='["APP_DIGEST"]'
expect_eq "old pick's release succeeded: persist stores the amd64 digest" "$(var APP_DIGEST)" "$D_AMD"
if has_var APP_DIGEST_PENDING; then fail "old pick's release succeeded: persist drops the record" "still there"; else pass "old pick's release succeeded: persist drops the record"; fi

reset legacy-confirmed-newer
index ghcr.io/acme/base:stable linux/amd64="$D_AMD" linux/386="$D_386"; set_var APP_DIGEST "$D_OLD"
pending APP_DIGEST "$D_386" 604; run_fixture 604 completed '"success"'
built "ghcr.io/acme/base@$D_AMD" 2026-11-07T10:00:00Z; latest_release 2026-11-06T08:00:00Z
run_step check
expect_eq "old pick released, amd64 newer: released as attempt 1" "$(out new-images) $(out dispatch-attempts)" '["app"] {"APP_DIGEST":1}'
expect_eq "old pick released, amd64 newer: the record is replaced by the dispatch, not dropped" "$(out pending-deletes)" '[]'
if grep -qF "::notice::app (ghcr.io/acme/base:stable): APP_DIGEST_PENDING records a successful release of the digest an earlier version of this module compared" "$FAKE/log" \
   && ! grep -qF "the stored digest is the one an earlier version" "$FAKE/log"; then
  pass "old pick released, amd64 newer: the notice names the record, not the stored digest"
else
  fail "old pick released, amd64 newer: the notice names the record, not the stored digest" "$(grep '::notice::' "$FAKE/log")"
fi

# --- handed over by the Dependabot module -------------------------------------
reset handoff
manifest ghcr.io/acme/base:stable "$D_NEW"; set_var APP_DIGEST "$D_OLD"; var_updated APP_DIGEST 2026-11-01T00:00:00Z
run_step check HANDOFFS="$(handoff APP_DIGEST "$D_NEW" 2026-11-10T10:00:00Z)"; expect_rc "handoff: step succeeds" $? 0
expect_eq "handoff: listed" "$(out handed-off-images)" '["app"]'
expect_eq "handoff: stored" "$(out variable-updates) $(out state-changed)" "{\"APP_DIGEST\":\"$D_NEW\"} true"
expect_eq "handoff: not an update" "$(out updates-found) $(out new-images) $(out new-digests)" 'false [] {}'
expect_eq "handoff: no commit, no dispatch" "$(out commit-needed) $(out dispatch-updates)" 'false {}'
expect_eq "handoff: release named" "$(out handed-off | jq -r '.[0] | "\(.release) \(.release_run_url)"')" "v1.2.3 $SERVER/$REPO/actions/runs/777"

reset handoff-same-second
manifest ghcr.io/acme/base:stable "$D_NEW"; set_var APP_DIGEST "$D_OLD"; var_updated APP_DIGEST 2026-11-10T10:00:00Z
run_step check HANDOFFS="$(handoff APP_DIGEST "$D_NEW" 2026-11-10T10:00:00Z)"
expect_eq "handoff recorded in the second of the last update: counts" "$(out handed-off-images)" '["app"]'

reset handoff-stale
manifest ghcr.io/acme/base:stable "$D_NEW"; set_var APP_DIGEST "$D_OLD"; var_updated APP_DIGEST 2026-11-11T00:00:00Z
run_step check HANDOFFS="$(handoff APP_DIGEST "$D_NEW" 2026-11-10T10:00:00Z)"; expect_rc "stale handoff: step succeeds" $? 0
expect_eq "stale handoff: released" "$(out new-images) $(out handed-off-images)" '["app"] []'
if grep -qF "::notice::app (ghcr.io/acme/base:stable): a Dependabot update recorded this digest as released, but the note was recorded before APP_DIGEST was last stored" "$FAKE/log"; then
  pass "stale handoff: notice"; else fail "stale handoff: notice" "$(grep '::notice::' "$FAKE/log")"; fi

# The note is not used, but the stored old pick is switched: no release, so
# no annotation may claim one.
reset handoff-stale-switched
migration_setup; var_updated APP_DIGEST 2026-11-11T00:00:00Z
built "ghcr.io/acme/base@$D_AMD" 2026-11-05T19:27:56Z; latest_release 2026-11-08T08:00:00Z
run_step check HANDOFFS="$(handoff APP_DIGEST "$D_AMD" 2026-11-10T10:00:00Z)"; expect_rc "stale handoff, old pick switched: step succeeds" $? 0
expect_eq "stale handoff, old pick switched: switched, not released" "$(out migrated-images) $(out new-images) $(out handed-off-images)" '["app"] [] []'
if grep -qF "released as an update" "$FAKE/log"; then fail "stale handoff, old pick switched: no release claimed" "$(grep '::notice::' "$FAKE/log")"; else pass "stale handoff, old pick switched: no release claimed"; fi
reset handoff-stale-not-switched
migration_setup; var_updated APP_DIGEST 2026-11-11T00:00:00Z
built "ghcr.io/acme/base@$D_AMD" 2026-11-07T10:00:00Z; latest_release 2026-11-06T08:00:00Z
run_step check HANDOFFS="$(handoff APP_DIGEST "$D_AMD" 2026-11-10T10:00:00Z)"
expect_eq "stale handoff, old pick not switched: released" "$(out new-images) $(out migrated-images)" '["app"] []'
if grep -qF "::notice::app (ghcr.io/acme/base:stable): a Dependabot update recorded this digest as released, but the note was recorded before APP_DIGEST was last stored - released as an update" "$FAKE/log"; then
  pass "stale handoff, old pick not switched: notice"; else fail "stale handoff, old pick not switched: notice" "$(grep '::notice::' "$FAKE/log")"; fi

reset handoff-other-digest
manifest ghcr.io/acme/base:stable "$D_NEW"; set_var APP_DIGEST "$D_OLD"
run_step check HANDOFFS="$(handoff APP_DIGEST "$D_NEWER" 2026-11-10T10:00:00Z)"
expect_eq "handoff of another digest: released" "$(out new-images) $(out handed-off-images)" '["app"] []'
if grep -q "actions/variables" "$FAKE/calls.log"; then fail "handoff of another digest: the last update is not read" "read"; else pass "handoff of another digest: the last update is not read"; fi

reset handoff-other-variable
manifest ghcr.io/acme/base:stable "$D_NEW"; set_var APP_DIGEST "$D_OLD"
run_step check HANDOFFS="$(handoff ENGINE_DIGEST "$D_NEW" 2026-11-10T10:00:00Z)"
expect_eq "handoff of another variable: released" "$(out new-images)" '["app"]'

reset handoff-new-variable
manifest ghcr.io/acme/base:stable "$D_NEW"
run_step check HANDOFFS="$(handoff APP_DIGEST "$D_NEW" 2026-11-10T10:00:00Z)"; expect_rc "handoff, variable missing: step succeeds" $? 0
expect_eq "handoff, variable missing: stored" "$(out handed-off-images) $(out variable-updates)" "[\"app\"] {\"APP_DIGEST\":\"$D_NEW\"}"

reset handoff-variable-unreadable
manifest ghcr.io/acme/base:stable "$D_NEW"; set_var APP_DIGEST "$D_OLD"; echo "gh: Server Error (HTTP 500)" > "$FAKE/var-error/APP_DIGEST"
run_step check HANDOFFS="$(handoff APP_DIGEST "$D_NEW" 2026-11-10T10:00:00Z)"
expect_eq "handoff, last update unreadable: released" "$(out new-images) $(out handed-off-images)" '["app"] []'
if grep -qF "the last update of APP_DIGEST could not be read" "$FAKE/log"; then pass "handoff, last update unreadable: notice"; else fail "handoff, last update unreadable: notice" "$(grep '::notice::' "$FAKE/log")"; fi

reset handoff-commit-mode
manifest ghcr.io/acme/base:stable "$D_NEW"; set_var APP_DIGEST "$D_OLD"
run_step check TARGET_WORKFLOW="" HANDOFFS="$(handoff APP_DIGEST "$D_NEW" 2026-11-10T10:00:00Z)"
expect_eq "handoff, commit mode: stored, no commit" "$(out handed-off-images) $(out commit-needed)" '["app"] false'

# The monitor's own release of the digest decides first.
reset handoff-own-release-running
manifest ghcr.io/acme/base:stable "$D_NEW"; set_var APP_DIGEST "$D_OLD"
pending APP_DIGEST "$D_NEW" 607; run_fixture 607 in_progress null
run_step check HANDOFFS="$(handoff APP_DIGEST "$D_NEW" 2026-11-10T10:00:00Z)"
expect_eq "handoff while the monitor's own release runs: waits for it" "$(out pending-images) $(out handed-off-images)" '["app"] []'

# The old pick's release succeeded and Dependabot released the amd64 digest.
reset handoff-legacy-confirmed
index ghcr.io/acme/base:stable linux/amd64="$D_AMD" linux/386="$D_386"; set_var APP_DIGEST "$D_OLD"
pending APP_DIGEST "$D_386" 608; run_fixture 608 completed '"success"'
run_step check HANDOFFS="$(handoff APP_DIGEST "$D_AMD" 2026-11-10T10:00:00Z)"
expect_eq "handoff after the old pick's release: stored, record dropped" "$(out handed-off-images) $(out pending-deletes)" '["app"] ["APP_DIGEST"]'
if grep -q "docker buildx" "$FAKE/calls.log"; then fail "handoff after the old pick's release: no switch needed" "inspected"; else pass "handoff after the old pick's release: no switch needed"; fi

reset handoff-garbage
manifest ghcr.io/acme/base:stable "$D_NEW"; set_var APP_DIGEST "$D_OLD"
run_step check HANDOFFS="not json"; expect_rc "handoff list unreadable: step succeeds" $? 0
expect_eq "handoff list unreadable: released" "$(out new-images)" '["app"]'

reset handoff-dry-run
manifest ghcr.io/acme/base:stable "$D_NEW"; set_var APP_DIGEST "$D_OLD"
run_step check DRY_RUN=true HANDOFFS="$(handoff APP_DIGEST "$D_NEW" 2026-11-10T10:00:00Z)"
expect_eq "handoff, dry run: reported" "$(out handed-off-images)" '["app"]'
if grep -qE "^gh variable (set|delete)" "$FAKE/calls.log"; then fail "handoff, dry run: writes nothing" "wrote a variable"; else pass "handoff, dry run: writes nothing"; fi

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

# === handoff step: notes of the Dependabot module =============================

reset handoff-step-none
run_step handoff; expect_rc "no notes ref: step succeeds" $? 0
expect_eq "no notes ref: nothing handed over" "$(out handoffs)" '[]'
if grep -q "::warning::" "$FAKE/log"; then fail "no notes ref: normal, no warning" "$(grep '::warning::' "$FAKE/log")"; else pass "no notes ref: normal, no warning"; fi

reset handoff-step-fetch-error
git -C "$FAKE/repo" remote set-url origin "$FAKE/missing.git"
run_step handoff; expect_rc "notes not fetched: step succeeds" $? 0
expect_eq "notes not fetched: nothing handed over" "$(out handoffs)" '[]'
if grep -qF "::warning::Could not fetch refs/notes/base-image-monitor" "$FAKE/log"; then pass "notes not fetched: warning"; else fail "notes not fetched: warning" "$(tr '\n' ' ' < "$FAKE/log" | cut -c1-300)"; fi

reset handoff-step
commit "fix(docker): bump python from 3.14-alpine to 3.15-alpine"; M1=$(head_sha)
commit "fix(docker): bump node from 22-alpine to 24-alpine"; M2=$(head_sha)
git -C "$FAKE/repo" push -q origin HEAD
note "$M1" "$(note_json "$M1" '{"PYTHON_DIGEST": "'"$D_NEW"'"}' 2026-11-10T10:00:00Z)"
note "$M2" "$(note_json "$M2" '{"NODE_DIGEST": "'"$D_NEWER"'", "PYTHON_DIGEST": "'"$D_NEW"'"}' 2026-11-11T10:00:00Z)"
run_step handoff; expect_rc "notes: step succeeds" $? 0
HANDED=$(out handoffs)
expect_eq "notes: one entry per variable" "$(printf '%s' "$HANDED" | jq -c 'map([.variable, .digest[0:8]])')" '[["NODE_DIGEST","sha256:3"],["PYTHON_DIGEST","sha256:2"]]'
expect_eq "notes: the newest note of a digest counts" "$(printf '%s' "$HANDED" | jq -r '.[] | select(.variable == "PYTHON_DIGEST") | "\(.merge_commit) \(.recorded_at) \(.recorded_epoch)"')" \
  "$M2 2026-11-11T10:00:00Z $(date -u -d 2026-11-11T10:00:00Z +%s)"
expect_eq "notes: release and run" "$(printf '%s' "$HANDED" | jq -r '.[0] | "\(.release) \(.release_run_url)"')" "v1.0.1 $SERVER/$REPO/actions/runs/900"
if has_ref refs/notes/base-image-monitor; then pass "notes: fetched into the checkout"; else fail "notes: fetched into the checkout" "missing"; fi
if grep -q "::warning::" "$FAKE/log"; then fail "notes: no warning" "$(grep '::warning::' "$FAKE/log")"; else pass "notes: no warning"; fi

# Only the newest note of a variable is kept, so the list - one environment
# value of the check - stays bounded however many updates were handed over.
# Its recorded_at has a fraction, which a date without fractions must read.
reset handoff-step-per-variable
commit "fix(docker): bump python from 3.14-alpine to 3.15-alpine"; M1=$(head_sha)
commit "fix(docker): bump python from 3.15-alpine to 3.16-alpine"; M2=$(head_sha)
git -C "$FAKE/repo" push -q origin HEAD
note "$M1" "$(note_json "$M1" '{"PYTHON_DIGEST": "'"$D_NEW"'"}' 2026-11-10T10:00:00Z)"
note "$M2" "$(note_json "$M2" '{"PYTHON_DIGEST": "'"$D_NEWER"'"}' 2026-11-11T10:00:00.5Z)"
run_step handoff PATH="$STRICT_PATH"; expect_rc "two notes of one variable: step succeeds" $? 0
expect_eq "two notes of one variable: only the newest counts" "$(out handoffs | jq -c 'map([.variable, .digest, .merge_commit])')" "[[\"PYTHON_DIGEST\",\"$D_NEWER\",\"$M2\"]]"
expect_eq "two notes of one variable: recorded_at with a fraction is read" "$(out handoffs | jq -r '.[0].recorded_epoch')" "$(date -u -d 2026-11-11T10:00:00Z +%s)"
if grep -q "::warning::" "$FAKE/log"; then fail "two notes of one variable: no warning" "$(grep '::warning::' "$FAKE/log")"; else pass "two notes of one variable: no warning"; fi

reset handoff-step-malformed
BAD=0
# bad_note LABEL CONTENT - on a commit of its own; @C@ in CONTENT is that commit.
bad_note() { commit "fix(docker): bump $1"; local c; c=$(head_sha); note "$c" "${2//@C@/$c}"; BAD=$((BAD + 1)); }
APP_NEW="{\"APP_DIGEST\": \"$D_NEW\"}"
commit "fix(docker): bump good"; GOOD=$(head_sha); note "$GOOD" "$(note_json "$GOOD" "$APP_NEW" 2026-11-10T10:00:00Z)"
bad_note "not-json" "not json"
bad_note "two-objects" "$(note_json @C@ "$APP_NEW" 2026-11-10T10:00:00Z) {}"
bad_note "array" '[]'
bad_note "schema-2" "$(note_json @C@ "$APP_NEW" 2026-11-10T10:00:00Z | jq -c '.schema = 2')"
bad_note "schema-string" "$(note_json @C@ "$APP_NEW" 2026-11-10T10:00:00Z | jq -c '.schema = "1"')"
bad_note "other-commit" "$(note_json "$GOOD" "$APP_NEW" 2026-11-10T10:00:00Z)"
bad_note "bad-digest" "$(note_json @C@ '{"APP_DIGEST": "sha256:XYZ"}' 2026-11-10T10:00:00Z)"
bad_note "digest-not-a-string" "$(note_json @C@ '{"APP_DIGEST": 1}' 2026-11-10T10:00:00Z)"
bad_note "bad-variable" "$(note_json @C@ "{\"../../x\": \"$D_NEW\"}" 2026-11-10T10:00:00Z)"
bad_note "no-digests" "$(note_json @C@ 'null' 2026-11-10T10:00:00Z)"
bad_note "recorded-free-form" "$(note_json @C@ "$APP_NEW" now)"
bad_note "recorded-not-utc" "$(note_json @C@ "$APP_NEW" 2026-11-10T10:00:00+01:00)"
bad_note "recorded-invalid" "$(note_json @C@ "$APP_NEW" 2026-13-40T10:00:00Z)"
git -C "$FAKE/repo" push -q origin HEAD
run_step handoff; expect_rc "malformed notes: step succeeds" $? 0
expect_eq "malformed notes: only the valid note counts" "$(out handoffs | jq -c 'map(.merge_commit)')" "[\"$GOOD\"]"
expect_eq "malformed notes: a warning for each" "$(grep -c '^::warning::Ignored the malformed note on' "$FAKE/log")" "$BAD"
if grep -qF "../../x" "$FAKE/log"; then fail "malformed notes: their content is not echoed" "echoed"; else pass "malformed notes: their content is not echoed"; fi
reset handoff-step-unsafe-fields
commit "fix(docker): bump app"; C=$(head_sha); git -C "$FAKE/repo" push -q origin HEAD
note "$C" "$(note_json "$C" '{"APP_DIGEST": "'"$D_NEW"'"}' 2026-11-10T10:00:00Z | jq -c '.release = "v1 | `x`" | .release_run_url = "javascript:alert(1)"')"
run_step handoff
expect_eq "unsafe release fields: blanked, the note still counts" "$(out handoffs | jq -c '.[0] | [.variable, .release, .release_run_url]')" '["APP_DIGEST","",""]'

reset handoff-step-unreachable
git -C "$FAKE/repo" checkout -q -b side; commit "fix(docker): bump on a side branch"; SIDE=$(head_sha); git -C "$FAKE/repo" checkout -q main
note "$SIDE" "$(note_json "$SIDE" '{"APP_DIGEST": "'"$D_NEW"'"}' 2026-11-10T10:00:00Z)"
run_step handoff; expect_rc "note on a commit not on the branch: step succeeds" $? 0
expect_eq "note on a commit not on the branch: ignored" "$(out handoffs)" '[]'
if grep -qF "Ignored the note on ${SIDE:0:12}: the commit is not on the checked out branch" "$FAKE/log"; then pass "note on a commit not on the branch: logged"; else fail "note on a commit not on the branch: logged" "$(tr '\n' ' ' < "$FAKE/log" | cut -c1-300)"; fi

# === summary: stored without a release ========================================

SUMMARY_LISTS=(RETRIED_JSON='[]' PENDING_JSON='[]' CONFIRMED_JSON='[]' EXHAUSTED_JSON='[]' UNREACHABLE_JSON='[]')
MIGRATED_ENTRY="[{\"name\":\"app\",\"old\":\"$D_386\",\"new\":\"$D_AMD\",\"created\":\"x\",\"released\":\"y\",\"run_url\":\"\"},
                 {\"name\":\"engine\",\"old\":\"$D_OLD\",\"new\":\"$D_AMD2\",\"created\":\"x\",\"released\":\"y\",\"run_url\":\"$SERVER/$REPO/actions/runs/602\"}]"
HANDED_ENTRY="[{\"name\":\"python\",\"digest\":\"$D_NEW\",\"release\":\"v1.0.1\",\"release_run_url\":\"$SERVER/$REPO/actions/runs/900\",\"merge_commit\":\"x\"}]"
reset summary-store-only
run_step summary GITHUB_STEP_SUMMARY="$FAKE/summary" IMAGES_CONFIGURED=2 IMAGES_CHECKED=2 UPDATES_FOUND=false STATE_CHANGED=true PERSIST_OUTCOME=success \
  "${SUMMARY_LISTS[@]}" MIGRATED_JSON="$MIGRATED_ENTRY" HANDED_OFF_JSON="$HANDED_ENTRY"
expect_rc "stored without a release: the summary step succeeds" $? 0
if grep -qF "All base images are up to date" "$FAKE/summary"; then pass "stored without a release: still up to date"; else fail "stored without a release: still up to date" "$(tr '\n' '|' < "$FAKE/summary")"; fi
if grep -qF "### 🔀 Switched to the linux/amd64 digest" "$FAKE/summary" \
   && grep -qF "| \`app\` | \`${D_386:0:19}…\` → \`${D_AMD:0:19}…\` | Stored digest is the old pick |" "$FAKE/summary"; then
  pass "switch: summary section"; else fail "switch: summary section" "$(tr '\n' '|' < "$FAKE/summary")"; fi
# The stored digest of a switch after the old pick's release is no old pick.
if grep -qF "| \`engine\` | \`${D_OLD:0:19}…\` → \`${D_AMD2:0:19}…\` | Release of the old pick succeeded: [run 602]($SERVER/$REPO/actions/runs/602) |" "$FAKE/summary"; then
  pass "switch after the old pick's release: evidence is the run"; else fail "switch after the old pick's release: evidence is the run" "$(tr '\n' '|' < "$FAKE/summary")"; fi
if grep -qF "or the release an earlier version dispatched for the old pick succeeded" "$FAKE/summary"; then
  pass "switch: the text covers both kinds of evidence"; else fail "switch: the text covers both kinds of evidence" "$(tr '\n' '|' < "$FAKE/summary")"; fi
if grep -qF "### 🤝 Already released with a Dependabot update" "$FAKE/summary" \
   && grep -qF "| \`python\` | \`v1.0.1\` | [run 900]($SERVER/$REPO/actions/runs/900) |" "$FAKE/summary"; then
  pass "handoff: summary section"; else fail "handoff: summary section" "$(tr '\n' '|' < "$FAKE/summary")"; fi
expect_eq "stored without a release: both say stored" "$(grep -c 'the digest is stored' "$FAKE/summary")" 2
reset summary-store-only-dry-run
run_step summary GITHUB_STEP_SUMMARY="$FAKE/summary" DRY_RUN=true IMAGES_CONFIGURED=2 IMAGES_CHECKED=2 UPDATES_FOUND=false STATE_CHANGED=true \
  "${SUMMARY_LISTS[@]}" MIGRATED_JSON="$MIGRATED_ENTRY" \
  HANDED_OFF_JSON='[{"name":"python","digest":"x","release":"","release_run_url":"","merge_commit":"x"}]'
expect_eq "stored without a release, dry run: says not stored" "$(grep -c 'the digest is not stored (dry run)' "$FAKE/summary")" 2
if grep -qF '| `python` | - | - |' "$FAKE/summary"; then pass "handoff without release fields: dashes"; else fail "handoff without release fields: dashes" "$(tr '\n' '|' < "$FAKE/summary")"; fi
reset summary-no-store-only
run_step summary GITHUB_STEP_SUMMARY="$FAKE/summary" IMAGES_CONFIGURED=1 IMAGES_CHECKED=1 UPDATES_FOUND=false "${SUMMARY_LISTS[@]}" MIGRATED_JSON='[]' HANDED_OFF_JSON='[]'
if grep -qE "Switched to the linux/amd64|Already released with a Dependabot" "$FAKE/summary"; then fail "nothing stored without a release: no sections" "present"; else pass "nothing stored without a release: no sections"; fi

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
  local handoffs
  run_step handoff || return 1
  handoffs=$(out handoffs)
  run_step check HANDOFFS="$handoffs" "$@" || return 1
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

# The first check after the upgrade, on an image whose stored digest is the
# old 386 pick: switched once, without a commit or a dispatch; then quiet.
reset cycle-migration
migration_setup; release_tagged 1.0.0; git -C "$FAKE/repo" push -q origin HEAD
built "ghcr.io/acme/base@$D_AMD" 2026-11-05T19:27:56Z; latest_release 2026-11-08T08:00:00Z
dispatch_returns 701; COMMITS=$(origin_count)
cycle; expect_rc "switch cycle 1: succeeds" $? 0
expect_eq "switch cycle 1: switched" "$(checked migrated-images)" '["app"]'
expect_eq "switch cycle 1: persist stored the amd64 digest" "$(var APP_DIGEST)" "$D_AMD"
expect_eq "switch cycle 1: no commit" "$(origin_count)" "$COMMITS"
if [ -f "$FAKE/dispatch-path" ]; then fail "switch cycle 1: nothing dispatched" "dispatched"; else pass "switch cycle 1: nothing dispatched"; fi
if has_var APP_DIGEST_PENDING; then fail "switch cycle 1: no record" "recorded"; else pass "switch cycle 1: no record"; fi
cycle; expect_rc "switch cycle 2: succeeds" $? 0
expect_eq "switch cycle 2: up to date" "$(checked updates-found) $(checked migrated-images) $(checked state-changed)" 'false [] false'
# The 386 manifest moves alone (rebuilt by docker-library): nothing for us.
index ghcr.io/acme/base:stable linux/amd64="$D_AMD" linux/arm64="$D_ARM" linux/386="$D_3862"
cycle; expect_rc "switch cycle 3 (386 rebuilt alone): succeeds" $? 0
expect_eq "switch cycle 3: no release" "$(checked updates-found) $(checked state-changed)" 'false false'
# The amd64 manifest moves: released.
index ghcr.io/acme/base:stable linux/amd64="$D_AMD2" linux/arm64="$D_ARM" linux/386="$D_3862"
cycle; expect_rc "switch cycle 4 (amd64 rebuilt): succeeds" $? 0
expect_eq "switch cycle 4: released" "$(checked new-images)" '["app"]'
expect_eq "switch cycle 4: run recorded for the amd64 digest" "$(var APP_DIGEST_PENDING | jq -c '[.digest, .run_id]')" "[\"$D_AMD2\",701]"

# A Dependabot tag bump whose release the Dependabot module handed over: the
# monitor stores the new tag's digest instead of releasing once more.
reset cycle-tag-bump-handoff
put src/app/Dockerfile $'FROM python:3.14-alpine AS prod\n'
config '{"name": "python", "image": "python", "dockerfile": "src/app/Dockerfile", "variable": "PYTHON_DIGEST"}'
git -C "$FAKE/repo" add -A; commit "feat: app"; release_tagged 1.0.0; git -C "$FAKE/repo" push -q origin HEAD
manifest python:3.14-alpine "$D_OLD"; manifest python:3.15-alpine "$D_NEW"
set_var PYTHON_DIGEST "$D_OLD"; var_updated PYTHON_DIGEST 2026-11-09T00:00:00Z
put src/app/Dockerfile $'FROM python:3.15-alpine AS prod\n'
git -C "$FAKE/repo" add -A; commit "fix(docker): bump python from 3.14-alpine to 3.15-alpine"; MERGE=$(head_sha)
release_tagged 1.0.1; git -C "$FAKE/repo" push -q origin HEAD
note "$MERGE" "$(note_json "$MERGE" "{\"PYTHON_DIGEST\": \"$D_NEW\"}" 2026-11-10T12:00:00Z)"
COMMITS=$(origin_count); dispatch_returns 801
resolved_cycle; expect_rc "handoff cycle 1 (after the bump): succeeds" $? 0
expect_eq "handoff cycle 1: handed over, no update" "$(checked handed-off-images) $(checked new-images)" '["python"] []'
expect_eq "handoff cycle 1: the new tag's digest is stored" "$(var PYTHON_DIGEST)" "$D_NEW"
expect_eq "handoff cycle 1: no commit" "$(origin_count)" "$COMMITS"
if [ -f "$FAKE/dispatch-path" ]; then fail "handoff cycle 1: nothing dispatched" "dispatched"; else pass "handoff cycle 1: nothing dispatched"; fi
resolved_cycle; expect_rc "handoff cycle 2: succeeds" $? 0
expect_eq "handoff cycle 2: up to date" "$(checked updates-found) $(checked handed-off-images)" 'false []'
# The new tag moves: the note is for the old digest, so this is released.
manifest python:3.15-alpine "$D_NEWER"
resolved_cycle; expect_rc "handoff cycle 3 (new tag moved): succeeds" $? 0
expect_eq "handoff cycle 3: released" "$(checked new-images)" '["python"]'
expect_eq "handoff cycle 3: run recorded" "$(var PYTHON_DIGEST_PENDING | jq -c '[.digest, .run_id]')" "[\"$D_NEWER\",801]"

echo ""
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
