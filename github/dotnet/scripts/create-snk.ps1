<#
.SYNOPSIS
    Creates a strong name key (.snk) file for .NET assembly signing.

.DESCRIPTION
    This script generates an SNK (Strong Name Key) file for signing .NET assemblies.
    It outputs the Base64-encoded key for use as a GitHub Secret.

.PARAMETER OutputPath
    Path where the SNK file will be created. Default: .\build\MyProject.snk

.PARAMETER KeySize
    RSA key size in bits. Default: 2048

.PARAMETER Force
    Overwrite existing SNK file without prompting.

.EXAMPLE
    .\create-snk.ps1
    Creates SNK file at .\build\MyProject.snk

.EXAMPLE
    .\create-snk.ps1 -OutputPath ".\keys\MyLib.snk"
    Creates SNK file at custom path

.EXAMPLE
    .\create-snk.ps1 -OutputPath ".\keys\MyLib.snk" -KeySize 4096 -Force
    Creates 4096-bit SNK file, overwriting if exists

.NOTES
    GitHub Secret Setup:
    1. Run this script to generate the SNK file
    2. Copy the Base64 output
    3. Create a GitHub secret named DOTNET_SIGNKEY_BASE64
    4. Paste the Base64 content as the secret value
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$OutputPath = ".\build\MyProject.snk",

    [Parameter(Position = 1)]
    [ValidateSet(1024, 2048, 4096)]
    [int]$KeySize = 2048,

    [switch]$Force
)

$ErrorActionPreference = "Stop"

# Colors
function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Prefix = "[+]",
        [ConsoleColor]$Color = [ConsoleColor]::Green
    )
    Write-Host "$Prefix " -ForegroundColor $Color -NoNewline
    Write-Host $Message
}

function Write-Info { Write-ColorOutput -Message $args[0] -Prefix "[+]" -Color Green }
function Write-Warn { Write-ColorOutput -Message $args[0] -Prefix "[!]" -Color Yellow }
function Write-Err { Write-ColorOutput -Message $args[0] -Prefix "[-]" -Color Red }
function Write-Step { Write-ColorOutput -Message $args[0] -Prefix "[*]" -Color Cyan }

# Header
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  .NET Strong Name Key (SNK) Generator" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Ensure output directory exists
$OutputDir = Split-Path -Parent $OutputPath
if ($OutputDir -and -not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    Write-Info "Created output directory: $OutputDir"
}

# Check if output file already exists
if ((Test-Path $OutputPath) -and -not $Force) {
    Write-Warn "SNK file already exists: $OutputPath"
    $response = Read-Host "Overwrite? (y/N)"
    if ($response -notmatch '^[Yy]$') {
        Write-Info "Aborted."
        exit 0
    }
}

Write-Step "Generating SNK key with $KeySize-bit RSA..."

# Method 1: Try using sn.exe from Visual Studio
$snPath = $null
$vsLocations = @(
    "C:\Program Files\Microsoft SDKs\Windows\*\bin\*\sn.exe",
    "C:\Program Files (x86)\Microsoft SDKs\Windows\*\bin\*\sn.exe",
    "C:\Program Files\Microsoft Visual Studio\*\*\SDK\*\bin\*\sn.exe"
)

foreach ($pattern in $vsLocations) {
    $found = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) {
        $snPath = $found.FullName
        break
    }
}

if ($snPath) {
    Write-Info "Using sn.exe: $snPath"
    & $snPath -k $OutputPath
    if ($LASTEXITCODE -ne 0) {
        Write-Err "sn.exe failed to create key"
        exit 1
    }
}
else {
    # Method 2: Use .NET cryptography APIs
    Write-Info "Using .NET cryptography APIs..."

    try {
        # Create RSA key pair
        $rsa = [System.Security.Cryptography.RSA]::Create($KeySize)

        # Export as PKCS#8 private key (compatible with SNK format)
        $keyBytes = $rsa.ExportRSAPrivateKey()

        # Write to file
        [System.IO.File]::WriteAllBytes($OutputPath, $keyBytes)

        $rsa.Dispose()

        Write-Info "Generated RSA key using .NET APIs"
    }
    catch {
        Write-Err "Failed to generate key: $_"
        exit 1
    }
}

