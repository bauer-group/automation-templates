#!/usr/bin/env bash
#
# Behavioural test for the Security Audit step of ../nodejs-build.yml.
#
# The audit checks the whole lockfile, so a Dependabot pull request that bumps
# one package failed on every OTHER open advisory and stayed red - the PRs that
# fix an advisory included, so none of them could merge. On a pull request
# opened by Dependabot the step now reports findings BELOW critical (warning
# annotation, audit output in the step summary) and the job goes on to build and
# test. Critical findings - npm reports malware as critical - still fail it
# there, and so does a failed audit whose critical count cannot be determined.
# Everywhere else - push, merge_group, release/tag, workflow_dispatch, every
# other pull request - it blocks at the caller's level.
#
# Static: the input default, the AUDIT_REPORT_ONLY expression (the PR author,
# not github.actor) and the job summary row are pinned as exact lines; GitHub
# evaluates them, this test cannot.
# Behavioural: the step body is extracted from the workflow at runtime, its
# ${{ }} expressions are replaced by test values, and it runs the way a step
# without `shell:` runs (bash -e) against stubs of npm, pnpm, yarn and bun that
# exit the way the real ones do:
#   npm, pnpm, bun  non-zero only for findings at or above the level they are
#                   given (npm: exit-code.js, pnpm: plugin-commands-audit,
#                   bun: docs "Exit codes")
#   yarn classic    a bit mask of EVERY severity found (1 info ... 16 critical),
#                   whatever --level says - that only filters the printed
#                   advisories (yarn 1.22 cli.js, audit run())
#   Yarn Berry      has no `yarn audit`: a usage error, exit 1, no counts
#   all of them     exit 1 when the registry request fails
#
# Usage: bash .github/workflows/tests/nodejs-build-audit.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW="$SCRIPT_DIR/../nodejs-build.yml"

if [ ! -f "$WORKFLOW" ]; then
  echo "FATAL: nodejs-build.yml not found at $WORKFLOW"
  exit 1
fi

FAILED=0
check() {
  if [ "$2" = "$3" ]; then echo "  ok   $1"; else echo "  FAIL $1 (expected '$3', got '$2')"; FAILED=$((FAILED + 1)); fi
}
has_line() {
  if grep -qxF -- "$2" "$WORKFLOW"; then echo "  ok   $1"; else echo "  FAIL $1: line not found: $2"; FAILED=$((FAILED + 1)); fi
}

# --- static ---------------------------------------------------------------------
echo "static"
INPUT=$(awk '/^      audit-dependabot-report-only:$/{f=1; next} f && /^      [a-z]/{exit} f' "$WORKFLOW")
check "input is a boolean" "$(printf '%s\n' "$INPUT" | grep -cxF '        type: boolean')" 1
check "input defaults to true (existing callers need no change)" \
  "$(printf '%s\n' "$INPUT" | grep -cxF '        default: true')" 1
check "input description says critical findings still fail" \
  "$(printf '%s\n' "$INPUT" | grep -c 'below critical.*Critical findings.*still fail')" 1
# shellcheck disable=SC2016 # literal workflow text
has_line "report-only = input AND pull request opened by Dependabot" \
  "          AUDIT_REPORT_ONLY: \${{ inputs.audit-dependabot-report-only && github.event.pull_request.user.login == 'dependabot[bot]' }}"
STEP=$(awk '/^        id: audit$/{f=1} f && /^      - name:/{exit} f' "$WORKFLOW" | grep -vE '^[[:space:]]*#')
check "the audit step does not decide by github.actor" \
  "$(printf '%s\n' "$STEP" | grep -cE 'github\.(actor|triggering_actor)')" 0
# shellcheck disable=SC2016 # literal workflow text
has_line "job summary reads the report-only output" \
  '          AUDIT_REPORT_ONLY_FINDINGS: ${{ steps.audit.outputs.report-only-findings }}'
# shellcheck disable=SC2016 # literal workflow text
ROW_REPORT_ONLY=$(grep -nxF '            elif [ "$AUDIT_REPORT_ONLY_FINDINGS" = "true" ]; then' "$WORKFLOW" | cut -d: -f1)
# shellcheck disable=SC2016 # literal workflow text
ROW_STATUS=$(grep -nF '$(status ${{ steps.audit.outcome }})' "$WORKFLOW" | cut -d: -f1)
check "summary renders report-only findings before the step outcome (never as Passed)" \
  "$([ -n "$ROW_REPORT_ONLY" ] && [ -n "$ROW_STATUS" ] && [ "$ROW_REPORT_ONLY" -lt "$ROW_STATUS" ] && echo yes)" yes

