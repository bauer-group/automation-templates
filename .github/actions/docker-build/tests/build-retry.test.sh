#!/usr/bin/env bash
#
# Regression test for the build retry in ../action.yml: the steps 'Build Docker
# Image (Local)' and 'Push Docker Image', their 'Check Build Failure' steps and their
# retries.
#
# On 2026-10-15 a burst of 31 scheduled base-image monitors (~100 runs in ~45
# repositories) made Docker Hub answer BuildKit's manifest HEAD requests with
# "429 Too Many Requests" in three builds that were logged in. Their releases were
# already tagged and ended half-published. Each build now runs with
# continue-on-error, and a check step reads the cause from BuildKit's build record:
# a rate limit, a 408 or 5xx answer or a network failure gets exactly one retry after
# a 60-90 s backoff, anything else fails the job at once. This pins both sides:
#
#   - the wiring: continue-on-error on the first attempt only, guards that run the
#     check and the retry only after a failed first attempt, a retry with exactly
#     the first attempt's inputs, and outputs that every consumer reads from
#     whichever attempt succeeded;
#   - the decision: retryable causes retry once with a bounded backoff, genuine
#     build errors fail without a retry, an unreadable record retries, and the
#     check never exits 0 without scheduling the retry - that would let the failed
#     first attempt pass silently.
#
# The check script is extracted from action.yml at runtime rather than duplicated
# here: a copied-out script would keep passing after the real one regressed.
# `docker` and `sleep` are stubbed, so no daemon is needed and no backoff is waited.
#
# Usage: bash .github/actions/docker-build/tests/build-retry.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION_FILE="$SCRIPT_DIR/../action.yml"
WORKFLOW_FILE="$SCRIPT_DIR/../../../workflows/docker-build.yml"

for f in "$ACTION_FILE" "$WORKFLOW_FILE"; do
  if [ ! -f "$f" ]; then
    echo "FATAL: $(basename "$f") not found at $f"
    exit 1
  fi
done

# step_block <id>: the step's own lines, from its `- name:` up to the next step.
step_block() {
  awk -v step="      id: $1" '
    /^    - / { if (found) exit; buf = $0; next }
    $0 == step  { found = 1; print buf; print; next }
    found       { print; next }
    buf != ""   { buf = buf "\n" $0 }
  ' "$ACTION_FILE"
}

