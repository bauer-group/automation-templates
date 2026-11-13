#!/usr/bin/env bash
#
# Regression test for issue #104: `attest-sbom: true` never attested the image.
#
# sbom-attest passed the SBOM to actions/attest-sbom as `subject-path` and never set
# `sbom-path`, so actions/attest ran in its provenance mode with the SBOM FILE as
# subject. The run was green and an attestation existed - but nothing named the
# image, and `gh attestation verify oci://<image>@<digest>` found nothing. Green,
# plausible, wrong. This pins:
#
#   - sbom-attest: a full subject selects image mode, no subject keeps the file
#     provenance (the CRA release pipeline relies on it), and half a subject, a
#     malformed digest, a tagged name or push-to-registry without an image fail
#     instead of falling back to the file;
#   - the two attest steps hand actions/attest exactly the inputs that select
#     their mode: image = subject-name + subject-digest + sbom-path, file =
#     subject-path and no sbom-path;
#   - docker-build derives the image name without its tag (keeping a registry
#     port), attests only a pushed image, and passes the push digest.
#
# Step scripts are extracted from the action files at runtime rather than copied
# here, so a regression in the real script fails this test. `syft` is stubbed.
#
# Usage: bash .github/actions/sbom-attest/tests/image-subject.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ATTEST_ACTION="$SCRIPT_DIR/../action.yml"
DOCKER_ACTION="$SCRIPT_DIR/../../docker-build/action.yml"

for f in "$ATTEST_ACTION" "$DOCKER_ACTION"; do
  if [ ! -f "$f" ]; then
    echo "FATAL: $f not found"
    exit 1
  fi
done
command -v jq >/dev/null 2>&1 || { echo "FATAL: jq is required to run this test"; exit 1; }

# step_block <file> <id>: the step's own lines, from its `- name:` up to the next step.
step_block() {
  awk -v step="      id: $2" '
    /^    - / { if (found) exit; buf = $0; next }
    $0 == step  { found = 1; print buf; print; next }
    found       { print; next }
    buf != ""   { buf = buf "\n" $0 }
  ' "$1"
}

# run_body <block>: the step's `run:` block, with the 8-space indent stripped.
run_body() {
  printf '%s\n' "$1" | awk '
    /^      run: \|$/ { collecting = 1; next }
    collecting {
      if ($0 == "") { print ""; next }
      if ($0 ~ /^        /) { sub(/^        /, ""); print; next }
      exit
    }
  '
}

# with_keys <block>: the keys of the step's `with:` map, comments dropped.
with_keys() {
  printf '%s\n' "$1" | awk '
    /^      with:$/                 { on = 1; next }
    on && /^        #/              { next }
    on && /^        [a-z-]+:/       { sub(/^ +/, ""); sub(/:.*/, ""); print; next }
    on && !/^         /             { exit }
  ' | sort | tr '\n' ' ' | sed 's/ $//'
}

require() {
  if [ -z "$2" ]; then
    echo "FATAL: step '$1' not found - it was renamed, removed or re-indented; update this test."
    exit 1
  fi
}

