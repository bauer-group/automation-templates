#!/bin/bash
# GitHub Repository Cleanup Tool - Bash Wrapper
# This script provides a convenient way to run the Python cleanup tool

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/github_cleanup.py"

# Check if Python is available
if ! command -v python3 &> /dev/null; then
    if ! command -v python &> /dev/null; then
        echo "❌ Error: Python is not installed or not in PATH"
        exit 1
    else
        PYTHON_CMD="python"
    fi
else
    PYTHON_CMD="python3"
fi

# Check if the Python script exists
if [ ! -f "$PYTHON_SCRIPT" ]; then
    echo "❌ Error: Python script not found at $PYTHON_SCRIPT"
    exit 1
fi

# Install requirements if needed
if [ ! -f "$SCRIPT_DIR/requirements_installed.flag" ]; then
    echo "📦 Installing Python requirements..."
    $PYTHON_CMD -m pip install -r "$SCRIPT_DIR/requirements.txt"
    touch "$SCRIPT_DIR/requirements_installed.flag"
fi

# Run the Python script with all passed arguments
echo "🚀 Starting GitHub Repository Cleanup Tool..."
$PYTHON_CMD "$PYTHON_SCRIPT" "$@"