# --- extract the step body ---------------------------------------------------------
BODY=$(awk '
  /^        id: audit$/ { found = 1; next }
  found && /^        run: \|$/ { collecting = 1; next }
  collecting {
    if ($0 == "") { print ""; next }
    if ($0 ~ /^          /) { sub(/^          /, ""); print; next }
    exit
  }
' "$WORKFLOW")
if [ -z "$BODY" ]; then
  echo "FATAL: could not extract the run block of the audit step - it was renamed or re-indented; update this test."
  exit 1
fi
subst() { BODY=${BODY//"$1"/"$2"}; }
# shellcheck disable=SC2016 # literal workflow expressions and their stand-ins
{
  subst '${{ steps.detect-pm.outputs.package-manager }}' '$TEST_PM'
  subst '${{ runner.temp }}' '$TEST_TEMP'
  subst "\${{ inputs.audit-production-only == true && '--prod' || '' }}" ''
  subst '${{ inputs.audit-production-only }}' 'false'
}
# shellcheck disable=SC2016 # literal workflow text
if [[ "$BODY" == *'${{'* ]]; then
  echo "FATAL: the audit step uses an expression this test does not stand in for:"
  grep -F '${{' <<< "$BODY"
  exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
printf '%s\n' "$BODY" > "$WORK/step.sh"

# --- stubs: exit the way the real package manager does -------------------------------
# STUB_MODE findings: print STUB_OUTPUT, exit by STUB_SEVERITIES (the severities
#                     the audit found) and the level the stub was called with
#           error:    print STUB_OUTPUT, exit 1 (registry error)
#           berry:    Yarn Berry's answer to `yarn audit`
# STUB_CRITICAL_MODE / STUB_CRITICAL_OUTPUT, if set, answer a run at level
# critical instead (e.g. the registry drops between the two runs).
mkdir -p "$WORK/bin"
for pm in npm pnpm yarn bun; do
  cat > "$WORK/bin/$pm" <<'STUB'
#!/usr/bin/env bash
# `bun --help` lists the commands; the step looks for `audit` there.
if [ "${1:-}" = "--help" ]; then printf '  install   Install dependencies\n  audit     Check for vulnerabilities\n'; exit 0; fi
pm=$(basename "$0")
printf '%s\n' "$pm $*" >> "$STUB_CALLS"
level=low prev=""
for arg in "$@"; do
  case "$arg" in --audit-level=*) level=${arg#*=} ;; esac
  case "$prev" in --audit-level|--level) level=$arg ;; esac
  prev=$arg
done
mode=$STUB_MODE output=$STUB_OUTPUT
if [ "$level" = critical ] && [ -n "${STUB_CRITICAL_MODE:-}" ]; then
  mode=$STUB_CRITICAL_MODE output=$STUB_CRITICAL_OUTPUT
fi
case "$mode" in
  error) cat "$output"; exit 1 ;;
  berry) echo "Usage Error: Couldn't find a script named \"audit\"."; exit 1 ;;
esac
cat "$output"
rank() { case $1 in info) echo 0 ;; low) echo 1 ;; moderate) echo 2 ;; high) echo 3 ;; critical) echo 4 ;; esac; }
rc=0
for severity in $STUB_SEVERITIES; do
  if [ "$pm" = yarn ]; then
    rc=$((rc | (1 << $(rank "$severity"))))
  elif [ "$(rank "$severity")" -ge "$(rank "$level")" ]; then
    rc=1
  fi
done
exit "$rc"
STUB
  chmod +x "$WORK/bin/$pm"
done

cat > "$WORK/npm-findings.txt" <<'EOF'
# npm audit report

next  16.0.0 - 16.3.1
Severity: high
Next.js middleware bypass - https://github.com/advisories/GHSA-aaaa-bbbb-cccc
fix available via `npm audit fix`
node_modules/next

2 vulnerabilities (1 moderate, 1 high)
EOF
cat > "$WORK/npm-critical.txt" <<'EOF'
# npm audit report

evil-pkg  *
Severity: critical
Malware in evil-pkg - https://github.com/advisories/GHSA-mmmm-wwww-xxxx
No fix available
node_modules/evil-pkg

