# GitHub Repository Cleanup Tool - PowerShell Wrapper
# This script provides a convenient way to run the Python cleanup tool on Windows

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$Owner,
    
    [Parameter(Mandatory=$true)]
    [string]$Repo,
    
    [string]$Token,
    
    [switch]$DryRun,
    
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PythonScript = Join-Path $ScriptDir "github_cleanup.py"

# Check if Python is available
$PythonCmd = $null
try {
    python --version | Out-Null
    $PythonCmd = "python"
} catch {
    try {
        python3 --version | Out-Null
        $PythonCmd = "python3"
    } catch {
        Write-Error "❌ Error: Python is not installed or not in PATH"
        exit 1
    }
}

# Check if the Python script exists
if (-not (Test-Path $PythonScript)) {
    Write-Error "❌ Error: Python script not found at $PythonScript"
    exit 1
}

# Install requirements if needed
$RequirementsFlag = Join-Path $ScriptDir "requirements_installed.flag"
if (-not (Test-Path $RequirementsFlag)) {
    Write-Host "📦 Installing Python requirements..." -ForegroundColor Yellow
    & $PythonCmd -m pip install -r (Join-Path $ScriptDir "requirements.txt")
    if ($LASTEXITCODE -eq 0) {
        New-Item -Path $RequirementsFlag -ItemType File | Out-Null
    }
}

# Build arguments for Python script
$PythonArgs = @("--owner", $Owner, "--repo", $Repo)

if ($Token) {
    $PythonArgs += @("--token", $Token)
}

if ($DryRun) {
    $PythonArgs += "--dry-run"
}

if ($Verbose) {
    $PythonArgs += "--verbose"
}

# Run the Python script
Write-Host "🚀 Starting GitHub Repository Cleanup Tool..." -ForegroundColor Green
& $PythonCmd $PythonScript @PythonArgs
