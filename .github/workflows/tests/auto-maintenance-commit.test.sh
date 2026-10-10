#!/usr/bin/env bash
#
# Behavioural test for the change detection and the selective staging of
# ../modules-auto-maintenance.yml.
#
# The commit step staged each ecosystem with ONE `git add` of fixed paths at
# the repository root, e.g. `git add package.json package-lock.json yarn.lock
# pnpm-lock.yaml`. Git stages nothing when one pathspec matches no file, and
# the error was swallowed by `2>/dev/null || true`. An npm project has no
# yarn.lock, a pip project no Pipfile.lock, a C# project no *.fsproj - so
# their updates were applied, validated and then dropped with "No dependency
# files to commit", while the run stayed green. Pinned here:
#
#   npm, yarn, pnpm lock files and package.json     -> committed
#   requirements*.txt and the configured file       -> committed
#   *.csproj, Directory.Packages.props,
#   packages.lock.json                              -> committed
#   go.mod, go.sum                                  -> committed (as before)
#   files below a working-directory                 -> committed
#   source files, build output, node_modules        -> left uncommitted
#   new lock file next to its tracked manifest      -> committed (go.sum)
#   new manifest, new lock file without a tracked
#   manifest next to it (unignored dist/, .venv/)   -> left uncommitted
#   tracked file named like a manifest (dist/)      -> committed
#   only non-dependency files changed               -> no commit, no push
#   base image update only                          -> empty commit (as before)
#
# The step bodies are extracted from the workflow at runtime rather than
# duplicated here and run the way a `shell: bash` step runs (-eo pipefail).
# Each scenario gets a real git repository with a local bare origin, so the
# commit is really pushed. No Docker, no network, no package manager: the
# fixture files are edited the way the update steps would leave them.
#
# Usage: bash .github/workflows/tests/auto-maintenance-commit.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW_FILE="$SCRIPT_DIR/../modules-auto-maintenance.yml"

if [ ! -f "$WORKFLOW_FILE" ]; then
  echo "FATAL: workflow not found at $WORKFLOW_FILE"
  exit 1
fi
for TOOL in jq git; do
  if ! command -v "$TOOL" > /dev/null; then
    echo "FATAL: $TOOL is required"
    exit 1
  fi
done

