#!/usr/bin/env bash
#
# Behavioural test for the base image check of ../modules-auto-maintenance.yml
# (steps base-images, persist-migrations and summary).
#
# For a multi-arch index the check compared .manifests | sort_by(.platform
# .architecture) | .[0] - the linux/386 manifest whenever an index has one,
# as "386" sorts before "amd64". The images built on these bases are amd64,
# and docker-library builds each architecture separately: 386 can lag an
# amd64 security rebuild or be rebuilt alone. The check now compares
# linux/amd64, and recognises the 386 digests the previous version stored:
#
#   386 + amd64 index                       -> the amd64 digest is compared
#   index without linux/amd64 (arm64 only)  -> the old pick, as before
#   amd64 with and without variant          -> the one without variant
#   single-platform manifest                -> .config.digest, as before
#   stored = this index's old 386 pick and
#     the amd64 image is more than 48h
#     older than the latest release         -> migrated: stored without a
#                                              commit or release, not an update
#     ... created at most 48h before the
#         release, or after it              -> update (released), notice
#     ... creation time unreadable or the
#         1970 placeholder                  -> update, notice (one retry)
#     ... no release / release unreadable   -> update, notice
#     ... dry run                           -> named, nothing stored
#   stored = neither pick (both changed)    -> update, nothing else read
#   real update and migration in one run    -> only the update is released;
#                                              it is still stored by
#                                              "Persist new digests" only
#
# The step bodies are extracted from the workflow at runtime rather than
# duplicated here and run the way a `shell: bash` step runs (-eo pipefail).
# `gh` and `docker` are replaced by stubs that keep repository variables,
# manifests, image configs and the latest release in a directory.
#
# Usage: bash .github/workflows/tests/auto-maintenance-base-images.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_FILE="$SCRIPT_DIR/../modules-auto-maintenance.yml"

if [ ! -f "$WORKFLOW_FILE" ]; then
  echo "FATAL: workflow not found at $WORKFLOW_FILE"
  exit 1
