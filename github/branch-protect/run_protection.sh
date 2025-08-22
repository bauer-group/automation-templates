#!/usr/bin/env bash

# GitHub Branch Protection Runner
# BAUER GROUP - Python implementation wrapper
# 
# Simple wrapper script to run the Python branch protection implementation
# with automatic dependency installation and proper error handling.
#
# Usage:
#   ./run_protection.sh [python-script-arguments]
#   ./run_protection.sh --help

set -euo pipefail

SCRIPT_DIR="$(cd "${BASH_SOURCE[0]%/*}" && pwd)"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Check if Python is available
check_python() {
    if command -v python3 &> /dev/null; then
        echo "python3"
        return 0
    elif command -v python &> /dev/null; then
        # Verify it's Python 3
        if python -c "import sys; sys.exit(0 if sys.version_info >= (3, 6) else 1)" 2>/dev/null; then
            echo "python"
            return 0
        fi
    fi
    return 1
}

# Install Python dependencies if needed
install_dependencies() {
    local python_cmd="$1"
    local requirements_file="$SCRIPT_DIR/requirements.txt"
    
    if [[ ! -f "$requirements_file" ]]; then
        log_error "Requirements file not found: $requirements_file"
        return 1
    fi
    
    log_info "Installing Python dependencies from requirements.txt..."
    if $python_cmd -m pip install --quiet --user -r "$requirements_file"; then
        log_success "Dependencies installed successfully"
        return 0
    else
        log_error "Failed to install dependencies"
        return 1
    fi
}

# Check if required packages are available
check_dependencies() {
    local python_cmd="$1"
    
    # Check for required packages
    if ! $python_cmd -c "import requests" &> /dev/null; then
        log_warning "Required Python packages not found"
        if install_dependencies "$python_cmd"; then
            return 0
        else
            return 1
        fi
    fi
    
    return 0
}

# Main execution function
main() {
    local python_script="$SCRIPT_DIR/src/protect_main.py"
    
    # Show banner
    log_info "🛡️  GitHub Branch Protection Runner"
    log_info "BAUER GROUP - Python Implementation Wrapper v1.0"
    echo
    
    # Check if Python script exists
    if [[ ! -f "$python_script" ]]; then
        log_error "Python implementation not found: $python_script"
        exit 1
    fi
    
    # Find suitable Python command
    local python_cmd
    if ! python_cmd=$(check_python); then
        log_error "Python 3.6+ is required but not found"
        log_error "Please install Python 3.6 or later to continue"
        exit 1
    fi
    
    log_info "Using Python: $(command -v $python_cmd)"
    
    # Check and install dependencies
    if ! check_dependencies "$python_cmd"; then
        log_error "Cannot proceed without required Python packages"
        log_error "Please ensure you have pip installed and try again"
        exit 1
    fi
    
    # Execute Python implementation
    log_info "🐍 Running Python branch protection implementation"
    echo
    
    exec $python_cmd "$python_script" "$@"
}

# Execute main function with all arguments
main "$@"