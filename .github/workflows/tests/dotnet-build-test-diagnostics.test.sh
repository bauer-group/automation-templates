#!/usr/bin/env bash
#
# Behavioural test for the 🧪 Run Tests and ✅ Validate Test Results steps of
# ../dotnet-build.yml.
#
# A failing `dotnet test` aborted 🧪 Run Tests under `bash -e` before any output
# was written, and that step is continue-on-error, so it showed green. ✅ Validate
# Test Results then turned the run red with only "Tests failed!" - when dotnet
# test failed before a single test ran (restore/MSBuild error, Microsoft.Testing
# .Platform v2 refusing VSTest mode) the real error sat in a green step. This
# pins:
#
#   - the test step keeps dotnet's exit code, writes its outputs on a failure
#     too (so the report and upload steps run) and keeps the log;
#   - without a .trx the validation step prints the first MSBuild errors from
#     that log, and names the Microsoft.Testing.Platform v2 case;
#   - with a .trx it counts per-test results only (the run-level ResultSummary
#     used to add one failure per file) and survives a file without failures.
#
# Both step bodies are extracted from the workflow at runtime, their ${{ }}
# expressions replaced by test values, and run the way a `shell: bash` step runs
# (bash -eo pipefail) against a stubbed `dotnet`.
#
# Usage: bash .github/workflows/tests/dotnet-build-test-diagnostics.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW="$SCRIPT_DIR/../dotnet-build.yml"
[ -f "$WORKFLOW" ] || { echo "FATAL: workflow not found at $WORKFLOW"; exit 1; }

FAILED=0
check() {
  if [ "$2" = "$3" ]; then echo "  ok   $1"; else echo "  FAIL $1 (expected '$3', got '$2')"; FAILED=$((FAILED + 1)); fi
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# extract_run <awk regex matching the step's first line>
extract_run() {
  awk -v start="$1" '
    $0 ~ start { found = 1; next }
    found && /^        run: \|$/ { collecting = 1; next }
    collecting {
      if ($0 == "") { print ""; next }
      if ($0 ~ /^          /) { sub(/^          /, ""); print; next }
      exit
    }
  ' "$WORKFLOW"
}

# shellcheck disable=SC2016 # literal workflow expressions
extract_run '^        id: test$' | sed \
  -e 's/\${{ inputs\.project-path }}/App.slnx/g' \
  -e 's/\${{ inputs\.configuration }}/Release/g' \
  -e 's/\${{ inputs\.verbosity }}/normal/g' \
  -e 's/\${{ inputs\.test-logger }}/trx/g' \
  -e 's/\${{ inputs\.working-directory }}/./g' \
  -e 's/${{[^$]*}}//g' > "$WORK/run-tests.sh"
# shellcheck disable=SC2016
extract_run '^      - name: ✅ Validate Test Results$' \
  | sed -e 's/\${{ steps\.test\.outcome }}/failure/g' > "$WORK/validate.sh"
for f in run-tests.sh validate.sh; do
  if [ ! -s "$WORK/$f" ] || grep -q '\${{' "$WORK/$f"; then
    echo "FATAL: could not extract $f from the workflow."
    exit 1
  fi
done

mkdir -p "$WORK/bin"
cat > "$WORK/bin/dotnet" <<'EOF'
#!/usr/bin/env bash
trx() { # trx <file> <failed> <passed>
  {
    echo '<TestRun>'
    for _ in $(seq 1 "$2"); do echo '  <UnitTestResult testName="t" outcome="Failed" />'; done
    for _ in $(seq 1 "$3"); do echo '  <UnitTestResult testName="t" outcome="Passed" />'; done
    [ "$2" -gt 0 ] && echo '  <ResultSummary outcome="Failed" />' || echo '  <ResultSummary outcome="Completed" />'
    echo '</TestRun>'
  } > "TestResults/$1"
}
case "$MODE" in
  restore-error)
    echo "  Determining projects to restore..."
    echo "/src/App.Tests/App.Tests.csproj : error NU1101: Unable to find package Foo.Bar. No packages exist with this id in source(s): nuget.org"
    exit 1 ;;
  mtp)
    echo "/src/App.Tests/App.Tests.csproj : error : Testing with VSTest target is no longer supported by Microsoft.Testing.Platform on .NET 10 SDK and later."
    exit 1 ;;
  tests-fail)
    trx a.trx 1 2; trx b.trx 0 3
    echo "Failed!  - Failed: 1, Passed: 2"
    exit 1 ;;
  pass)
    trx a.trx 0 3
    exit 0 ;;
