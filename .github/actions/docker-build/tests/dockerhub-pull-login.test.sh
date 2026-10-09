#!/usr/bin/env bash
#
# Regression test for the optional Docker Hub pull login in
# ../../../workflows/docker-build.yml (steps 'Check Docker Hub Credentials',
# 'Log in to Docker Hub' and 'Docker Hub Login Failed').
#
# A build that publishes to GHCR still pulls from Docker Hub - base images, the
# BuildKit image, the QEMU image - and GitHub-hosted runners share their IPs, so
# anonymous pulls failed with 429 'toomanyrequests' when many builds ran at once.
# The login fixes that for callers that pass DOCKER_USERNAME / DOCKER_PASSWORD.
# The workflow serves ~80 repositories, most of which pass no such secrets or run
# as Dependabot or from forks, so this pins both sides:
#
#   - the decision: login only when both secrets are present, otherwise skipped
#     cleanly - never a failed step;
#   - the wiring: GHCR builds only (dockerhub/both log in inside the build action),
#     presence-only checks that never put a secret value into the script, a login
#     that can only warn, and a position ahead of everything that pulls.
#
# The step body is extracted from the workflow at runtime rather than duplicated
# here: a copied-out script would keep passing after the real one regressed.
#
# Usage: bash .github/actions/docker-build/tests/dockerhub-pull-login.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_FILE="$SCRIPT_DIR/../../../workflows/docker-build.yml"

if [ ! -f "$WORKFLOW_FILE" ]; then
  echo "FATAL: docker-build.yml not found at $WORKFLOW_FILE"
  exit 1
fi

# step_block <id>: the step's own lines, from its `- name:` up to the next step.
step_block() {
  awk -v step="        id: $1" '
    /^      - / { if (found) exit; buf = $0; next }
    $0 == step  { found = 1; print buf; print; next }
    found       { print; next }
    buf != ""   { buf = buf "\n" $0 }
  ' "$WORKFLOW_FILE"
}

# line_of <exact line>: 1-based line number of its first occurrence, empty if none.
line_of() {
  awk -v want="$1" '$0 == want { print NR; exit }' "$WORKFLOW_FILE"
}

# require_block <id> <block>: stop when a step could not be found at all.
require_block() {
  if [ -z "$2" ]; then
    echo "FATAL: step '$1' not found in docker-build.yml."
    echo "       It was renamed, removed, or re-indented - update this test."
    exit 1
  fi
}

CHECK_BLOCK=$(step_block dockerhub-pull)
LOGIN_BLOCK=$(step_block dockerhub-pull-login)
WARN_BLOCK=$(step_block dockerhub-pull-warning)
require_block dockerhub-pull "$CHECK_BLOCK"
require_block dockerhub-pull-login "$LOGIN_BLOCK"
require_block dockerhub-pull-warning "$WARN_BLOCK"

