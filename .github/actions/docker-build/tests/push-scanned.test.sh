#!/usr/bin/env bash
#
# Behavioural test for the single-build fast path in ../action.yml: the step
# 'Push Scanned Image (single-build, no rebuild)' (id: push-scanned).
#
# With single-build-scan the scanned image is pushed with `docker push`, tag by tag,
# instead of a second build. Its digest then names the image for Cosign and for the
# SBOM attestation. Three ways that went wrong, all after the push - when the release
# is already half out:
#
#   - the first tag was read with `printf ... | head -n1` under pipefail. With more
#     tags than head reads, printf dies of SIGPIPE and the step fails (the same
#     "Broken pipe" primary-tag.test.sh pins for the other steps);
#   - the digest was the FIRST line of RepoDigests, which lists every repository the
#     image went to in no guaranteed order - with a secondary registry that can be
#     the other registry's digest, so signature and attestation name the wrong one;
#   - one registry throttle in the middle of the tag loop failed the job with some
#     tags pushed and others not. The standard push retries once (build-retry.test.sh);
#     the fast path did not.
#
# The step script is extracted from action.yml at runtime and run the way a
# `shell: bash` step runs (-e -o pipefail). `docker` and `sleep` are stubbed.
#
# Usage: bash .github/actions/docker-build/tests/push-scanned.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION_FILE="$SCRIPT_DIR/../action.yml"

if [ ! -f "$ACTION_FILE" ]; then
  echo "FATAL: action.yml not found at $ACTION_FILE"
  exit 1
fi

