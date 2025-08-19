#!/bin/bash

# 🚀 Manual Release Script
# For creating releases manually when automatic release-please fails or is not suitable

set -euo pipefail

# Configuration
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Validate we're in a git repository and get the actual repo root
if command -v git &> /dev/null; then
    GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
    if [[ -n "$GIT_ROOT" ]]; then
        REPO_ROOT="$GIT_ROOT"
    fi
fi

echo "Repository Root: $REPO_ROOT"
MANIFEST_FILE="$REPO_ROOT/.github/config/.release-please-manifest.json"
CONFIG_FILE="$REPO_ROOT/.github/config/release-please-config.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Function to get current version
get_current_version() {
    local version="0.0.0"
    
    # Try manifest file first
    if [[ -f "$MANIFEST_FILE" ]]; then
        if command -v jq &> /dev/null; then
            version=$(jq -r '."."' "$MANIFEST_FILE" 2>/dev/null || echo "0.0.0")
            if [[ "$version" != "null" && "$version" != "0.0.0" ]]; then
                echo "$version"
                return
            fi
        else
            # Simple grep-based parsing as fallback
            version=$(grep -o '"\.": *"[^"]*"' "$MANIFEST_FILE" 2>/dev/null | sed 's/.*: *"\([^"]*\)".*/\1/' || echo "0.0.0")
            if [[ "$version" != "0.0.0" ]]; then
                echo "$version"
                return
            fi
        fi
    fi
    
    # Fallback to git tags
    if [[ "$version" == "0.0.0" ]] || [[ "$version" == "null" ]]; then
        version=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || echo "0.0.0")
    fi
    
    echo "$version"
}

# Function to increment version
increment_version() {
    local version="$1"
    local bump_type="${2:-patch}"
    
    IFS='.' read -r major minor patch_num <<< "$version"
    
    case "$bump_type" in
        major)
            echo "$((major + 1)).0.0"
            ;;
        minor)
            echo "$major.$((minor + 1)).0"
            ;;
        patch)
            echo "$major.$minor.$((patch_num + 1))"
            ;;
        *)
            echo "$version"
            ;;
    esac
}

# Function to detect bump type from commits
detect_bump_type() {
    local last_tag
    last_tag=$(git describe --tags --abbrev=0 2>/dev/null || git rev-list --max-parents=0 HEAD)
    
    # Get commits since last release
    local commits
    commits=$(git log "${last_tag}..HEAD" --pretty=format:"%s" 2>/dev/null || git log --pretty=format:"%s" -10)
    
    # Check for breaking changes or major features
    if echo "$commits" | grep -qiE "(BREAKING|major|breaking change)"; then
        echo "major"
        return
    fi
    
    # Check for new features
    if echo "$commits" | grep -qiE "(feat|feature|add|new)"; then
        echo "minor"
        return
    fi
    
    # Default to patch
    echo "patch"
}

# Function to generate changelog
generate_changelog() {
    local version="$1"
    local current_version="$2"
    
    local last_tag
    last_tag=$(git describe --tags --abbrev=0 2>/dev/null || git rev-list --max-parents=0 HEAD)
    
    cat <<EOF
## 🚀 What's Changed in v${version}

### 📋 Changes since v${current_version}

$(git log "${last_tag}..HEAD" --pretty=format:"- %s" --reverse 2>/dev/null | head -20 || git log --pretty=format:"- %s" -10)

### 🔗 Full Changelog

**Full Changelog**: https://github.com/${GITHUB_REPOSITORY:-owner/repo}/compare/v${current_version}...v${version}

---

*This release was created using the Universal Release Script.*
EOF
}

# Function to create release with fallback
create_release() {
    local version="$1"
    local changelog="$2"
    local current_version="$3"
    
    log "Creating release v$version..."
    
    # Ensure we have the necessary directories
    mkdir -p "$(dirname "$MANIFEST_FILE")"
    mkdir -p "$(dirname "$CONFIG_FILE")"
    
    # Create or update manifest file
    echo "{\".\": \"$version\"}" > "$MANIFEST_FILE"
    
    # Create minimal config if it doesn't exist
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" <<EOF
{
  "\$schema": "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json",
  "packages": {
    ".": {
      "release-type": "simple"
    }
  },
  "release-search-depth": 1,
  "commit-search-depth": 1
}
EOF
    fi
    
    # Configure git
    git config --global user.name "${GIT_USER_NAME:-github-actions[bot]}"
    git config --global user.email "${GIT_USER_EMAIL:-41898282+github-actions[bot]@users.noreply.github.com}"
    
    # Update CHANGELOG.MD
    if [[ -f "CHANGELOG.MD" ]]; then
        # Prepend to existing changelog
        {
            echo "$changelog"
            echo ""
            echo "---"
            echo ""
            cat CHANGELOG.MD
        } > tmp_changelog.md
        mv tmp_changelog.md CHANGELOG.MD
    else
        echo "$changelog" > CHANGELOG.MD
    fi
    
    # Commit changes
    git add .
    if git diff --staged --quiet; then
        warn "No changes to commit"
    else
        git commit -m "chore: release v$version

- Update version to $version
- Update CHANGELOG.MD with release notes
- Automated release creation

[skip ci]"
    fi
    
    # Create tag
    git tag -a "v$version" -m "Release v$version"
    
    # Push changes
    git push origin "$(git branch --show-current)" || warn "Failed to push branch"
    git push origin "v$version" || warn "Failed to push tag"
    
    # Create GitHub release if gh CLI is available
    if command -v gh &> /dev/null; then
        log "Creating GitHub release..."
        gh release create "v$version" \
            --title "🚀 Release v$version" \
            --notes "$changelog" \
            --latest || warn "Failed to create GitHub release"
    else
        warn "GitHub CLI not available, skipping GitHub release creation"
    fi
    
    success "Release v$version created successfully!"
}

# Main function
main() {
    log "🚀 Starting Universal Release Process..."
    
    # Change to repository root
    cd "$REPO_ROOT"
    
    # Get current version
    local current_version
    current_version=$(get_current_version)
    log "Current version: $current_version"
    
    # Log version detection details
    if [[ -f "$MANIFEST_FILE" ]]; then
        log "✅ Found version in manifest file"
    else
        log "⚠️ Using fallback version detection"
    fi
    
    # Detect bump type or use provided
    local bump_type="${1:-$(detect_bump_type)}"
    log "Bump type: $bump_type"
    
    # Calculate new version
    local new_version
    new_version=$(increment_version "$current_version" "$bump_type")
    log "New version: $new_version"
    
    # Generate changelog
    local changelog
    changelog=$(generate_changelog "$new_version" "$current_version")
    
    # Create release
    create_release "$new_version" "$changelog" "$current_version"
    
    success "🎉 Release process completed!"
}

# Script execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
