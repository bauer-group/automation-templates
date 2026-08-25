#!/usr/bin/env bash
#
# Behavioural test for the 'Resolve MSI Version' step in ../action.yml.
#
# An MSI ProductVersion is not a semantic version. Windows Installer requires
# major.minor.build with major/minor <= 255 and build <= 65535, rejects any
# prerelease suffix, and IGNORES the fourth field when deciding whether one package
# upgrades another. A version straight out of semantic-release ("1.2.3-rc.1") is
# therefore not a legal ProductVersion, and a CalVer like "20260825.1.0" overflows
# the major field.
#
# Both are caught here rather than in a WiX error that names neither the input nor
# the reason. The prerelease case is deliberately NOT a hard failure - it is a
# warning plus a stripped ProductVersion - because prerelease MSIs are a normal
# thing to build; what matters is that the log says the two builds are
# indistinguishable to Windows Installer rather than leaving that to be discovered
# during a rollout.
#
# The step body is extracted from action.yml at runtime rather than duplicated here:
# a copied-out script would keep passing after the real one regressed.
#
# Usage: bash .github/actions/dotnet-msi/tests/resolve-msi-version.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION_FILE="$SCRIPT_DIR/../action.yml"
STEP_ID="resolve-version"

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

# assert_version <description> <input-version> <expected-exit-code> <expectation>...
#   out=key=value   step output `key` equals `value`
#   log=substring   stdout/stderr contains substring
assert_version() {
  local desc="$1" input="$2" want_rc="$3"
  shift 3

  local workdir out_file log_file rc problems=()
  workdir=$(mktemp -d)
  out_file="$workdir/github_output"
  log_file="$workdir/log"
  : > "$out_file"

  MSI_VERSION="$input" \
  GITHUB_OUTPUT="$out_file" \
    bash -eo pipefail -c "$STEP_BODY" > "$log_file" 2>&1
  rc=$?

  if [ "$rc" -ne "$want_rc" ]; then
    problems+=("expected exit $want_rc, got $rc: $(tr '\n' ' ' < "$log_file")")
  fi

  local expectation key want got
  for expectation in "$@"; do
    key="${expectation%%=*}"
    want="${expectation#*=}"
    case "$key" in
      out)
        got=$(grep -m1 -- "^${want%%=*}=" "$out_file" | cut -d= -f2-)
        if [ "$got" != "${want#*=}" ]; then
          problems+=("output ${want%%=*}: expected '${want#*=}', got '$got'")
        fi
        ;;
      log)
        grep -qF -- "$want" "$log_file" || problems+=("expected log containing '$want'")
        ;;
      nolog)
        grep -qF -- "$want" "$log_file" && problems+=("log must NOT contain '$want'")
        ;;
      *) problems+=("unknown expectation '$expectation'") ;;
    esac
  done

  rm -rf "$workdir"

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

# --- Versions that are already legal ---------------------------------------------
assert_version "a three-part version passes through unchanged" "1.2.3" 0 \
  "out=product-version=1.2.3" "out=file-version=1.2.3"

assert_version "a leading v is stripped" "v1.2.3" 0 \
  "out=product-version=1.2.3" "out=file-version=1.2.3"

assert_version "a two-part version is padded to three" "1.2" 0 \
  "out=product-version=1.2.0" "out=file-version=1.2"

assert_version "a bare major is padded to three" "7" 0 \
  "out=product-version=7.0.0"

# Windows Installer ignores the fourth field, but WiX accepts it, so it is kept.
assert_version "a four-part version keeps its fourth field" "1.2.3.4" 0 \
  "out=product-version=1.2.3.4" "out=file-version=1.2.3.4"

# The boundary values are legal and must not be rejected by an off-by-one.
assert_version "the maximum legal version is accepted" "255.255.65535" 0 \
  "out=product-version=255.255.65535"

# --- Prerelease and build metadata ------------------------------------------------
assert_version "a prerelease is stripped from ProductVersion but kept in the file name" "1.2.3-rc.1" 0 \
  "out=product-version=1.2.3" "out=file-version=1.2.3-rc.1" \
  "log=indistinguishable"

assert_version "build metadata is stripped from ProductVersion" "1.2.3+build.5" 0 \
  "out=product-version=1.2.3" "out=file-version=1.2.3+build.5" \
  "log=indistinguishable"

assert_version "a prerelease on a four-part version keeps all four fields" "1.2.3.4-rc.1" 0 \
  "out=product-version=1.2.3.4" "out=file-version=1.2.3.4-rc.1"

# A release build must not be told its version is ambiguous.
assert_version "a release version produces no ambiguity warning" "1.2.3" 0 \
  "nolog=indistinguishable"

# --- Loud failures ----------------------------------------------------------------
assert_version "an empty version names the input" "" 1 \
  "log=version"

assert_version "a non-numeric version is rejected" "not-a-version" 1 \
  "log=not-a-version"

# CalVer overflows the major field - the exact mistake this guard exists for.
assert_version "a major over 255 is rejected, naming the limit" "20260825.1.0" 1 \
  "log=255"

assert_version "a minor over 255 is rejected, naming the limit" "1.256.0" 1 \
  "log=255"

assert_version "a build over 65535 is rejected, naming the limit" "1.2.70000" 1 \
  "log=65535"

assert_version "more than four fields is rejected" "1.2.3.4.5" 1 \
  "log=1.2.3.4.5"

echo
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
