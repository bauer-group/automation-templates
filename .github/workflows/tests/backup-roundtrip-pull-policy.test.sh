#!/usr/bin/env bash
#
# Real-Docker test for the two upgrade checks of
# ../modules-backup-roundtrip-test.yml that depend on what 'docker compose up'
# does to an image reference the module tagged: Check Previous Release
# (id: previous-running) and Upgrade Stack (id: upgrade).
#
# backup-roundtrip-module.test.sh fakes docker. This test runs the same
# extracted step bodies against the real Docker Engine and Compose, so it
# proves what the fakes assume:
#
#   pull_policy: always   'up' pulls the registry's image over the reference
#   pull_policy: build    'up' builds its own image under the reference
#   default (missing)     'up' keeps the tagged image
#
# and that both checks fail in the first two cases and pass in the third.
#
# Three tiny public images play the parts: busybox 1.35 is the previous
# release, 1.36 the build of this commit, and 1.37 the reference the service
# resolves to - the image the registry holds under it.
#
# Needs Docker with the compose plugin and jq; pulls about 6 MB.
# Usage: bash .github/workflows/tests/backup-roundtrip-pull-policy.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_FILE="$SCRIPT_DIR/../modules-backup-roundtrip-test.yml"

for TOOL in docker jq; do
  command -v "$TOOL" > /dev/null || { echo "FATAL: $TOOL is required"; exit 1; }
done
docker compose version > /dev/null 2>&1 || { echo "FATAL: the docker compose plugin is required"; exit 1; }

# Same extraction as backup-roundtrip-module.test.sh.
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
extract_lib() {
  awk '
    /^          cat > "\$ROUNDTRIP_DIR\/lib.sh" << .LIB.$/ { collecting = 1; next }
    collecting && /^          LIB$/ { exit }
    collecting { if ($0 == "") { print ""; next } sub(/^          /, ""); print }
  ' "$WORKFLOW_FILE"
}

WORK="$(mktemp -d)"
PROJECT="rt-pull-policy-$$"
STACK="$WORK/stack"
mkdir -p "$STACK/build"
cleanup() {
  (cd "$STACK" && COMPOSE_FILE=previous.yml docker compose -p "$PROJECT" down --remove-orphans --timeout 1 > /dev/null 2>&1)
  rm -rf "$WORK"
}
trap cleanup EXIT

for STEP in previous-running upgrade; do
  extract_step "$STEP" > "$WORK/$STEP.sh"
  if [ ! -s "$WORK/$STEP.sh" ]; then
    echo "FATAL: could not extract the '$STEP' run block from the workflow - update this test."
    exit 1
  fi
done
extract_lib > "$WORK/lib.sh"
[ -s "$WORK/lib.sh" ] || { echo "FATAL: could not extract lib.sh from the workflow"; exit 1; }

PASSED=0
FAILED=0
pass() { echo "PASS $1"; PASSED=$((PASSED + 1)); }
fail() { echo "FAIL $1: $2"; FAILED=$((FAILED + 1)); }
expect_rc() {
  if [ "$2" -eq "$3" ]; then pass "$1"; else fail "$1" "exit $2, want $3 - log: $(tr '\n' ' ' < "$DIR/log" | cut -c1-600)"; fi
}
expect_log() {
  if grep -qF -- "$2" "$DIR/log"; then pass "$1"; else fail "$1" "log lacks '$2'"; fi
}
expect_eq() {
  if [ "$2" = "$3" ]; then pass "$1"; else fail "$1" "got '$2', want '$3'"; fi
}

PREVIOUS=busybox:1.35
BUILD=busybox:1.36
REF=busybox:1.37
for IMAGE in "$PREVIOUS" "$BUILD" "$REF"; do
  docker pull --quiet "$IMAGE" > /dev/null || { echo "FATAL: could not pull $IMAGE"; exit 1; }
done
image_id() { docker image inspect --format '{{.Id}}' "$1"; }
PREVIOUS_ID=$(image_id "$PREVIOUS")
BUILD_ID=$(image_id "$BUILD")
REGISTRY_ID=$(image_id "$REF")
if [ "$PREVIOUS_ID" = "$BUILD_ID" ] || [ "$BUILD_ID" = "$REGISTRY_ID" ] || [ "$PREVIOUS_ID" = "$REGISTRY_ID" ]; then
  echo "FATAL: the three busybox images must differ"
  exit 1
fi

# A compose file with one service on the reference and the given policy.
compose_file() {
  {
    echo "services:"
    echo "  app:"
    echo "    image: $REF"
    echo "    command: [\"sleep\", \"600\"]"
    [ "$2" = "missing" ] || echo "    pull_policy: $2"
    [ "$2" != "build" ] || echo "    build: {context: ./build}"
  } > "$STACK/$1"
}
printf 'FROM %s\nRUN touch /built-by-compose\n' "$BUILD" > "$STACK/build/Dockerfile"
compose_file previous.yml missing

