#!/usr/bin/env bash
#
# Behavioural test for the Gitleaks pull request path in ../action.yml.
#
# gitleaks-action scans a pull request by listing its commits through the REST API,
# which in a private repository needs `pull-requests: read`. modules-security-scan.yml
# can never pass that scope (its own `permissions:` block caps the token), so on every
# pull request of a private repository the action died with HTTP 403 before gitleaks
# ran and the repository was NOT scanned. The fix probes the API first and, where the
# token cannot list the commits, scans the same commits with the gitleaks CLI.
#
# Two steps carry that decision and are tested here:
#   gitleaks-mode  - picks the runner. Where the token CAN list the commits it must
#                    keep gitleaks-action, so callers that worked stay unchanged.
#   gitleaks-cli   - scans BASE..HEAD of the pull request. It must find a secret the
#                    pull request adds, must NOT report one that was already on the
#                    base branch (that is the push scan's job, as with the action),
#                    and must fail loudly - never pass - when the range is missing.
#
# The step bodies are extracted from action.yml at runtime rather than duplicated
# here: a copied-out script would keep passing after the real one regressed. The
# scan cases need the real gitleaks binary on PATH; the Workflow Validation job
# installs the pinned version before running this. Fake credentials are generated
# at runtime so this file never contains a credential-shaped string itself.
#
# Usage: bash .github/actions/security-scan/tests/pull-request-scan.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION_FILE="$SCRIPT_DIR/../action.yml"

if [ ! -f "$ACTION_FILE" ]; then
  echo "FATAL: action.yml not found at $ACTION_FILE"
  exit 1
fi

extract_step() {
  awk -v step="      id: $1" '
    $0 == step        { found = 1; next }
    found && /^      run: \|$/ { collecting = 1; next }
    collecting {
      if ($0 == "") { print ""; next }
      if ($0 ~ /^        /) { sub(/^        /, ""); print; next }
      exit
    }
  ' "$ACTION_FILE"
}

MODE_BODY=$(extract_step gitleaks-mode)
SCAN_BODY=$(extract_step gitleaks-cli)

for pair in "gitleaks-mode:$MODE_BODY" "gitleaks-cli:$SCAN_BODY"; do
  if [ -z "${pair#*:}" ]; then
    echo "FATAL: could not extract the '${pair%%:*}' run block from action.yml."
    echo "       The step was renamed, removed, or re-indented - update this test."
    exit 1
  fi
done

if ! command -v gitleaks >/dev/null 2>&1; then
  echo "FATAL: gitleaks is not on PATH."
  echo "       Install it (https://github.com/gitleaks/gitleaks/releases) or run this"
  echo "       through the Workflow Validation job, which installs the pinned version."
  exit 1
fi
GITLEAKS_PATH="$(command -v gitleaks)"

PASSED=0
FAILED=0

report() {
  local desc="$1"
  shift
  if [ "$#" -eq 0 ]; then
    PASSED=$((PASSED + 1))
    printf 'ok   %s\n' "$desc"
  else
    FAILED=$((FAILED + 1))
    printf 'FAIL %s\n' "$desc"
    printf '       %s\n' "$@"
  fi
}

# --- gitleaks-mode: which runner scans ---------------------------------------------

# A stand-in for curl that records its arguments and answers with a fixed status.
STUB_DIR=$(mktemp -d)
cat > "$STUB_DIR/curl" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$CURL_ARGS"
printf '%s' "${FAKE_HTTP_STATUS:-}"
exit "${FAKE_CURL_EXIT:-0}"
STUB
chmod +x "$STUB_DIR/curl"

