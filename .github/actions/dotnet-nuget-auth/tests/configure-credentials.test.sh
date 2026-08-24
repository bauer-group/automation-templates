#!/usr/bin/env bash
#
# Behavioural test for the 'Configure Private Feed Credentials' step in ../action.yml.
#
# Guards the failure class reported in issue #77: a .NET workflow that cannot restore
# from an authenticated feed, where every way of getting it wrong ends in a bare HTTP
# 401 with nothing in the log pointing at the cause. NuGet discards a malformed
# NuGetPackageSourceCredentials_<source> value silently, and its lookup is
# case-SENSITIVE on Linux while being case-insensitive on Windows - so a mismatched
# source key passes on windows-latest and fails the day the job moves to ubuntu-latest.
#
# Every assertion below therefore pins a *loud* failure: the step must reject the bad
# input before `dotnet restore` runs, naming the input or secret at fault.
#
# The step body is extracted from action.yml at runtime rather than duplicated here:
# a copied-out script would keep passing after the real one regressed.
#
# `dotnet` is stubbed so the parser is exercised against realistic CLI output without
# needing a real feed. The stub also records `dotnet nuget add source` invocations so
# the auto-registration path can be asserted on.
#
# Usage: bash .github/actions/dotnet-nuget-auth/tests/configure-credentials.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTION_FILE="$SCRIPT_DIR/../action.yml"
STEP_ID="configure"

if [ ! -f "$ACTION_FILE" ]; then
  echo "FATAL: action.yml not found at $ACTION_FILE"
  exit 1
fi

# Extract the `run:` block of the step with id: $STEP_ID and strip its 8-space indent.
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

# A realistic `dotnet nuget list source` listing. Note "Syncfusion WinUI Nugets 24.1.41":
# source names may contain spaces, so the parser cannot treat the name as one token.
DEFAULT_SOURCES='Registered Sources:
  1.  nuget.org [Enabled]
      https://api.nuget.org/v3/index.json
  2.  GITHUB [Enabled]
      https://nuget.pkg.github.com/bauer-group/index.json
  3.  Syncfusion WinUI Nugets 24.1.41 [Enabled]
      C:\Program Files (x86)\Syncfusion\NuGetPackages'

# assert_auth <description> <expected-exit-code> <expectation>...
#
# Inputs are taken from T_* variables, which callers set as a command prefix:
#   T_SOURCE_NAME=GITHUB T_CREDENTIAL=tok assert_auth "..." 0 "env=..."
#
# Expectations:
#   env=NAME=VALUE  a line exactly equal to NAME=VALUE was written to $GITHUB_ENV
#   noenv=NAME      no line starting with NAME= was written to $GITHUB_ENV
#   out=key=value   the step output `key` has value `value`
#   log=substring   stdout/stderr contains substring
#   nolog=substring stdout/stderr does NOT contain substring
#   added=substring `dotnet nuget add source` was called with a matching argv
#   noadd=          `dotnet nuget add source` was not called at all
assert_auth() {
  local desc="$1" want_rc="$2"
  shift 2

  local source_name="${T_SOURCE_NAME-}"
  local credential="${T_CREDENTIAL-}"
  local username="${T_USERNAME-}"
  local source_url="${T_SOURCE_URL-}"
  local sources="${T_SOURCES-$DEFAULT_SOURCES}"
  local actor="${T_ACTOR-octocat}"

  local workdir env_file out_file log_file add_log bin_dir rc problems=()
  workdir=$(mktemp -d)
  env_file="$workdir/github_env"
  out_file="$workdir/github_output"
  log_file="$workdir/log"
  add_log="$workdir/add-source.log"
  bin_dir="$workdir/bin"
  : > "$env_file"
  : > "$out_file"
  : > "$add_log"
  mkdir -p "$bin_dir"

  # `dotnet` stub: answers `nuget list source`, records `nuget add source` and - as
  # the real CLI does - makes the newly added source visible to the next listing.
  # T_ADD_HAS_NO_EFFECT models a repository whose nuget.config contains <clear />,
  # which discards every inherited source so a user-level registration never shows up.
  {
    echo '#!/usr/bin/env bash'
    echo "if [ \"\${1-}\" = nuget ] && [ \"\${2-}\" = list ]; then"
    echo "  cat \"$workdir/sources.txt\""
    echo '  exit 0'
    echo 'fi'
    echo "if [ \"\${1-}\" = nuget ] && [ \"\${2-}\" = add ]; then"
    echo "  printf '%s\\n' \"\$*\" >> \"$add_log\""
    echo "  if [ ! -f \"$workdir/no-effect\" ]; then"
    echo '    name=""; while [ $# -gt 0 ]; do if [ "$1" = --name ]; then name="$2"; fi; shift; done'
    echo "    printf '  9.  %s [Enabled]\\n' \"\$name\" >> \"$workdir/sources.txt\""
    echo '  fi'
    echo '  exit 0'
    echo 'fi'
    echo 'exit 1'
  } > "$bin_dir/dotnet"
  [ -n "${T_ADD_HAS_NO_EFFECT-}" ] && : > "$workdir/no-effect"
  chmod +x "$bin_dir/dotnet"
  printf '%s\n' "$sources" > "$workdir/sources.txt"

  PATH="$bin_dir:$PATH" \
  NUGET_SOURCE_NAME="$source_name" \
  NUGET_CREDENTIAL="$credential" \
  NUGET_USERNAME="$username" \
  NUGET_SOURCE_URL="$source_url" \
  GITHUB_ACTOR="$actor" \
  GITHUB_ENV="$env_file" \
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
      env)
        if ! grep -qxF -- "$want" "$env_file"; then
          problems+=("expected \$GITHUB_ENV line '$want', got: $(tr '\n' '|' < "$env_file")")
        fi
        ;;
      noenv)
        if grep -q -- "^$want=" "$env_file"; then
          problems+=("expected NO \$GITHUB_ENV entry for '$want', got: $(tr '\n' '|' < "$env_file")")
        fi
        ;;
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
      added)
        grep -qF -- "$want" "$add_log" || problems+=("expected 'dotnet nuget add source' with '$want', got: $(tr '\n' '|' < "$add_log")")
        ;;
      noadd)
        [ -s "$add_log" ] && problems+=("'dotnet nuget add source' must not be called, got: $(tr '\n' '|' < "$add_log")")
        ;;
      *)
        problems+=("unknown expectation '$expectation'")
        ;;
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

