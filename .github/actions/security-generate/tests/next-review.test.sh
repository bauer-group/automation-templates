#!/usr/bin/env bash
#
# Regression test for the 'Calculate Dates' step in ../action.yml.
#
# The step told GNU from BSD date with `date --version | grep -q GNU` and used
# `date -d "+N months"` or `date -v+Nm`. Ubuntu 26.04 runners ship uutils date,
# which is neither: it took the BSD branch, rejected -v and failed the security
# policy job of every release - XPD-AIModelSync, 2026-10-30, the first runs after
# ubuntu-latest moved to 26.04. The step now does month arithmetic itself, so it
# may only use what every date implementation shares: -u and one +FORMAT.
#
# review_cycle comes from the caller's config file. It used to be spliced into the
# script with ${{ }}, where `$(...)` in the value ran as a command. It is now read
# from env and must be a whole number before bash arithmetic sees it.
#
# Usage: bash .github/actions/security-generate/tests/next-review.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION_FILE="$SCRIPT_DIR/../action.yml"

if [ ! -f "$ACTION_FILE" ]; then
  echo "FATAL: action.yml not found at $ACTION_FILE"
  exit 1
fi

PASSED=0
FAILED=0

pass() { PASSED=$((PASSED + 1)); printf 'ok   %s\n' "$1"; }
fail() { FAILED=$((FAILED + 1)); printf 'FAIL %s\n' "$1"; shift; printf '       %s\n' "$@"; }

# The step's own lines, from its `id:` up to the next step.
step_block() {
  awk -v step="      id: $1" '
    $0 == step            { found = 1; print; next }
    found && /^    - /    { exit }
    found                 { print }
  ' "$ACTION_FILE"
}

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

# A date that only knows -u and one +FORMAT (%Y %m %d %H %M %S) and answers with
# FAKE_NOW - the part GNU, BSD, BusyBox and uutils date have in common.
mkdir -p "$WORK/shim"
cat > "$WORK/shim/date" <<'SHIM'
#!/usr/bin/env bash
fmt=""
for arg in "$@"; do
  case "$arg" in
    -u) ;;
    +*) fmt="${arg#+}" ;;
    *) echo "date shim: unsupported argument '$arg'" >&2; exit 1 ;;
  esac