# assert_mode <description> <event> <http-status> <curl-exit> <expectation>...
#   out=key=value   step output `key` equals `value`
#   log=substring   output contains substring
#   nolog=substring output does not contain substring
#   arg=substring   curl was called with an argument containing substring
#   nocall          curl was not called at all
assert_mode() {
  local desc="$1" event="$2" status="$3" curl_exit="$4"
  shift 4

  local dir out_file log_file args_file rc problems=()
  dir=$(mktemp -d)
  out_file="$dir/github_output"
  log_file="$dir/log"
  args_file="$dir/curl_args"
  : > "$out_file"

  ( cd "$dir" && \
    PATH="$STUB_DIR:$PATH" \
    CURL_ARGS="$args_file" \
    FAKE_HTTP_STATUS="$status" \
    FAKE_CURL_EXIT="$curl_exit" \
    EVENT_NAME="$event" \
    PR_NUMBER="7" \
    REPOSITORY="acme/widget" \
    API_URL="https://api.example.test" \
    GH_TOKEN="placeholder-token" \
    GITHUB_OUTPUT="$out_file" \
      bash -eo pipefail -c "$MODE_BODY" ) > "$log_file" 2>&1
  rc=$?

  # The probe decides; it never fails the run. A failed probe must still yield a mode.
  [ "$rc" -eq 0 ] || problems+=("step exited $rc, but it must always exit 0: $(tr '\n' ' ' < "$log_file")")

  local expectation key want got
  for expectation in "$@"; do
    key="${expectation%%=*}"
    want="${expectation#*=}"
    case "$key" in
      out)
        got=$(grep -m1 -- "^${want%%=*}=" "$out_file" | cut -d= -f2-)
        [ "$got" = "${want#*=}" ] || problems+=("output ${want%%=*}: expected '${want#*=}', got '$got'")
        ;;
      log)    grep -qF -- "$want" "$log_file" || problems+=("expected log containing '$want'") ;;
      nolog)  grep -qF -- "$want" "$log_file" && problems+=("log must NOT contain '$want'") ;;
      arg)    { [ -f "$args_file" ] && grep -qF -- "$want" "$args_file"; } || problems+=("expected a curl argument containing '$want'") ;;
      nocall) [ -f "$args_file" ] && problems+=("curl must not be called for this event") ;;
      *)      problems+=("unknown expectation '$expectation'") ;;
    esac
  done

  rm -rf "$dir"
  report "$desc" "${problems[@]+"${problems[@]}"}"
}

echo "Testing 'gitleaks-mode' and 'gitleaks-cli' from $(basename "$ACTION_FILE")"
echo

# Not a pull request: gitleaks-action needs no API listing, nothing changes.
assert_mode "a push keeps gitleaks-action and makes no API call" push "" 0 \
  "out=mode=action" "nocall"
assert_mode "a scheduled run keeps gitleaks-action" schedule "" 0 \
  "out=mode=action" "nocall"

# The token can list the commits: callers that worked before must stay on the action.
assert_mode "a pull request whose token can list commits keeps gitleaks-action" pull_request 200 0 \
  "out=mode=action" "nolog=::notice" \
  "arg=https://api.example.test/repos/acme/widget/pulls/7/commits?per_page=1"

# The bug: modules-security-scan.yml's token has no pull-requests scope.
assert_mode "a 403 (no pull-requests: read) switches to the gitleaks CLI" pull_request 403 0 \
  "out=mode=cli" "log=::notice" "log=HTTP 403" "log=pull-requests: read"

# Any other non-answer: the action would fail on it too, so the CLI scans instead.
assert_mode "a network error switches to the CLI and does not abort" pull_request 000 6 \
  "out=mode=cli" "log=HTTP 000"
assert_mode "a 404 switches to the CLI" pull_request 404 0 \
  "out=mode=cli"

# The token travels in a header, never in the URL that curl may echo on errors.
assert_mode "the token is sent as a header, not in the URL" pull_request 200 0 \
  "arg=Authorization: Bearer placeholder-token"

rm -rf "$STUB_DIR"

# --- gitleaks-cli: what the pull request scan covers --------------------------------

rand() { head -c 2000 /dev/urandom | tr -dc "$1" | head -c "$2"; }
FAKE_PAT_ON_BASE="ghp_$(rand 'a-zA-Z0-9' 36)"
FAKE_PAT_IN_PR="ghp_$(rand 'a-zA-Z0-9' 36)"

# History: a secret already on the base branch, the base, then a pull request branch
# with one clean commit and one commit that adds a secret.
REPO=$(mktemp -d)
(
  cd "$REPO" || exit 1
  git init -q
  git config user.name "Test"
  git config user.email "test@example.invalid"
  git config commit.gpgsign false
  git config core.autocrlf false
  printf 'token = "%s"\n' "$FAKE_PAT_ON_BASE" > already-on-base.txt
  git add . && git commit -q -m "base history with a secret"
  printf 'readme\n' > README.md
  git add . && git commit -q -m "base"
  git checkout -q -b feature
  printf 'feature\n' > feature.txt
  git add . && git commit -q -m "clean change"
  printf 'token = "%s"\n' "$FAKE_PAT_IN_PR" > added-in-pr.txt
  git add . && git commit -q -m "change with a secret"
) || { echo "FATAL: could not build the test repository"; exit 1; }