# --- Opt-out: the action is a no-op for the overwhelming majority of callers -------
assert_auth "no source and no credential is a silent no-op" 0 \
  "out=configured=false" "noenv=NuGetPackageSourceCredentials_GITHUB" "noadd="

# --- The happy path ---------------------------------------------------------------
T_SOURCE_NAME=GITHUB T_CREDENTIAL=ghp_secrettoken \
assert_auth "credentials are bound to the configured source" 0 \
  "env=NuGetPackageSourceCredentials_GITHUB=Username=octocat;Password=ghp_secrettoken" \
  "out=configured=true" "out=credential-env-var=NuGetPackageSourceCredentials_GITHUB" "noadd="

T_SOURCE_NAME=GITHUB T_CREDENTIAL=ghp_secrettoken T_USERNAME=svc-build \
assert_auth "an explicit username overrides the actor" 0 \
  "env=NuGetPackageSourceCredentials_GITHUB=Username=svc-build;Password=ghp_secrettoken"

T_SOURCE_NAME=GITHUB T_CREDENTIAL=ghp_secrettoken \
assert_auth "the credential is masked in case it did not come from a secret" 0 \
  "log=::add-mask::ghp_secrettoken"

T_SOURCE_NAME="Syncfusion WinUI Nugets 24.1.41" T_CREDENTIAL=tok \
assert_auth "a source name containing spaces is matched, not split" 0 \
  "env=NuGetPackageSourceCredentials_Syncfusion WinUI Nugets 24.1.41=Username=octocat;Password=tok"

# The listing arrives with CRLF line endings on Windows runners. A parser that keeps
# the \r matches nothing and reports every source as unknown.
T_SOURCE_NAME=GITHUB T_CREDENTIAL=tok \
T_SOURCES=$'Registered Sources:\r\n  1.  nuget.org [Enabled]\r\n      https://api.nuget.org/v3/index.json\r\n  2.  GITHUB [Enabled]\r\n      https://nuget.pkg.github.com/bauer-group/index.json\r' \
assert_auth "a CRLF listing from a Windows runner still matches" 0 \
  "env=NuGetPackageSourceCredentials_GITHUB=Username=octocat;Password=tok"

T_SOURCE_NAME=GITHUB T_CREDENTIAL=$'  ghp_secrettoken\n' \
assert_auth "surrounding whitespace on a pasted secret is trimmed" 0 \
  "env=NuGetPackageSourceCredentials_GITHUB=Username=octocat;Password=ghp_secrettoken"

# --- Loud failures: each of these used to surface as a bare 401 -------------------
T_SOURCE_NAME=GITHUB \
assert_auth "a source without a credential names the secret to set" 1 \
  "log=DOTNET_NUGET_RESTORE_CREDENTIALS" "log=NuGetPackageSourceCredentials_GITHUB" \
  "noenv=NuGetPackageSourceCredentials_GITHUB"

T_CREDENTIAL=ghp_secrettoken \
assert_auth "a credential without a source names the input to set" 1 \
  "log=nuget-source-name" "nolog=ghp_secrettoken"

# The central trap from issue #77: case-insensitive on Windows, case-SENSITIVE on Linux.
T_SOURCE_NAME=github T_CREDENTIAL=tok \
assert_auth "a case-mismatched source key fails with both spellings" 1 \
  "log=github" "log=GITHUB" "log=case-sensitive" "noenv=NuGetPackageSourceCredentials_github" "noadd="

