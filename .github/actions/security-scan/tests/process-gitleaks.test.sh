#!/usr/bin/env bash
#
# Behavioural test for the 'Process Gitleaks Results' step in ../action.yml.
#
# Guards the worst failure mode a security scanner can have: reporting "no secrets
# found" when it did not actually finish. That is what this pipeline did. The
# third-party gitleaks action exits 2 on findings, which failed the step, which
# aborted the composite before this processing step, the summary step and the
# deliberate `fail-on-findings` gate could run. Everything downstream then rendered
# an empty output as `false`, so a run with a real finding printed
# "Secrets Found | false" in its summary.
#
# The distinction that matters here is three-valued, not two: findings, no findings,
# and "the scan did not complete". The third must never collapse into the second -
# absence of evidence is not evidence of absence.
#
# The step body is extracted from action.yml at runtime rather than duplicated here:
# a copied-out script would keep passing after the real one regressed.
#
# Usage: bash .github/actions/security-scan/tests/process-gitleaks.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION_FILE="$SCRIPT_DIR/../action.yml"
STEP_ID="process-gitleaks"

if [ ! -f "$ACTION_FILE" ]; then
  echo "FATAL: action.yml not found at $ACTION_FILE"
  exit 1
fi

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

PASSED=0
FAILED=0

# A SARIF report shaped like the one gitleaks writes: a large `rules` array whose
# entries use "id", and a `results` array whose entries use "ruleId". Only the latter
# are findings, which is what makes counting "ruleId" reliable.
write_sarif() {
  local path="$1" findings="$2" i
  {
    printf '{\n "version": "2.1.0",\n "runs": [\n  {\n   "tool": {\n    "driver": {\n     "name": "gitleaks",\n     "rules": [\n'
    printf '      { "id": "aws-access-token" },\n      { "id": "github-pat" }\n'
    printf '     ]\n    }\n   },\n   "results": [\n'
    for ((i = 0; i < findings; i++)); do
      [ "$i" -eq 0 ] || printf ',\n'
      printf '    { "ruleId": "aws-access-token", "message": { "text": "redacted" } }'
    done
    printf '\n   ]\n  }\n ]\n}\n'
  } > "$path"
}

# assert_process <description> <sarif-findings|none> <gitleaks-outcome> <expectation>...
#   out=key=value   step output `key` equals `value`
#   log=substring   stdout/stderr contains substring
#   nolog=substring stdout/stderr does not contain substring
assert_process() {
  local desc="$1" sarif_findings="$2" outcome="$3"
  shift 3

  local dir out_file log_file rc problems=()
  dir=$(mktemp -d)
  out_file="$dir/github_output"
  log_file="$dir/log"
  : > "$out_file"

  if [ "$sarif_findings" != "none" ]; then
    write_sarif "$dir/results.sarif" "$sarif_findings"
  fi

  ( cd "$dir" && \
    GITLEAKS_OUTCOME="$outcome" \
    GITLEAKS_SARIF="results.sarif" \
    GITHUB_OUTPUT="$out_file" \
      bash -eo pipefail -c "$STEP_BODY" ) > "$log_file" 2>&1
  rc=$?

  # The step reports; it never decides. Failing the run is the dedicated gate's job,
  # so this step must exit 0 even when it has found something.
  if [ "$rc" -ne 0 ]; then
    problems+=("step exited $rc, but it must always exit 0 and leave the decision to the gate: $(tr '\n' ' ' < "$log_file")")
  fi

  local expectation key want got
  for expectation in "$@"; do
    key="${expectation%%=*}"
    want="${expectation#*=}"
    case "$key" in
      out)
        got=$(grep -m1 -- "^${want%%=*}=" "$out_file" | cut -d= -f2-)
        [ "$got" = "${want#*=}" ] || problems+=("output ${want%%=*}: expected '${want#*=}', got '$got'")
        ;;
      log)   grep -qF -- "$want" "$log_file" || problems+=("expected log containing '$want'") ;;
      nolog) grep -qF -- "$want" "$log_file" && problems+=("log must NOT contain '$want'") ;;
      *)     problems+=("unknown expectation '$expectation'") ;;
    esac
  done

  rm -rf "$dir"

  if [ ${#problems[@]} -eq 0 ]; then
    PASSED=$((PASSED + 1))
    printf 'ok   %s\n' "$desc"
  else
    FAILED=$((FAILED + 1))
    printf 'FAIL %s\n' "$desc"
    printf '       %s\n' "${problems[@]}"
  fi
}

echo "Testing '$STEP_ID' from $(basename "$ACTION_FILE")"
echo

# --- A scan that completed -------------------------------------------------------
assert_process "a clean report is reported as clean" 0 success \
  "out=secrets-found=false" "out=secrets-count=0"

# gitleaks exits non-zero when it finds something, so `failure` is the NORMAL outcome
# for a run with findings - not an error.
assert_process "findings are counted, not inferred from the exit status" 2 failure \
  "out=secrets-found=true" "out=secrets-count=2"

assert_process "a single finding is reported" 1 failure \
  "out=secrets-found=true" "out=secrets-count=1"

# The regression that started all of this: one finding must never render as false.
assert_process "one finding is never reported as false" 1 failure \
  "nolog=secrets-found=false"

# --- A scan that did NOT complete ------------------------------------------------
# No report on disk plus a failed step means gitleaks itself broke - a bad config, a
# network failure, a missing licence. Reporting that as "clean" is the dangerous
# outcome, so it gets its own value and a loud error.
assert_process "a scan that produced no report is unknown, never clean" none failure \
  "out=secrets-found=unknown" "log=::error" "nolog=secrets-found=false"

assert_process "the unknown case says the scan did not complete" none failure \
  "log=did not complete"

# A successful step with no report is genuinely clean: gitleaks writes no SARIF when
# it is configured not to, and success means it ran to completion.
assert_process "a successful scan with no report is clean" none success \
  "out=secrets-found=false" "out=secrets-count=0"

# Defensive: an outcome we do not model must not be silently optimistic.
assert_process "an unmodelled outcome is unknown, not clean" none cancelled \
  "out=secrets-found=unknown"

echo
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