BASE=$(git -C "$REPO" rev-parse HEAD~2)
HEAD_CLEAN=$(git -C "$REPO" rev-parse HEAD~1)
HEAD_LEAKY=$(git -C "$REPO" rev-parse HEAD)

# assert_scan <description> <base-sha> <head-sha> <expected-exit> <expectation>...
#   findings=N        the SARIF report holds exactly N findings
#   noreport          no SARIF report was written
#   report=substring  the SARIF report contains substring
#   noreport=substring the SARIF report does not contain substring
#   log=substring     output contains substring
assert_scan() {
  local desc="$1" base="$2" head="$3" want_rc="$4"
  shift 4

  local log_file rc problems=() sarif="$REPO/results.sarif"
  log_file=$(mktemp)
  rm -f "$sarif"

  ( cd "$REPO" && \
    GITLEAKS_BIN="$GITLEAKS_PATH" \
    BASE_SHA="$base" \
    HEAD_SHA="$head" \
      bash -eo pipefail -c "$SCAN_BODY" ) > "$log_file" 2>&1
  rc=$?

  [ "$rc" -eq "$want_rc" ] || problems+=("exit code: expected $want_rc, got $rc: $(tail -n 5 "$log_file" | tr '\n' ' ')")

  local expectation key want count
  for expectation in "$@"; do
    key="${expectation%%=*}"
    want="${expectation#*=}"
    case "$key" in
      findings)
        if [ -f "$sarif" ]; then
          count=$( { grep -o '"ruleId"' "$sarif" || true; } | wc -l | tr -d '[:space:]')
          [ "$count" = "$want" ] || problems+=("findings: expected $want, got $count")
        else
          problems+=("findings: expected $want, but no SARIF report was written")
        fi
        ;;
      noreport)
        if [ "$expectation" = "noreport" ]; then
          [ -f "$sarif" ] && problems+=("no report must be written when the scan cannot run")
        else
          [ -f "$sarif" ] && grep -qF -- "$want" "$sarif" && problems+=("report must NOT contain '$want'")
        fi
        ;;
      report) { [ -f "$sarif" ] && grep -qF -- "$want" "$sarif"; } || problems+=("expected the report to contain '$want'") ;;
      log)    grep -qF -- "$want" "$log_file" || problems+=("expected log containing '$want'") ;;
      *)      problems+=("unknown expectation '$expectation'") ;;
    esac
  done

  rm -f "$log_file"
  report "$desc" "${problems[@]+"${problems[@]}"}"
}

# A clean pull request: exit 0, an empty report. The secret already on the base
# branch is in history but outside the range, exactly as gitleaks-action scans it.
assert_scan "a clean pull request is clean, base history is out of range" "$BASE" "$HEAD_CLEAN" 0 \
  "findings=0" "noreport=already-on-base.txt"

# A secret the pull request adds: exit 2 (a result, not an error) and a finding.
assert_scan "a secret added by the pull request is found" "$BASE" "$HEAD_LEAKY" 2 \
  "findings=1" "report=added-in-pr.txt" "noreport=already-on-base.txt"

# The report is redacted, like the action's.
assert_scan "the report never contains the secret itself" "$BASE" "$HEAD_LEAKY" 2 \
  "noreport=$FAKE_PAT_IN_PR"

# A range that is not in the checkout (shallow clone): fail without a report, so the
# result processing reports 'unknown' - never a clean scan of nothing.
assert_scan "a base commit missing from the checkout fails without a report" \
  "0000000000000000000000000000000000000000" "$HEAD_LEAKY" 1 \
  "noreport" "log=::error title=Gitleaks range unavailable"
assert_scan "an empty range end fails without a report" "$BASE" "" 1 \
  "noreport" "log=::error title=Gitleaks range unavailable"

rm -rf "$REPO"

echo
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
