#!/usr/bin/env bash
#
# Installs a scanner (Trivy, Grype, Syft) through its vendor install script and
# retries the WHOLE install, not only the script download.
#
# A vendor installer is two downloads: the script from raw.githubusercontent.com,
# then the release tarball that script fetches from github.com. The plain
# `curl ... | sh` this replaces retried neither, so a single connection reset on
# either hop failed the job (issue #101: an OT-CAN2IP release lost its SBOM to
# "curl: (35) Recv failure: Connection reset by peer" after the image was already
# pushed). curl's own --retry would cover the first hop only, and a reset not even
# that without --retry-all-errors, which needs curl >= 7.71 - not a given on an
# older self-hosted runner.
#
# The script is saved to a file before it runs. Piped into sh, a download cut off
# midway would execute whatever part of the script had arrived.
#
# Usage: install-tool.sh <name> <installer-url> [installer args...]
#   e.g. install-tool.sh Syft https://raw.githubusercontent.com/anchore/syft/main/install.sh -b /usr/local/bin
# Env:   INSTALL_ATTEMPTS (default 3)
#        INSTALL_BACKOFF  (seconds, default 10; attempt n waits n * INSTALL_BACKOFF)

set -uo pipefail

if [ "$#" -lt 2 ]; then
  echo "::error::usage: install-tool.sh <name> <installer-url> [installer args...]"
  exit 2
fi

NAME="$1"
URL="$2"
shift 2
ATTEMPTS="${INSTALL_ATTEMPTS:-3}"
BACKOFF="${INSTALL_BACKOFF:-10}"

INSTALLER="$(mktemp)"
trap 'rm -f "$INSTALLER"' EXIT

for ((attempt = 1; attempt <= ATTEMPTS; attempt++)); do
  if curl -sSfL --connect-timeout 10 --max-time 60 -o "$INSTALLER" "$URL" \
     && sh "$INSTALLER" "$@"; then
    exit 0
  fi
  if [ "$attempt" -lt "$ATTEMPTS" ]; then
    echo "::warning::Installing $NAME failed (attempt $attempt of $ATTEMPTS) - retrying in $((attempt * BACKOFF)) s."
    sleep "$((attempt * BACKOFF))"
  fi
done

echo "::error::Installing $NAME failed after $ATTEMPTS attempts. This is a download failure between the runner and GitHub, not a problem with the image - the curl or installer output above names the cause. Re-running the job usually clears it."
exit 1