3 vulnerabilities (1 moderate, 1 high, 1 critical)
EOF
printf 'found 0 vulnerabilities\n' > "$WORK/npm-clean.txt"
printf 'npm error audit endpoint returned an error\n' > "$WORK/npm-error.txt"
printf '2 vulnerabilities found\nSeverity: 1 moderate | 1 high\n' > "$WORK/pnpm-findings.txt"
printf '3 vulnerabilities found\nSeverity: 1 moderate | 1 high | 1 critical\n' > "$WORK/pnpm-critical.txt"
printf ' ERR_PNPM_AUDIT_BAD_RESPONSE  The audit endpoint responded with 503: Service Unavailable\n' > "$WORK/pnpm-error.txt"
printf '2 vulnerabilities found - Packages audited: 512\nSeverity: 1 Moderate | 1 High\n' > "$WORK/yarn-findings.txt"
printf '3 vulnerabilities found - Packages audited: 512\nSeverity: 1 Moderate | 1 High | 1 Critical\n' > "$WORK/yarn-critical.txt"
printf 'error An unexpected error occurred: "https://registry.yarnpkg.com/-/npm/v1/security/audits: getaddrinfo ENOTFOUND registry.yarnpkg.com".\n' > "$WORK/yarn-error.txt"
printf 'undici <8.12.0\n  high: GHSA-dddd-eeee-ffff\n\n2 vulnerabilities (1 high, 1 moderate)\n' > "$WORK/bun-findings.txt"
printf 'evil-pkg *\n  critical: Malware in evil-pkg GHSA-mmmm-wwww-xxxx\n\n3 vulnerabilities (1 critical, 1 high, 1 moderate)\n' > "$WORK/bun-critical.txt"
printf 'error: audit request to the registry failed: ConnectionRefused\n' > "$WORK/bun-error.txt"
printf 'npm error audit endpoint returned an error (critical run)\n' > "$WORK/registry-error.txt"
{ for i in $(seq 1 400); do echo "advisory line $i"; done; echo "1 high severity vulnerability"; } > "$WORK/npm-long.txt"

# run_case <name> <pm> <AUDIT_REPORT_ONLY> <stub mode> <fixture> [severities found]
# CASE_CRITICAL_MODE / CASE_CRITICAL_OUTPUT before it: how a run at level
# critical is answered. The caller's audit-level is high.
# Leaves rc, log (stdout+stderr), output (GITHUB_OUTPUT), summary, calls in $WORK/<name>/.
run_case() {
  local dir="$WORK/$1"
  mkdir -p "$dir/tmp"
  : > "$dir/output"
  : > "$dir/summary"
  : > "$dir/calls"
  (
    cd "$dir" || exit 99
    PATH="$WORK/bin:$PATH" TEST_PM="$2" TEST_TEMP="$dir/tmp" AUDIT_LEVEL=high \
      AUDIT_REPORT_ONLY="$3" STUB_MODE="$4" STUB_OUTPUT="$WORK/$5" STUB_SEVERITIES="${6:-}" \
      STUB_CRITICAL_MODE="${CASE_CRITICAL_MODE:-}" STUB_CRITICAL_OUTPUT="$WORK/${CASE_CRITICAL_OUTPUT:-registry-error.txt}" \
      STUB_CALLS="$dir/calls" GITHUB_OUTPUT="$dir/output" GITHUB_STEP_SUMMARY="$dir/summary" \
      bash -e "$WORK/step.sh"
  ) > "$dir/log" 2>&1
  echo $? > "$dir/rc"
}
rc()        { cat "$WORK/$1/rc"; }
out()       { sed -n "s/^$2=//p" "$WORK/$1/output"; }
warns()     { grep -c '^::warning title=Security audit (report-only)::' "$WORK/$1/log"; }
errors()    { grep -c '^::error title=Security audit (blocking)::' "$WORK/$1/log"; }
summary()   { grep -cF -- "$2" "$WORK/$1/summary"; }
sumbytes()  { wc -c < "$WORK/$1/summary" | tr -d ' '; }
audits()    { wc -l < "$WORK/$1/calls" | tr -d ' '; }
critruns()  { grep -cE -- '(--audit-level=|--audit-level |--level )critical' "$WORK/$1/calls"; }