# The check step's `run:` block, with the 10-space indent stripped.
CHECK_BODY=$(printf '%s\n' "$CHECK_BLOCK" | awk '
  /^        run: \|$/ { collecting = 1; next }
  collecting {
    if ($0 == "") { print ""; next }
    if ($0 ~ /^          /) { sub(/^          /, ""); print; next }
    exit
  }
')

if [ -z "$CHECK_BODY" ]; then
  echo "FATAL: could not extract the run block of 'dockerhub-pull' from docker-build.yml."
  exit 1
fi

PASSED=0
FAILED=0

pass() { PASSED=$((PASSED + 1)); printf 'ok   %s\n' "$1"; }
fail() { FAILED=$((FAILED + 1)); printf 'FAIL %s\n' "$1"; shift; printf '       %s\n' "$@"; }

# assert_line <description> <block> <exact line>
assert_line() {
  local desc="$1" block="$2" line="$3"
  if printf '%s\n' "$block" | grep -qxF -- "$line"; then
    pass "$desc"
  else
    fail "$desc" "expected the step to contain the line: $line"
  fi
}

# assert_no_text <description> <block> <text>
assert_no_text() {
  local desc="$1" block="$2" text="$3"
  if printf '%s\n' "$block" | grep -qF -- "$text"; then
    fail "$desc" "the step must not contain: $text"
  else
    pass "$desc"
  fi
}

# assert_decision <description> <HAS_DOCKER_USERNAME> <HAS_DOCKER_PASSWORD> <true|false>
assert_decision() {
  local desc="$1" has_user="$2" has_pass="$3" want="$4"
  local out_file log_file rc got
  out_file=$(mktemp)
  log_file=$(mktemp)

  # As the runner invokes `shell: bash`, with the step's env. The env carries the
  # *results* of `secrets.X != ''`, which the runner renders as 'true' / 'false'.
  HAS_DOCKER_USERNAME="$has_user" HAS_DOCKER_PASSWORD="$has_pass" GITHUB_OUTPUT="$out_file" \
    bash --noprofile --norc -eo pipefail -c "$CHECK_BODY" > "$log_file" 2>&1
  rc=$?

  got=$(sed -n 's/^login=//p' "$out_file")

  local problems=()
  [ "$rc" -eq 0 ] || problems+=("the step failed (exit $rc) - a missing secret must skip the login, never fail the build: $(tr '\n' ' ' < "$log_file")")
  [ "$got" = "$want" ] || problems+=("expected login=$want, got login='$got'")
  [ "$(grep -c '^login=' "$out_file")" -eq 1 ] || problems+=("expected exactly one login= output line")
  grep -qF -- "::error::" "$log_file" && problems+=("emitted an ::error:: annotation")
  rm -f "$out_file" "$log_file"

  if [ ${#problems[@]} -eq 0 ]; then pass "$desc"; else fail "$desc" "${problems[@]}"; fi
}

echo "Testing the Docker Hub pull login in $(basename "$WORKFLOW_FILE")"
echo

# --- Check Docker Hub Credentials -------------------------------------------
assert_line "check runs for GHCR builds only (dockerhub/both log in inside the build action)" "$CHECK_BLOCK" \
  "        if: inputs.publish-to == 'ghcr'"
assert_line "check reads the username's presence, not its value" "$CHECK_BLOCK" \
  "          HAS_DOCKER_USERNAME: \${{ secrets.DOCKER_USERNAME != '' }}"
assert_line "check reads the password's presence, not its value" "$CHECK_BLOCK" \
  "          HAS_DOCKER_PASSWORD: \${{ secrets.DOCKER_PASSWORD != '' }}"
assert_no_text "check never references the username value" "$CHECK_BLOCK" \
  "secrets.DOCKER_USERNAME }}"
assert_no_text "check never references the password value" "$CHECK_BLOCK" \
  "secrets.DOCKER_PASSWORD }}"

assert_decision "both secrets set -> login"                         true  true  true
assert_decision "no secrets (fork PR, Dependabot, no inherit) -> skip" false false false
assert_decision "username only -> skip"                             true  false false
assert_decision "password only -> skip"                             false true  false

# --- Log in to Docker Hub -----------------------------------------------------
assert_line "login runs only on the check's decision" "$LOGIN_BLOCK" \
  "        if: steps.dockerhub-pull.outputs.login == 'true'"
assert_line "a failed login cannot fail the build" "$LOGIN_BLOCK" \
  "        continue-on-error: true"
assert_line "login uses docker/login-action (major tag pin)" "$LOGIN_BLOCK" \
  "        uses: docker/login-action@v4"
assert_line "login targets Docker Hub" "$LOGIN_BLOCK" \
  "          registry: docker.io"
assert_line "login uses DOCKER_USERNAME" "$LOGIN_BLOCK" \
  "          username: \${{ secrets.DOCKER_USERNAME }}"
assert_line "login uses DOCKER_PASSWORD" "$LOGIN_BLOCK" \
  "          password: \${{ secrets.DOCKER_PASSWORD }}"
assert_no_text "login keeps the post-step logout (no logout: false)" "$LOGIN_BLOCK" \
  "logout: false"

# --- Docker Hub Login Failed ---------------------------------------------------
assert_line "warning runs only when the login failed" "$WARN_BLOCK" \
  "        if: steps.dockerhub-pull-login.outcome == 'failure'"
if printf '%s\n' "$WARN_BLOCK" | grep -qF -- "::warning"; then
  pass "a failed login is reported as a warning"
else
  fail "a failed login is reported as a warning" "expected a ::warning annotation in the step"
fi
assert_no_text "warning never prints a secret" "$WARN_BLOCK" "secrets."

# --- Position: ahead of everything that pulls ---------------------------------
LOGIN_LINE=$(line_of "        id: dockerhub-pull-login")
for target in "        id: docker-build" "      - name: 🧪 Run Pre-Build Tests"; do
  TARGET_LINE=$(line_of "$target")
  desc="login runs before '${target#*: }'"
  if [ -z "$TARGET_LINE" ]; then
    fail "$desc" "could not find the line: $target"
  elif [ "$LOGIN_LINE" -lt "$TARGET_LINE" ]; then
    pass "$desc"
  else
    fail "$desc" "login at line $LOGIN_LINE, target at line $TARGET_LINE"
  fi
done

echo
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
