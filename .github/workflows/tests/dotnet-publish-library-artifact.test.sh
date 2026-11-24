#!/usr/bin/env bash
#
# Regression test for the per-call artifact name of ../dotnet-publish-library.yml.
#
# Callers run this workflow twice in one run: a validation pack with a version
# suffix ("pr") and the release pack. Both uploaded an artifact named
# "nuget-packages", and download-artifact takes the one with the highest artifact
# ID, which is not always the one of the same call. LIB-Shared-NET release 4.0.3
# pushed the validation package 4.0.2-pr.310 that way. This pins:
#
#   - the name is derived from every version input that is set, so a validation
#     call and a release call never share it, and it only holds characters an
#     artifact name allows;
#   - the build passes that suffix to the dotnet-nuget action (which appends it
#     to "nuget-packages"), and both publish jobs download exactly that name.
#
# The step body is extracted from the workflow at runtime and run the way a
# `shell: bash` step runs.
#
# Usage: bash .github/workflows/tests/dotnet-publish-library-artifact.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW="$SCRIPT_DIR/../dotnet-publish-library.yml"
[ -f "$WORKFLOW" ] || { echo "FATAL: workflow not found at $WORKFLOW"; exit 1; }

FAILED=0
check() {
  if [ "$2" = "$3" ]; then echo "  ok   $1"; else echo "  FAIL $1 (expected '$3', got '$2')"; FAILED=$((FAILED + 1)); fi
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

awk '
  $0 == "        id: artifact" { found = 1; next }
  found && /^        run: \|$/ { collecting = 1; next }
  collecting {
    if ($0 == "") { print ""; next }
    if ($0 ~ /^          /) { sub(/^          /, ""); print; next }
    exit
  }
' "$WORKFLOW" > "$WORK/artifact.sh"
if [ ! -s "$WORK/artifact.sh" ]; then
  echo "FATAL: could not extract the 'artifact' run block from the workflow."
  exit 1
fi

# suffix <release-version> <package-version> <version-suffix>
suffix() {
  export GITHUB_OUTPUT="$WORK/output" RELEASE_VERSION="$1" PACKAGE_VERSION="$2" VERSION_SUFFIX="$3"
  : > "$GITHUB_OUTPUT"
  bash -e "$WORK/artifact.sh" > /dev/null 2>&1 || { echo "<step failed>"; return; }
  sed -n 's/^suffix=//p' "$GITHUB_OUTPUT"
}

echo "artifact name"
check "release call (LIB-Shared-NET publish)" "$(suffix 4.0.3 "" "")" "-4.0.3"
check "validation call (version-suffix pr)" "$(suffix "" "" pr)" "-pr"
check "validation call (package-version 0.0.0-pr.12)" "$(suffix "" 0.0.0-pr.12 "")" "-0.0.0-pr.12"
check "release-version plus suffix differs from the release alone" "$(suffix 1.2.3 "" beta)" "-1.2.3-beta"
check "no version input at all" "$(suffix "" "" "")" "-build"
check "characters an artifact name does not allow are replaced" "$(suffix '1.2.3+sha/abc:1' "" "")" "-1.2.3-sha-abc-1"

echo "wiring"
WIRED=$(grep -cxF '          artifact-suffix: ${{ steps.artifact.outputs.suffix }}' "$WORKFLOW")
check "the build passes the suffix to dotnet-nuget" "$WIRED" 1
OUTPUT=$(grep -cxF '      artifact-suffix: ${{ steps.artifact.outputs.suffix }}' "$WORKFLOW")
check "the build job exposes the suffix" "$OUTPUT" 1
DOWNLOADS=$(grep -cxF '          name: nuget-packages${{ needs.build.outputs.artifact-suffix }}' "$WORKFLOW")
check "both publish jobs download this call's artifact" "$DOWNLOADS" 2
check "no download of the bare 'nuget-packages' name is left" "$(grep -cxF '          name: nuget-packages' "$WORKFLOW")" 0

echo
if [ "$FAILED" -gt 0 ]; then
  echo "$FAILED check(s) failed"
  exit 1
fi
echo "all checks passed"
