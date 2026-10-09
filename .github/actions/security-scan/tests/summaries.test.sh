#!/usr/bin/env bash
#
# Behavioural test for the two security summaries: the security-scan action's report
# (step id: summary) and the job summary of modules-security-scan.yml.
#
# Gitleaks is opt-in, so most runs now have no secret scan at all. That is a
# configuration, not a failure - but it is not a clean secret scan either. Both
# summaries must say "disabled" in that case, never "none found" / "no", and must
# not present a score that only covers dependencies as if it covered secrets.
# The explicit opt-in keeps reporting exactly as before.
#
# The step bodies are extracted from the real files at runtime rather than copied
# here: a copied-out script would keep passing after the real one regressed.
#
# Usage: bash .github/actions/security-scan/tests/summaries.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
ACTION_FILE="$REPO_ROOT/.github/actions/security-scan/action.yml"
WORKFLOW_FILE="$REPO_ROOT/.github/workflows/modules-security-scan.yml"

# extract <file> <line that marks the step> <indent of the step's keys>
# Prints the body of the first `run: |` block after the marker, de-indented.
extract() {
  awk -v marker="$2" -v ind="$3" '
    index($0, marker) == 1 { found = 1; next }
    found && $0 == ind "run: |" { collecting = 1; next }
    collecting {
      if ($0 == "") { print ""; next }
      if (index($0, ind "  ") == 1) { print substr($0, length(ind) + 3); next }
      exit
    }
  ' "$1"
}

ACTION_STEP="$(extract "$ACTION_FILE" "      id: summary" "      ")"
WORKFLOW_STEP="$(extract "$WORKFLOW_FILE" "      - name: 📊 Security Report Summary" "        ")"

for pair in "action summary:$ACTION_STEP" "workflow summary:$WORKFLOW_STEP"; do
  if [ -z "${pair#*:}" ]; then
    echo "FATAL: could not extract the ${pair%%:*} run block."
    echo "       The step was renamed, removed, or re-indented - update this test."
    exit 1
  fi
done

PASSED=0
FAILED=0
OUT=""
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# expect <name> <file> <must contain|-> <must not contain|->
expect() {
  local name="$1" file="$2" want="$3" unwanted="$4" ok=true
  [ "$want" = "-" ] || grep -qF -- "$want" "$file" || ok=false
  [ "$unwanted" = "-" ] || ! grep -qF -- "$unwanted" "$file" || ok=false
  if [ "$ok" = true ]; then
    PASSED=$((PASSED + 1))
    printf 'ok   %s\n' "$name"
  else
    FAILED=$((FAILED + 1))
    printf 'FAIL %s\n       expected: %s\n       not:      %s\n' "$name" "$want" "$unwanted"
    sed 's/^/       | /' "$file"
  fi
}

# run_action <case> <secret-engine> <gitleaks secrets-found> <count>
# Sets OUT to a file with the rendered report and the step log.
run_action() {
  local dir="$WORK/action-$1"
  mkdir -p "$dir/security-reports"
  : > "$dir/output"
  ( cd "$dir" && SECRET_ENGINE="$2" GITLEAKS_SECRETS="$3" GITLEAKS_COUNT="$4" \
      VULNS_FOUND=false TRIVY_CRITICAL=0 TRIVY_HIGH=0 TRIVY_MEDIUM=0 \
      TRIVY_TARGETS=1 TRIVY_PACKAGES=12 PYTHON_RESOLVED=0 PYTHON_FAILED=0 \
      GITHUB_OUTPUT="$dir/output" bash -c "$ACTION_STEP" ) > "$dir/log" 2>&1 \
    || { echo "FAIL action summary step crashed ($1)"; sed 's/^/       | /' "$dir/log"; FAILED=$((FAILED + 1)); }
  cat "$dir/security-reports/dual-security-summary.md" "$dir/log" > "$dir/all" 2>/dev/null
  OUT="$dir/all"
}

