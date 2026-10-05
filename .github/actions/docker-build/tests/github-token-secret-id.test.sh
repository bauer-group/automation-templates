#!/usr/bin/env bash
#
# Regression test for the 'Validate GitHub Token Secret ID' step in
# ../../../workflows/docker-build.yml.
#
# github-token-secret-id is spliced into the `id=value` lines that carry the
# workflow's own GITHUB_TOKEN into the build (issue #106). docker/build-push-action
# splits that value into one secret per line and each line at its first '=', then
# hands buildx `id=<id>,src=<file>`. An id holding a newline, an '=' or a ',' could
# therefore define a secret line or buildx option of the caller's choosing next to
# the token. This step is the only thing standing between the input and that list,
# so it is pinned from both sides: plain ids pass, anything else fails the job.
#
# The step body is extracted from the workflow at runtime rather than duplicated
# here: a copied-out script would keep passing after the real one regressed.
#
# Usage: bash .github/actions/docker-build/tests/github-token-secret-id.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_FILE="$SCRIPT_DIR/../../../workflows/docker-build.yml"
STEP_ID="validate-token-secret-id"

if [ ! -f "$WORKFLOW_FILE" ]; then
  echo "FATAL: docker-build.yml not found at $WORKFLOW_FILE"
  exit 1
fi

# The step's own lines, from its `id:` up to the next step.
STEP_BLOCK=$(awk -v step="        id: $STEP_ID" '
  $0 == step                 { found = 1; print; next }
  found && /^      - /       { exit }
  found                      { print }
' "$WORKFLOW_FILE")

# Its `run:` block, with the 10-space indent stripped.
STEP_BODY=$(printf '%s\n' "$STEP_BLOCK" | awk '
  /^        run: \|$/ { collecting = 1; next }
  collecting {
    if ($0 == "") { print ""; next }
    if ($0 ~ /^          /) { sub(/^          /, ""); print; next }
    exit
  }
')

if [ -z "$STEP_BODY" ]; then
  echo "FATAL: could not extract the '$STEP_ID' run block from docker-build.yml."
  echo "       The step was renamed, removed, or re-indented - update this test."
  exit 1
fi

PASSED=0
FAILED=0

pass() { PASSED=$((PASSED + 1)); printf 'ok   %s\n' "$1"; }
fail() { FAILED=$((FAILED + 1)); printf 'FAIL %s\n' "$1"; shift; printf '       %s\n' "$@"; }

# The wiring the script relies on: the id arrives through env (a value pasted into
# the script would execute before any check ran), under the C locale the pattern
# assumes, and the step runs whenever the input is set.
assert_wiring() {
  local desc="$1" line="$2"
  if printf '%s\n' "$STEP_BLOCK" | grep -qxF -- "$line"; then
    pass "$desc"
  else
    fail "$desc" "expected the step to contain the line: $line"
  fi
}

# assert_id <description> <id> <accept|reject>
assert_id() {
  local desc="$1" id="$2" want="$3"
  local stdout_file rc got
  stdout_file=$(mktemp)

  # As the runner invokes `shell: bash`, with the step's env.
  LC_ALL=C SECRET_ID="$id" \
    bash --noprofile --norc -eo pipefail -c "$STEP_BODY" > "$stdout_file" 2>&1
  rc=$?

  if [ "$rc" -eq 0 ]; then got=accept; else got=reject; fi

  local problems=()
  [ "$got" = "$want" ] || problems+=("expected $want, got $got (exit $rc): $(tr '\n' ' ' < "$stdout_file")")
  if [ "$want" = "reject" ]; then
    grep -qF -- "::error::" "$stdout_file" || problems+=("rejected without an ::error:: annotation")
    # The rejected value must not reach the log, where a newline in it could start
    # a workflow command of its own.
    grep -qF -- "INJECTED" "$stdout_file" && problems+=("the rejected value was echoed to the log")
  fi
  rm -f "$stdout_file"

  if [ ${#problems[@]} -eq 0 ]; then pass "$desc"; else fail "$desc" "${problems[@]}"; fi
}

echo "Testing '$STEP_ID' from $(basename "$WORKFLOW_FILE")"
echo

assert_wiring "runs whenever the input is set" \
  "        if: inputs.github-token-secret-id != ''"
assert_wiring "reads the id through env, not the script" \
  '          SECRET_ID: ${{ inputs.github-token-secret-id }}'
assert_wiring "matches under the C locale" \
  "          LC_ALL: C"

assert_id "plain id"                             "npm_token"               accept
assert_id "upper case, digits, dot and dash"     "NPM.Token-2_x"           accept
assert_id "single character"                     "t"                       accept

assert_id "newline starts a second secret line"  $'npm_token\nINJECTED=1'  reject
assert_id "trailing newline"                     $'npm_token\n'            reject
assert_id "leading newline"                      $'\nnpm_token'            reject
assert_id "carriage return"                      $'npm_token\rINJECTED'    reject
assert_id "'=' moves the id/value split"         "npm=INJECTED"            reject
assert_id "',' adds a buildx option"             "npm,src=/INJECTED"       reject
assert_id "space"                                "npm INJECTED"            reject
assert_id "double quote opens a CSV field"       '"INJECTED'               reject
assert_id "shell syntax is never executed"       '$(echo INJECTED)'        reject
assert_id "workflow command"                     '::INJECTED::'            reject
assert_id "non-ASCII letter"                     "npmé"                    reject

echo
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