# The step's `run:` block, 8-space indent stripped.
BODY=$(awk '
  /^      id: push-scanned$/ { found = 1; next }
  found && /^      run: \|$/  { on = 1; next }
  on && /^    - /             { exit }
  on { if ($0 == "") { print ""; next } sub(/^        /, ""); print }
' "$ACTION_FILE")
if [ -z "$BODY" ]; then
  echo "FATAL: the push-scanned step or its run block was not found - renamed or re-indented; update this test."
  exit 1
fi
if printf '%s\n' "$BODY" | grep -qF '${{'; then
  echo "FATAL: the push-scanned script interpolates an expression; it must read its inputs from env."
  exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
printf '%s\n' "$BODY" > "$WORK/step.sh"

mkdir -p "$WORK/bin"
# docker push <tag>: fails for the first $PUSH_FAILS calls (any tag), logs every call.
# docker inspect: prints $REPO_DIGESTS (one per line), or fails when it is unset.
cat > "$WORK/bin/docker" <<'EOF'
#!/usr/bin/env bash
case "$1" in
  push)
    n=$(( $(cat "$STATE/pushes" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$STATE/pushes"
    echo "$2" >> "$STATE/pushed"
    if [ "$n" -le "${PUSH_FAILS:-0}" ]; then
      echo "toomanyrequests: You have reached your pull rate limit" >&2
      exit 1
    fi ;;
  inspect)
    [ -n "${REPO_DIGESTS+x}" ] || exit 1
    printf '%s\n' "$REPO_DIGESTS" ;;
  *) echo "unexpected docker $*" >&2; exit 2 ;;
esac
EOF
printf '#!/usr/bin/env bash\necho "$1" >> "$STATE/sleeps"\n' > "$WORK/bin/sleep"
chmod +x "$WORK/bin/docker" "$WORK/bin/sleep"

FAILED=0
pass() { echo "  ok   $1"; }
fail() { echo "  FAIL $1"; FAILED=$((FAILED + 1)); }
check() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (expected '$3', got '$2')"; fi; }

GH="ghcr.io/org/app"
HUB="docker.io/org/app"
D_GH="sha256:$(printf 'a%.0s' $(seq 64))"
D_HUB="sha256:$(printf 'b%.0s' $(seq 64))"

# run_step <tags> [VAR=value ...]: runs the step, sets EXIT, DIGEST, PUSHES, SLEEPS, LOG.
run_step() {
  local tags="$1"; shift
  export STATE="$WORK/state-$RANDOM$RANDOM"; mkdir -p "$STATE"; : > "$STATE/out"
  ( export "$@"; META_TAGS="$tags" GITHUB_OUTPUT="$STATE/out" PATH="$WORK/bin:$PATH" \
      bash -e -o pipefail "$WORK/step.sh" ) > "$STATE/log" 2>&1
  EXIT=$?
  DIGEST=$(sed -n 's/^digest=//p' "$STATE/out")
  PUSHES=$(cat "$STATE/pushes" 2>/dev/null || echo 0)
  SLEEPS=$(cat "$STATE/sleeps" 2>/dev/null | tr '\n' ' ' | sed 's/ $//')
  LOG=$(cat "$STATE/log")
}

echo "push-scanned"

echo "- digest of the primary repository"
run_step "$GH:1.2.3"$'\n'"$GH:1.2"$'\n'"$HUB:1.2.3" REPO_DIGESTS="$HUB@$D_HUB"$'\n'"$GH@$D_GH"
check "exits 0" "$EXIT" 0
check "every tag pushed" "$PUSHES" 3
check "digest is the primary repo's even when RepoDigests lists another first" "$DIGEST" "$D_GH"

echo "- Docker Hub as primary (RepoDigests use the short name)"
run_step "docker.io/org/app:1.2.3" REPO_DIGESTS="org/app@$D_HUB"
check "docker.io/ prefix normalised" "$EXIT/$DIGEST" "0/$D_HUB"
run_step "docker.io/library/app:1" REPO_DIGESTS="app@$D_HUB"
check "library/ prefix normalised" "$EXIT/$DIGEST" "0/$D_HUB"

echo "- registry port in the primary tag"
run_step "registry.local:5000/org/app:1.2.3" REPO_DIGESTS="registry.local:5000/org/app@$D_GH"
check "port kept, tag stripped" "$EXIT/$DIGEST" "0/$D_GH"

echo "- many tags under pipefail"
# The SIGPIPE needs more output than a pipe buffer holds (thousands of tags), which
# would mean thousands of stubbed pushes. The class is pinned statically instead: no
# pipe into head anywhere in the step - plus one run with a realistic tag count.
if printf '%s\n' "$BODY" | grep -vE '^[[:space:]]*#' | grep -nE '\|[[:space:]]*head\b'; then
  fail "no pipe into head in the step (SIGPIPE under pipefail)"
else
  pass "no pipe into head in the step (SIGPIPE under pipefail)"
fi
MANY=$(for i in $(seq 1 50); do printf '%s:t%s\n' "$GH" "$i"; done)
run_step "$MANY" REPO_DIGESTS="$GH@$D_GH"
check "50 tags pushed, primary digest reported" "$EXIT/$PUSHES/$DIGEST" "0/50/$D_GH"

echo "- registry throttle in the middle of the tags"
run_step "$GH:1.2.3"$'\n'"$GH:1.2" REPO_DIGESTS="$GH@$D_GH" PUSH_FAILS=1
check "the failed tag is retried once and the step succeeds" "$EXIT/$PUSHES" "0/3"
check "  after one 60-90 s backoff" "$([ "${SLEEPS:-0}" -ge 60 ] && [ "${SLEEPS:-0}" -le 90 ] && echo yes || echo "no ($SLEEPS)")" yes
if printf '%s' "$LOG" | grep -q '::warning title=Docker push retried::'; then pass "  and says so"; else fail "  and says so"; fi

echo "- a second failure"
run_step "$GH:1.2.3" REPO_DIGESTS="$GH@$D_GH" PUSH_FAILS=2
check "fails the job after exactly one retry" "$EXIT/$PUSHES" "1/2"

echo "- no digest for the primary repository"
run_step "$GH:1.2.3" REPO_DIGESTS="$HUB@$D_HUB"
check "fails instead of reporting a push without a digest" "$EXIT" 1
check "  writes no digest" "$DIGEST" ""
if printf '%s' "$LOG" | grep -q '^::error::'; then pass "  and says why"; else fail "  and says why"; fi
run_step "$GH:1.2.3"
check "inspect failing counts as no digest" "$EXIT/$DIGEST" "1/"

echo
if [ "$FAILED" -gt 0 ]; then
  echo "$FAILED check(s) failed"
  exit 1
fi
echo "all checks passed"
