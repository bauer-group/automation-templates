#!/usr/bin/env bash
#
# Behavioural test for the 'Evaluate Vulnerability Results' step (id: vulnerability-scan)
# in ../action.yml.
#
# Pins the difference between "scanned and clean" and "nothing was scanned". Trivy
# writes `Results: null` when it finds no dependency file it can read - for example a
# Python project with only a pyproject.toml - and the step used to turn that into
# "No vulnerabilities detected" and a 100/100 score. 'unknown' must stay 'unknown'.
#
# The step body is extracted from action.yml at runtime rather than duplicated here:
# a copied-out script would keep passing after the real one regressed.
#
# Requires jq (preinstalled on GitHub-hosted runners).
#
# Usage: bash .github/actions/security-scan/tests/evaluate-vulnerabilities.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION_FILE="$SCRIPT_DIR/../action.yml"
STEP_ID="vulnerability-scan"

if ! command -v jq > /dev/null 2>&1; then
  echo "FATAL: jq is required"
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
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# run_case <name> <report content or __MISSING__> <found> <targets> <packages> <critical> <high> <medium> <annotation or ->
run_case() {
  local name="$1" report="$2" e_found="$3" e_targets="$4" e_packages="$5" e_crit="$6" e_high="$7" e_med="$8" e_ann="$9"
  local dir="$WORK/$name"
  mkdir -p "$dir/security-reports/vulnerabilities"
  : > "$dir/output"
  if [ "$report" != "__MISSING__" ]; then
    printf '%s' "$report" > "$dir/security-reports/vulnerabilities/trivy-results.json"
  fi

  ( cd "$dir" && REPORT="security-reports/vulnerabilities/trivy-results.json" \
      GITHUB_OUTPUT="$dir/output" bash -c "$STEP_BODY" ) > "$dir/log" 2>&1
  local rc=$?

  out() { sed -n "s/^$1=//p" "$dir/output"; }
  local got
  got="found=$(out vulnerabilities-found) targets=$(out trivy-targets) packages=$(out trivy-packages) critical=$(out trivy-critical) high=$(out trivy-high) medium=$(out trivy-medium)"
  local want="found=$e_found targets=$e_targets packages=$e_packages critical=$e_crit high=$e_high medium=$e_med"
  local ok=true
  [ "$rc" -eq 0 ] || ok=false
  [ "$got" = "$want" ] || ok=false
  if [ "$e_ann" = "-" ]; then
    grep -q '^::\(notice\|warning\)' "$dir/log" && ok=false
  else
    grep -q "^::${e_ann}" "$dir/log" || ok=false
  fi

  if [ "$ok" = true ]; then
    PASSED=$((PASSED + 1))
    printf 'ok   %-26s %s\n' "$name" "$got"
  else
    FAILED=$((FAILED + 1))
    printf 'FAIL %-26s rc=%s\n       got:  %s\n       want: %s (annotation %s)\n' "$name" "$rc" "$got" "$want" "$e_ann"
    sed 's/^/       | /' "$dir/log"
  fi
}

# What Trivy writes when it finds nothing to scan (pyproject.toml only, no lock file).
NOTHING='{"SchemaVersion":2,"ArtifactName":".","ArtifactType":"filesystem","Results":null}'
NO_RESULTS_KEY='{"SchemaVersion":2,"ArtifactName":".","ArtifactType":"filesystem"}'

CLEAN='{"SchemaVersion":2,"Results":[
  {"Target":"security-reports/python-deps/requirements.txt","Class":"lang-pkgs","Type":"pip",
   "Packages":[{"Name":"httpx","Version":"0.28.1"},{"Name":"pyyaml","Version":"6.0.3"},{"Name":"anyio","Version":"4.11.0"}]},
  {"Target":"package-lock.json","Class":"lang-pkgs","Type":"npm",
   "Packages":[{"Name":"left-pad","Version":"1.3.0"}]}]}'

FINDINGS='{"SchemaVersion":2,"Results":[
  {"Target":"requirements.txt","Class":"lang-pkgs","Type":"pip",
   "Packages":[{"Name":"jinja2","Version":"2.10"},{"Name":"urllib3","Version":"1.24"}],
   "Vulnerabilities":[{"VulnerabilityID":"CVE-1","Severity":"CRITICAL"},{"VulnerabilityID":"CVE-2","Severity":"HIGH"},
                      {"VulnerabilityID":"CVE-3","Severity":"HIGH"},{"VulnerabilityID":"CVE-4","Severity":"MEDIUM"}]}]}'

run_case nothing-scanned        "$NOTHING"        unknown 0 0 0 0 0 notice
run_case no-results-key         "$NO_RESULTS_KEY" unknown 0 0 0 0 0 notice
run_case scanned-and-clean      "$CLEAN"          false   2 4 0 0 0 -
run_case scanned-with-findings  "$FINDINGS"       true    1 2 1 2 1 -
run_case report-missing         "__MISSING__"     unknown 0 0 0 0 0 warning
run_case report-not-json        "Trivy crashed"   unknown 0 0 0 0 0 warning

echo
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
