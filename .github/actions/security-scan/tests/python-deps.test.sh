#!/usr/bin/env bash
#
# Behavioural test for the 'Resolve Python Dependencies for Trivy' step (id: python-deps)
# in ../action.yml.
#
# Trivy cannot read pyproject.toml, so a Python project without a lock file was never
# scanned for vulnerable dependencies. The step resolves such projects with
# `uv pip compile` into security-reports/python-deps/, where Trivy finds them. This test
# pins WHICH projects get resolved, that a lock file (also a workspace lock in a parent
# directory) always wins, that excluded and vendored directories are left alone, and
# that a failing resolution is reported without ever failing the step.
#
# `uv` is replaced by a stub, so the test needs no network. With REAL_UV=1 and uv on
# PATH it additionally resolves a real project against PyPI.
#
# The step body is extracted from action.yml at runtime rather than duplicated here:
# a copied-out script would keep passing after the real one regressed.
#
# Usage: bash .github/actions/security-scan/tests/python-deps.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION_FILE="$SCRIPT_DIR/../action.yml"
STEP_ID="python-deps"

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

# Stub uv: `uv pip compile <pyproject> [--universal] --quiet -o <out>` writes one pinned
# package per project, or fails when the project directory holds a FAIL marker.
mkdir -p "$WORK/bin"
cat > "$WORK/bin/uv" << 'STUB'
#!/usr/bin/env bash
src="$3"; out=""
while [ $# -gt 0 ]; do
  if [ "$1" = "-o" ]; then out="$2"; fi
  shift
done
if [ -f "$(dirname "$src")/FAIL" ]; then
  echo "error: No solution found when resolving dependencies" >&2
  exit 1
fi
printf '# stub\nhttpx==0.28.1\n    # via stub\npyyaml==6.0.3 ; python_full_version >= "3.12"\n' > "$out"
STUB
chmod +x "$WORK/bin/uv"

project() {  # project <dir> [table]
  mkdir -p "$1"
  printf '[%s]\nname = "x"\ndependencies = ["httpx>=0.27"]\n' "${2:-project}" > "$1/pyproject.toml"
}

# run_case <name> <exclude-paths> <expected resolved> <expected failed> <expected files (space separated, relative to security-reports/python-deps) or -> <annotation or ->
run_case() {
  local name="$1" exclude="$2" e_res="$3" e_fail="$4" e_files="$5" e_ann="$6"
  local dir="$WORK/repo-$name"
  : > "$dir.output"
  ( cd "$dir" && PATH="$WORK/bin:$PATH" EXCLUDE_PATHS="$exclude" OUT_ROOT="security-reports/python-deps" \
      RUNNER_TEMP="$WORK/tmp-$name" GITHUB_OUTPUT="$dir.output" bash -c "$STEP_BODY" ) > "$dir.log" 2>&1
  local rc=$?

  local res fail files ok=true
  res=$(sed -n 's/^resolved=//p' "$dir.output" | tail -n 1)
  fail=$(sed -n 's/^failed=//p' "$dir.output" | tail -n 1)
  files=$(cd "$dir" && find security-reports/python-deps -name requirements.txt 2>/dev/null | sed 's#^security-reports/python-deps/##' | sort | tr '\n' ' ' | sed 's/ $//')
  [ -n "$files" ] || files="-"
  [ "$rc" -eq 0 ] || ok=false
  [ "$res" = "$e_res" ] || ok=false
  [ "$fail" = "$e_fail" ] || ok=false
  [ "$files" = "$e_files" ] || ok=false
  if [ "$e_ann" = "-" ]; then
    grep -q '^::warning' "$dir.log" && ok=false
  else
    grep -q "^::${e_ann}" "$dir.log" || ok=false
  fi

  if [ "$ok" = true ]; then
    PASSED=$((PASSED + 1))
    printf 'ok   %-28s resolved=%s failed=%s files=%s\n' "$name" "$res" "$fail" "$files"
  else
    FAILED=$((FAILED + 1))
    printf 'FAIL %-28s rc=%s resolved=%s failed=%s files=%s\n       want resolved=%s failed=%s files=%s annotation=%s\n' \
      "$name" "$rc" "$res" "$fail" "$files" "$e_res" "$e_fail" "$e_files" "$e_ann"
    sed 's/^/       | /' "$dir.log"
  fi
}

# 1. Root project without a lock file: resolved, Trivy gets a pinned requirements.txt.
R="$WORK/repo-root-unlocked"; project "$R"
run_case root-unlocked "" 1 0 "requirements.txt" notice

# 2. Each lock file Trivy reads wins over resolving.
for lock in uv.lock poetry.lock requirements.txt Pipfile.lock pylock.toml pylock.dev.toml; do
  R="$WORK/repo-locked-$lock"; project "$R"; : > "$R/$lock"
  run_case "locked-$lock" "" 0 0 "-" -
done

# 3. A workspace lock at the root covers members in subdirectories.
R="$WORK/repo-workspace-member"; project "$R"; project "$R/packages/member"; : > "$R/uv.lock"
run_case workspace-member "" 0 0 "-" -

# 4. Tool configuration only (no [project] / [tool.poetry]): nothing to resolve.
R="$WORK/repo-tool-config-only"; mkdir -p "$R"; printf '[tool.ruff]\nline-length = 100\n' > "$R/pyproject.toml"
run_case tool-config-only "" 0 0 "-" -

# 5. Poetry project without poetry.lock is resolved too.
R="$WORK/repo-poetry-unlocked"; project "$R" tool.poetry
run_case poetry-unlocked "" 1 0 "requirements.txt" notice

# 6. Vendored / virtualenv / excluded directories are never searched; a nested
#    unlocked project is resolved to a mirrored path.
R="$WORK/repo-nested-and-excluded"
project "$R/node_modules/pkg"; project "$R/.venv/lib/site-packages/pkg"; project "$R/test/fixtures/proj"
project "$R/vendor/lib"; project "$R/services/api"
run_case nested-and-excluded ".git,node_modules,vendor, test/fixtures/" 1 0 "services/api/requirements.txt" notice

# 7. A resolution failure is a warning, never a failed step, and leaves no file.
R="$WORK/repo-one-fails"; project "$R/a"; project "$R/b"; : > "$R/b/FAIL"
run_case one-fails "" 1 1 "a/requirements.txt" warning

# 8. No Python at all.
mkdir -p "$WORK/repo-no-python/src"
run_case no-python "" 0 0 "-" -

# Optional: a real resolution against PyPI (needs network and uv on PATH).
if [ "${REAL_UV:-0}" = "1" ] && command -v uv > /dev/null 2>&1; then
  R="$WORK/real"; mkdir -p "$R"
  printf '[project]\nname = "real"\nversion = "0"\nrequires-python = ">=3.10"\ndependencies = ["requests>=2.20,<3"]\n' > "$R/pyproject.toml"
  ( cd "$R" && GITHUB_OUTPUT="$R.output" EXCLUDE_PATHS="" OUT_ROOT="security-reports/python-deps" RUNNER_TEMP="$WORK" \
      bash -c "$STEP_BODY" ) > "$R.log" 2>&1
  if grep -q '^requests==' "$R/security-reports/python-deps/requirements.txt" 2>/dev/null \
     && grep -q '^urllib3==' "$R/security-reports/python-deps/requirements.txt"; then
    PASSED=$((PASSED + 1)); echo "ok   real-uv                      requests and its dependencies pinned"
  else
    FAILED=$((FAILED + 1)); echo "FAIL real-uv"; sed 's/^/       | /' "$R.log"
  fi
fi

echo
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
