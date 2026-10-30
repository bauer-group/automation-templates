#!/usr/bin/env bash
#
# Regression test for ../install-tool.sh and its wiring (issue #101).
#
# A release in OT-CAN2IP went red on "curl: (35) Recv failure: Connection reset by
# peer" while installing Syft - after the image had already been pushed, so what was
# lost was the SBOM. Trivy, Grype and Syft were all installed with an unretried
# `curl ... | sh`, and the vendor installer then downloads the release tarball with
# no retry of its own. This pins:
#
#   - a reset on the script download is retried, and so is a failure of the
#     installer itself (the second hop the first fix idea would have missed);
#   - a persistent failure gives up after a bounded number of attempts with an
#     error naming the tool, and never runs a script whose download failed;
#   - installer arguments arrive unchanged, the backoff grows and is not slept
#     after the last attempt;
#   - every scanner install in docker-build and fork-docker-build goes through a
#     retry, and no raw `curl | sh` is left.
#
# `curl` and `sleep` are stubbed on PATH: nothing is downloaded, nothing is waited.
#
# Usage: bash .github/actions/docker-build/tests/install-tool.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER="$SCRIPT_DIR/../install-tool.sh"
ACTION_FILE="$SCRIPT_DIR/../action.yml"
FORK_WORKFLOW="$SCRIPT_DIR/../../../workflows/fork-docker-build.yml"

for f in "$HELPER" "$ACTION_FILE" "$FORK_WORKFLOW"; do
  if [ ! -f "$f" ]; then
    echo "FATAL: $(basename "$f") not found at $f"
    exit 1
  fi
done

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# --- Stubs ------------------------------------------------------------------------
#
# curl: fails with exit 35 for the first $CURL_FAILS calls, otherwise writes an
# installer to the -o target. The installer fails for its first $INSTALLER_FAILS
# runs and records its arguments.
mkdir -p "$WORK/bin"
cat > "$WORK/bin/curl" <<'EOF'
#!/usr/bin/env bash
n=$(( $(cat "$STATE/curl-count" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$STATE/curl-count"
out=""
while [ "$#" -gt 0 ]; do
  [ "$1" = "-o" ] && { out="$2"; shift; }
  shift
done
if [ "$n" -le "${CURL_FAILS:-0}" ]; then
  echo "curl: (35) Recv failure: Connection reset by peer" >&2
  exit 35
fi
cat > "$out" <<'INSTALLER'
n=$(( $(cat "$STATE/installer-count" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$STATE/installer-count"
echo "$*" >> "$STATE/installer-args"
if [ "$n" -le "${INSTALLER_FAILS:-0}" ]; then
  echo "installer: release tarball download failed" >&2
  exit 1
fi
exit 0
INSTALLER
EOF
cat > "$WORK/bin/sleep" <<'EOF'
#!/usr/bin/env bash
echo "$1" >> "$STATE/sleeps"
EOF
chmod +x "$WORK/bin/curl" "$WORK/bin/sleep"

FAILED=0
pass() { echo "  ok   $1"; }
fail() { echo "  FAIL $1"; FAILED=$((FAILED + 1)); }
check() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (expected '$3', got '$2')"; fi; }

# run_case <curl-fails> <installer-fails>: runs the helper for "Syft" with fresh state.
run_case() {
  export STATE="$WORK/state-$RANDOM$RANDOM"
  mkdir -p "$STATE"
  CURL_FAILS="$1" INSTALLER_FAILS="$2" PATH="$WORK/bin:$PATH" \
    bash "$HELPER" Syft https://example.invalid/install.sh -b /usr/local/bin > "$STATE/out" 2>&1
  EXIT=$?
  CURLS=$(cat "$STATE/curl-count" 2>/dev/null || echo 0)
  INSTALLS=$(cat "$STATE/installer-count" 2>/dev/null || echo 0)
  SLEEPS=$(cat "$STATE/sleeps" 2>/dev/null | tr '\n' ' ' | sed 's/ $//')
  WARNINGS=$(grep -c '^::warning::' "$STATE/out")
}

echo "install-tool.sh"

echo "- clean install"
run_case 0 0
check "exits 0" "$EXIT" 0
check "one download" "$CURLS" 1
check "one installer run" "$INSTALLS" 1
check "no warning" "$WARNINGS" 0
check "installer args forwarded unchanged" "$(cat "$STATE/installer-args")" "-b /usr/local/bin"

echo "- connection reset on the script download, twice"
run_case 2 0
check "recovers and exits 0" "$EXIT" 0
check "three downloads" "$CURLS" 3
check "installer ran once, after the good download" "$INSTALLS" 1
check "one warning per failed attempt" "$WARNINGS" 2
check "backoff grows: 10 s, then 20 s" "$SLEEPS" "10 20"

echo "- the installer's own download fails once (second hop)"
run_case 0 1
check "recovers and exits 0" "$EXIT" 0
check "installer ran twice" "$INSTALLS" 2

echo "- persistent failure"
run_case 99 0
check "exits 1" "$EXIT" 1
check "gives up after three attempts" "$CURLS" 3
check "never runs a script whose download failed" "$INSTALLS" 0
check "no sleep after the last attempt" "$SLEEPS" "10 20"
if grep -q '^::error::Installing Syft failed after 3 attempts' "$STATE/out"; then
  pass "error names the tool and the attempts"
else
  fail "error names the tool and the attempts"
fi

echo "- usage"
PATH="$WORK/bin:$PATH" bash "$HELPER" Syft > /dev/null 2>&1
check "missing URL is a usage error" "$?" 2

echo "wiring"

if grep -nE 'install\.sh *\| *(sudo +)?sh' "$ACTION_FILE" "$FORK_WORKFLOW"; then
  fail "no unretried 'curl | sh' install left in docker-build or fork-docker-build"
else
  pass "no unretried 'curl | sh' install left in docker-build or fork-docker-build"
fi

for tool in Trivy Grype Syft; do
  if grep -qE "bash \"\\\$GITHUB_ACTION_PATH/install-tool.sh\" $tool( |\\\\|\$)" "$ACTION_FILE"; then
    pass "docker-build installs $tool through install-tool.sh"
  else
    fail "docker-build installs $tool through install-tool.sh"
  fi
done

# The security step fails closed: an install that gave up must not leave
# scan-passed unset, because downstream reads an unset output as an empty string.
if [ "$(grep -A2 'install-tool.sh" \(Trivy\|Grype\)' "$ACTION_FILE" | grep -c 'scan-passed=false')" -eq 2 ]; then
  pass "a failed scanner install sets scan-passed=false"
else
  fail "a failed scanner install sets scan-passed=false"
fi

if grep -q 'for attempt in 1 2 3; do' "$FORK_WORKFLOW" \
   && grep -q 'Installing Trivy failed after 3 attempts' "$FORK_WORKFLOW"; then
  pass "fork-docker-build retries the Trivy install and stops on failure"
else
  fail "fork-docker-build retries the Trivy install and stops on failure"
fi

echo
if [ "$FAILED" -gt 0 ]; then
  echo "$FAILED check(s) failed"
  exit 1
fi
echo "all checks passed"
