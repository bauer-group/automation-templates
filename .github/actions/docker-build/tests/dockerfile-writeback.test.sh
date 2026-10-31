#!/usr/bin/env bash
#
# Regression test for the 'Commit Dockerfile Version Update' step in ../action.yml.
#
# A multi-image release runs one job per image, and every one of them writes its
# Dockerfile's version back to the default branch within seconds of the others.
# The push used to be a single attempt, so the job that lost the race between its
# own pull and its push failed the whole release with "cannot lock ref" although
# its image was already in the registry (CS-NocoDB, 2026-09-29). The step now
# rebases and retries; these cases pin that it recovers from a lost race and from
# server errors, that it does not paper over a real conflict, and that it still
# fails - loudly - when the push never goes through.
#
# Each case runs the real step body against local repositories: a bare "origin",
# the job's checkout, and a second checkout that plays the parallel job. A `git`
# wrapper on PATH lets that parallel job push exactly between this job's pull and
# its first push, and a pre-receive hook on origin simulates server-side
# rejections. `sleep` is stubbed so the backoff is recorded instead of waited for.
#
# The step body is extracted from action.yml at runtime rather than duplicated
# here: a copied-out script would keep passing after the real one regressed.
#
# Usage: bash .github/actions/docker-build/tests/dockerfile-writeback.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION_FILE="$SCRIPT_DIR/../action.yml"
STEP_ID="dockerfile-writeback"

if [ ! -f "$ACTION_FILE" ]; then
  echo "FATAL: action.yml not found at $ACTION_FILE"
  exit 1
fi

