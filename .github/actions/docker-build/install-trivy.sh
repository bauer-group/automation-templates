#!/usr/bin/env bash
#
# Installs Trivy from its GitHub release and verifies the tarball against the
# checksums file of the same release.
#
# Trivy's own contrib/install.sh fetches the tarball from get.trivy.dev and only
# the checksums from GitHub. When that host stopped resolving on 2026-11-03, every
# image scan in docker-build and fork-docker-build failed and releases were tagged
# without an image (issue #136). The GitHub release carries the identical file -
# it is what install.sh verifies against - so going there directly removes the
# extra host without weakening the check.
#
# The whole install is retried, as in install-tool.sh (issue #101). A checksum
# mismatch is not retried: a complete download with the wrong digest is not a
# network hiccup.
#
# Usage: install-trivy.sh <bindir> [version]
#   version: vX.Y.Z or X.Y.Z; empty = the latest release
# Env:   INSTALL_ATTEMPTS (default 3)
#        INSTALL_BACKOFF  (seconds, default 10; attempt n waits n * INSTALL_BACKOFF)

set -uo pipefail

BINDIR="${1:-}"
VERSION="${2:-}"
ATTEMPTS="${INSTALL_ATTEMPTS:-3}"
BACKOFF="${INSTALL_BACKOFF:-10}"
RELEASES="https://github.com/aquasecurity/trivy/releases"

if [ -z "$BINDIR" ]; then
  echo "::error::usage: install-trivy.sh <bindir> [version]"
  exit 2
fi

case "$(uname -s)" in
  Linux) OS=Linux ;;
  Darwin) OS=macOS ;;
  *) echo "::error::Installing Trivy: no release asset for OS $(uname -s)"; exit 1 ;;
esac
case "$(uname -m)" in
  x86_64 | amd64) ARCH=64bit ;;
  aarch64 | arm64) ARCH=ARM64 ;;
  *) echo "::error::Installing Trivy: no release asset for architecture $(uname -m)"; exit 1 ;;
esac

sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Returns 0 on success, 1 for a retryable failure, 3 for a checksum mismatch.
install_once() {
  local tag="$VERSION" url version tarball checksums want got
  if [ -z "$tag" ]; then
    # /releases/latest redirects to /releases/tag/<tag>: no API call, no token,
    # no API rate limit.
    url="$(curl -sSfL --connect-timeout 10 --max-time 30 -o /dev/null -w '%{url_effective}' "$RELEASES/latest")" || return 1
    tag="${url##*/}"
  fi
  case "$tag" in v*) ;; *) tag="v$tag" ;; esac
  version="${tag#v}"
  tarball="trivy_${version}_${OS}-${ARCH}.tar.gz"
  checksums="trivy_${version}_checksums.txt"

  echo "Trivy $tag ($OS-$ARCH) from $RELEASES/download/$tag"
  curl -sSfL --connect-timeout 10 --max-time 180 -o "$WORK/$tarball" "$RELEASES/download/$tag/$tarball" || return 1
  curl -sSfL --connect-timeout 10 --max-time 60 -o "$WORK/$checksums" "$RELEASES/download/$tag/$checksums" || return 1

  want="$(awk -v f="$tarball" '$2 == f || $2 == "*" f {print $1}' "$WORK/$checksums")"
  got="$(sha256 "$WORK/$tarball")"
  if [ -z "$want" ] || [ "$want" != "$got" ]; then
    echo "::error::Checksum mismatch for $tarball: release lists '${want:-nothing}', download is '$got'. Not installed."
    return 3
  fi

  tar -xzf "$WORK/$tarball" -C "$WORK" trivy || return 1
  install -m 0755 "$WORK/trivy" "$BINDIR/trivy" || return 1
  echo "Installed $("$BINDIR/trivy" --version 2>/dev/null | head -n1 || echo "trivy $tag") to $BINDIR"
}

for ((attempt = 1; attempt <= ATTEMPTS; attempt++)); do
  install_once
  rc=$?
  [ "$rc" -eq 0 ] && exit 0
  [ "$rc" -eq 3 ] && exit 1
  if [ "$attempt" -lt "$ATTEMPTS" ]; then
    echo "::warning::Installing Trivy failed (attempt $attempt of $ATTEMPTS) - retrying in $((attempt * BACKOFF)) s."
    sleep "$((attempt * BACKOFF))"
  fi
done

echo "::error::Installing Trivy failed after $ATTEMPTS attempts. The curl output above names the download that failed (github.com release assets). Re-running helps only if that was a transient network error."
exit 1