# Verify the file was created
if (-not (Test-Path $OutputPath)) {
    Write-Err "Failed to create SNK file."
    exit 1
}

$fileInfo = Get-Item $OutputPath
Write-Info "SNK key created: $OutputPath"
Write-Info "File size: $($fileInfo.Length) bytes"

# Generate Base64 for GitHub Secret
Write-Host ""
Write-Step "Generating Base64 encoding for GitHub Secrets..."
Write-Host ""

$bytes = [System.IO.File]::ReadAllBytes($OutputPath)
$base64 = [Convert]::ToBase64String($bytes)

Write-Host "============================================" -ForegroundColor Yellow
Write-Host "  DOTNET_SIGNKEY_BASE64 (GitHub Secret)" -ForegroundColor Yellow
Write-Host "============================================" -ForegroundColor Yellow
Write-Host ""
Write-Host $base64
Write-Host ""
Write-Host "============================================" -ForegroundColor Yellow
Write-Host ""

# Save to file for convenience
$base64File = "$OutputPath.base64"
$base64 | Out-File -FilePath $base64File -Encoding ASCII -NoNewline
Write-Info "Base64 saved to: $base64File"

# Copy to clipboard if available
try {
    $base64 | Set-Clipboard
    Write-Info "Base64 copied to clipboard!"
}
catch {
    # Clipboard not available (e.g., non-interactive session)
}

# Extract public key information (if sn.exe available)
if ($snPath) {
    Write-Host ""
    Write-Step "Extracting public key information..."

    $publicKeyFile = $OutputPath -replace '\.snk$', '.pub'

    try {
        & $snPath -p $OutputPath $publicKeyFile 2>$null
        if (Test-Path $publicKeyFile) {
            Write-Info "Public key extracted: $publicKeyFile"

            # Get public key token
            $tokenOutput = & $snPath -tp $publicKeyFile 2>$null
            $tokenMatch = $tokenOutput | Select-String -Pattern "Public key token is ([a-f0-9]+)"
            if ($tokenMatch) {
                $publicKeyToken = $tokenMatch.Matches[0].Groups[1].Value
                Write-Host ""
                Write-Info "Public Key Token: $publicKeyToken"
                Write-Host ""
                Write-Host "Use this for InternalsVisibleTo:" -ForegroundColor Cyan
                Write-Host "[assembly: InternalsVisibleTo(`"YourTestProject, PublicKey=$publicKeyToken`")]" -ForegroundColor White
            }
        }
    }
    catch {
        # Ignore errors extracting public key
    }
}

# Instructions
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Next Steps" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Go to your GitHub repository"
Write-Host "2. Navigate to: Settings > Secrets and variables > Actions"
Write-Host "3. Click 'New repository secret'"
Write-Host "4. Name: " -NoNewline; Write-Host "DOTNET_SIGNKEY_BASE64" -ForegroundColor Yellow
Write-Host "5. Value: (paste the Base64 content above)"
Write-Host "6. Click 'Add secret'"
Write-Host ""
Write-Host "In your workflow:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  jobs:" -ForegroundColor Gray
Write-Host "    publish:" -ForegroundColor Gray
Write-Host "      uses: bauer-group/automation-templates/.github/workflows/dotnet-publish-library.yml@main" -ForegroundColor Gray
Write-Host "      with:" -ForegroundColor Gray
Write-Host "        project-path: 'src/MyLibrary.csproj'" -ForegroundColor Gray
Write-Host "        sign-assembly: true" -ForegroundColor Gray
Write-Host "      secrets:" -ForegroundColor Gray
Write-Host "        DOTNET_SIGNKEY_BASE64: `${{ secrets.DOTNET_SIGNKEY_BASE64 }}" -ForegroundColor Gray
Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

Write-Info "Done!"