esac
EOF
chmod +x "$WORK/bin/dotnet"

# run_case <mode>: runs both steps in a fresh working directory
run_case() {
  CASE="$WORK/case.$1"
  mkdir -p "$CASE"
  export GITHUB_OUTPUT="$CASE/output" MODE="$1"
  : > "$GITHUB_OUTPUT"
  (cd "$CASE" && PATH="$WORK/bin:$PATH" bash -eo pipefail "$WORK/run-tests.sh" > "$CASE/run.out" 2>&1)
  RUN_RC=$?
  (cd "$CASE" && bash -eo pipefail "$WORK/validate.sh" > "$CASE/validate.out" 2>&1)
  VALIDATE_RC=$?
  OUT_TESTS_FOUND=$(sed -n 's/^tests-found=//p' "$GITHUB_OUTPUT" | tail -1)
  OUT_RESULTS=$(sed -n 's/^results-path=//p' "$GITHUB_OUTPUT" | tail -1)
}

echo "- dotnet test fails at restore, no .trx"
run_case restore-error
check "test step keeps dotnet's exit code" "$RUN_RC" 1
check "outputs are written: tests-found" "$OUT_TESTS_FOUND" false
check "outputs are written: no results path" "$(grep -c '^results-path=$' "$GITHUB_OUTPUT")" 1
check "the dotnet output is kept in TestResults/dotnet-test.log" "$(grep -c 'error NU1101' "$CASE/TestResults/dotnet-test.log")" 1
check "the dotnet output is still printed in the step" "$(grep -c 'error NU1101' "$CASE/run.out")" 1
check "validation fails" "$VALIDATE_RC" 1
check "validation names the missing results" "$(grep -c '^::error title=No test results::' "$CASE/validate.out")" 1
check "validation shows the MSBuild error" "$(grep -c '^    /src/App.Tests/App.Tests.csproj : error NU1101' "$CASE/validate.out")" 1
check "no Microsoft.Testing.Platform hint for a restore error" "$(grep -c 'Microsoft.Testing.Platform v2' "$CASE/validate.out")" 0

echo "- Microsoft.Testing.Platform v2 refuses VSTest mode"
run_case mtp
check "validation fails" "$VALIDATE_RC" 1
check "validation shows the error line" "$(grep -c '^    .*error : Testing with VSTest target is no longer supported' "$CASE/validate.out")" 1
check "validation names the Microsoft.Testing.Platform v2 case" "$(grep -c '^::error title=Microsoft.Testing.Platform v2 vs. VSTest dotnet test::' "$CASE/validate.out")" 1

echo "- failing tests with .trx files"
run_case tests-fail
check "test step keeps dotnet's exit code" "$RUN_RC" 1
check "results path is set, so the report and upload steps run" "$OUT_RESULTS" TestResults
check "validation fails" "$VALIDATE_RC" 1
check "per-test counts, the ResultSummary is not counted" "$(grep -c 'a.trx — Passed: 2, Failed: 1$' "$CASE/validate.out")" 1
check "a file without failures does not abort the listing" "$(grep -c 'b.trx — Passed: 3, Failed: 0$' "$CASE/validate.out")" 1

echo "- passing tests"
run_case pass
check "test step succeeds" "$RUN_RC" 0
check "results path is set" "$OUT_RESULTS" TestResults
check "tests-found stays true" "$OUT_TESTS_FOUND" true

echo "- static"
# shellcheck disable=SC2016
check "coverage is processed only after passing tests" \
  "$(grep -cF "if: inputs.collect-coverage && steps.test.outcome == 'success' && steps.test.outputs.results-path != ''" "$WORKFLOW")" 1

echo
if [ "$FAILED" -gt 0 ]; then
  echo "$FAILED check(s) failed"
  exit 1
fi
echo "all checks passed"