# Prints the run block of the step with the given id, de-indented.
extract_step() {
  awk -v id="        id: $1" '
    $0 == id { found = 1; next }
    found && /^        run: \|$/ { collecting = 1; next }
    collecting {
      if ($0 == "") { print ""; next }
      if ($0 ~ /^          /) { sub(/^          /, ""); print; next }
      exit
    }
  ' "$WORKFLOW_FILE"
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

for STEP in detect-changes commit; do
  extract_step "$STEP" > "$WORK/$STEP.sh"
  if [ ! -s "$WORK/$STEP.sh" ]; then
    echo "FATAL: could not extract the '$STEP' run block from the workflow."
    echo "       The step was renamed, removed, or re-indented - update this test."
    exit 1
  fi
done

# The developer's own git configuration (signing, hooks, autocrlf) must not
# change what the steps do.
: > "$WORK/gitconfig"
export GIT_CONFIG_GLOBAL="$WORK/gitconfig" GIT_CONFIG_NOSYSTEM=1

PASSED=0
FAILED=0
pass() { echo "PASS $1"; PASSED=$((PASSED + 1)); }
fail() { echo "FAIL $1: $2"; FAILED=$((FAILED + 1)); }

# --- the step must be wired the way the tests below assume --------------------
static_check() {
  local name="$1" pattern="$2"
  if grep -qF -- "$pattern" "$WORKFLOW_FILE"; then
    pass "$name"
  else
    fail "$name" "'$pattern' not found"
  fi
}
static_check "commit step knows the Python working directory" \
  "PYTHON_WORKDIR: \${{ steps.config.outputs.python-workdir }}"
static_check "commit step knows the configured requirements file" \
  "PYTHON_REQUIREMENTS: \${{ steps.config.outputs.python-requirements }}"
static_check "commit step follows the change detection" \
  "HAS_FILE_CHANGES: \${{ steps.detect-changes.outputs.has-file-changes }}"
static_check "job has a timeout" "    timeout-minutes: "
if grep -qE 'git add [^-].*2>/dev/null \|\| true' "$WORKFLOW_FILE"; then
  fail "no silenced multi-path git add" "a 'git add ... 2>/dev/null || true' is back"
else
  pass "no silenced multi-path git add"
fi

# --- fixtures -----------------------------------------------------------------
# Fresh repository for a scenario: a checkout ($REPO) whose initial commit
# holds the given files (path=content pairs), pushed to a bare origin.
reset() {
  FAKE="$WORK/fake-$1"; shift
  REPO="$FAKE/repo"
  rm -rf "$FAKE"
  git init -q --bare "$FAKE/origin.git"
  git init -q "$REPO"
  git -C "$REPO" remote add origin "$FAKE/origin.git"
  local pair
  for pair in "$@"; do
    write "${pair%%=*}" "${pair#*=}"
  done
  git -C "$REPO" add -A
  git -C "$REPO" -c user.name=fixture -c user.email=fixture@example.invalid \
    commit -q --allow-empty -m "feat: initial"
  git -C "$REPO" push -q origin HEAD:main
}
# write PATH CONTENT - creates or overwrites a file in the checkout.
write() { mkdir -p "$(dirname "$REPO/$1")"; printf '%s\n' "$2" > "$REPO/$1"; }

# Runs a step with the environment of the workflow. Extra VAR=value pairs
# override the defaults; the step's GITHUB_OUTPUT ends up in $FAKE/output.
run_step() {
  local step="$1"; shift
  : > "$FAKE/output"; : > "$FAKE/env"
  (cd "$REPO" && env GH_TOKEN=dummy \
    GITHUB_OUTPUT="$FAKE/output" GITHUB_ENV="$FAKE/env" \
    COMMIT_PREFIX="fix(deps)" TARGET_BRANCH=main TRIGGER_WORKFLOW="" \
    BASE_IMAGES_UPDATED=false UPDATED_IMAGES_JSON='[]' UPDATE_DETAILS="" \
    HAS_FILE_CHANGES=true PYTHON_WORKDIR="" PYTHON_REQUIREMENTS="" \
    "$@" bash -eo pipefail "$WORK/$step.sh") > "$FAKE/log" 2>&1
}
out() { grep "^$1=" "$FAKE/output" | tail -n 1 | cut -d= -f2-; }
# Files changed by the commit on origin's main, sorted, one per line.
pushed_files() { git -C "$FAKE/origin.git" diff-tree --no-commit-id --name-only -r main | sort; }
origin_count() { git -C "$FAKE/origin.git" rev-list --count main; }
origin_subject() { git -C "$FAKE/origin.git" log -1 --format=%s main; }
# What is still modified or new in the checkout after the step, sorted.
left_behind() { (cd "$REPO" && { git diff --name-only; git ls-files --others --exclude-standard; } | sort); }
lines() { printf '%s\n' "$@" | sort; }

expect_eq() {
  local name="$1" got="$2" want="$3"
  if [ "$got" = "$want" ]; then pass "$name"; else fail "$name" "got '$got', want '$want'"; fi
}
expect_rc() {
  local name="$1" got="$2" want="$3"
  if [ "$got" -eq "$want" ]; then pass "$name"; else fail "$name" "exit $got, want $want - log: $(tr '\n' ' ' < "$FAKE/log" | cut -c1-400)"; fi
}

# === detect-changes ===========================================================

reset detect-none "package.json={}" "package-lock.json={}"
run_step detect-changes; expect_rc "detect, nothing changed: step succeeds" $? 0
expect_eq "detect, nothing changed: no file changes" "$(out has-file-changes)" "false"
expect_eq "detect, nothing changed: no updates" "$(out updates-found)" "false"

reset detect-lock "package.json={}" "package-lock.json={}"
write package-lock.json '{"lockfileVersion": 3}'
run_step detect-changes; expect_rc "detect, lock file only: step succeeds" $? 0
expect_eq "detect, lock file only: counts as a file change" "$(out has-file-changes)" "true"
expect_eq "detect, lock file only: updates found" "$(out updates-found)" "true"

# === commit: one package manager per repository ================================

# npm: no yarn.lock and no pnpm-lock.yaml - the case that used to stage nothing.
reset npm "package.json={}" "package-lock.json={}"
write package-lock.json '{"lockfileVersion": 3, "packages": {"node_modules/left-pad": {"version": "1.3.1"}}}'
run_step commit; expect_rc "npm: step succeeds" $? 0
expect_eq "npm: committed" "$(out committed)" "true"
expect_eq "npm: lock file pushed" "$(pushed_files)" "package-lock.json"
expect_eq "npm: commit subject" "$(origin_subject)" "fix(deps): automated maintenance update"
expect_eq "npm: one commit on top" "$(origin_count)" "2"
expect_eq "npm: count for the job summary" "$(out dependency-files)" "1"

reset yarn "package.json={}" "yarn.lock=# yarn lockfile v1"
write yarn.lock '# yarn lockfile v1
left-pad@^1.3.0:
  version "1.3.1"'
run_step commit; expect_rc "yarn: step succeeds" $? 0
expect_eq "yarn: lock file pushed" "$(pushed_files)" "yarn.lock"

reset pnpm "package.json={}" "pnpm-lock.yaml=lockfileVersion: '9.0'"
write pnpm-lock.yaml "lockfileVersion: '9.0'
importers: {}"
write package.json '{"dependencies": {"left-pad": "^1.3.1"}}'
run_step commit; expect_rc "pnpm: step succeeds" $? 0
expect_eq "pnpm: manifest and lock file pushed" "$(pushed_files)" "$(lines package.json pnpm-lock.yaml)"

# pip: requirements.txt only - no Pipfile.lock, no poetry.lock.
reset pip "requirements.txt=requests==2.31.0"
write requirements.txt "requests==2.32.3"
run_step commit PYTHON_WORKDIR=. PYTHON_REQUIREMENTS=requirements.txt
expect_rc "pip: step succeeds" $? 0
expect_eq "pip: committed" "$(out committed)" "true"
expect_eq "pip: requirements pushed" "$(pushed_files)" "requirements.txt"

# pip in a working-directory with a requirements file of any name.
reset pip-custom "services/api/deps/prod.txt=flask==3.0.0" "services/api/requirements-dev.txt=pytest==8.0.0"
write services/api/deps/prod.txt "flask==3.1.0"
write services/api/requirements-dev.txt "pytest==8.3.4"
run_step commit PYTHON_WORKDIR=services/api PYTHON_REQUIREMENTS=deps/prod.txt
expect_rc "pip, custom file in a working-directory: step succeeds" $? 0
expect_eq "pip, custom file in a working-directory: both pushed" "$(pushed_files)" \
  "$(lines services/api/deps/prod.txt services/api/requirements-dev.txt)"

# ./ in the configured paths is how the defaults arrive ("." + "requirements.txt").
reset pip-dotted "src/reqs.txt=click==8.1.0"
write src/reqs.txt "click==8.1.8"
run_step commit PYTHON_WORKDIR=./src PYTHON_REQUIREMENTS=./reqs.txt
expect_rc "pip, ./ in the configured paths: step succeeds" $? 0
expect_eq "pip, ./ in the configured paths: pushed" "$(pushed_files)" "src/reqs.txt"

# .NET: C# only - no *.fsproj, no Directory.Build.props.
reset dotnet \
  "Directory.Packages.props=<Project><ItemGroup><PackageVersion Include=\"Serilog\" Version=\"3.1.0\" /></ItemGroup></Project>" \
  "src/App/App.csproj=<Project Sdk=\"Microsoft.NET.Sdk\" />" \
  "src/App/packages.lock.json={\"version\": 1}" \
  "src/App/Program.cs=// app"
write Directory.Packages.props '<Project><ItemGroup><PackageVersion Include="Serilog" Version="3.1.1" /></ItemGroup></Project>'
write src/App/App.csproj '<Project Sdk="Microsoft.NET.Sdk"><ItemGroup><PackageReference Include="Polly" Version="8.4.2" /></ItemGroup></Project>'
write src/App/packages.lock.json '{"version": 1, "dependencies": {}}'
# dotnet restore leaves obj/ behind; the fixture has no .gitignore for it.
write src/App/obj/project.assets.json '{}'
write src/App/obj/App.csproj.nuget.g.props '<Project />'
run_step commit; expect_rc ".NET: step succeeds" $? 0
expect_eq ".NET: committed" "$(out committed)" "true"
expect_eq ".NET: project, central versions and lock file pushed" "$(pushed_files)" \
  "$(lines Directory.Packages.props src/App/App.csproj src/App/packages.lock.json)"
expect_eq ".NET: restore output left behind" "$(left_behind)" \
  "$(lines src/App/obj/App.csproj.nuget.g.props src/App/obj/project.assets.json)"

# Go at the root already worked; it must keep working.
reset go "go.mod=module example.invalid/app" "go.sum="
write go.mod "module example.invalid/app

require golang.org/x/text v0.21.0"
write go.sum "golang.org/x/text v0.21.0 h1:placeholder="
run_step commit; expect_rc "Go: step succeeds" $? 0
expect_eq "Go: go.mod and go.sum pushed" "$(pushed_files)" "$(lines go.mod go.sum)"

# npm in a working-directory below the root.
reset npm-subdir "frontend/package.json={}" "frontend/package-lock.json={}"
write frontend/package-lock.json '{"lockfileVersion": 3}'
run_step commit; expect_rc "npm in a working-directory: step succeeds" $? 0
expect_eq "npm in a working-directory: lock file pushed" "$(pushed_files)" "frontend/package-lock.json"

# A file name with a space and one with glob characters stay one path each.
reset odd-names "my app/package.json={}" "[x]/package.json={}" "x/package.json={}"
write "my app/package.json" '{"version": "1.0.1"}'
write "[x]/package.json" '{"version": "1.0.1"}'
run_step commit; expect_rc "odd file names: step succeeds" $? 0
expect_eq "odd file names: exactly these pushed" "$(pushed_files)" "$(lines "[x]/package.json" "my app/package.json")"

# === commit: selective staging =================================================

# Only manifests and lock files are committed. Source edits, build output and
# an unignored node_modules stay in the checkout.
reset selective "package.json={}" "package-lock.json={}" "src/index.js=// v1"
write package-lock.json '{"lockfileVersion": 3}'
write src/index.js "// v2"
write dist/bundle.js "built"
write node_modules/left-pad/package.json '{"name": "left-pad"}'
run_step commit; expect_rc "selective: step succeeds" $? 0
expect_eq "selective: only the lock file pushed" "$(pushed_files)" "package-lock.json"
expect_eq "selective: everything else left behind" "$(left_behind)" \
  "$(lines dist/bundle.js node_modules/left-pad/package.json src/index.js)"
if grep -q "src/index.js" "$FAKE/log"; then
  pass "selective: the log names what was left out"
else
  fail "selective: the log names what was left out" "src/index.js not in the log"
fi

# === commit: new files ========================================================
# A new file is staged only when it is a lock file next to the tracked manifest
# it belongs to. Unignored build and tool directories hold files named like a
# manifest or lock file, but no tracked manifest - nothing in them is pushed.

# go mod tidy creates go.sum next to a tracked go.mod.
reset new-go-sum "go.mod=module example.invalid/app"
write go.mod "module example.invalid/app

require golang.org/x/text v0.21.0"
write go.sum "golang.org/x/text v0.21.0 h1:placeholder="
run_step commit; expect_rc "new go.sum: step succeeds" $? 0
expect_eq "new go.sum: go.mod and the new go.sum pushed" "$(pushed_files)" "$(lines go.mod go.sum)"

# First lock files next to tracked manifests below the root.
reset new-locks "frontend/package.json={}" "src/App/App.csproj=<Project Sdk=\"Microsoft.NET.Sdk\" />"   "[x]/package.json={}"
write frontend/package-lock.json '{"lockfileVersion": 3}'
write src/App/packages.lock.json '{"version": 1}'
write "[x]/yarn.lock" "# yarn lockfile v1"
run_step commit; expect_rc "new lock files next to tracked manifests: step succeeds" $? 0
expect_eq "new lock files next to tracked manifests: pushed" "$(pushed_files)"   "$(lines "[x]/yarn.lock" frontend/package-lock.json src/App/packages.lock.json)"

# A build that leaves an unignored dist/ with its own package.json and lock file.
reset dist-untracked "package.json={}" "package-lock.json={}"
write package-lock.json '{"lockfileVersion": 3}'
write dist/package.json '{"name": "built"}'
write dist/package-lock.json '{"lockfileVersion": 3}'
write dist/lib/package.json '{"name": "lib"}'
run_step commit; expect_rc "unignored dist/: step succeeds" $? 0
expect_eq "unignored dist/: only the lock file at the root pushed" "$(pushed_files)" "package-lock.json"
expect_eq "unignored dist/: build output left behind" "$(left_behind)"   "$(lines dist/lib/package.json dist/package-lock.json dist/package.json)"

# A validation command that creates an unignored virtualenv or tox directory.
reset venv-untracked "requirements.txt=requests==2.31.0"
write requirements.txt "requests==2.32.3"
write .venv/lib/python3.13/site-packages/foo/static/package.json '{"name": "foo-assets"}'
write .venv/lib/python3.13/site-packages/foo/static/yarn.lock "# yarn lockfile v1"
write .venv/lib/python3.13/site-packages/bar/requirements.txt "six==1.16.0"
write .tox/py313/requirements-test.txt "pytest==8.3.4"
write .tox/py313/poetry.lock "# poetry"
run_step commit PYTHON_WORKDIR=. PYTHON_REQUIREMENTS=requirements.txt
expect_rc "unignored .venv/ and .tox/: step succeeds" $? 0
expect_eq "unignored .venv/ and .tox/: only requirements.txt pushed" "$(pushed_files)" "requirements.txt"
expect_eq "unignored .venv/ and .tox/: everything in them left behind" "$(left_behind)"   "$(lines .tox/py313/poetry.lock .tox/py313/requirements-test.txt     .venv/lib/python3.13/site-packages/bar/requirements.txt     .venv/lib/python3.13/site-packages/foo/static/package.json     .venv/lib/python3.13/site-packages/foo/static/yarn.lock)"

# New manifests are never staged, even between tracked files; a lock file is
# not staged when its manifest is only tracked in a subdirectory or in a
# directory whose name merely matches as a glob ([y] vs y), or when the
# directory holds tracked files but no manifest.
reset new-manifests "go.mod=module example.invalid/app" "src/index.js=// v1"   "tools/sub/go.mod=module example.invalid/tools" "y/package.json={}" "out/.gitkeep="
write src/package.json '{"name": "new"}'
write src/requirements.txt "flask==3.1.0"
write src/App.csproj '<Project Sdk="Microsoft.NET.Sdk" />'
write tools/go.sum "golang.org/x/text v0.21.0 h1:placeholder="
write "[y]/package-lock.json" '{"lockfileVersion": 3}'
write out/package-lock.json '{"lockfileVersion": 3}'
run_step commit; expect_rc "new manifests: step succeeds" $? 0
expect_eq "new manifests: not committed" "$(out committed)" "false"
expect_eq "new manifests: nothing staged" "$(out dependency-files)" "0"
expect_eq "new manifests: nothing pushed" "$(origin_count)" "1"
expect_eq "new manifests: all left behind" "$(left_behind)"   "$(lines "[y]/package-lock.json" out/package-lock.json src/App.csproj src/package.json     src/requirements.txt tools/go.sum)"

# A TRACKED file named like a manifest is committed wherever it is - e.g. the
# committed dist/ of a JavaScript Action that the validation build rewrote.
reset dist-tracked "package.json={}" "package-lock.json={}" "dist/package.json={}" "dist/index.js=// v1"
write package-lock.json '{"lockfileVersion": 3}'
write dist/package.json '{"type": "module"}'
write dist/index.js "// v2"
run_step commit; expect_rc "tracked dist/: step succeeds" $? 0
expect_eq "tracked dist/: manifest pushed with the lock file" "$(pushed_files)"   "$(lines dist/package.json package-lock.json)"
expect_eq "tracked dist/: count for the job summary" "$(out dependency-files)" "2"
expect_eq "tracked dist/: bundle left behind" "$(left_behind)" "dist/index.js"

# Changes, but none of them a dependency file: no commit, nothing pushed.
reset no-deps "package.json={}" "src/index.js=// v1"
write src/index.js "// v2"
run_step commit; expect_rc "no dependency changes: step succeeds" $? 0
expect_eq "no dependency changes: not committed" "$(out committed)" "false"
expect_eq "no dependency changes: job summary sees nothing staged" "$(out dependency-files)" "0"
expect_eq "no dependency changes: nothing pushed" "$(origin_count)" "1"
if grep -q "No dependency files to commit" "$FAKE/log"; then
  pass "no dependency changes: reported"
else
  fail "no dependency changes: reported" "message missing"
fi

# === commit: base images (unchanged behaviour) ================================

reset base-only "Dockerfile=FROM python:3-alpine"
run_step commit HAS_FILE_CHANGES=false BASE_IMAGES_UPDATED=true UPDATED_IMAGES_JSON='["python-alpine"]' \
  TRIGGER_WORKFLOW=docker-release.yml
expect_rc "base image only: step succeeds" $? 0
expect_eq "base image only: committed" "$(out committed)" "true"
expect_eq "base image only: empty commit" "$(pushed_files)" ""
expect_eq "base image only: subject" "$(origin_subject)" "fix(deps): update base image python-alpine [skip ci]"

reset base-and-deps "requirements.txt=requests==2.31.0"
write requirements.txt "requests==2.32.3"
run_step commit BASE_IMAGES_UPDATED=true UPDATED_IMAGES_JSON='["python-alpine"]' \
  PYTHON_WORKDIR=. PYTHON_REQUIREMENTS=requirements.txt TRIGGER_WORKFLOW=docker-release.yml
expect_rc "base image and dependencies: step succeeds" $? 0
expect_eq "base image and dependencies: one commit" "$(origin_count)" "2"
expect_eq "base image and dependencies: requirements pushed" "$(pushed_files)" "requirements.txt"
expect_eq "base image and dependencies: push CI kept (no [skip ci])" "$(origin_subject)" \
  "fix(deps): automated maintenance update"
if git -C "$FAKE/origin.git" log -1 --format=%b main | grep -q "Base image updates: python-alpine"; then
  pass "base image and dependencies: body names the image"
else
  fail "base image and dependencies: body names the image" "$(git -C "$FAKE/origin.git" log -1 --format=%b main)"
fi

echo ""
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
