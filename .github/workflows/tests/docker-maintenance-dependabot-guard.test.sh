#!/usr/bin/env bash
#
# Behavioural test for the 'Merge guard' step (id: guard) in
# ../docker-maintenance-dependabot.yml.
#
# Without required status checks on the base branch, `gh pr merge --auto` merges a
# PR immediately - before CI finishes and even with a failed check. That merged
# bauer-group/CS-BillingStack#12 three seconds after its label check went red. The
# guard only lets approve + auto-merge run when CI is actually required:
#
#   semver-major (allow-major off)            -> left open, notice
#   no required checks (ruleset or protection) -> left open, notice
#   rules or protection unreadable            -> left open, warning
#   required checks, 'Allow auto-merge' off   -> left open, warning
#   required checks (ruleset or classic)      -> ok
#
# The step body is extracted from the workflow at runtime rather than duplicated
# here and run the way a `shell: bash` step runs (-eo pipefail). `gh` is replaced
# by a stub that applies the step's real --jq filters (with jq) to API responses
# shaped like GitHub's.
#
# Usage: bash .github/workflows/tests/docker-maintenance-dependabot-guard.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_FILE="$SCRIPT_DIR/../docker-maintenance-dependabot.yml"

if [ ! -f "$WORKFLOW_FILE" ]; then
  echo "FATAL: workflow not found at $WORKFLOW_FILE"
  exit 1
fi
if ! command -v jq > /dev/null; then
  echo "FATAL: jq is required to evaluate the step's --jq filters"
  exit 1
fi

STEP_BODY=$(awk '
  $0 == "        id: guard" { found = 1; next }
  found && /^        run: \|$/ { collecting = 1; next }
  collecting {
    if ($0 == "") { print ""; next }
    if ($0 ~ /^          /) { sub(/^          /, ""); print; next }
    exit
  }
' "$WORKFLOW_FILE")

if [ -z "$STEP_BODY" ]; then
  echo "FATAL: could not extract the 'guard' run block from the workflow."
  echo "       The step was renamed, removed, or re-indented - update this test."
  exit 1
fi

PASSED=0
FAILED=0
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# --- the guard must actually gate the two steps that act on the PR ------------
static_check() {
  local name="$1" pattern="$2"
  if grep -qF -- "$pattern" "$WORKFLOW_FILE"; then
    echo "PASS $name"; PASSED=$((PASSED + 1))
  else
    echo "FAIL $name: '$pattern' not found"; FAILED=$((FAILED + 1))
  fi
}
static_check "approve is gated by the guard" "if: inputs.auto-approve && steps.guard.outputs.ok == 'true'"
static_check "auto-merge is gated by the guard" "        if: steps.guard.outputs.ok == 'true'"
static_check "job has a timeout" "    timeout-minutes: "

# --- gh stub ------------------------------------------------------------------
mkdir -p "$WORK/bin"
cat > "$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
# gh api <path> --jq <filter>; responses come from FAKE_RULES / FAKE_BRANCH / FAKE_REPO,
# the value FAIL simulates an HTTP error.
[ "${1:-}" = "api" ] || { echo "unexpected gh call: $*" >&2; exit 2; }
path="$2"; shift 2
filter="."
while [ $# -gt 0 ]; do
  case "$1" in --jq) filter="$2"; shift 2 ;; *) shift ;; esac
