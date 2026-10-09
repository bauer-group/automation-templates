#!/usr/bin/env bash
#
# Behavioural test for the 'Create Backup' (id: create) step of
# ../modules-backup-roundtrip-test.yml - the decision the fixture round trip in
# backup-roundtrip-selftest.yml cannot reach.
#
# Create Backup: since BackupHelper 1.7.7 'backuphelper create' exits 1 when a
# component failed, yet the snapshot is still stored. The step used to end on
# that exit code, so the snapshot id stayed unknown and Inspect Snapshot - the
# step that names the failed component - never ran. A failing create cannot be
# provoked in the self-test without turning it red, so it is tested here:
#
#   exit 0, new snapshot            -> snapshot-id set, step passes
#   exit 1, new (partial) snapshot  -> snapshot-id set, step fails
#   exit 1, no new snapshot         -> no snapshot-id, step fails
#   exit 0, no new snapshot         -> step fails (zero jobs ran)
#
# The step bodies are extracted from the workflow at runtime and run the way a
# `shell: bash` step runs (-eo pipefail). The engine CLI ('bh' from lib.sh) is a
# stub.
#
# Usage: bash .github/workflows/tests/backup-roundtrip-module.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_FILE="$SCRIPT_DIR/../modules-backup-roundtrip-test.yml"

if [ ! -f "$WORKFLOW_FILE" ]; then
  echo "FATAL: workflow not found at $WORKFLOW_FILE"
  exit 1
fi
if ! command -v jq > /dev/null; then
  echo "FATAL: jq is required"
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

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

extract_step create > "$WORK/create.sh"
if [ ! -s "$WORK/create.sh" ]; then
  echo "FATAL: could not extract the 'create' run block from the workflow."
  echo "       The step was renamed, removed, or re-indented - update this test."
  exit 1
fi

PASSED=0
FAILED=0
pass() { echo "PASS $1"; PASSED=$((PASSED + 1)); }
fail() { echo "FAIL $1: $2"; FAILED=$((FAILED + 1)); }
expect_eq() {
  local name="$1" got="$2" want="$3"
  if [ "$got" = "$want" ]; then pass "$name"; else fail "$name" "got '$got', want '$want'"; fi
}
expect_rc() {
  local name="$1" got="$2" want="$3"
  if [ "$got" -eq "$want" ]; then pass "$name"; else fail "$name" "exit $got, want $want - log: $(tr '\n' ' ' < "$DIR/log" | cut -c1-400)"; fi
}
expect_log() {
  if grep -qF -- "$2" "$DIR/log"; then pass "$1"; else fail "$1" "log lacks '$2'"; fi
}

# --- wiring the tests below rely on ------------------------------------------
static_check() {
  if grep -qF -- "$2" "$WORKFLOW_FILE"; then pass "$1"; else fail "$1" "'$2' not found"; fi
}
static_check "Inspect Snapshot runs after a failed create that stored a snapshot" \
  "if: \${{ !cancelled() && steps.create.outputs.snapshot-id != '' }}"
static_check "the summary reports the create exit code" \
  "CREATE_EXIT: \${{ steps.create.outputs.create-exit-code }}"
# Verify and everything after it must keep the implicit success(): after a
# failed create the job ends with Inspect Snapshot.
VERIFY_IF=$(awk '/- name: "🔍 Verify Snapshot"/ { getline; print; exit }' "$WORKFLOW_FILE")
if [[ "$VERIFY_IF" == *"if:"* ]]; then
  fail "Verify Snapshot keeps the implicit success()" "has '$VERIFY_IF'"
else
  pass "Verify Snapshot keeps the implicit success()"
fi

reset() {
  DIR="$WORK/case-$1"
  rm -rf "$DIR"
  mkdir -p "$DIR/diagnostics"
  : > "$DIR/output"; : > "$DIR/env"
  export DIR
}
run_step() {
  local step="$1"; shift
  env ROUNDTRIP_DIR="$DIR" GITHUB_OUTPUT="$DIR/output" GITHUB_ENV="$DIR/env" \
    BACKUP_SERVICE=backup START_SERVICES="" "$@" bash -eo pipefail "$WORK/$step.sh" > "$DIR/log" 2>&1
}
out() { grep "^$1=" "$DIR/output" | tail -n 1 | cut -d= -f2-; }

