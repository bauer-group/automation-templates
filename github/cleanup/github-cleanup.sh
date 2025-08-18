#!/bin/bash
# GitHub Repository Cleanup Tool - Bash Wrapper
# This script provides a convenient way to run the Python cleanup tool on Linux/macOS

set -e

# Colors for output
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
CYAN='\033[36m'
RESET='\033[0m'

# Function to print colored output
print_color() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${RESET}"
}

# Function to check if Python is available
check_python() {
    print_color "$BLUE" "🔍 Checking Python installation..."
    
    if command -v python3 &> /dev/null; then
        PYTHON_CMD="python3"
        print_color "$GREEN" "✅ Python found: $(python3 --version) (python3)"
    elif command -v python &> /dev/null; then
        PYTHON_CMD="python"
        print_color "$GREEN" "✅ Python found: $(python --version) (python)"
    else
        print_color "$RED" "❌ Python not found!"
        print_color "$YELLOW" "💡 Please install Python from https://python.org"
        exit 1
    fi
}

# Function to install Python dependencies
install_requirements() {
    local script_dir=$(dirname "$0")
    local requirements_file="$script_dir/requirements.txt"
    
    if [ ! -f "$requirements_file" ]; then
        print_color "$RED" "❌ requirements.txt not found!"
        exit 1
    fi
    
    print_color "$BLUE" "📦 Installing Python dependencies..."
    
    if ! $PYTHON_CMD -m pip install --upgrade pip --quiet; then
        print_color "$RED" "❌ Failed to upgrade pip"
        exit 1
    fi
    
    if ! $PYTHON_CMD -m pip install -r "$requirements_file" --quiet --user; then
        print_color "$RED" "❌ Failed to install dependencies"
        print_color "$YELLOW" "💡 Try running: $PYTHON_CMD -m pip install -r requirements.txt"
        exit 1
    fi
    
    print_color "$GREEN" "✅ Dependencies installed successfully"
}

# Function to run the cleanup tool
run_cleanup() {
    local script_dir=$(dirname "$0")
    local script_file="$script_dir/github_cleanup.py"
    
    if [ ! -f "$script_file" ]; then
        print_color "$RED" "❌ github_cleanup.py not found!"
        exit 1
    fi
    
    print_color "$BLUE" "🚀 Starting GitHub Cleanup Tool..."
    print_color "$BLUE" "📂 Repository: $OWNER/$REPO"
    
    if [ "$DRY_RUN" = true ]; then
        print_color "$YELLOW" "🔍 DRY-RUN mode - no changes will be made"
    fi
    
    # Build arguments for Python script
    local args=("$script_file" "--owner" "$OWNER" "--repo" "$REPO")
    
    if [ "$DRY_RUN" = true ]; then
        args+=("--dry-run")
    fi
    
    if [ "$VERBOSE" = true ]; then
        args+=("--verbose")
    fi
    
    if ! $PYTHON_CMD "${args[@]}"; then
        print_color "$RED" "❌ Cleanup completed with errors"
        exit 1
    fi
    
    print_color "$GREEN" "✅ Cleanup completed successfully!"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 <owner> <repo> [--dry-run] [--verbose]"
    echo ""
    echo "Arguments:"
    echo "  owner        GitHub repository owner/organization"
    echo "  repo         GitHub repository name"
    echo ""
    echo "Options:"
    echo "  --dry-run    Show what would be deleted without actually deleting"
    echo "  --verbose    Enable verbose output"
    echo ""
    echo "Examples:"
    echo "  $0 bauer-group automation-templates --dry-run"
    echo "  $0 myorg myrepo"
}

# Parse command line arguments
if [ $# -lt 2 ]; then
    show_usage
    exit 1
fi

OWNER="$1"
REPO="$2"
DRY_RUN=false
VERBOSE=false

# Process optional arguments
shift 2
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        *)
            print_color "$RED" "❌ Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
print_color "$BLUE" "🧹 GitHub Repository Cleanup Tool"
print_color "$BLUE" "================================="

check_python
install_requirements
run_cleanup

print_color "$GREEN" "🎉 Done!"