done
echo "$path" >> "$FAKE_GH_LOG"
case "$path" in
  repos/*/rules/branches/*) response="$FAKE_RULES" ;;
  repos/*/branches/*)       response="$FAKE_BRANCH" ;;
  repos/*)                  response="$FAKE_REPO" ;;
  *) echo "unexpected path: $path" >&2; exit 2 ;;
esac
if [ "$response" = "FAIL" ]; then
  echo "gh: Not Found (HTTP 404)" >&2
  exit 1
fi
jq -r "$filter" <<< "$response"
STUB
chmod +x "$WORK/bin/gh"

# --- API responses, shaped like GitHub's ---------------------------------------
RULES_NONE='[]'
RULES_CHECKS='[{"type":"deletion","ruleset_source_type":"Repository","ruleset_source":"o/r","ruleset_id":1},{"type":"required_status_checks","parameters":{"strict_required_status_checks_policy":false,"do_not_enforce_on_create":false,"required_status_checks":[{"context":"🔍 Validate Base Image Labels","integration_id":15368},{"context":"build"}]},"ruleset_source_type":"Repository","ruleset_source":"o/r","ruleset_id":1}]'
RULES_NO_CHECK_RULE='[{"type":"deletion","ruleset_source_type":"Organization","ruleset_source":"o","ruleset_id":2},{"type":"non_fast_forward","ruleset_source_type":"Organization","ruleset_source":"o","ruleset_id":2}]'
BRANCH_OPEN='{"name":"main","protected":false,"protection":{"enabled":false,"required_status_checks":{"enforcement_level":"off","contexts":[],"checks":[]}},"protection_url":"https://api.github.com/repos/o/r/branches/main/protection"}'
BRANCH_PROTECTED='{"name":"main","protected":true,"protection":{"enabled":true,"required_status_checks":{"enforcement_level":"non_admins","contexts":["build"],"checks":[{"context":"build","app_id":15368}]}}}'
BRANCH_NO_FIELD='{"name":"main","protected":false}'
REPO_AUTOMERGE='{"full_name":"o/r","allow_auto_merge":true}'
REPO_NO_AUTOMERGE='{"full_name":"o/r","allow_auto_merge":false}'
REPO_NO_FIELD='{"full_name":"o/r"}'

# run_case <name> <update-type> <allow-major> <rules> <branch> <repo> <ok> <reason> <annotation|-> [base]
run_case() {
  local name="$1" update_type="$2" allow_major="$3" rules="$4" branch="$5" repo="$6"
  local want_ok="$7" want_reason="$8" annotation="$9" base="${10:-main}"
  local dir="$WORK/case-$name"
  mkdir -p "$dir"
  : > "$dir/output"
  : > "$dir/gh.log"

  ( cd "$dir" && PATH="$WORK/bin:$PATH" GITHUB_OUTPUT="$dir/output" FAKE_GH_LOG="$dir/gh.log" \
      FAKE_RULES="$rules" FAKE_BRANCH="$branch" FAKE_REPO="$repo" \
      GH_TOKEN="test" REPO="o/r" BASE="$base" UPDATE_TYPE="$update_type" ALLOW_MAJOR="$allow_major" \
      bash --noprofile --norc -eo pipefail -c "$STEP_BODY" ) > "$dir/log" 2>&1
  local rc=$?

  local got_ok got_reason ok=true why=""
  got_ok=$(sed -n 's/^ok=//p' "$dir/output")
  got_reason=$(sed -n 's/^reason=//p' "$dir/output")
  [ "$rc" -eq 0 ] || { ok=false; why="exit $rc"; }
  [ "$got_ok" = "$want_ok" ] || { ok=false; why="$why ok='$got_ok'"; }
  [ "$got_reason" = "$want_reason" ] || { ok=false; why="$why reason='$got_reason'"; }
  if [ "$annotation" = "-" ]; then
    grep -q '^::\(notice\|warning\|error\)' "$dir/log" && { ok=false; why="$why unexpected annotation"; }
  else
    grep -q "^::${annotation} " "$dir/log" || { ok=false; why="$why missing ::${annotation}"; }
  fi
  if [ "$base" != "main" ]; then
    grep -qxF "repos/o/r/rules/branches/$base" "$dir/gh.log" || { ok=false; why="$why rules not read for '$base'"; }
  fi

  if [ "$ok" = true ]; then
    echo "PASS $name"
    PASSED=$((PASSED + 1))
  else
    echo "FAIL $name:$why"
    sed 's/^/     | /' "$dir/log"
    FAILED=$((FAILED + 1))
  fi
}

MINOR="version-update:semver-minor"
PATCH="version-update:semver-patch"
MAJOR="version-update:semver-major"

run_case major-left-open        "$MAJOR" false "$RULES_CHECKS"        "$BRANCH_OPEN"      "$REPO_AUTOMERGE"    false major               notice
run_case major-allowed          "$MAJOR" true  "$RULES_CHECKS"        "$BRANCH_OPEN"      "$REPO_AUTOMERGE"    true  required-checks     -
run_case minor-ruleset          "$MINOR" false "$RULES_CHECKS"        "$BRANCH_OPEN"      "$REPO_AUTOMERGE"    true  required-checks     -
run_case patch-classic          "$PATCH" false "$RULES_NONE"          "$BRANCH_PROTECTED" "$REPO_AUTOMERGE"    true  required-checks     -
run_case unknown-update-type    ""       false "$RULES_CHECKS"        "$BRANCH_OPEN"      "$REPO_AUTOMERGE"    true  required-checks     -
run_case no-required-checks     "$MINOR" false "$RULES_NONE"          "$BRANCH_OPEN"      "$REPO_AUTOMERGE"    false no-required-checks  notice
run_case ruleset-without-checks "$PATCH" false "$RULES_NO_CHECK_RULE" "$BRANCH_OPEN"      "$REPO_AUTOMERGE"    false no-required-checks  notice
run_case no-protection-field    "$PATCH" false "$RULES_NONE"          "$BRANCH_NO_FIELD"  "$REPO_AUTOMERGE"    false no-required-checks  notice
run_case rules-unreadable       "$MINOR" false FAIL                   "$BRANCH_PROTECTED" "$REPO_AUTOMERGE"    false api-error           warning
run_case branch-unreadable      "$MINOR" false "$RULES_CHECKS"        FAIL                "$REPO_AUTOMERGE"    false api-error           warning
run_case auto-merge-disabled    "$MINOR" false "$RULES_CHECKS"        "$BRANCH_OPEN"      "$REPO_NO_AUTOMERGE" false auto-merge-disabled warning
run_case auto-merge-unreadable  "$MINOR" false "$RULES_CHECKS"        "$BRANCH_OPEN"      FAIL                 true  required-checks     -
run_case auto-merge-not-shown   "$MINOR" false "$RULES_CHECKS"        "$BRANCH_OPEN"      "$REPO_NO_FIELD"     true  required-checks     -
run_case base-with-slash        "$MINOR" false "$RULES_CHECKS"        "$BRANCH_OPEN"      "$REPO_AUTOMERGE"    true  required-checks     -  release/1.x

echo ""
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
