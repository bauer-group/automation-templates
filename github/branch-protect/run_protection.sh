#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "${BASH_SOURCE[0]%/*}" && pwd)"
python -m pip install --quiet -r "$SCRIPT_DIR/requirements.txt"
python "$SCRIPT_DIR/src/protect_main.py" "$@"
