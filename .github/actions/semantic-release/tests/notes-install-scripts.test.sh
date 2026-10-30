#!/usr/bin/env bash
#
# Pins the notes toolchain install to --ignore-scripts (issue #109).
#
# The release job holds the caller's write token, and an npm install script runs
# as the same user with that token in reach. The notes toolchain is installed from
# a lockfile owned by this action, so its install scripts can be switched off -
# which is safe exactly as long as no locked package needs one. Both halves are
# checked: the flag, and the lockfile. A future dependency that needs an install
# script fails here, where it gets a decision, instead of silently half-installing
# and breaking every repository's changelog on its next release.
#
# Usage: bash .github/actions/semantic-release/tests/notes-install-scripts.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION_FILE="$SCRIPT_DIR/../action.yml"
LOCKFILE="$SCRIPT_DIR/../notes/package-lock.json"

for f in "$ACTION_FILE" "$LOCKFILE"; do
  if [ ! -f "$f" ]; then
    echo "FATAL: $f not found"
    exit 1
  fi
done

FAILED=0
pass() { echo "  ok   $1"; }
fail() { echo "  FAIL $1"; FAILED=$((FAILED + 1)); }

INSTALLS=$(grep -nE '^\s*npm (ci|install)\b' "$ACTION_FILE")
if [ -z "$INSTALLS" ]; then
  echo "FATAL: no npm install found in action.yml - the install moved; update this test."
  exit 1
fi

if printf '%s\n' "$INSTALLS" | grep -v -- '--ignore-scripts' | grep -q .; then
  fail "every npm install in action.yml runs with --ignore-scripts"
  printf '%s\n' "$INSTALLS" | grep -v -- '--ignore-scripts' | sed 's/^/       /'
else
  pass "every npm install in action.yml runs with --ignore-scripts"
fi

# Parsed, not grepped: npm writes the flag below dependencies/engines blocks of any
# length, so a fixed line window around it would miss the package name.
NEEDS_SCRIPTS=$(node -e '
  const lock = JSON.parse(require("fs").readFileSync(process.argv[1], "utf8"));
  for (const [path, pkg] of Object.entries(lock.packages || {}))
    if (pkg.hasInstallScript) console.log(path || "(this package itself)");
' "$LOCKFILE")
if [ "$?" -ne 0 ]; then
  echo "FATAL: could not parse $LOCKFILE"
  exit 1
fi
if [ -n "$NEEDS_SCRIPTS" ]; then
  fail "no package in notes/package-lock.json needs an install script"
  printf '%s\n' "$NEEDS_SCRIPTS" | sed 's/^/       /'
  echo "       --ignore-scripts would skip it. Decide whether the toolchain needs the package at all"
  echo "       before relaxing the flag: the release job holds a write token."
else
  pass "no package in notes/package-lock.json needs an install script"
fi

echo
if [ "$FAILED" -gt 0 ]; then
  echo "$FAILED check(s) failed"
  exit 1
fi
echo "all checks passed"