SEV_HIGH="moderate high"
SEV_CRIT="moderate high critical"

# --- Dependabot pull request: report-only below critical ------------------------------
echo "Dependabot pull request (AUDIT_REPORT_ONLY=true), npm in detail"
run_case dep-npm npm true findings npm-findings.txt "$SEV_HIGH"
check "npm findings up to high do not fail the step" "$(rc dep-npm)" 0
check "the audit ran at the caller's level"          "$(grep -c -- '--audit-level=high' "$WORK/dep-npm/calls")" 1
check "...and once more at level critical"           "$(critruns dep-npm)" 1
check "report-only-findings=true"                    "$(out dep-npm report-only-findings)" true
check "audit-summary keeps the counts"               "$(out dep-npm audit-summary)" "2 vulnerabilities (1 moderate, 1 high)"
check "one warning annotation, no error"             "$(warns dep-npm)$(errors dep-npm)" 10
check "the warning names the counts"                 "$(grep -c '^::warning.*2 vulnerabilities (1 moderate, 1 high) at audit level high, none critical' "$WORK/dep-npm/log")" 1
check "the warning says critical findings would block" "$(grep -c '^::warning.*critical findings would' "$WORK/dep-npm/log")" 1
check "the findings are in the step summary"         "$(summary dep-npm 'GHSA-aaaa-bbbb-cccc')" 1
check "the step summary says report-only"            "$(summary dep-npm 'report-only (Dependabot pull request)')" 1
check "the step summary says critical blocks"        "$(summary dep-npm 'Critical findings block this pull request too')" 1
check "the audit output is still in the log"         "$(grep -c 'GHSA-aaaa-bbbb-cccc' "$WORK/dep-npm/log")" 1

run_case dep-clean npm true findings npm-clean.txt ""
check "a clean audit passes"                         "$(rc dep-clean)" 0
check "clean: no second audit"                       "$(audits dep-clean)" 1
check "clean: report-only-findings=false"            "$(out dep-clean report-only-findings)" false
check "clean: no warning, no error"                  "$(warns dep-clean)$(errors dep-clean)" 00
check "clean: nothing added to the step summary"     "$(sumbytes dep-clean)" 0
check "clean: npm's own count"                       "$(out dep-clean audit-summary)" "0 vulnerabilities"

run_case dep-long npm true findings npm-long.txt "high"
check "long output: not blocking"                    "$(rc dep-long)" 0
check "long output: truncated in the step summary"   "$(summary dep-long 'truncated after 300 lines')" 1
check "long output: 300 lines kept"                  "$(grep -c '^advisory line ' "$WORK/dep-long/summary")" 300
check "long output: full output in the log"          "$(grep -c '^advisory line ' "$WORK/dep-long/log")" 400

# --- each package manager: critical / only high / undeterminable -----------------------
for pm in npm pnpm yarn bun; do
  echo "Dependabot pull request, $pm"
  # yarn classic: the exit code is the severity bit mask (4 moderate + 8 high
  # + 16 critical), read from the first run - no second audit.
  crit_rc=1 high_runs=1
  if [ "$pm" = yarn ]; then crit_rc=28 high_runs=0; fi

  run_case "crit-$pm" "$pm" true findings "$pm-critical.txt" "$SEV_CRIT"
  check "$pm: a critical finding fails the step with the audit's code" "$(rc "crit-$pm")" "$crit_rc"
  check "$pm: critical: report-only-findings=false"        "$(out "crit-$pm" report-only-findings)" false
  check "$pm: critical: an error annotation, no warning"   "$(errors "crit-$pm")$(warns "crit-$pm")" 10
  check "$pm: critical: nothing added to the step summary" "$(sumbytes "crit-$pm")" 0
  check "$pm: critical: decided the documented way"        "$(critruns "crit-$pm")" "$high_runs"

  run_case "high-$pm" "$pm" true findings "$pm-findings.txt" "$SEV_HIGH"
  check "$pm: findings up to high do not fail the step"    "$(rc "high-$pm")" 0
  check "$pm: high: report-only-findings=true"             "$(out "high-$pm" report-only-findings)" true
  check "$pm: high: a warning, no error"                   "$(warns "high-$pm")$(errors "high-$pm")" 10
  check "$pm: high: decided the documented way"            "$(critruns "high-$pm")" "$high_runs"

  run_case "undet-$pm" "$pm" true error "$pm-error.txt"
  check "$pm: an audit that could not run fails the step"  "$(rc "undet-$pm")" 1
  check "$pm: undeterminable: never 'no issues'"           "$(out "undet-$pm" audit-summary)" "audit exited with 1 - see step log"
  check "$pm: undeterminable: says why it blocks"          "$(grep -c '^::error.*cannot be determined' "$WORK/undet-$pm/log")" 1
  check "$pm: undeterminable: no report-only warning"      "$(warns "undet-$pm")" 0
  check "$pm: undeterminable: report-only-findings=false"  "$(out "undet-$pm" report-only-findings)" false