# section <block> <key>: the entries of the step's `with:` or `env:` map, comments dropped.
section() {
  printf '%s\n' "$1" | awk -v key="      $2:" '
    $0 == key            { on = 1; next }
    on && /^        /    { if ($0 !~ /^ *#/) print; next }
    on                   { exit }
  '
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

# require_block <id> <block>: stop when a step could not be found at all.
require_block() {
  if [ -z "$2" ]; then
    echo "FATAL: step '$1' not found in action.yml."
    echo "       It was renamed, removed, or re-indented - update this test."
    exit 1
  fi
}

PASSED=0
FAILED=0

pass() { PASSED=$((PASSED + 1)); printf 'ok   %s\n' "$1"; }
fail() { FAILED=$((FAILED + 1)); printf 'FAIL %s\n' "$1"; shift; printf '       %s\n' "$@"; }

# Both read a here-string, not `printf | grep -q`: they are also handed whole files,
# where grep -q exits before printf has written everything, and under pipefail the
# SIGPIPE turns a match into a miss.
# assert_line <description> <block> <exact line>
assert_line() {
  local desc="$1" block="$2" line="$3"
  if grep -qxF -- "$line" <<< "$block"; then
    pass "$desc"
  else
    fail "$desc" "expected the line: $line"
  fi
}

# assert_no_text <description> <block> <text>
assert_no_text() {
  local desc="$1" block="$2" text="$3"
  if grep -qF -- "$text" <<< "$block"; then
    fail "$desc" "must not contain: $text"
  else
    pass "$desc"
  fi
}

echo "Testing the build retry in $(basename "$ACTION_FILE")"
echo

# "<step number> <id>" for every step with an id, numbered over ALL steps - also those
# without an id - to pin that check and retry follow their build directly: numbering
# the id lines alone would miss an id-less step slipped in between.
STEP_IDS=$(awk '/^    - / { n++ } /^      id: / { print n, substr($0, 11) }' "$ACTION_FILE")
position() { printf '%s\n' "$STEP_IDS" | awk -v id="$1" '$2 == id { print $1 }'; }

# --- Wiring, per build path ------------------------------------------------------
for path in "build-local build-local-retry-check build-local-retry" \
            "build build-retry-check build-retry"; do
  read -r FIRST CHECK RETRY <<< "$path"
  FIRST_BLOCK=$(step_block "$FIRST")
  CHECK_BLOCK=$(step_block "$CHECK")
  RETRY_BLOCK=$(step_block "$RETRY")
  require_block "$FIRST" "$FIRST_BLOCK"
  require_block "$CHECK" "$CHECK_BLOCK"
  require_block "$RETRY" "$RETRY_BLOCK"

  P_FIRST=$(position "$FIRST"); P_CHECK=$(position "$CHECK"); P_RETRY=$(position "$RETRY")
  if [ "$P_CHECK" -eq $((P_FIRST + 1)) ] && [ "$P_RETRY" -eq $((P_CHECK + 1)) ]; then
    pass "$FIRST: '$CHECK' and '$RETRY' follow it directly"
  else
    fail "$FIRST: '$CHECK' and '$RETRY' follow it directly" "positions: $FIRST=$P_FIRST $CHECK=$P_CHECK $RETRY=$P_RETRY"
  fi

  # The first attempt defers its failure; nothing else may swallow one.
  if [ "$(printf '%s\n' "$FIRST_BLOCK" | grep -cxF -- '      continue-on-error: true')" -eq 1 ]; then
    pass "$FIRST: the first attempt runs with continue-on-error"
  else
    fail "$FIRST: the first attempt runs with continue-on-error" "expected exactly one line: continue-on-error: true"
  fi
  for step in "$CHECK" "$RETRY"; do
    if grep -qE '^      continue-on-error:' <<< "$(step_block "$step")"; then
      fail "$step: its failure fails the job (no continue-on-error)" "only the first attempt may set continue-on-error"
    else
      pass "$step: its failure fails the job (no continue-on-error)"
    fi
  done

  assert_line "$CHECK: runs only after a failed first attempt" "$CHECK_BLOCK" \
    "      if: steps.$FIRST.outcome == 'failure'"
  assert_line "$RETRY: runs only after a failed first attempt the check cleared" "$RETRY_BLOCK" \
    "      if: steps.$FIRST.outcome == 'failure' && steps.$CHECK.outputs.retry == 'true'"
  assert_line "$CHECK: runs under bash" "$CHECK_BLOCK" "      shell: bash"
  if grep -qE '^        BUILD_NAME: [A-Z].+$' <<< "$(section "$CHECK_BLOCK" env)"; then
    pass "$CHECK: names its build through env"
  else
    fail "$CHECK: names its build through env" "expected an env entry BUILD_NAME: <sentence-case name>"
  fi

  FIRST_USES=$(printf '%s\n' "$FIRST_BLOCK" | grep -E '^      uses: ')
  RETRY_USES=$(printf '%s\n' "$RETRY_BLOCK" | grep -E '^      uses: ')
  if [ -n "$FIRST_USES" ] && [ "$FIRST_USES" = "$RETRY_USES" ]; then
    pass "$RETRY: uses the same action as $FIRST (${FIRST_USES#*uses: })"
  else
    fail "$RETRY: uses the same action as $FIRST" "first: '$FIRST_USES'" "retry: '$RETRY_USES'"
  fi

  for key in with env; do
    FIRST_SECTION=$(section "$FIRST_BLOCK" "$key")
    RETRY_SECTION=$(section "$RETRY_BLOCK" "$key")
    if [ -n "$FIRST_SECTION" ] && [ "$FIRST_SECTION" = "$RETRY_SECTION" ]; then
      pass "$RETRY: '$key:' is identical to $FIRST ($(printf '%s\n' "$FIRST_SECTION" | grep -c .) entries)"
    else
      fail "$RETRY: '$key:' is identical to $FIRST" \
        "$(diff <(printf '%s\n' "$FIRST_SECTION") <(printf '%s\n' "$RETRY_SECTION") | tr '\n' ' ')"
    fi
  done
done

LOCAL_BODY=$(run_body "$(step_block build-local-retry-check)")
PUSH_BODY=$(run_body "$(step_block build-retry-check)")
if [ -n "$LOCAL_BODY" ] && [ "$LOCAL_BODY" = "$PUSH_BODY" ]; then
  pass "both check steps run the same script"
else
  fail "both check steps run the same script" "the run blocks of build-local-retry-check and build-retry-check differ"
fi

# --- Every consumer reads both attempts ------------------------------------------
# A reference to one attempt's output must sit next to the other's, or the value
# is empty whenever the other attempt was the one that succeeded.
REFS=0
while IFS= read -r ref; do
  [ -n "$ref" ] || continue
  REFS=$((REFS + 1))
  LINE_NO="${ref%%:*}"
  LINE_TEXT="${ref#*:}"
  for pair in "build build-retry" "build-local build-local-retry"; do
    read -r A B <<< "$pair"
    for out in $(printf '%s\n' "$LINE_TEXT" | grep -oE "steps\.($A|$B)\.outputs\.[A-Za-z0-9_-]+" | sed -E 's/.*\.outputs\.//' | sort -u); do
      if printf '%s\n' "$LINE_TEXT" | grep -qF "steps.$A.outputs.$out" \
        && printf '%s\n' "$LINE_TEXT" | grep -qF "steps.$B.outputs.$out"; then
        pass "line $LINE_NO: '$out' is read from $A and $B"
      else
        fail "line $LINE_NO: '$out' is read from $A and $B" "found: ${LINE_TEXT#"${LINE_TEXT%%[! ]*}"}"
      fi
    done
  done
done < <(grep -nE 'steps\.(build|build-retry|build-local|build-local-retry)\.outputs\.' "$ACTION_FILE")

if [ "$REFS" -ge 2 ]; then
  pass "build outputs are consumed ($REFS lines checked)"
else
  fail "build outputs are consumed" "expected at least the image-digest output and the signing digest, found $REFS lines"
fi

assert_line "image-digest coalesces push, push retry, fast-path push, local, local retry - in that order" "$(cat "$ACTION_FILE")" \
  "    value: \${{ steps.build.outputs.digest || steps.build-retry.outputs.digest || steps.push-scanned.outputs.digest || steps.build-local.outputs.digest || steps.build-local-retry.outputs.digest }}"

# single-build-scan pushes in its own step (push-scanned), so a push digest has three
# sources. A consumer that reads only build/build-retry passes the pairing check above
# and still gets an empty digest on the fast path - for the SBOM attestation that
# fails the release after the push.
MISSING_FAST_PATH=$(grep -nF 'steps.build.outputs.digest' "$ACTION_FILE" | grep -vF 'steps.push-scanned.outputs.digest')
if [ -z "$MISSING_FAST_PATH" ]; then
  pass "every push-digest consumer also reads the single-build fast path"
else
  fail "every push-digest consumer also reads the single-build fast path" "missing in: $MISSING_FAST_PATH"
fi
assert_line "the workflow takes the digest from the action's coalesced output" "$(cat "$WORKFLOW_FILE")" \
  "      image-digest: \${{ steps.docker-build.outputs.image-digest }}"
assert_no_text "the workflow never reads the action's inner build steps" "$(cat "$WORKFLOW_FILE")" \
  "steps.build"

# The first attempt's outcome says nothing about the build once a retry may follow;
# only the check and the retry guard may read it.
OUTCOME_REFS=$(grep -nE 'steps\.(build|build-retry|build-local|build-local-retry)\.(outcome|conclusion)' "$ACTION_FILE" \
  | grep -vE "^[0-9]+:      if: steps\.(build|build-local)\.outcome == 'failure'( && steps\.(build|build-local)-retry-check\.outputs\.retry == 'true')?$")
if [ -z "$OUTCOME_REFS" ]; then
  pass "no step reads a build attempt's outcome except the check and retry guards"
else
  fail "no step reads a build attempt's outcome except the check and retry guards" "found: $OUTCOME_REFS"
fi

# --- The check's decision ----------------------------------------------------------
if [ -z "$LOCAL_BODY" ]; then
  echo "FATAL: could not extract the run block of 'build-local-retry-check' from action.yml."
  exit 1
fi

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"
cat > "$WORK/bin/docker" <<'EOF'
#!/usr/bin/env bash
# Plays `docker buildx history inspect`: prints the record in $STUB_RECORD_FILE, or
# fails like an older buildx when $STUB_EXIT is set.
printf '%s\n' "$*" >> "$DOCKER_LOG"
if [ -n "${STUB_EXIT:-}" ]; then
  echo "ERROR: unknown command \"history\" for \"docker buildx\"" >&2
  exit "$STUB_EXIT"
fi
cat "$STUB_RECORD_FILE"
EOF
cat > "$WORK/bin/sleep" <<'EOF'
#!/usr/bin/env bash
echo "$1" >> "$SLEEP_LOG"
EOF
chmod +x "$WORK/bin/docker" "$WORK/bin/sleep"

# failed_record <message>: `history inspect --format json` of a failed build. The
# message travels on stdin, not as an argument, so it may be longer than ARG_MAX.
failed_record() {
  jq -Rs '{Name: "app", Ref: "qu2gsuo8ejqrwdfii23xkkckt", Status: "failed",
    Error: {Code: 2, Message: rtrimstr("\n")}, NumCompletedSteps: 3, NumTotalSteps: 9}' <<< "$1"
}

# run_check <record> [exit]: the check as the runner invokes `shell: bash`, with the
# PATH in $CHECK_PATH when set. Sets RC, LOG, OUT, SLEPT and DOCKER_ARGS.
run_check() {
  local record_file out_file log_file sleep_file docker_file
  record_file=$(mktemp "$WORK/record.XXXXXX"); out_file=$(mktemp "$WORK/out.XXXXXX")
  log_file=$(mktemp "$WORK/log.XXXXXX"); sleep_file=$(mktemp "$WORK/sleep.XXXXXX")
  docker_file=$(mktemp "$WORK/docker.XXXXXX")
  printf '%s\n' "$1" > "$record_file"
  PATH="${CHECK_PATH:-$WORK/bin:$PATH}" STUB_RECORD_FILE="$record_file" STUB_EXIT="${2:-}" \
  DOCKER_LOG="$docker_file" SLEEP_LOG="$sleep_file" \
  BUILD_NAME="The local (scan) build" GITHUB_OUTPUT="$out_file" \
    bash --noprofile --norc -eo pipefail -c "$LOCAL_BODY" > "$log_file" 2>&1
  RC=$?
  LOG=$(cat "$log_file"); OUT=$(cat "$out_file"); SLEPT=$(cat "$sleep_file"); DOCKER_ARGS=$(cat "$docker_file")
  rm -f "$record_file" "$out_file" "$log_file" "$sleep_file" "$docker_file"
}

# The invariant that keeps continue-on-error safe: exit 0 if and only if retry=true.
invariant_problems() {
  if [ "$RC" -eq 0 ] && [ "$OUT" != "retry=true" ]; then
    echo "exited 0 without exactly 'retry=true' in GITHUB_OUTPUT (got '$OUT') - the failed build would pass"
  fi
  if [ "$RC" -ne 0 ] && [ -n "$OUT" ]; then
    echo "failed but still wrote '$OUT' to GITHUB_OUTPUT"
  fi
}

# assert_retry <description> <record> [exit]
assert_retry() {
  local desc="$1" problems=() p
  run_check "$2" "${3:-}"
  while IFS= read -r p; do [ -n "$p" ] && problems+=("$p"); done < <(invariant_problems)
  [ "$RC" -eq 0 ] || problems+=("expected a retry, the step failed (exit $RC): $(printf '%s' "$LOG" | tr '\n' ' ')")
  [ "$OUT" = "retry=true" ] || problems+=("expected GITHUB_OUTPUT 'retry=true', got '$OUT'")
  if [[ "$SLEPT" =~ ^[0-9]+$ ]] && [ "$SLEPT" -ge 60 ] && [ "$SLEPT" -le 90 ]; then
    printf '%s\n' "$LOG" | grep -qF -- "retrying once in ${SLEPT}s" \
      || problems+=("the warning does not name the ${SLEPT}s actually waited")
  else
    problems+=("expected one backoff of 60-90 s, slept: '$SLEPT'")
  fi
  printf '%s\n' "$LOG" | grep -qE '^::warning title=Docker build retried::The local \(scan\) build failed ' \
    || problems+=("expected a '::warning title=Docker build retried::' annotation naming the build")
  printf '%s\n' "$LOG" | grep -qF -- "::error" && problems+=("emitted an ::error annotation")
  [ "$DOCKER_ARGS" = "buildx history inspect --format json" ] \
    || problems+=("expected one 'docker buildx history inspect --format json', got: $(printf '%s' "$DOCKER_ARGS" | tr '\n' ';')")
  if [ ${#problems[@]} -eq 0 ]; then pass "$desc"; else fail "$desc" "${problems[@]}"; fi
}

# assert_no_retry <description> <record>
assert_no_retry() {
  local desc="$1" problems=() p
  run_check "$2"
  while IFS= read -r p; do [ -n "$p" ] && problems+=("$p"); done < <(invariant_problems)
  [ "$RC" -ne 0 ] || problems+=("expected the step to fail, it exited 0")
  [ -z "$OUT" ] || problems+=("expected no retry output, got '$OUT'")
  [ -z "$SLEPT" ] || problems+=("expected no backoff, slept '$SLEPT'")
  printf '%s\n' "$LOG" | grep -qE '^::error title=Docker build failed::The local \(scan\) build failed .*not retried' \
    || problems+=("expected a '::error title=Docker build failed::' annotation saying it is not retried")
  printf '%s\n' "$LOG" | grep -qF -- "::warning" && problems+=("emitted a ::warning annotation")
  if [ ${#problems[@]} -eq 0 ]; then pass "$desc"; else fail "$desc" "${problems[@]}"; fi
}

# Retried: rate limits, 408 and 5xx answers, network failures.
assert_retry "429 on the manifest HEAD (2026-10-15) -> retry" "$(failed_record \
  'failed to resolve source metadata for docker.io/library/nginx:stable: unexpected status from HEAD request to https://registry-1.docker.io/v2/library/nginx/manifests/stable: 429 Too Many Requests')"
assert_retry "Docker Hub pull limit (toomanyrequests) -> retry" "$(failed_record \
  'failed to copy: httpReadSeeker: failed open: unexpected status code https://registry-1.docker.io/v2/library/node/manifests/sha256:4d1b: 429 Too Many Requests - Server message: toomanyrequests: You have reached your unauthenticated pull rate limit. https://www.docker.com/increase-rate-limit')"
assert_retry "bare 'toomanyrequests' without a status line -> retry" "$(failed_record \
  'failed to resolve source metadata for lscr.io/linuxserver/nginx:latest: toomanyrequests: retry-after: 1.2ms, allowed: 44000/minute')"
assert_retry "429 on a push to GHCR -> retry" "$(failed_record \
  'failed to push ghcr.io/bauer-group/app:1.2.3: unexpected status from PUT request to https://ghcr.io/v2/bauer-group/app/manifests/1.2.3: 429 Too Many Requests')"
assert_retry "lowercase '429 too many requests' -> retry" "$(failed_record \
  'unexpected status from HEAD request to https://registry.example.com/v2/app/manifests/1: 429 too many requests')"
assert_retry "500 Internal Server Error -> retry" "$(failed_record \
  'unexpected status from HEAD request to https://registry-1.docker.io/v2/library/nginx/manifests/stable: 500 Internal Server Error')"
assert_retry "502 Bad Gateway -> retry" "$(failed_record \
  'failed to push docker.io/bauergroup/app:1.2.3: unexpected status from PUT request to https://registry-1.docker.io/v2/bauergroup/app/blobs/uploads/: 502 Bad Gateway')"
assert_retry "503 Service Unavailable -> retry" "$(failed_record \
  'unexpected status from HEAD request to https://registry-1.docker.io/v2/library/nginx/manifests/stable: 503 Service Unavailable')"
assert_retry "504 Gateway Timeout -> retry" "$(failed_record \
  'unexpected status from GET request to https://ghcr.io/v2/bauer-group/base/manifests/1: 504 Gateway Timeout')"
assert_retry "connection reset by peer -> retry" "$(failed_record \
  'failed to do request: Head "https://registry-1.docker.io/v2/library/nginx/manifests/stable": read tcp 10.1.0.4:41234->54.236.113.205:443: read: connection reset by peer')"
assert_retry "TLS handshake timeout -> retry" "$(failed_record \
  'failed to do request: Head "https://registry-1.docker.io/v2/library/nginx/manifests/stable": net/http: TLS handshake timeout')"
assert_retry "i/o timeout -> retry" "$(failed_record \
  'failed to do request: Head "https://registry-1.docker.io/v2/library/nginx/manifests/stable": dial tcp 54.236.113.205:443: i/o timeout')"
assert_retry "408 Request Timeout -> retry" "$(failed_record \
  'unexpected status from HEAD request to https://ghcr.io/v2/bauer-group/base/manifests/1: 408 Request Timeout')"
assert_retry "unexpected EOF while reading a blob -> retry" "$(failed_record \
  'failed to copy: httpReadSeeker: failed open: failed to do request: Get "https://production.cloudflare.docker.com/registry-v2/docker/registry/v2/blobs/sha256/4d/4d1b/data": unexpected EOF')"
assert_retry "DNS server failure (server misbehaving) -> retry" "$(failed_record \
  'failed to do request: Head "https://registry-1.docker.io/v2/library/nginx/manifests/stable": dial tcp: lookup registry-1.docker.io on 168.63.129.16:53: server misbehaving')"
assert_retry "connection closed by the registry (EOF) -> retry" "$(failed_record \
  'failed to resolve source metadata for docker.io/library/nginx:stable: failed to do request: Head "https://registry-1.docker.io/v2/library/nginx/manifests/stable": EOF')"
assert_line "a dropped connection is reported as 'EOF'" "$LOG" \
  "::warning title=Docker build retried::The local (scan) build failed with 'EOF' from the registry - retrying once in ${SLEPT}s."
# ~1 MB after the match - far more than a pipe and grep's read buffer hold, so a
# `printf | grep -m1` would die of SIGPIPE every time and read the throttle as
# "not retryable".
assert_retry "429 at the top of a ~1 MB message -> retry" "$(failed_record \
  "$(printf '%s\n' 'unexpected status from HEAD request to https://registry-1.docker.io/v2/library/nginx/manifests/stable: 429 Too Many Requests'; \
     printf 'detail line %05d of a long BuildKit error message ......\n' $(seq 20000))")"

# Unknown cause: retried, because a throttle that is not retried half-publishes a release.
assert_retry "buildx without 'history' (older than 0.21) -> retry" "" 1
assert_retry "a record that is not JSON -> retry" "not json at all"
assert_retry "newest record is not a failed build (failure before BuildKit started) -> retry" \
  "$(jq -n '{Name: "app", Ref: "abc", Status: "completed", NumCompletedSteps: 9, NumTotalSteps: 9}')"
assert_retry "failed record without an error message -> retry" "$(jq -n '{Ref: "abc", Status: "failed"}')"

# Not retried: errors that waiting cannot fix.
assert_no_retry "failing RUN (compile error) -> no retry" "$(failed_record \
  'process "/bin/sh -c npm run build" did not complete successfully: exit code: 1')"
assert_no_retry "failing RUN whose command text contains 429 -> no retry" "$(failed_record \
  'process "/bin/sh -c test \"$(curl -so /dev/null -w %{http_code} https://example.invalid)\" != 429" did not complete successfully: exit code: 1')"
# BuildKit quotes the command with Go's %q, inner quotes as \" - the whole quoted text
# is cut out, not just the part up to the first inner quote.
assert_no_retry "failing RUN whose command text quotes '429 Too Many Requests' -> no retry" "$(failed_record \
  'process "/bin/sh -c curl -fsS https://api.example.com | grep -v \"429 Too Many Requests\"" did not complete successfully: exit code: 1')"
assert_no_retry "failing RUN whose command text contains '\": EOF' and a reset -> no retry" "$(failed_record \
  'process "/bin/sh -c printf \"%s\\n\" \"x\": EOF; echo connection reset by peer; exit 3" did not complete successfully: exit code: 3')"
assert_no_retry "Dockerfile parse error -> no retry" "$(failed_record \
  'dockerfile parse error on line 7: unknown instruction: RUNN')"
assert_no_retry "401 Unauthorized -> no retry" "$(failed_record \
  'failed to authorize: failed to fetch oauth token: unexpected status from GET request to https://auth.docker.io/token?scope=repository%3Alibrary%2Fnginx%3Apull&service=registry.docker.io: 401 Unauthorized')"
assert_no_retry "unknown tag -> no retry" "$(failed_record \
  'docker.io/library/nginx:stabel: not found')"
assert_no_retry "missing build secret -> no retry" "$(failed_record \
  'failed to compute cache key: secret npm_token: not found')"
assert_no_retry "missing COPY source whose name contains EOF -> no retry" "$(failed_record \
  'failed to compute cache key: failed to calculate checksum of ref 5c4e0b1a::kq3x9: "/docs/EOF-NOTES.md": not found')"
# The most common genuine push failures: a token without write access.
assert_no_retry "403 on a push to GHCR (no packages:write) -> no retry" "$(failed_record \
  'failed to push ghcr.io/bauer-group/app:1.2.3: unexpected status from HEAD request to https://ghcr.io/v2/bauer-group/app/blobs/sha256:4d1b: 403 Forbidden')"
assert_no_retry "push to Docker Hub denied (insufficient_scope) -> no retry" "$(failed_record \
  'failed to push docker.io/bauergroup/app:1.2.3: push access denied, repository does not exist or may require authorization: server message: insufficient_scope: authorization failed')"

# Without GNU coreutils' `timeout` (a macOS self-hosted runner) the record is still
# read: a genuine error fails at once instead of being retried as "unknown".
mkdir -p "$WORK/no-timeout"
for tool in bash cat grep jq sed; do
  ln -s "$(command -v "$tool")" "$WORK/no-timeout/$tool"
done
CHECK_PATH="$WORK/bin:$WORK/no-timeout" assert_no_retry "no 'timeout' on the runner, failing RUN -> no retry" "$(failed_record \
  'process "/bin/sh -c npm run build" did not complete successfully: exit code: 1')"
CHECK_PATH="$WORK/bin:$WORK/no-timeout" assert_retry "no 'timeout' on the runner, 429 -> retry" "$(failed_record \
  'unexpected status from HEAD request to https://registry-1.docker.io/v2/library/nginx/manifests/stable: 429 Too Many Requests')"

# The message is build output: it may not reach the log, where a line of it could
# be read as a workflow command.
run_check "$(failed_record $'unexpected status from HEAD request to https://registry-1.docker.io/v2/library/nginx/manifests/stable: 429 Too Many Requests\n::error::forged annotation\nregistry-1.docker.io')"
if [ "$RC" -eq 0 ] && ! printf '%s\n' "$LOG" | grep -qF -- "forged annotation" \
  && ! printf '%s\n' "$LOG" | grep -qF -- "registry-1.docker.io"; then
  pass "only the matched phrase reaches the log, never the error message"
else
  fail "only the matched phrase reaches the log, never the error message" "exit $RC, log: $(printf '%s' "$LOG" | tr '\n' ' ')"
fi

# Bounded and spread: every backoff within 60-90 s, and not all the same.
SEEN=""
OUT_OF_RANGE=""
for _ in $(seq 40); do
  run_check "$(failed_record 'unexpected status from HEAD request to https://registry-1.docker.io/v2/library/nginx/manifests/stable: 429 Too Many Requests')"
  if ! [[ "$SLEPT" =~ ^[0-9]+$ ]] || [ "$SLEPT" -lt 60 ] || [ "$SLEPT" -gt 90 ]; then
    OUT_OF_RANGE="$OUT_OF_RANGE '$SLEPT'"
  fi
  SEEN="$SEEN $SLEPT"
done
DISTINCT=$(printf '%s\n' $SEEN | sort -u | grep -c .)
if [ -z "$OUT_OF_RANGE" ] && [ "$DISTINCT" -gt 1 ]; then
  pass "backoff stays within 60-90 s and is jittered ($DISTINCT distinct values in 40 runs)"
else
  fail "backoff stays within 60-90 s and is jittered" "out of range:${OUT_OF_RANGE:- none}, distinct values: $DISTINCT"
fi

echo
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
