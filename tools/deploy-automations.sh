#!/bin/bash

# 🚀 Automation Templates Deployment Tool (Bash Wrapper)
# This is a lightweight wrapper around the Python implementation

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PYTHON_SCRIPT="$SCRIPT_DIR/deploy_automations.py"
VENV_DIR="$SCRIPT_DIR/.venv"
REQUIREMENTS="$SCRIPT_DIR/requirements.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

# Check if Python is available
check_python() {
    if command -v python3 &> /dev/null; then
        PYTHON_CMD="python3"
    elif command -v python &> /dev/null && python --version 2>&1 | grep -q "Python 3"; then
        PYTHON_CMD="python"
    else
        log_error "Python 3 is required but not found"
        log_info "Please install Python 3.8 or newer"
        exit 1
    fi
}

# Setup virtual environment
setup_venv() {
    if [[ ! -d "$VENV_DIR" ]]; then
        log_info "Creating Python virtual environment..."
        $PYTHON_CMD -m venv "$VENV_DIR"
    fi
    
    # Activate virtual environment
    source "$VENV_DIR/bin/activate"
    
    # Install/upgrade dependencies
    if [[ ! -f "$VENV_DIR/.deps_installed" ]] || [[ "$REQUIREMENTS" -nt "$VENV_DIR/.deps_installed" ]]; then
        log_info "Installing Python dependencies..."
        pip install --upgrade pip > /dev/null 2>&1
        pip install -r "$REQUIREMENTS" > /dev/null 2>&1
        touch "$VENV_DIR/.deps_installed"
        log_success "Dependencies installed"
    fi
}

# Show help if no arguments
if [[ $# -eq 0 ]]; then
    source "$VENV_DIR/bin/activate" 2>/dev/null || true
    $PYTHON_CMD "$PYTHON_SCRIPT" --help
    exit 0
fi

# Main execution
main() {
    log_info "🚀 Automation Templates Deployment Tool (Bash Wrapper)"
    
    # Check Python availability
    check_python
    
    # Setup virtual environment and dependencies
    setup_venv
    
    # Execute Python script with all arguments
    $PYTHON_CMD "$PYTHON_SCRIPT" "$@"
}

# Run main function with all arguments
main "$@"