T_SOURCE_NAME=CONTOSO T_CREDENTIAL=tok \
assert_auth "an unknown source lists the sources that do exist" 1 \
  "log=CONTOSO" "log=nuget.org" "log=GITHUB" "log=nuget-source-url" "noadd="

# NuGet splits the value on ';', so a password containing one is silently truncated
# and the restore fails with a 401 that blames the token.
T_SOURCE_NAME=GITHUB T_CREDENTIAL='tok;en' \
assert_auth "a semicolon in the credential fails instead of truncating" 1 \
  "log=semicolon" "noenv=NuGetPackageSourceCredentials_GITHUB"

T_SOURCE_NAME=GITHUB T_CREDENTIAL=tok T_USERNAME='bad;user' \
assert_auth "a semicolon in the username fails instead of truncating" 1 \
  "noenv=NuGetPackageSourceCredentials_GITHUB"

# --- Auto-registration for repositories that ship no nuget.config ------------------
T_SOURCE_NAME=CONTOSO T_CREDENTIAL=tok T_SOURCE_URL=https://nuget.contoso.com/v3/index.json \
assert_auth "an unknown source with a url is registered, then bound" 0 \
  "added=CONTOSO" "added=https://nuget.contoso.com/v3/index.json" \
  "env=NuGetPackageSourceCredentials_CONTOSO=Username=octocat;Password=tok"

T_SOURCE_NAME=GITHUB T_CREDENTIAL=tok T_SOURCE_URL=https://nuget.pkg.github.com/bauer-group/index.json \
assert_auth "an already-configured source is never re-registered" 0 \
  "noadd=" "env=NuGetPackageSourceCredentials_GITHUB=Username=octocat;Password=tok"

# A <clear /> in the repository's <packageSources> discards inherited sources, so a
# user-level registration silently has no effect and the restore 401s anyway.
T_SOURCE_NAME=CONTOSO T_CREDENTIAL=tok T_SOURCE_URL=https://nuget.contoso.com/v3/index.json \
T_ADD_HAS_NO_EFFECT=1 \
assert_auth "a registration that <clear /> discards fails loudly" 1 \
  "log=clear" "log=CONTOSO" "noenv=NuGetPackageSourceCredentials_CONTOSO"

# `dotnet nuget add source` must not receive the credential: it would persist it to
# the user-level nuget.config on the runner, which is exactly what issue #77 asks to
# avoid ("no credential ever reaches a file").
T_SOURCE_NAME=CONTOSO T_CREDENTIAL=ghp_secrettoken T_SOURCE_URL=https://nuget.contoso.com/v3/index.json \
assert_auth "registration never writes the credential to disk" 0 \
  "added=CONTOSO"

# The negative half of the assertion above needs its own check, since `added=` only
# proves presence. Re-run and grep the recorded argv for the secret.
_check_no_secret_persisted() {
  local workdir bin_dir add_log
  workdir=$(mktemp -d); bin_dir="$workdir/bin"; add_log="$workdir/add-source.log"
  mkdir -p "$bin_dir"; : > "$add_log"
  {
    echo '#!/usr/bin/env bash'
    echo "if [ \"\${1-}\" = nuget ] && [ \"\${2-}\" = list ]; then echo 'Registered Sources:'; echo '  1.  nuget.org [Enabled]'; exit 0; fi"
    echo "if [ \"\${1-}\" = nuget ] && [ \"\${2-}\" = add ]; then printf '%s\\n' \"\$*\" >> \"$add_log\"; exit 0; fi"
    echo 'exit 1'
  } > "$bin_dir/dotnet"
  chmod +x "$bin_dir/dotnet"

  PATH="$bin_dir:$PATH" NUGET_SOURCE_NAME=CONTOSO NUGET_CREDENTIAL=ghp_secrettoken \
  NUGET_USERNAME="" NUGET_SOURCE_URL=https://nuget.contoso.com/v3/index.json \
  GITHUB_ACTOR=octocat GITHUB_ENV="$workdir/env" GITHUB_OUTPUT="$workdir/out" \
    bash -eo pipefail -c "$STEP_BODY" > "$workdir/log" 2>&1

  if grep -q 'ghp_secrettoken' "$add_log"; then
    FAILED=$((FAILED + 1))
    printf 'FAIL %s\n' "the credential is never passed to 'dotnet nuget add source'"
    printf '       recorded argv: %s\n' "$(cat "$add_log")"
  else
    PASSED=$((PASSED + 1))
    printf 'ok   %s\n' "the credential is never passed to 'dotnet nuget add source'"
  fi
  rm -rf "$workdir"
}
_check_no_secret_persisted

echo
echo "$PASSED passed, $FAILED failed"
[ "$FAILED" -eq 0 ]