done

echo "Dependabot pull request, Yarn Berry (no \`yarn audit\`)"
run_case undet-berry yarn true berry yarn-findings.txt
check "berry: the usage error fails the step"           "$(rc undet-berry)" 1
check "berry: no counts, so it cannot be determined"    "$(grep -c '^::error.*cannot be determined' "$WORK/undet-berry/log")" 1
check "berry: no report-only warning"                   "$(warns undet-berry)" 0

echo "Dependabot pull request, critical count unknown"
# Findings counted at level high, but the registry drops before the run at level critical.
CASE_CRITICAL_MODE=error run_case crit-error npm true findings npm-findings.txt "$SEV_HIGH"
check "a failed run at level critical fails the step"   "$(rc crit-error)" 1
check "...with an error annotation, no warning"         "$(errors crit-error)$(warns crit-error)" 10
check "...that names the run at level critical"         "$(grep -c '^::error.*the same audit at level critical failed too' "$WORK/crit-error/log")" 1
check "...whose output is in the log"                   "$(grep -c 'critical run' "$WORK/crit-error/log")" 1
# The first run failed without counts; a run at level critical would pass now.
CASE_CRITICAL_MODE=findings CASE_CRITICAL_OUTPUT=npm-clean.txt run_case undet-no-retry npm true error npm-error.txt
check "a failed audit without counts is not retried"    "$(audits undet-no-retry)" 1
check "...and fails the step"                           "$(rc undet-no-retry)" 1

# --- everything else: blocking (unchanged) -------------------------------------------
echo "push, merge_group, release, workflow_dispatch, other pull requests (AUDIT_REPORT_ONLY=false)"
run_case block-npm npm false findings npm-findings.txt "$SEV_HIGH"
check "npm findings fail the step"                   "$(rc block-npm)" 1
check "blocking: no second audit"                    "$(audits block-npm)" 1
check "blocking: report-only-findings=false"         "$(out block-npm report-only-findings)" false
check "blocking: no report-only warning or error"    "$(warns block-npm)$(errors block-npm)" 00
check "blocking: nothing added to the step summary"  "$(sumbytes block-npm)" 0
check "blocking: audit-summary keeps the counts"     "$(out block-npm audit-summary)" "2 vulnerabilities (1 moderate, 1 high)"

run_case block-error npm false error npm-error.txt
check "an audit that could not run fails the step"   "$(rc block-error)" 1
check "...and is not reported as 'no issues'"        "$(out block-error audit-summary)" "audit exited with 1 - see step log"

run_case block-pnpm pnpm false findings pnpm-findings.txt "$SEV_HIGH"
check "pnpm findings fail the step"                  "$(rc block-pnpm)" 1
run_case block-yarn yarn false findings yarn-findings.txt "$SEV_HIGH"
check "yarn findings fail the step with yarn's code" "$(rc block-yarn)" 12
run_case block-bun bun false findings bun-findings.txt "$SEV_HIGH"
check "bun findings fail the step"                   "$(rc block-bun)" 1

run_case block-clean npm false findings npm-clean.txt ""
check "a clean audit passes"                         "$(rc block-clean)" 0

# Only the literal "true" GitHub renders for a true expression downgrades.
run_case block-empty npm "" findings npm-findings.txt "$SEV_HIGH"
check "an empty AUDIT_REPORT_ONLY blocks"            "$(rc block-empty)" 1
run_case block-other npm "True" findings npm-findings.txt "$SEV_HIGH"
check "anything but 'true' blocks"                   "$(rc block-other)" 1
check "...without a second audit"                    "$(audits block-other)" 1

echo
if [ "$FAILED" -gt 0 ]; then
  echo "$FAILED check(s) failed"
  exit 1
fi
echo "all checks passed"