run_action disabled disabled skipped n/a; f="$OUT"
expect "action: Gitleaks disabled is reported as disabled" "$f" \
  "| **Secrets (Gitleaks)** | ⏭️ disabled - Gitleaks is opt-in" "| **Secrets (Gitleaks)** | ✅ none found"
expect "action: Gitleaks disabled leaves the score to the dependencies" "$f" \
  "Score: 100/100" "Security Issues Found"
run_action gitleaks-clean gitleaks false 0; f="$OUT"
expect "action: explicit Gitleaks, clean, still reports none found" "$f" \
  "| **Secrets (Gitleaks)** | ✅ none found |" "disabled"
run_action gitleaks-finding gitleaks true 2; f="$OUT"
expect "action: explicit Gitleaks finding still reported" "$f" \
  "🚨 2 secret(s) found" "disabled"
run_action gitguardian none skipped n/a; f="$OUT"
expect "action: removed engine is 'no secret engine', not 'disabled'" "$f" \
  "not scanned - no secret engine ran" "disabled"

# run_workflow <case> <scan-engine input> <scan-type> <secrets-found> <vulns-found> <targets>
# Sets OUT to the rendered job summary.
run_workflow() {
  local dir="$WORK/workflow-$1"
  mkdir -p "$dir"
  : > "$dir/summary"
  local engines_used="gitleaks"
  [ "$4" = "skipped" ] && engines_used="none"
  ( cd "$dir" && SCAN_ENGINE="$engines_used" SCAN_ENGINE_INPUT="$2" SCAN_TYPE="$3" \
      SECURITY_SCORE=100 SECRETS_FOUND="$4" SECRETS_COUNT=0 VULNERABILITIES_FOUND="$5" \
      VULN_TARGETS="$6" VULN_PACKAGES=12 PYTHON_RESOLVED=0 SCAN_RESULTS="Security Scan Complete" \
      GITHUB_STEP_SUMMARY="$dir/summary" bash -c "$WORKFLOW_STEP" ) > "$dir/log" 2>&1 \
    || { echo "FAIL workflow summary step crashed ($1)"; sed 's/^/       | /' "$dir/log"; FAILED=$((FAILED + 1)); }
  OUT="$dir/summary"
}

run_workflow default none all skipped false 1; f="$OUT"
expect "workflow: default run says Gitleaks is disabled" "$f" \
  "| **Secrets Found** | ⏭️ disabled - Gitleaks is opt-in" "| **Secrets Found** | ✅ no |"
expect "workflow: default run says the score covers dependencies only" "$f" \
  "the score covers dependencies only" "No secret scan ran"
expect "workflow: default run names no engine" "$f" \
  "| **Engine Used** | none (Gitleaks disabled) |" "-"
run_workflow secrets-only none secrets skipped '' 0; f="$OUT"
expect "workflow: secrets-only with Gitleaks disabled scanned nothing" "$f" \
  "Nothing was scanned: scan-type is 'secrets' and Gitleaks is disabled" "Excellent security posture"
run_workflow no-deps none all skipped unknown 0; f="$OUT"
expect "workflow: no dependency file and Gitleaks disabled scanned nothing" "$f" \
  "Nothing was scanned: Trivy found no dependency file and Gitleaks is disabled" "Excellent security posture"
run_workflow gitleaks-clean gitleaks all false false 1; f="$OUT"
expect "workflow: explicit Gitleaks, clean, unchanged" "$f" \
  "| **Secrets Found** | ✅ no |" "disabled"
expect "workflow: explicit Gitleaks, clean, gets the verdict" "$f" \
  "Excellent security posture" "-"
run_workflow gitleaks-unknown gitleaks all unknown false 1; f="$OUT"
expect "workflow: explicit Gitleaks that did not complete is not clean" "$f" \
  "The secret scan did not complete" "Excellent security posture"
run_workflow gitguardian gitguardian all skipped false 1; f="$OUT"
expect "workflow: removed engine says no secret scan ran" "$f" \
  "No secret scan ran - the score does not cover secrets." "disabled"

echo
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
