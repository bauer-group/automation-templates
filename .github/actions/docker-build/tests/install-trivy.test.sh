#!/usr/bin/env bash
#
# Regression test for ../install-trivy.sh (issue #136).
#
# get.trivy.dev stopped resolving on 2026-11-03. Trivy's contrib/install.sh takes
# the tarball from that host, so every image scan in docker-build failed and
# releases were tagged without an image. install-trivy.sh takes tarball and
# checksums from the GitHub release instead. This pins:
#
#   - only github.com release URLs are requested, get.trivy.dev never;
#   - "latest" is resolved from the /releases/latest redirect, an explicit
#     version skips that lookup;
#   - the tarball is installed only when its digest matches the checksums file,
#     and a mismatch is neither installed nor retried;
#   - a transient download failure is retried, a persistent one gives up after a
#     bounded number of attempts with an error naming Trivy.
#
# `curl`, `uname` and `sleep` are stubbed on PATH: nothing is downloaded, nothing
# is waited. The tarball is a real one, holding a stand-in `trivy`.
#
# Usage: bash .github/actions/docker-build/tests/install-trivy.test.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER="$SCRIPT_DIR/../install-trivy.sh"
[ -f "$HELPER" ] || { echo "FATAL: install-trivy.sh not found at $HELPER"; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# --- Fixture: trivy_9.9.9_Linux-64bit.tar.gz with a stand-in binary -------------
mkdir -p "$WORK/fixture" "$WORK/bin"
printf '#!/bin/sh\necho "Version: 9.9.9"\n' > "$WORK/fixture/trivy"
chmod +x "$WORK/fixture/trivy"
tar -czf "$WORK/trivy_9.9.9_Linux-64bit.tar.gz" -C "$WORK/fixture" trivy
if command -v sha256sum >/dev/null 2>&1; then
  GOOD_SUM="$(sha256sum "$WORK/trivy_9.9.9_Linux-64bit.tar.gz" | awk '{print $1}')"
else
  GOOD_SUM="$(shasum -a 256 "$WORK/trivy_9.9.9_Linux-64bit.tar.gz" | awk '{print $1}')"
fi
export FIXTURE="$WORK/trivy_9.9.9_Linux-64bit.tar.gz" GOOD_SUM

# --- Stubs ------------------------------------------------------------------------
cat > "$WORK/bin/curl" <<'EOF'
#!/usr/bin/env bash
out="" fmt="" url=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -o) out="$2"; shift ;;
    -w) fmt="$2"; shift ;;
    --connect-timeout | --max-time) shift ;;
    -*) ;;
    *) url="$1" ;;
  esac
  shift
done
echo "$url" >> "$STATE/urls"
case "$url" in
  */releases/latest)
    printf '%s' "https://github.com/aquasecurity/trivy/releases/tag/v9.9.9"
    ;;
  *.tar.gz)
    n=$(( $(cat "$STATE/tgz-count" 2>/dev/null || echo 0) + 1 )); echo "$n" > "$STATE/tgz-count"
    if [ "$n" -le "${TGZ_FAILS:-0}" ]; then
      echo "curl: (35) Recv failure: Connection reset by peer" >&2
      exit 35
    fi
    cp "$FIXTURE" "$out"
    ;;
  *_checksums.txt)
    if [ "${BAD_SUM:-0}" = 1 ]; then sum=0000000000000000000000000000000000000000000000000000000000000000; else sum="$GOOD_SUM"; fi
    printf '%s  trivy_9.9.9_Linux-ARM64.tar.gz\n%s  trivy_9.9.9_Linux-64bit.tar.gz\n' "1111111111111111111111111111111111111111111111111111111111111111" "$sum" > "$out"
    ;;
  *)
    echo "curl: (6) Could not resolve host" >&2
    exit 6
    ;;
esac
[ -n "$fmt" ] || true
EOF
cat > "$WORK/bin/uname" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in -m) echo x86_64 ;; *) echo Linux ;; esac
EOF
cat > "$WORK/bin/sleep" <<'EOF'
#!/usr/bin/env bash
echo "$1" >> "$STATE/sleeps"
EOF
chmod +x "$WORK/bin/curl" "$WORK/bin/uname" "$WORK/bin/sleep"

FAILED=0
pass() { echo "  ok   $1"; }
fail() { echo "  FAIL $1"; FAILED=$((FAILED + 1)); }
check() { if [ "$2" = "$3" ]; then pass "$1"; else fail "$1 (expected '$3', got '$2')"; fi; }

# run_case <version> : fresh state and bindir, env passed through by the caller.
run_case() {
  export STATE="$WORK/state.$RANDOM"
  mkdir -p "$STATE" "$STATE/bindir"
  PATH="$WORK/bin:$PATH" INSTALL_BACKOFF=1 bash "$HELPER" "$STATE/bindir" "$1" > "$STATE/out" 2>&1
  RC=$?
  URLS="$(cat "$STATE/urls" 2>/dev/null)"
  WARNINGS=$(grep -c '^::warning::' "$STATE/out")
  INSTALLED=$([ -x "$STATE/bindir/trivy" ] && echo yes || echo no)
}

echo "- latest release, clean download"
run_case ""
check "exit code" "$RC" 0
check "trivy installed and executable" "$INSTALLED" yes
check "latest resolved from the redirect" "$(grep -c '/releases/latest$' <<<"$URLS")" 1
check "tarball from the GitHub release" "$(grep -c '^https://github.com/aquasecurity/trivy/releases/download/v9.9.9/trivy_9.9.9_Linux-64bit.tar.gz$' <<<"$URLS")" 1
check "get.trivy.dev never contacted" "$(grep -c 'trivy.dev' <<<"$URLS")" 0

echo "- explicit version"
run_case "0.76.2"
check "no latest lookup" "$(grep -c '/releases/latest' <<<"$URLS")" 0
check "version normalised to a v-tag" "$(grep -c '/download/v0.76.2/trivy_0.76.2_Linux-64bit.tar.gz$' <<<"$URLS")" 1

echo "- checksum mismatch"
BAD_SUM=1 run_case ""
check "exit code" "$RC" 1
check "nothing installed" "$INSTALLED" no
check "not retried" "$(cat "$STATE/tgz-count")" 1
if grep -q '^::error::Checksum mismatch for trivy_9.9.9_Linux-64bit.tar.gz' "$STATE/out"; then
  pass "error names the tarball"
else
  fail "error names the tarball"
fi

echo "- transient tarball failure"
TGZ_FAILS=1 run_case ""
check "exit code" "$RC" 0
check "installed on the second attempt" "$INSTALLED" yes
check "one warning" "$WARNINGS" 1

echo "- persistent failure"
TGZ_FAILS=99 run_case ""
check "exit code" "$RC" 1
check "bounded attempts" "$(cat "$STATE/tgz-count")" 3
check "no sleep after the last attempt" "$(wc -l < "$STATE/sleeps" | tr -d ' ')" 2
if grep -q '^::error::Installing Trivy failed after 3 attempts' "$STATE/out"; then
  pass "error names Trivy and the attempts"
else
  fail "error names Trivy and the attempts"
fi

echo
if [ "$FAILED" -gt 0 ]; then
  echo "$FAILED check(s) failed"
  exit 1
fi
echo "all checks passed"