# === Create Backup ==============================================================
# The fake engine: 'list' prints list.before until 'create' ran, then list.after;
# 'create' exits with the code in create-exit.
cat > "$WORK/lib.sh" <<'LIB'
bh() {
  case "$1" in
    list)
      if [ -f "$DIR/created" ]; then
        [ ! -f "$DIR/list-fails" ] || { echo "Error: service not running" >&2; return 1; }
        cat "$DIR/list.after"
      else
        cat "$DIR/list.before"
      fi ;;
    create)
      touch "$DIR/created"
      echo "job main snapshot fake finished: $(cat "$DIR/create-status")"
      return "$(cat "$DIR/create-exit")" ;;
    *) echo "unexpected bh call: $*" >&2; return 2 ;;
  esac
}
LIB
OLD="2026-10-08_03-15-00"
NEW="2026-10-09_09-14-46"
NEWER="2026-10-09_09-14-58"
create_case() {
  reset "$1"
  cp "$WORK/lib.sh" "$DIR/lib.sh"
  echo "$2" > "$DIR/create-exit"
  if [ "$2" -eq 0 ]; then echo success; else echo error; fi > "$DIR/create-status"
  printf '%-24s %12d bytes\n' "$OLD" 2048 > "$DIR/list.before"
  cp "$DIR/list.before" "$DIR/list.after"
}
add_after() { printf '%-24s %12d bytes%s\n' "$1" "$2" "${3:-}" >> "$DIR/list.after"; }

create_case ok 0; add_after "$NEW" 4096
run_step create; expect_rc "create ok: step passes" $? 0
expect_eq "create ok: snapshot id" "$(out snapshot-id)" "$NEW"
expect_eq "create ok: exit code recorded" "$(out create-exit-code)" 0
if grep -q "^ROUNDTRIP_SNAPSHOT_ID=$NEW$" "$DIR/env"; then pass "create ok: id exported to the scripts"; else fail "create ok: id exported to the scripts" "missing in GITHUB_ENV"; fi
if [ -s "$DIR/diagnostics/create.log" ]; then pass "create ok: create.log written"; else fail "create ok: create.log written" "empty"; fi

create_case partial 1; add_after "$NEW" 4096
run_step create; expect_rc "failed component: step fails" $? 1
expect_eq "failed component: snapshot id still resolved" "$(out snapshot-id)" "$NEW"
expect_eq "failed component: exit code recorded" "$(out create-exit-code)" 1
expect_log "failed component: error names the stored snapshot" "'backuphelper create' exited 1: snapshot $NEW was stored"
if grep -q "^ROUNDTRIP_SNAPSHOT_ID=$NEW$" "$DIR/env"; then pass "failed component: id exported"; else fail "failed component: id exported" "missing"; fi

create_case aborted 1
run_step create; expect_rc "aborted run: step fails" $? 1
expect_eq "aborted run: no snapshot id" "$(out snapshot-id)" ""
expect_log "aborted run: error says nothing was stored" "exited 1 and stored no local snapshot"

create_case zero-jobs 0
run_step create; expect_rc "zero jobs: step fails" $? 1
expect_eq "zero jobs: no snapshot id" "$(out snapshot-id)" ""
expect_log "zero jobs: error explains the empty job list" "exited 0 but no new local snapshot appeared"

create_case sidecar-gone 1; add_after "$NEW" 4096; touch "$DIR/list-fails"
run_step create; expect_rc "sidecar gone: step fails" $? 1
expect_log "sidecar gone: error names the failing list" "'backuphelper list' failed after 'backuphelper create' (exit code 1)"

create_case two-new 0; add_after "$NEW" 4096; add_after "$NEWER" 4096
run_step create; expect_rc "two new snapshots: step passes" $? 0
expect_eq "two new snapshots: newest used" "$(out snapshot-id)" "$NEWER"
expect_log "two new snapshots: warning" "::warning::2 new snapshots"

create_case offsite-only 0; add_after "$NEW" 0 "  (off-site only)"
run_step create; expect_rc "off-site-only row: not a local snapshot" $? 1

echo ""
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