# The state after Pull Previous Release and Start Stack: the reference holds
# the previous release, and 'up' ran with the previous release's files.
start_previous() {
  DIR="$WORK/case-$1"
  rm -rf "$DIR"; mkdir -p "$DIR"
  : > "$DIR/env"; : > "$DIR/output"
  compose_file "start-$1.yml" "$2"
  (cd "$STACK" && COMPOSE_FILE="start-$1.yml" docker compose -p "$PROJECT" down --remove-orphans --timeout 1 > /dev/null 2>&1)
  docker tag "$PREVIOUS" "$REF"
  printf 'app\t%s\t%s\n' "$PREVIOUS" "$REF" > "$DIR/upgrade-plan.tsv"
  (cd "$STACK" && COMPOSE_FILE="start-$1.yml" docker compose -p "$PROJECT" up -d --wait --wait-timeout 60 > "$DIR/up.log" 2>&1) \
    || { echo "FATAL: the stack did not start: $(cat "$DIR/up.log")"; exit 1; }
  (cd "$STACK" && COMPOSE_FILE="start-$1.yml" docker compose -p "$PROJECT" config --format json) > "$DIR/compose-config.json"
  cp "$WORK/lib.sh" "$DIR/lib.sh"
}
run_step() {
  local step="$1" file="$2"; shift 2
  (cd "$STACK" && env ROUNDTRIP_DIR="$DIR" GITHUB_ENV="$DIR/env" GITHUB_OUTPUT="$DIR/output" \
    COMPOSE_FILE="$file" COMPOSE_PROJECT_NAME="$PROJECT" BACKUP_SERVICE=app START_SERVICES="" \
    WAIT_TIMEOUT=60 SCRIPT_TIMEOUT=60 "$@" bash -eo pipefail "$WORK/$step.sh") > "$DIR/log" 2>&1
}
running_id() { docker inspect --format '{{.Image}}' "$(cd "$STACK" && COMPOSE_FILE=previous.yml docker compose -p "$PROJECT" ps -q app)"; }

# === Check Previous Release =====================================================
start_previous prev-missing missing
run_step previous-running start-prev-missing.yml; expect_rc "previous release, default policy: check passes" $? 0
expect_eq "previous release, default policy: Compose kept the tagged image" "$(running_id)" "$PREVIOUS_ID"

start_previous prev-always always
expect_eq "previous release, pull_policy always: Compose pulled the registry's image over the reference" "$(image_id "$REF")" "$REGISTRY_ID"
run_step previous-running start-prev-always.yml; expect_rc "previous release, pull_policy always: check fails" $? 1
expect_log "previous release, pull_policy always: names the replaced reference" "'up' replaced $REF, which held the previous release $PREVIOUS"

# === Upgrade Stack ==============================================================
# The previous release runs; the build of this commit waits staged. The
# upgrade switches to target-<policy>.yml.
upgrade_case() {
  start_previous "up-$1" missing
  compose_file "target-$1.yml" "$1"
  docker tag "$BUILD" roundtrip-staged/image-0:build
  printf 'app\troundtrip-staged/image-0:build\n' > "$DIR/staged-images.txt"
  run_step upgrade "start-up-$1.yml" ROUNDTRIP_COMPOSE_FILE_TARGET="target-$1.yml" \
    UPGRADE_SCRIPT="" CHECK_SCRIPT="" RUN_HEALTHCHECK=false
}

upgrade_case missing; RC=$?
expect_rc "upgrade, default policy: check passes" "$RC" 0
expect_eq "upgrade, default policy: the container runs the build" "$(running_id)" "$BUILD_ID"

upgrade_case always; RC=$?
expect_eq "upgrade, pull_policy always: Compose pulled the registry's image over the build" "$(image_id "$REF")" "$REGISTRY_ID"
expect_rc "upgrade, pull_policy always: check fails" "$RC" 1
expect_log "upgrade, pull_policy always: names the replaced reference" "'up' replaced the image under test $REF"

upgrade_case build; RC=$?
BUILT_ID=$(image_id "$REF")
if [ "$BUILT_ID" != "$BUILD_ID" ] && [ "$BUILT_ID" != "$REGISTRY_ID" ]; then pass "upgrade, pull_policy build: Compose built its own image under the reference"; else fail "upgrade, pull_policy build: Compose built its own image under the reference" "reference holds $BUILT_ID"; fi
expect_rc "upgrade, pull_policy build: check fails" "$RC" 1
expect_log "upgrade, pull_policy build: names the replaced reference" "'up' replaced the image under test $REF"

docker image rm roundtrip-staged/image-0:build > /dev/null 2>&1

echo ""
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