# Extract the `run:` block of the step with id: $STEP_ID and strip its 8-space indent.
STEP_BODY=$(awk -v step="      id: $STEP_ID" '
  $0 == step        { found = 1; next }
  found && /^      run: \|$/ { collecting = 1; next }
  collecting {
    if ($0 == "") { print ""; next }
    if ($0 ~ /^        /) { sub(/^        /, ""); print; next }
    exit
  }
' "$ACTION_FILE")

if [ -z "$STEP_BODY" ]; then
  echo "FATAL: could not extract the '$STEP_ID' run block from action.yml."
  echo "       The step was renamed, removed, or re-indented - update this test."
  exit 1
fi

REAL_GIT=$(command -v git)
export REAL_GIT

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# Isolate from the machine's git configuration (pull.rebase, autocrlf, hooks path).
printf '[init]\n\tdefaultBranch = main\n[advice]\n\tdetachedHead = false\n' > "$WORK/gitconfig"
export GIT_CONFIG_GLOBAL="$WORK/gitconfig"
export GIT_CONFIG_NOSYSTEM=1

mkdir -p "$WORK/bin"
cat > "$WORK/bin/sleep" <<'EOF'
#!/usr/bin/env bash
echo "$1" >> "$SLEEP_LOG"
EOF
cat > "$WORK/bin/git" <<'EOF'
#!/usr/bin/env bash
# Counts pushes and, once, lets the parallel job push right before this job's push.
if [ "${1:-}" = "push" ]; then
  echo push >> "$PUSH_LOG"
  if [ -n "${RACE_SCRIPT:-}" ] && [ ! -e "$PUSH_LOG.raced" ]; then
    : > "$PUSH_LOG.raced"
    bash "$RACE_SCRIPT" > "$PUSH_LOG.race-output" 2>&1 || { echo "test harness: race script failed" >&2; exit 99; }
  fi
fi
exec "$REAL_GIT" "$@"
EOF
chmod +x "$WORK/bin/sleep" "$WORK/bin/git"

PASSED=0
FAILED=0

pass() { PASSED=$((PASSED + 1)); printf 'ok   %s\n' "$1"; }
fail() { FAILED=$((FAILED + 1)); printf 'FAIL %s\n' "$1"; shift; printf '       %s\n' "$@"; }

dockerfile() { printf 'FROM scratch\nLABEL org.opencontainers.image.version="%s"\n' "$1"; }

# new_case <clone-depth>: origin with a/Dockerfile and b/Dockerfile at 1.0.0 on main,
# the job's checkout ($CASE/job) and the parallel job's checkout ($CASE/other).
new_case() {
  local depth="${1:-0}"
  CASE=$(mktemp -d "$WORK/case.XXXXXX")
  "$REAL_GIT" init -q --bare "$CASE/origin.git"
  "$REAL_GIT" -C "$CASE/origin.git" symbolic-ref HEAD refs/heads/main
  "$REAL_GIT" clone -q "$CASE/origin.git" "$CASE/seed" 2>/dev/null
  mkdir -p "$CASE/seed/a" "$CASE/seed/b"
  dockerfile 1.0.0 > "$CASE/seed/a/Dockerfile"
  dockerfile 1.0.0 > "$CASE/seed/b/Dockerfile"
  "$REAL_GIT" -C "$CASE/seed" add -A
  "$REAL_GIT" -C "$CASE/seed" -c user.name=seed -c user.email=seed@example.invalid commit -qm init
  "$REAL_GIT" -C "$CASE/seed" push -q origin HEAD:main
  if [ "$depth" -gt 0 ]; then
    "$REAL_GIT" clone -q --depth "$depth" "file://$CASE/origin.git" "$CASE/job"
  else
    "$REAL_GIT" clone -q "$CASE/origin.git" "$CASE/job"
  fi
  "$REAL_GIT" clone -q "$CASE/origin.git" "$CASE/other"
  "$REAL_GIT" -C "$CASE/other" config user.name other
  "$REAL_GIT" -C "$CASE/other" config user.email other@example.invalid
  : > "$CASE/push.log"
  : > "$CASE/sleep.log"
  RACE_SCRIPT=""
}

# race <dockerfile> <version>: what the parallel job pushes between this job's pull and push.
race() {
  RACE_SCRIPT="$CASE/race.sh"
  cat > "$RACE_SCRIPT" <<EOF
set -e
cd "$CASE/other"
"\$REAL_GIT" pull -q origin main
printf 'FROM scratch\nLABEL org.opencontainers.image.version="%s"\n' "$2" > "$1"
"\$REAL_GIT" commit -qam "chore: update Dockerfile version to $2"
"\$REAL_GIT" push -q origin HEAD:main
EOF
}

# reject_pushes <n>: origin refuses the next n pushes, as GitHub does on a 5xx.
reject_pushes() {
  echo "$1" > "$CASE/rejects"
  cat > "$CASE/origin.git/hooks/pre-receive" <<EOF
#!/usr/bin/env bash
n=\$(cat "$CASE/rejects")
if [ "\$n" -gt 0 ]; then
  echo \$((n - 1)) > "$CASE/rejects"
  echo "simulated: 500 Internal Server Error" >&2
  exit 1
fi
EOF
  chmod +x "$CASE/origin.git/hooks/pre-receive"
}

# run_step <dockerfile> <version>: the step as the runner invokes `shell: bash`.
run_step() {
  ( cd "$CASE/job" && \
    PATH="$WORK/bin:$PATH" PUSH_LOG="$CASE/push.log" SLEEP_LOG="$CASE/sleep.log" RACE_SCRIPT="$RACE_SCRIPT" \
    DOCKERFILE_PATH="$1" VERSION="$2" RELEASE_VERSION="$2" GITHUB_REF="refs/heads/main" \
      bash --noprofile --norc -eo pipefail -c "$STEP_BODY" ) > "$CASE/out.log" 2>&1
  RC=$?
}

origin_version() { "$REAL_GIT" -C "$CASE/origin.git" show "main:$1" 2>/dev/null | grep -oE '"[^"]+"' | tr -d '"'; }
pushes() { wc -l < "$CASE/push.log" | tr -dc '0-9'; }
sleeps() { wc -l < "$CASE/sleep.log" | tr -dc '0-9'; }
commits() { "$REAL_GIT" -C "$CASE/origin.git" rev-list --count main; }
merges() { "$REAL_GIT" -C "$CASE/origin.git" rev-list --merges --count main; }
log_has() { grep -qF -- "$1" "$CASE/out.log"; }

report() {
  local desc="$1"; shift
  if [ $# -eq 0 ]; then pass "$desc"; else fail "$desc" "$@" "step output: $(tr '\n' ' ' < "$CASE/out.log" | cut -c1-600)"; fi
}

echo "Testing '$STEP_ID' from $(basename "$ACTION_FILE")"
echo

# --- 1. No competition: one push, no retry ------------------------------------------
new_case
run_step a/Dockerfile 1.1.0
p=()
[ "$RC" -eq 0 ] || p+=("exit $RC, expected 0")
[ "$(origin_version a/Dockerfile)" = "1.1.0" ] || p+=("origin a/Dockerfile is $(origin_version a/Dockerfile), expected 1.1.0")
[ "$(pushes)" = "1" ] || p+=("$(pushes) push attempts, expected 1")
[ "$(sleeps)" = "0" ] || p+=("slept $(sleeps) times, expected 0")
log_has "::warning::Push attempt" && p+=("warned about a retry that did not happen")
report "uncontended write-back pushes once" "${p[@]}"

# --- 2. A parallel image job wins the race between pull and push ---------------------
new_case
race b/Dockerfile 1.1.0
run_step a/Dockerfile 1.1.0
p=()
[ "$RC" -eq 0 ] || p+=("exit $RC, expected 0 - the lost race failed the release")
[ "$(origin_version a/Dockerfile)" = "1.1.0" ] || p+=("origin a/Dockerfile is $(origin_version a/Dockerfile), expected 1.1.0")
[ "$(origin_version b/Dockerfile)" = "1.1.0" ] || p+=("origin b/Dockerfile is $(origin_version b/Dockerfile), expected the parallel job's 1.1.0")
[ "$(pushes)" = "2" ] || p+=("$(pushes) push attempts, expected 2")
[ "$(commits)" = "3" ] || p+=("$(commits) commits on main, expected 3 (init + one per job)")
[ "$(merges)" = "0" ] || p+=("$(merges) merge commit(s) on main, expected a linear history")
log_has "::warning::Push attempt 1/5" || p+=("no ::warning:: for the rejected first attempt")
report "lost race to a parallel image job is rebased and retried" "${p[@]}"

# --- 3. Same race with a shallow checkout (checkout-fetch-depth: 1) ------------------
new_case 1
race b/Dockerfile 1.1.0
run_step a/Dockerfile 1.1.0
p=()
[ "$RC" -eq 0 ] || p+=("exit $RC, expected 0")
[ "$(origin_version a/Dockerfile)" = "1.1.0" ] || p+=("origin a/Dockerfile is $(origin_version a/Dockerfile), expected 1.1.0")
[ "$(origin_version b/Dockerfile)" = "1.1.0" ] || p+=("origin b/Dockerfile is $(origin_version b/Dockerfile), expected 1.1.0")
[ "$(merges)" = "0" ] || p+=("$(merges) merge commit(s) on main, expected a linear history")
report "lost race is retried from a shallow checkout too" "${p[@]}"

# --- 4. Two jobs bump the same Dockerfile to the same version ------------------------
new_case
race a/Dockerfile 1.1.0
run_step a/Dockerfile 1.1.0
p=()
[ "$RC" -eq 0 ] || p+=("exit $RC, expected 0")
[ "$(origin_version a/Dockerfile)" = "1.1.0" ] || p+=("origin a/Dockerfile is $(origin_version a/Dockerfile), expected 1.1.0")
[ "$(commits)" = "2" ] || p+=("$(commits) commits on main, expected 2 - the duplicate bump should be dropped")
report "identical bump already upstream is dropped, not duplicated" "${p[@]}"

# --- 5. GitHub refuses the first two pushes ------------------------------------------
new_case
reject_pushes 2
run_step a/Dockerfile 1.1.0
p=()
[ "$RC" -eq 0 ] || p+=("exit $RC, expected 0")
[ "$(origin_version a/Dockerfile)" = "1.1.0" ] || p+=("origin a/Dockerfile is $(origin_version a/Dockerfile), expected 1.1.0")
[ "$(pushes)" = "3" ] || p+=("$(pushes) push attempts, expected 3")
mapfile -t delays < "$CASE/sleep.log"
{ [ "${#delays[@]}" -eq 2 ] && [ "${delays[0]}" -ge 5 ] && [ "${delays[0]}" -le 9 ] && [ "${delays[1]}" -ge 10 ] && [ "${delays[1]}" -le 14 ]; } \
  || p+=("backoff delays were '${delays[*]}', expected one in 5-9 then one in 10-14 seconds")
report "transient push errors are retried with growing backoff" "${p[@]}"

# --- 6. The push never goes through: the release stays red --------------------------
new_case
reject_pushes 99
run_step a/Dockerfile 1.1.0
p=()
[ "$RC" -ne 0 ] || p+=("exit 0 - a write-back that never landed was reported as success")
[ "$(pushes)" = "5" ] || p+=("$(pushes) push attempts, expected 5")
[ "$(sleeps)" = "4" ] || p+=("slept $(sleeps) times, expected 4")
[ "$(origin_version a/Dockerfile)" = "1.0.0" ] || p+=("origin a/Dockerfile changed to $(origin_version a/Dockerfile)")
log_has "::error::Pushing the Dockerfile version update to main failed after 5 attempts" || p+=("no ::error:: naming the 5 failed attempts")
report "after 5 failed attempts the step fails" "${p[@]}"

# --- 7. A conflicting change landed meanwhile: fail at once, leave no rebase behind ---
new_case
race a/Dockerfile 2.0.0
run_step a/Dockerfile 1.1.0
p=()
[ "$RC" -ne 0 ] || p+=("exit 0 - a conflicting write-back was reported as success")
[ "$(pushes)" = "1" ] || p+=("$(pushes) push attempts, expected 1 - a conflict must not be retried")
[ "$(origin_version a/Dockerfile)" = "2.0.0" ] || p+=("origin a/Dockerfile is $(origin_version a/Dockerfile), expected the newer 2.0.0 untouched")
log_has "::error::The Dockerfile version commit conflicts" || p+=("no ::error:: naming the conflict")
{ [ -d "$CASE/job/.git/rebase-merge" ] || [ -d "$CASE/job/.git/rebase-apply" ]; } \
  && p+=("a rebase was left in progress in the job's checkout")
[ -z "$("$REAL_GIT" -C "$CASE/job" status --porcelain)" ] || p+=("the job's checkout was left dirty")
report "conflicting change on main fails without retrying" "${p[@]}"

echo
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
