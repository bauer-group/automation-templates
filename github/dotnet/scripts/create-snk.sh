#!/usr/bin/env bash
# =============================================================================
# SNK Key Generation Script
# =============================================================================
# Creates a strong name key (.snk) file for .NET assembly signing
#
# Usage:
#   ./create-snk.sh [output-path] [key-size]
#
# Examples:
#   ./create-snk.sh                           # Creates ./build/MyProject.snk
#   ./create-snk.sh ./keys/MyLib.snk          # Custom path
#   ./create-snk.sh ./keys/MyLib.snk 4096     # Custom path and key size
#
# Output:
#   - Creates the .snk file at the specified path
#   - Prints the Base64-encoded key for GitHub Secrets
#   - Extracts public key token (if sn.exe available)
#
# GitHub Secret Setup:
#   1. Run this script to generate the SNK file
#   2. Copy the Base64 output
#   3. Create a GitHub secret named DOTNET_SIGNKEY_BASE64
#   4. Paste the Base64 content as the secret value
# =============================================================================

set -euo pipefail

# Configuration
OUTPUT_PATH="${1:-./build/MyProject.snk}"
KEY_SIZE="${2:-2048}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${GREEN}[+]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $*"; }
log_error() { echo -e "${RED}[-]${NC} $*"; }
log_step() { echo -e "${BLUE}[*]${NC} $*"; }

# Header
echo ""
echo "============================================"
echo "  .NET Strong Name Key (SNK) Generator"
echo "============================================"
echo ""

# Ensure output directory exists
OUTPUT_DIR=$(dirname "$OUTPUT_PATH")
if [ -n "$OUTPUT_DIR" ] && [ "$OUTPUT_DIR" != "." ]; then
    mkdir -p "$OUTPUT_DIR"
    log_info "Created output directory: $OUTPUT_DIR"
fi

# Check if output file already exists
if [ -f "$OUTPUT_PATH" ]; then
    log_warn "SNK file already exists: $OUTPUT_PATH"
    read -p "Overwrite? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Aborted."
        exit 0
    fi
fi

log_step "Generating SNK key with $KEY_SIZE-bit RSA..."

# Method 1: Try using sn.exe (Windows/.NET SDK)
if command -v sn &> /dev/null; then
    log_info "Using sn.exe (Strong Name Tool)..."
    sn -k "$OUTPUT_PATH"

# Method 2: Try using dotnet with a temporary project
elif command -v dotnet &> /dev/null; then
    log_info "Using .NET SDK with OpenSSL..."

    # Check for OpenSSL
    if ! command -v openssl &> /dev/null; then
        log_error "OpenSSL not found. Please install OpenSSL or use sn.exe."
        exit 1
    fi

    # Generate RSA key pair using OpenSSL
    TEMP_DIR=$(mktemp -d)
    trap "rm -rf $TEMP_DIR" EXIT

    # Generate private key
    openssl genrsa -out "$TEMP_DIR/key.pem" "$KEY_SIZE" 2>/dev/null

    # Convert to DER format (SNK format is raw RSA private key in DER)
    openssl rsa -in "$TEMP_DIR/key.pem" -outform DER -out "$OUTPUT_PATH" 2>/dev/null

    log_info "Generated RSA key using OpenSSL"

# Method 3: Pure PowerShell/dotnet approach
else
    log_error "Neither sn.exe nor dotnet found."
    log_error "Please install the .NET SDK or Visual Studio."
    exit 1
fi

# Verify the file was created
if [ ! -f "$OUTPUT_PATH" ]; then
    log_error "Failed to create SNK file."
    exit 1
fi

log_info "SNK key created: $OUTPUT_PATH"

# Get file size
FILE_SIZE=$(wc -c < "$OUTPUT_PATH")
log_info "File size: $FILE_SIZE bytes"

# Generate Base64 for GitHub Secret
echo ""
log_step "Generating Base64 encoding for GitHub Secrets..."
echo ""

# Platform-specific base64 encoding
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    BASE64_KEY=$(base64 < "$OUTPUT_PATH")
else
    # Linux
    BASE64_KEY=$(base64 -w 0 < "$OUTPUT_PATH")
fi

echo "============================================"
echo "  DOTNET_SIGNKEY_BASE64 (GitHub Secret)"
echo "============================================"
echo ""
echo "$BASE64_KEY"
echo ""
echo "============================================"
echo ""

# Save to file for convenience
BASE64_FILE="${OUTPUT_PATH}.base64"
echo "$BASE64_KEY" > "$BASE64_FILE"
log_info "Base64 saved to: $BASE64_FILE"

# Extract public key token (if sn.exe available)
if command -v sn &> /dev/null; then
    echo ""
    log_step "Extracting public key information..."

    # Extract public key
    PUBLIC_KEY_FILE="${OUTPUT_PATH%.snk}.pub"
    sn -p "$OUTPUT_PATH" "$PUBLIC_KEY_FILE" 2>/dev/null && {
        log_info "Public key extracted: $PUBLIC_KEY_FILE"

        # Get public key token
        TOKEN_OUTPUT=$(sn -tp "$PUBLIC_KEY_FILE" 2>/dev/null || true)
        if [ -n "$TOKEN_OUTPUT" ]; then
            PUBLIC_KEY_TOKEN=$(echo "$TOKEN_OUTPUT" | grep -i "public key token" | awk '{print $NF}' || true)
            if [ -n "$PUBLIC_KEY_TOKEN" ]; then
                echo ""
                log_info "Public Key Token: $PUBLIC_KEY_TOKEN"
                echo ""
                echo "Use this for InternalsVisibleTo:"
                echo "[assembly: InternalsVisibleTo(\"YourTestProject, PublicKey=$PUBLIC_KEY_TOKEN\")]"
            fi
        fi
    }
fi

# Instructions
echo ""
echo "============================================"
echo "  Next Steps"
echo "============================================"
echo ""
echo "1. Go to your GitHub repository"
echo "2. Navigate to: Settings > Secrets and variables > Actions"
echo "3. Click 'New repository secret'"
echo "4. Name: DOTNET_SIGNKEY_BASE64"
echo "5. Value: (paste the Base64 content above)"
echo "6. Click 'Add secret'"
echo ""
echo "In your workflow:"
echo ""
echo "  jobs:"
echo "    publish:"
echo "      uses: bauer-group/automation-templates/.github/workflows/dotnet-publish-library.yml@main"
echo "      with:"
echo "        project-path: 'src/MyLibrary.csproj'"
echo "        sign-assembly: true"
echo "      secrets:"
echo "        DOTNET_SIGNKEY_BASE64: \${{ secrets.DOTNET_SIGNKEY_BASE64 }}"
echo ""
echo "============================================"
echo ""

log_info "Done!"