done
[ -n "$fmt" ] || { echo "date shim: no +FORMAT given" >&2; exit 1; }
out=$fmt
out=${out//\%Y/${FAKE_NOW:0:4}}
out=${out//\%m/${FAKE_NOW:5:2}}
out=${out//\%d/${FAKE_NOW:8:2}}
out=${out//\%H/${FAKE_NOW:11:2}}
out=${out//\%M/${FAKE_NOW:14:2}}
out=${out//\%S/${FAKE_NOW:17:2}}
case "$out" in *%*) echo "date shim: unsupported format '$fmt'" >&2; exit 1 ;; esac
printf '%s\n' "$out"
SHIM
chmod +x "$WORK/shim/date"

echo "Testing the next review date in $(basename "$ACTION_FILE")"
echo

BLOCK=$(step_block dates)
if [ -z "$BLOCK" ]; then
  fail "dates: step found" "no step with id 'dates' - renamed or removed? update this test"
  echo
  echo "$PASSED passed, $FAILED failed"
  exit 1
fi

# shellcheck disable=SC2016 # the literal workflow expression, not a shell expansion
if printf '%s\n' "$BLOCK" | grep -qxF -- '        REVIEW_CYCLE: ${{ steps.config.outputs.review_cycle }}'; then
  pass "dates: reads review_cycle through env"
else
  fail "dates: reads review_cycle through env" "expected the line: REVIEW_CYCLE: \${{ steps.config.outputs.review_cycle }}"
fi

BODY=$(printf '%s\n' "$BLOCK" | awk 'body { sub(/^        /, ""); print } /^      run: \|$/ { body = 1 }')
if [ -z "$BODY" ]; then
  fail "dates: run body found" "no 'run: |' block in the step"
fi

# shellcheck disable=SC2016 # literal workflow expression syntax
if printf '%s\n' "$BODY" | grep -qF '${{'; then
  fail "dates: no workflow expression in the run body" "found: $(printf '%s\n' "$BODY" | grep -F '${{' | head -1)"
else
  pass "dates: no workflow expression in the run body"
fi

# run_step <now> <review_cycle> [real] - prints next_review; exit status of the step
# The value goes in through env, and also where the runner would splice it in had a
# ${{ }} expression crept back into the body - so a regression fails behaviourally.
# shellcheck disable=SC2016 # the literal workflow expression, not a shell expansion
EXPR='${{ steps.config.outputs.review_cycle }}'
run_step() {
  local out="$WORK/github_output" path="$WORK/shim:$PATH" body
  : > "$out"
  [ "${3:-}" = real ] && path=$PATH
  body=${BODY//"$EXPR"/"$2"}
  ( cd "$WORK" && PATH="$path" FAKE_NOW="$1" REVIEW_CYCLE="$2" GITHUB_OUTPUT="$out" \
      bash --noprofile --norc -eo pipefail -c "$body" ) >"$WORK/log" 2>&1
  local rc=$?
  sed -n 's/^next_review=//p' "$out"
  return "$rc"
}

# assert_next_review <now> <review_cycle> <expected>
assert_next_review() {
  local got rc
  got=$(run_step "$1" "$2")
  rc=$?
  if [ "$rc" -eq 0 ] && [ "$got" = "$3" ]; then
    pass "$1 + $2 months -> $3"
  else
    fail "$1 + $2 months -> $3" "exit $rc, got '$got'" "$(tail -n 3 "$WORK/log")"
  fi
}

assert_next_review "2026-10-30 21:14:05" 12  "October 2027"
assert_next_review "2026-08-15 08:00:00" 12  "August 2027"     # "08" is not octal
assert_next_review "2026-09-01 00:00:00" 6   "March 2027"      # "09" is not octal
assert_next_review "2026-12-10 12:00:00" 1   "January 2027"
assert_next_review "2026-12-10 12:00:00" 24  "December 2028"
assert_next_review "2026-01-31 12:00:00" 1   "February 2026"   # a month on, not a day overflow
assert_next_review "2028-02-29 12:00:00" 12  "February 2029"
assert_next_review "2026-01-05 12:00:00" 0   "January 2026"
assert_next_review "2026-10-30 12:00:00" 012 "October 2027"    # leading zero is decimal

# assert_rejected <review_cycle> <description>
assert_rejected() {
  local got rc
  rm -f "$WORK/pwned"
  # shellcheck disable=SC2034 # output is not the point here, only the exit status
  got=$(run_step "2026-10-30 12:00:00" "$1")
  rc=$?
  if [ -e "$WORK/pwned" ]; then
    fail "rejects $2" "the value was executed"
  elif [ "$rc" -ne 0 ] && grep -q 'Invalid review cycle' "$WORK/log"; then
    pass "rejects $2"
  else
    fail "rejects $2" "exit $rc, expected the 'Invalid review cycle' error" "$(tail -n 3 "$WORK/log")"
  fi
}

# shellcheck disable=SC2016 # the payloads must reach the step unexpanded
assert_rejected 'a[$(touch pwned)]' "an arithmetic command substitution"
# shellcheck disable=SC2016
assert_rejected '12$(touch pwned)' "a command substitution"
assert_rejected '12; touch pwned' "a command list"
assert_rejected '' "an empty value"
assert_rejected '-3' "a negative number"
assert_rejected '1.5' "a fraction"

# And once with this machine's own date: on ubuntu-latest that is uutils.
if got=$(run_step "" 12 real); then
  year=$(date -u '+%Y') month=$(date -u '+%m')
  months=(January February March April May June July August September October November December)
  target=$((year * 12 + 10#$month - 1 + 12))
  expected="${months[target % 12]} $((target / 12))"
  if [ "$got" = "$expected" ]; then
    pass "real date ($(date --version 2>/dev/null | head -1 || echo 'no --version')): $got"
  else
    fail "real date: next review in 12 months" "got '$got', expected '$expected'"
  fi
else
  fail "real date: step runs" "$(tail -n 3 "$WORK/log")"
fi

echo
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