FAILED=0
pass() { echo "  ok   $1"; }
fail() { echo "  FAIL $1"; FAILED=$((FAILED + 1)); }
check() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (expected '$3', got '$2')"; fi; }
contains() { if printf '%s' "$2" | grep -qF -- "$3"; then pass "$1"; else fail "$1 (missing: $3)"; fi; }
lacks() { if printf '%s' "$2" | grep -qF -- "$3"; then fail "$1 (found: $3)"; else pass "$1"; fi; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# --- sbom-attest: subject validation ------------------------------------------------

VALIDATE=$(step_block "$ATTEST_ACTION" validate); require validate "$VALIDATE"
run_body "$VALIDATE" > "$WORK/validate.sh"

echo '{"bomFormat":"CycloneDX","components":[]}' > "$WORK/sbom.json"
echo '{not json' > "$WORK/broken.json"
DIGEST="sha256:$(printf 'a%.0s' $(seq 64))"

# validate <sbom> <name> <digest> <push>: runs the step, sets EXIT, MODE and OUT.
validate() {
  : > "$WORK/out"
  SBOM_PATH="$1" SUBJECT_NAME="$2" SUBJECT_DIGEST="$3" PUSH_TO_REGISTRY="$4" \
    GITHUB_OUTPUT="$WORK/out" bash -e "$WORK/validate.sh" > "$WORK/log" 2>&1
  EXIT=$?
  MODE=$(sed -n 's/^mode=//p' "$WORK/out")
  OUT=$(cat "$WORK/log")
}

echo "sbom-attest: subject validation"

validate "$WORK/sbom.json" "" "" false
check "no subject -> file mode" "$EXIT/$MODE" "0/file"

validate "$WORK/sbom.json" "ghcr.io/org/image" "$DIGEST" false
check "name + digest -> image mode" "$EXIT/$MODE" "0/image"

validate "$WORK/sbom.json" "registry.local:5000/org/image" "$DIGEST" true
check "registry port is not mistaken for a tag" "$EXIT/$MODE" "0/image"

validate "$WORK/sbom.json" "ghcr.io/org/image" "" false
check "name without digest fails, no fallback to file" "$EXIT/$MODE" "1/"

validate "$WORK/sbom.json" "" "$DIGEST" false
check "digest without name fails, no fallback to file" "$EXIT/$MODE" "1/"

validate "$WORK/sbom.json" "ghcr.io/org/image" "sha256:abc" false
check "malformed digest fails" "$EXIT/$MODE" "1/"

validate "$WORK/sbom.json" "ghcr.io/org/image:1.2.3" "$DIGEST" false
check "tagged subject-name fails" "$EXIT/$MODE" "1/"
contains "  and says why" "$OUT" "without tag"

validate "$WORK/sbom.json" "" "" true
check "push-to-registry without an image fails" "$EXIT/$MODE" "1/"

validate "$WORK/missing.json" "" "" false
check "missing SBOM fails" "$EXIT" 1

validate "$WORK/broken.json" "" "" false
check "invalid JSON fails" "$EXIT" 1

# --- sbom-attest: what actions/attest receives ------------------------------------

echo "sbom-attest: attest step wiring"

IMAGE_STEP=$(step_block "$ATTEST_ACTION" attest-image); require attest-image "$IMAGE_STEP"
FILE_STEP=$(step_block "$ATTEST_ACTION" attest-file); require attest-file "$FILE_STEP"

contains "image step uses actions/attest@v4" "$IMAGE_STEP" "uses: actions/attest@v4"
contains "image step runs only in image mode" "$IMAGE_STEP" "if: steps.validate.outputs.mode == 'image'"
check "image step passes the SBOM as predicate and the image as subject" \
  "$(with_keys "$IMAGE_STEP")" "create-storage-record push-to-registry sbom-path subject-digest subject-name"
contains "image step needs no artifact-metadata permission" "$IMAGE_STEP" "create-storage-record: false"

contains "file step uses actions/attest@v4" "$FILE_STEP" "uses: actions/attest@v4"
contains "file step runs only in file mode" "$FILE_STEP" "if: steps.validate.outputs.mode == 'file'"
check "file step passes only subject-path (provenance for the file)" "$(with_keys "$FILE_STEP")" "subject-path"

lacks "deprecated actions/attest-sbom is gone" "$(cat "$ATTEST_ACTION")" "actions/attest-sbom@"

# --- docker-build: subject and gating ---------------------------------------------

echo "docker-build: subject derivation and gating"

SBOM_STEP=$(step_block "$DOCKER_ACTION" sbom); require sbom "$SBOM_STEP"
DB_ATTEST=$(step_block "$DOCKER_ACTION" attest-sbom); require attest-sbom "$DB_ATTEST"

run_body "$SBOM_STEP" | sed 's/\${{ inputs.sbom-format }}/cyclonedx/g' > "$WORK/sbom-step.sh"
mkdir -p "$WORK/bin"
printf '#!/usr/bin/env bash\nwhile [ "$#" -gt 0 ]; do [ "$1" = --file ] && echo "{}" > "$2"; shift; done\n' > "$WORK/bin/syft"
chmod +x "$WORK/bin/syft"

# sbom_step <first-tag> <attest> <pushed>: runs the SBOM step, sets IMAGE and LOG.
sbom_step() {
  : > "$WORK/out"
  ( cd "$WORK" && mkdir -p docker-build-reports && \
    META_TAGS="$1"$'\n'"other.registry/org/image:1.2.3" ATTEST_SBOM="$2" IMAGE_PUSHED="$3" \
    GITHUB_OUTPUT="$WORK/out" GITHUB_ACTION_PATH="/nonexistent" PATH="$WORK/bin:$PATH" \
    bash -e sbom-step.sh ) > "$WORK/log" 2>&1
  IMAGE=$(sed -n 's/^image-name=//p' "$WORK/out")
  LOG=$(cat "$WORK/log")
}

sbom_step "ghcr.io/org/image:1.2.3" true true
check "tag stripped from the primary tag" "$IMAGE" "ghcr.io/org/image"
lacks "no notice when the image was pushed" "$LOG" "SBOM not attested"

sbom_step "registry.local:5000/org/image:sha-abc" true true
check "registry port kept, tag stripped" "$IMAGE" "registry.local:5000/org/image"

sbom_step "registry.local:5000/org/image" true true
check "untagged reference with a port is left whole" "$IMAGE" "registry.local:5000/org/image"

sbom_step "ghcr.io/org/image:pr-7" true false
contains "a build without push says why it attests nothing" "$LOG" "::notice title=SBOM not attested::"

sbom_step "ghcr.io/org/image:pr-7" false false
lacks "no notice when attestation was not requested" "$LOG" "SBOM not attested"

contains "attests only a pushed image" "$DB_ATTEST" "steps.build-info.outputs.pushed == 'true'"
contains "passes the derived image name" "$DB_ATTEST" "subject-name: \${{ steps.sbom.outputs.image-name }}"
contains "passes the push digest of either attempt or the single-build fast path" "$DB_ATTEST" \
  "subject-digest: \${{ steps.build.outputs.digest || steps.build-retry.outputs.digest || steps.push-scanned.outputs.digest }}"

echo
if [ "$FAILED" -gt 0 ]; then
  echo "$FAILED check(s) failed"
  exit 1
fi
echo "all checks passed"