fi
for TOOL in jq git; do
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
# Prints the YAML of the step with the given id, from its id to the next step.
step_yaml() {
  awk -v id="        id: $1" '$0 == id { found = 1 } found && /^      - / { exit } found { print }' "$WORKFLOW_FILE"
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

for STEP in base-images persist-migrations summary detect-changes; do
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
step_has() {
  local name="$1" step="$2" pattern="$3"
  if step_yaml "$step" | grep -qF -- "$pattern"; then
    pass "$name"
  else
    fail "$name" "'$pattern' not found in step $step"
  fi
}

# The filters are shared with the base image monitor and the Dependabot
# module; this pins this module's copy to the agreed text.
NEW_FILTER='if .config.digest then
  .config.digest
elif .manifests then
  ([.manifests[] | select(.platform.os == "linux" and .platform.architecture == "amd64")]
    | (map(select((.platform.variant // "") == "")) + .) | first | .digest)
  // (.manifests | sort_by(.platform.architecture) | .[0].digest)
else
  empty
end'
LEGACY_FILTER='if .config.digest then .config.digest elif .manifests then .manifests | sort_by(.platform.architecture) | .[0].digest else empty end'
STEP_BODY="$(cat "$WORK/base-images.sh")"
if [[ "$STEP_BODY" == *"$NEW_FILTER"* ]]; then pass "the compared digest uses the shared filter verbatim"; else fail "the compared digest uses the shared filter verbatim" "filter text differs"; fi
if [[ "$STEP_BODY" == *"$LEGACY_FILTER"* ]]; then pass "the previous pick uses the shared filter verbatim"; else fail "the previous pick uses the shared filter verbatim" "filter text differs"; fi
if grep -q 'sort_by(.platform.architecture) | .\[0\].digest$' "$WORK/base-images.sh"; then
  fail "the old pick is no longer the compared digest" "a bare sort_by pick is back"
else
  pass "the old pick is no longer the compared digest"
fi

step_has "migrations are stored only outside a dry run" persist-migrations \
  "        if: steps.base-images.outputs.migration-updates != '' && steps.base-images.outputs.migration-updates != '{}' && inputs.dry-run != true"
step_has "migrations are stored from their own output" persist-migrations \
  "MIGRATION_UPDATES: \${{ steps.base-images.outputs.migration-updates }}"
# Real updates: exactly as before - stored last, after their commit.
step_has "real updates are still stored only after their commit" persist "          && steps.commit.outputs.committed == 'true'"
step_has "real updates are still stored only after every earlier step succeeded" persist "          success()"
step_has "real updates are not stored in a dry run" persist "          && inputs.dry-run != true"
step_has "persist stores only the real updates" persist \
  "VARIABLE_UPDATES: \${{ steps.base-images.outputs.variable-updates }}"
if step_yaml persist | grep -q "migration"; then
  fail "persist does not see migrations" "the step mentions them"
else
  pass "persist does not see migrations"
fi
step_has "the commit names only the updated images" commit \
  "UPDATED_IMAGES_JSON: \${{ steps.base-images.outputs.updated-images }}"
step_has "the summary names the migrated images" summary \
  "MIGRATED_IMAGES_JSON: \${{ steps.base-images.outputs.migrated-images }}"
step_has "the summary knows whether they were stored" summary \
  "MIGRATION_STORED: \${{ steps.persist-migrations.outputs.all-stored }}"
# The summary states the margin in words; it must be the one the check applies.
step_has "the check migrates only beyond a 48h margin" base-images "          MIGRATION_MARGIN_HOURS=48"
step_has "the summary names the same margin" summary "the amd64 image is more than 48h older than the latest release"
if awk '$0 == "        id: base-images" { b = NR } $0 == "        id: persist-migrations" { m = NR } $0 == "        id: commit" { c = NR }
        END { exit !(b && m && c && b < m && m < c) }' "$WORKFLOW_FILE"; then
  pass "migrations are stored after the check, before anything is committed"
else
  fail "migrations are stored after the check, before anything is committed" "step order changed"
fi
static_check "job has a timeout" "    timeout-minutes: "

# --- stubs --------------------------------------------------------------------
# State lives in $FAKE: vars/<NAME> (repository variables), manifests/<ref>,
# images/<ref> (image config JSON, as `imagetools inspect --format
# '{{json .Image}}'` prints it), images/<ref>.failures (count of failing
# reads left), release.json or release.error (latest release), fail-set/<NAME>.
# A ref is stored with / : @ as _. Every call is logged.
mkdir -p "$WORK/bin"
cat > "$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
echo "gh $*" >> "$FAKE/calls.log"
case "$1 $2" in
  "variable get")
    [ -f "$FAKE/vars/$3" ] || { echo "variable $3 was not found" >&2; exit 1; }
    cat "$FAKE/vars/$3"; echo; exit 0 ;;
  "variable set")
    [ "$4" = "--body" ] || { echo "unexpected: $*" >&2; exit 2; }
    [ ! -f "$FAKE/fail-set/$3" ] || { echo "HTTP 500" >&2; exit 1; }
    printf '%s' "$5" > "$FAKE/vars/$3"; exit 0 ;;
esac
if [ "$1" = "api" ] && [ "$2" = "repos/$GITHUB_REPOSITORY/releases/latest" ] && [ "$3" = "--jq" ]; then
  if [ -f "$FAKE/release.error" ]; then cat "$FAKE/release.error" >&2; exit 1; fi
  [ -f "$FAKE/release.json" ] || { echo "gh: Not Found (HTTP 404)" >&2; exit 1; }
  jq -r "$4" "$FAKE/release.json"; exit 0
fi
echo "unexpected gh call: $*" >&2
exit 2
STUB
cat > "$WORK/bin/docker" <<'STUB'
#!/usr/bin/env bash
echo "docker $*" >> "$FAKE/calls.log"
if [ "$1 $2" = "manifest inspect" ]; then
  f="$FAKE/manifests/$(printf '%s' "$3" | tr '/:@' '___')"
  [ -f "$f" ] || { echo "manifest unknown"; exit 1; }
  cat "$f"; exit 0
fi
if [ "$1 $2 $3" = "buildx imagetools inspect" ] && [ "$5 $6" = "--format {{json .Image}}" ]; then
  f="$FAKE/images/$(printf '%s' "$4" | tr '/:@' '___')"
  if [ -f "$f.failures" ] && [ "$(cat "$f.failures")" -gt 0 ]; then
    echo $(( $(cat "$f.failures") - 1 )) > "$f.failures"
    echo "ERROR: failed to do request: 503 Service Unavailable" >&2; exit 1
  fi
  [ -f "$f" ] || { echo "ERROR: $4: not found" >&2; exit 1; }
  cat "$f"; exit 0
fi
echo "unexpected docker call: $*" >&2
exit 2
STUB
# The check backs off between attempts; the test only records the wait.
printf '#!/usr/bin/env bash\necho "sleep $*" >> "$FAKE/calls.log"\n' > "$WORK/bin/sleep"
chmod +x "$WORK/bin/gh" "$WORK/bin/docker" "$WORK/bin/sleep"

REPO="acme/app"
# python:3.15-alpine on 2026-11-12: the 386 manifest is what the previous
# version stored, the amd64 manifest what is compared now.
D386="sha256:8e0a3ebb91f875d149b3b00900ae1f16100d4a3897a804678e1bdd0d35c21fc1"
DAMD="sha256:a943ed02f4e22d024d2b4fc5083619497dfb9bc1c64c193861f3bc6d3074f5b1"
CREATED="2026-11-05T19:27:56.890249894Z"
DARM64="sha256:4e2ab06756120000000000000000000000000000000000000000000000000000"
DARMV7="sha256:16786d30244b0000000000000000000000000000000000000000000000000000"
DATT1="sha256:d939d511467200000000000000000000000000000000000000000000000000aa"
DATT2="sha256:1ebe467d10bd00000000000000000000000000000000000000000000000000bb"
D386_NEW="sha256:3860000000000000000000000000000000000000000000000000000000000386"
DAMD_V3="sha256:a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3a3"
DCFG_OLD="sha256:1111111111111111111111111111111111111111111111111111111111111111"
DCFG_NEW="sha256:2222222222222222222222222222222222222222222222222222222222222222"
DOTHER="sha256:9999999999999999999999999999999999999999999999999999999999999999"

PY='{"name": "python", "image": "python", "tag": "3.15-alpine", "variable": "PYTHON_DIGEST"}'
N8N='{"name": "n8n", "image": "n8nio/n8n", "tag": "stable", "variable": "N8N_DIGEST"}'
ARM='{"name": "arm-only", "image": "ghcr.io/acme/arm", "tag": "latest", "variable": "ARM_DIGEST"}'
CFG='{"name": "single", "image": "ghcr.io/acme/single", "tag": "stable", "variable": "SINGLE_DIGEST"}'

reset() {
  FAKE="$WORK/fake-$1"
  rm -rf "$FAKE"
  mkdir -p "$FAKE/vars" "$FAKE/manifests" "$FAKE/images" "$FAKE/fail-set" "$FAKE/repo"
  : > "$FAKE/calls.log"
  export FAKE
}
ref_file() { printf '%s' "$1" | tr '/:@' '___'; }
# index REF [DIGEST ARCH VARIANT]... - a multi-arch index; "-" for no variant,
# arch "unknown" for an attestation manifest.
index() {
  local ref="$1" json='[]'; shift
  while [ $# -gt 0 ]; do
    json=$(jq -c --arg d "$1" --arg a "$2" --arg v "$3" \
      '. + [{mediaType: "application/vnd.oci.image.manifest.v1+json", digest: $d,
             platform: ({architecture: $a, os: (if $a == "unknown" then "unknown" else "linux" end)}
                        + (if $v == "-" then {} else {variant: $v} end))}]' <<< "$json")
    shift 3
  done
  jq -n --argjson m "$json" '{schemaVersion: 2, mediaType: "application/vnd.oci.image.index.v1+json", manifests: $m}' \
    > "$FAKE/manifests/$(ref_file "$ref")"
}
# The index of python:3.15-alpine, in registry order.
python_index() {
  index "python:3.15-alpine" "$DAMD" amd64 - "$DATT1" unknown - "$DARMV7" arm v7 "$DARM64" arm64 v8 \
    "${1:-$D386}" 386 - "$DATT2" unknown -
}
single() { printf '{"schemaVersion": 2, "config": {"digest": "%s"}}' "$2" > "$FAKE/manifests/$(ref_file "$1")"; }
created() { jq -n --arg c "$2" '{architecture: "amd64", os: "linux", created: $c, config: {}}' > "$FAKE/images/$(ref_file "$1")"; }
release() { jq -n --arg c "$1" '{tag_name: "v1.4.0", created_at: $c}' > "$FAKE/release.json"; }
set_var() { printf '%s' "$2" > "$FAKE/vars/$1"; }
var() { cat "$FAKE/vars/$1" 2>/dev/null; }
out() { grep "^$1=" "$FAKE/output" | tail -n 1 | cut -d= -f2-; }
calls() { grep -c -- "$1" "$FAKE/calls.log"; }
# UPDATE_DETAILS as the check wrote it to GITHUB_ENV, without its empty lines.
details() { awk 'NR == 1 { d = substr($0, index($0, "<<") + 2); next } $0 == d { exit } NF { print }' "$FAKE/env"; }

# Runs a step with the environment of the workflow. Extra VAR=value pairs
# override the defaults.
run_step() {
  local step="$1"; shift
  : > "$FAKE/output"; : > "$FAKE/env"; : > "$FAKE/summary"
  (cd "$FAKE/repo" && env PATH="$WORK/bin:$PATH" GH_TOKEN=dummy \
    GITHUB_OUTPUT="$FAKE/output" GITHUB_ENV="$FAKE/env" GITHUB_STEP_SUMMARY="$FAKE/summary" \
    GITHUB_REPOSITORY="$REPO" BASE_IMAGES="[$PY]" DRY_RUN=false FAIL_ON_UNREACHABLE=true \
    "$@" bash -eo pipefail "$WORK/$step.sh") > "$FAKE/log" 2>&1
}

expect_eq() {
  local name="$1" got="$2" want="$3"
  if [ "$got" = "$want" ]; then pass "$name"; else fail "$name" "got '$got', want '$want'"; fi
}
expect_rc() {
  local name="$1" got="$2" want="$3"
  if [ "$got" -eq "$want" ]; then pass "$name"; else fail "$name" "exit $got, want $want - log: $(tr '\n' ' ' < "$FAKE/log" | cut -c1-600)"; fi
}
expect_log() {
  local name="$1" pattern="$2"
  if grep -qF -- "$pattern" "$FAKE/log"; then pass "$name"; else fail "$name" "'$pattern' not in the log"; fi
}
expect_no_log() {
  local name="$1" pattern="$2"
  if grep -qF -- "$pattern" "$FAKE/log"; then fail "$name" "'$pattern' in the log"; else pass "$name"; fi
}
# A run that released nothing and migrated nothing.
expect_quiet() {
  expect_eq "$1: no update" "$(out updates-found)" "false"
  expect_eq "$1: nothing to store" "$(out variable-updates)" "{}"
  expect_eq "$1: nothing migrated" "$(out migration-updates)" "{}"
  expect_eq "$1: no image config read" "$(calls "imagetools")" "0"
  expect_eq "$1: no release read" "$(calls "releases/latest")" "0"
}
# A run that releases IMAGE's amd64 digest as an update, not as a migration.
expect_update() {
  expect_eq "$1: update found" "$(out updates-found)" "true"
  expect_eq "$1: the image is released" "$(out updated-images)" '["python"]'
  expect_eq "$1: the amd64 digest is stored after the commit" "$(out variable-updates)" "{\"PYTHON_DIGEST\":\"$DAMD\"}"
  expect_eq "$1: nothing migrated" "$(out migration-updates)" "{}"
  expect_eq "$1: nothing migrated (names)" "$(out migrated-images)" "[]"
  expect_eq "$1: the commit names it" "$(details)" "- python (python:3.15-alpine): ${D386:0:12}... -> ${DAMD:0:12}..."
}

# === which digest is compared =================================================

reset amd64-unchanged
python_index; set_var PYTHON_DIGEST "$DAMD"
run_step base-images; expect_rc "386 + amd64 index, amd64 stored: step succeeds" $? 0
expect_quiet "386 + amd64 index, amd64 stored"
expect_log "386 + amd64 index, amd64 stored: the amd64 digest is the current one" "Current digest: ${DAMD:0:20}..."
expect_eq "386 + amd64 index, amd64 stored: counted as checked" "$(out images-checked)" "1"

# 386 rebuilt alone: the previous version released this with nothing changed.
reset only-386-rebuilt
python_index "$D386_NEW"; set_var PYTHON_DIGEST "$DAMD"
run_step base-images; expect_rc "386 rebuilt alone: step succeeds" $? 0
expect_quiet "386 rebuilt alone"

reset first-run
python_index
run_step base-images; expect_rc "nothing stored yet: step succeeds" $? 0
expect_eq "nothing stored yet: update found" "$(out updates-found)" "true"
expect_eq "nothing stored yet: the amd64 digest is stored after the commit" "$(out variable-updates)" "{\"PYTHON_DIGEST\":\"$DAMD\"}"
expect_eq "nothing stored yet: no migration" "$(out migration-updates)" "{}"
expect_eq "nothing stored yet: no image config read" "$(calls "imagetools")" "0"

reset variant
index "python:3.15-alpine" "$DAMD_V3" amd64 v3 "$D386" 386 - "$DAMD" amd64 -
set_var PYTHON_DIGEST "$DAMD"
run_step base-images; expect_rc "amd64 with and without variant: step succeeds" $? 0
expect_eq "amd64 with and without variant: the one without variant is compared" "$(out updates-found)" "false"

reset arm-only
index "ghcr.io/acme/arm:latest" "$DARM64" arm64 v8 "$DATT1" unknown - "$DARMV7" arm v7
set_var ARM_DIGEST "$DARMV7"
run_step base-images BASE_IMAGES="[$ARM]"; expect_rc "index without amd64: step succeeds" $? 0
expect_quiet "index without amd64, old pick stored"
set_var ARM_DIGEST "$DOTHER"
run_step base-images BASE_IMAGES="[$ARM]"; expect_rc "index without amd64, changed: step succeeds" $? 0
expect_eq "index without amd64, changed: update found" "$(out updates-found)" "true"
expect_eq "index without amd64, changed: the old pick is stored after the commit" "$(out variable-updates)" "{\"ARM_DIGEST\":\"$DARMV7\"}"
expect_eq "index without amd64, changed: no image config read" "$(calls "imagetools")" "0"

# === unchanged behaviour ======================================================

reset single
single "ghcr.io/acme/single:stable" "$DCFG_OLD"; set_var SINGLE_DIGEST "$DCFG_OLD"
run_step base-images BASE_IMAGES="[$CFG]"; expect_rc "single-platform manifest, unchanged: step succeeds" $? 0
expect_quiet "single-platform manifest, unchanged"
single "ghcr.io/acme/single:stable" "$DCFG_NEW"
run_step base-images BASE_IMAGES="[$CFG]"; expect_rc "single-platform manifest, changed: step succeeds" $? 0
expect_eq "single-platform manifest, changed: update found" "$(out updates-found)" "true"
expect_eq "single-platform manifest, changed: stored after the commit" "$(out variable-updates)" "{\"SINGLE_DIGEST\":\"$DCFG_NEW\"}"
expect_eq "single-platform manifest, changed: commit details" "$(details)" \
  "- single (ghcr.io/acme/single:stable): ${DCFG_OLD:0:12}... -> ${DCFG_NEW:0:12}..."
expect_eq "single-platform manifest, changed: no image config read" "$(calls "imagetools")" "0"

# 386 and amd64 both changed since the stored 386 digest: an update, nothing to weigh.
reset both-changed
python_index "$D386_NEW"; set_var PYTHON_DIGEST "$D386"
run_step base-images; expect_rc "stored digest is neither pick: step succeeds" $? 0
expect_update "stored digest is neither pick"
expect_eq "stored digest is neither pick: no image config read" "$(calls "imagetools")" "0"
expect_eq "stored digest is neither pick: no release read" "$(calls "releases/latest")" "0"

reset unreachable
python_index; set_var PYTHON_DIGEST "$DAMD"
run_step base-images BASE_IMAGES="[$PY, $N8N]"; expect_rc "unreachable image: the job fails" $? 1
expect_eq "unreachable image: named" "$(out unreachable-images)" '["n8nio/n8n:stable"]'
expect_eq "unreachable image: the other one was checked" "$(out images-checked)" "1"
expect_eq "unreachable image: nothing migrated" "$(out migration-updates)" "{}"
run_step base-images BASE_IMAGES="[$PY, $N8N]" FAIL_ON_UNREACHABLE=false
expect_rc "unreachable image, downgraded: step succeeds" $? 0
expect_log "unreachable image, downgraded: warned" "::warning::1 of 2 base image(s) could not be checked"

# === migration of the stored 386 digest =======================================

reset migrate
python_index; set_var PYTHON_DIGEST "$D386"
created "python@$DAMD" "$CREATED"; release "2026-11-08T09:00:00Z"
run_step base-images; expect_rc "migration: step succeeds" $? 0
expect_eq "migration: not an update" "$(out updates-found)" "false"
expect_eq "migration: nothing released" "$(out updated-images)" "[]"
expect_eq "migration: no new digest reported" "$(out new-digests)" "{}"
expect_eq "migration: nothing stored after a commit" "$(out variable-updates)" "{}"
expect_eq "migration: the amd64 digest is migrated" "$(out migration-updates)" "{\"PYTHON_DIGEST\":\"$DAMD\"}"
expect_eq "migration: named" "$(out migrated-images)" '["python"]'
expect_eq "migration: no commit details" "$(details)" ""
expect_eq "migration: the check itself stores nothing" "$(calls "variable set")" "0"
expect_eq "migration: the image config of the amd64 digest was read" "$(calls "imagetools inspect python@$DAMD")" "1"
expect_log "migration: the log names it" "Migrated python to its linux/amd64 digest"
expect_log "migration: the run log lists it" "Migrated to the linux/amd64 digest without a release: python"
expect_no_log "migration: no notice" "::notice::"
MIGRATION_UPDATES="$(out migration-updates)"
# Without a base image update and without file changes nothing is committed.
git init -q "$FAKE/repo"
run_step detect-changes BASE_IMAGES_UPDATED=false
expect_eq "migration: no commit, no release" "$(out updates-found)" "false"
run_step persist-migrations MIGRATION_UPDATES="$MIGRATION_UPDATES"
expect_rc "migration: persist step succeeds" $? 0
expect_eq "migration: stored" "$(var PYTHON_DIGEST)" "$DAMD"
expect_eq "migration: reported as stored" "$(out all-stored)" "true"
# The next run finds the amd64 digest and has nothing more to read.
: > "$FAKE/calls.log"
run_step base-images; expect_rc "after the migration: step succeeds" $? 0
expect_quiet "after the migration"

reset migrate-store-fails
touch "$FAKE/fail-set/PYTHON_DIGEST"; set_var PYTHON_DIGEST "$D386"
run_step persist-migrations MIGRATION_UPDATES="{\"PYTHON_DIGEST\":\"$DAMD\"}"
expect_rc "migration not stored: the job goes on" $? 0
expect_log "migration not stored: warned" "::warning::Could not store the migrated digest of PYTHON_DIGEST"
expect_eq "migration not stored: reported" "$(out all-stored)" "false"
expect_eq "migration not stored: the old digest stays" "$(var PYTHON_DIGEST)" "$D386"

# The amd64 image was rebuilt after our last release while 386 lagged.
reset created-after-release
python_index; set_var PYTHON_DIGEST "$D386"
created "python@$DAMD" "$CREATED"; release "2026-11-01T10:00:00Z"
run_step base-images; expect_rc "amd64 newer than the release: step succeeds" $? 0
expect_update "amd64 newer than the release"
expect_log "amd64 newer than the release: notice names the reason" \
  "::notice::python (python:3.15-alpine): released as an update - its stored digest is the previous linux/386 pick, but the linux/amd64 image ($CREATED) is not more than 48h older than the latest release (2026-11-01T10:00:00Z)"

# Same second: not older, so released.
reset created-same-second
python_index; set_var PYTHON_DIGEST "$D386"
created "python@$DAMD" "$CREATED"; release "2026-11-05T19:27:56Z"
run_step base-images; expect_rc "amd64 created in the release's second: step succeeds" $? 0
expect_update "amd64 created in the release's second"

# python:3.15-alpine on 2026-11-05 (Docker Hub): amd64 built 19:27:56, in the
# tag at 23:06; 386 in the tag since 20:06. A check of the previous version in
# between stored the 386 digest and released at 21:00 on the OLD amd64 image.
# The amd64 image is older than that release, but it was never shipped.
reset created-before-release-not-in-tag
python_index; set_var PYTHON_DIGEST "$D386"
created "python@$DAMD" "$CREATED"; release "2026-11-05T21:00:00Z"
run_step base-images; expect_rc "amd64 built before a release it missed: step succeeds" $? 0
expect_update "amd64 built before a release it missed"
expect_log "amd64 built before a release it missed: notice names the reason" \
  "but the linux/amd64 image ($CREATED) is not more than 48h older than the latest release (2026-11-05T21:00:00Z)"

# The margin is exclusive: exactly 48h (fractional seconds dropped) is released.
reset margin-exact
python_index; set_var PYTHON_DIGEST "$D386"
created "python@$DAMD" "$CREATED"; release "2026-11-07T19:27:56Z"
run_step base-images; expect_rc "amd64 exactly 48h older than the release: step succeeds" $? 0
expect_update "amd64 exactly 48h older than the release"

reset margin-passed
python_index; set_var PYTHON_DIGEST "$D386"
created "python@$DAMD" "$CREATED"; release "2026-11-07T19:27:57Z"
run_step base-images; expect_rc "amd64 48h and 1s older than the release: step succeeds" $? 0
expect_eq "amd64 48h and 1s older than the release: migrated" "$(out migration-updates)" "{\"PYTHON_DIGEST\":\"$DAMD\"}"
expect_eq "amd64 48h and 1s older than the release: not an update" "$(out updates-found)" "false"

reset created-unreadable
python_index; set_var PYTHON_DIGEST "$D386"; release "2026-11-08T09:00:00Z"
run_step base-images; expect_rc "creation time not readable: step succeeds" $? 0
expect_update "creation time not readable"
expect_eq "creation time not readable: read twice" "$(calls "imagetools inspect")" "2"
expect_eq "creation time not readable: one wait of 10s" "$(grep -c '^sleep 10$' "$FAKE/calls.log")" "1"
expect_log "creation time not readable: notice names the reason" \
  "but the creation time of the linux/amd64 image could not be read"

reset created-missing
python_index; set_var PYTHON_DIGEST "$D386"; release "2026-11-08T09:00:00Z"
jq -n '{architecture: "amd64", os: "linux", config: {}}' > "$FAKE/images/$(ref_file "python@$DAMD")"
run_step base-images; expect_rc "image without a creation time: step succeeds" $? 0
expect_update "image without a creation time"
expect_eq "image without a creation time: not read again" "$(calls "imagetools inspect")" "1"

# 1970-01-01 is the placeholder of reproducible builds, not a build time.
reset created-epoch-zero
python_index; set_var PYTHON_DIGEST "$D386"
created "python@$DAMD" "1970-01-01T00:00:00Z"; release "2026-11-08T09:00:00Z"
run_step base-images; expect_rc "creation time 1970 (reproducible build): step succeeds" $? 0
expect_update "creation time 1970 (reproducible build)"
expect_log "creation time 1970 (reproducible build): notice names the reason" \
  "but the linux/amd64 image has no usable creation time (1970-01-01T00:00:00Z)"

# nixpkgs dockerTools writes 1970-01-01T00:00:01Z; anything before 1980 is a
# placeholder, 1980-01-01 itself the lowest real SOURCE_DATE_EPOCH.
reset created-epoch-one
python_index; set_var PYTHON_DIGEST "$D386"
created "python@$DAMD" "1970-01-01T00:00:01Z"; release "2026-11-08T09:00:00Z"
run_step base-images; expect_rc "creation time 1970-01-01T00:00:01Z (nixpkgs): step succeeds" $? 0
expect_update "creation time 1970-01-01T00:00:01Z (nixpkgs)"
reset created-1980
python_index; set_var PYTHON_DIGEST "$D386"
created "python@$DAMD" "1980-01-01T00:00:00Z"; release "2026-11-08T09:00:00Z"
run_step base-images; expect_rc "creation time 1980-01-01 (SOURCE_DATE_EPOCH floor): step succeeds" $? 0
expect_eq "creation time 1980-01-01 (SOURCE_DATE_EPOCH floor): migrated" "$(out migration-updates)" "{\"PYTHON_DIGEST\":\"$DAMD\"}"

# Image build times carry nanoseconds; a date that does not read fractions
# (uutils date on ubuntu-latest may not) must still get a time, or every
# stored 386 pick would be released at once.
mkdir -p "$WORK/strictdate"
REAL_DATE=$(command -v date)
cat > "$WORK/strictdate/date" <<STRICT
#!/usr/bin/env bash
for a in "\$@"; do
  case "\$a" in *T*:*:*.[0-9]*) echo "date: invalid date '\$a'" >&2; exit 1 ;; esac
done
exec "$REAL_DATE" "\$@"
STRICT
chmod +x "$WORK/strictdate/date"
reset migrate-strict-date
python_index; set_var PYTHON_DIGEST "$D386"
created "python@$DAMD" "$CREATED"; release "2026-11-08T09:00:00Z"
run_step base-images PATH="$WORK/strictdate:$WORK/bin:$PATH"; expect_rc "build time in nanoseconds, date without fractions: step succeeds" $? 0
expect_eq "build time in nanoseconds, date without fractions: migrated" "$(out migration-updates)" "{\"PYTHON_DIGEST\":\"$DAMD\"}"
expect_eq "build time in nanoseconds, date without fractions: not an update" "$(out updates-found)" "false"

# Only RFC 3339 counts: `date -d` would read these as a date long before the
# release and switch the digest without evidence (as the monitor, released).
for NOT_RFC3339 in "2024-01-01" "2024-01-01 00:00:00" "Jan 1 2024" "2 years ago" "2024-01-01t00:00:00z"; do
  reset created-not-rfc3339
  python_index; set_var PYTHON_DIGEST "$D386"
  created "python@$DAMD" "$NOT_RFC3339"; release "2026-11-08T09:00:00Z"
  run_step base-images; expect_rc "creation time '$NOT_RFC3339': step succeeds" $? 0
  expect_update "creation time '$NOT_RFC3339'"
  expect_log "creation time '$NOT_RFC3339': notice names the reason" \
    "but the creation time of the linux/amd64 image could not be read"
done

reset created-retry
python_index; set_var PYTHON_DIGEST "$D386"
created "python@$DAMD" "$CREATED"; release "2026-11-08T09:00:00Z"
echo 1 > "$FAKE/images/$(ref_file "python@$DAMD").failures"
run_step base-images; expect_rc "creation time read on the retry: step succeeds" $? 0
expect_eq "creation time read on the retry: migrated" "$(out migration-updates)" "{\"PYTHON_DIGEST\":\"$DAMD\"}"
expect_eq "creation time read on the retry: not an update" "$(out updates-found)" "false"

reset no-release
python_index; set_var PYTHON_DIGEST "$D386"; created "python@$DAMD" "$CREATED"
run_step base-images; expect_rc "no release yet: step succeeds" $? 0
expect_update "no release yet"
expect_log "no release yet: notice names the reason" "but the repository has no release yet"

reset release-unreadable
python_index; set_var PYTHON_DIGEST "$D386"; created "python@$DAMD" "$CREATED"
echo "gh: Server Error (HTTP 502)" > "$FAKE/release.error"
run_step base-images; expect_rc "latest release not readable: step succeeds" $? 0
expect_update "latest release not readable"
expect_log "latest release not readable: notice names the reason" \
  "but the latest release could not be read (gh: Server Error (HTTP 502))"

reset release-garbled
python_index; set_var PYTHON_DIGEST "$D386"; created "python@$DAMD" "$CREATED"
jq -n '{tag_name: "v1.4.0", created_at: null}' > "$FAKE/release.json"
run_step base-images; expect_rc "release without a creation time: step succeeds" $? 0
expect_update "release without a creation time"

reset dry-run
python_index; set_var PYTHON_DIGEST "$D386"
created "python@$DAMD" "$CREATED"; release "2026-11-08T09:00:00Z"
run_step base-images DRY_RUN=true; expect_rc "dry run: step succeeds" $? 0
expect_eq "dry run: named" "$(out migrated-images)" '["python"]'
expect_eq "dry run: not an update" "$(out updates-found)" "false"
expect_eq "dry run: nothing stored" "$(calls "variable set")" "0"
expect_eq "dry run: the old digest stays" "$(var PYTHON_DIGEST)" "$D386"
expect_log "dry run: reported" "DRY RUN: Would set variable PYTHON_DIGEST"

# Two candidates, one release lookup; next to them a real update.
reset mixed
python_index; set_var PYTHON_DIGEST "$D386"
index "n8nio/n8n:stable" "$DAMD_V3" amd64 - "$D386_NEW" 386 -; set_var N8N_DIGEST "$D386_NEW"
created "python@$DAMD" "$CREATED"; created "n8nio/n8n@$DAMD_V3" "2026-10-30T08:00:00Z"
release "2026-11-08T09:00:00Z"
single "ghcr.io/acme/single:stable" "$DCFG_NEW"; set_var SINGLE_DIGEST "$DCFG_OLD"
run_step base-images BASE_IMAGES="[$PY, $N8N, $CFG]"; expect_rc "migrations next to an update: step succeeds" $? 0
expect_eq "migrations next to an update: the release is read once" "$(calls "releases/latest")" "1"
expect_eq "migrations next to an update: both migrated" "$(out migration-updates)" \
  "{\"PYTHON_DIGEST\":\"$DAMD\",\"N8N_DIGEST\":\"$DAMD_V3\"}"
expect_eq "migrations next to an update: both named" "$(out migrated-images)" '["python","n8n"]'
expect_eq "migrations next to an update: update found" "$(out updates-found)" "true"
expect_eq "migrations next to an update: only the update is released" "$(out updated-images)" '["single"]'
expect_eq "migrations next to an update: only the update waits for the commit" "$(out variable-updates)" \
  "{\"SINGLE_DIGEST\":\"$DCFG_NEW\"}"
expect_eq "migrations next to an update: only the update is in the commit" "$(details)" \
  "- single (ghcr.io/acme/single:stable): ${DCFG_OLD:0:12}... -> ${DCFG_NEW:0:12}..."

# === job summary ==============================================================

summary_env=(HAS_BASE_IMAGES=true BASE_IMAGES_UPDATED=false UPDATED_IMAGES_JSON='[]' NEW_DIGESTS_JSON='{}'
  UPDATES_FOUND=false HAS_FILE_CHANGES=false COMMITTED="" CONFIG_FILE=config.json TOKEN_SOURCE=MAINTENANCE_TOKEN
  HAS_NODE=false HAS_PYTHON=false HAS_DOTNET=false HAS_GO=false HAS_VALIDATION=false PERSIST_OUTCOME=skipped)
summary_has() {
  if grep -qF -- "$2" "$FAKE/summary"; then pass "$1"; else fail "$1" "'$2' not in: $(tr '\n' ' ' < "$FAKE/summary")"; fi
}
summary_lacks() {
  if grep -qF -- "$2" "$FAKE/summary"; then fail "$1" "'$2' in the summary"; else pass "$1"; fi
}
reset summary
run_step summary "${summary_env[@]}" MIGRATED_IMAGES_JSON='["python"]' MIGRATION_STORED=true
expect_rc "summary, migrated: step succeeds" $? 0
summary_has "summary, migrated: says so" "Moved to the linux/amd64 digest without a release"
summary_has "summary, migrated: names the image" '- `python`'
summary_has "summary, migrated: still up to date" "All base images are up to date."
summary_lacks "summary, migrated and stored: no warning" "Not stored"
run_step summary "${summary_env[@]}" MIGRATED_IMAGES_JSON='["python"]' MIGRATION_STORED=""
summary_has "summary, migration not stored: warns" "Not stored. The next run checks these images again."
run_step summary "${summary_env[@]}" MIGRATED_IMAGES_JSON='["python"]' MIGRATION_STORED="" DRY_RUN=true
summary_has "summary, dry run: nothing stored" "Dry run: not stored."
run_step summary "${summary_env[@]}" MIGRATED_IMAGES_JSON='[]' MIGRATION_STORED=""
summary_lacks "summary, nothing migrated: not mentioned" "linux/amd64"
run_step summary "${summary_env[@]}" MIGRATED_IMAGES_JSON="" MIGRATION_STORED="" HAS_BASE_IMAGES=""
expect_rc "summary, no base images: step succeeds" $? 0
summary_lacks "summary, no base images: no base image section" "Base Images"

echo ""
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
