# 🚀 Automation Templates Deployment Tool (PowerShell Wrapper)
# This is a lightweight wrapper around the Python implementation

param(
    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Arguments
)

# Configuration
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PYTHON_SCRIPT = Join-Path $SCRIPT_DIR "deploy_automations.py"
$VENV_DIR = Join-Path $SCRIPT_DIR ".venv"
$REQUIREMENTS = Join-Path $SCRIPT_DIR "requirements.txt"

# Helper functions
function Write-Info { param($Message) Write-Host "ℹ️  $Message" -ForegroundColor Blue }
function Write-Success { param($Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host "⚠️  $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "❌ $Message" -ForegroundColor Red }

# Check if Python is available
function Test-Python {
    $pythonCmd = $null
    
    if (Get-Command "python3" -ErrorAction SilentlyContinue) {
        $pythonCmd = "python3"
    } elseif (Get-Command "python" -ErrorAction SilentlyContinue) {
        $version = & python --version 2>&1
        if ($version -match "Python 3") {
            $pythonCmd = "python"
        }
    }
    
    if (-not $pythonCmd) {
        Write-Error "Python 3 is required but not found"
        Write-Info "Please install Python 3.8 or newer"
        exit 1
    }
    
    return $pythonCmd
}

# Setup virtual environment
function Initialize-VirtualEnvironment {
    param($PythonCmd)
    
    if (-not (Test-Path $VENV_DIR)) {
        Write-Info "Creating Python virtual environment..."
        & $PythonCmd -m venv $VENV_DIR
    }
    
    # Activate virtual environment
    $activateScript = Join-Path $VENV_DIR "Scripts\Activate.ps1"
    if (Test-Path $activateScript) {
        & $activateScript
    } else {
        Write-Error "Failed to activate virtual environment"
        exit 1
    }
    
    # Install/upgrade dependencies
    $depsInstalled = Join-Path $VENV_DIR ".deps_installed"
    if (-not (Test-Path $depsInstalled) -or (Get-Item $REQUIREMENTS).LastWriteTime -gt (Get-Item $depsInstalled).LastWriteTime) {
        Write-Info "Installing Python dependencies..."
        & pip install --upgrade pip | Out-Null
        & pip install -r $REQUIREMENTS | Out-Null
        New-Item -ItemType File -Path $depsInstalled -Force | Out-Null
        Write-Success "Dependencies installed"
    }
}

# Show help if no arguments
if ($Arguments.Count -eq 0) {
    try {
        $activateScript = Join-Path $VENV_DIR "Scripts\Activate.ps1"
        if (Test-Path $activateScript) {
            & $activateScript
        }
        & python $PYTHON_SCRIPT --help
    } catch {
        # If virtual environment doesn't exist, just try with system Python
        $pythonCmd = Test-Python
        & $pythonCmd $PYTHON_SCRIPT --help
    }
    exit 0
}

# Main execution
function Main {
    Write-Info "🚀 Automation Templates Deployment Tool (PowerShell Wrapper)"
    
    # Check Python availability
    $pythonCmd = Test-Python
    
    # Setup virtual environment and dependencies
    Initialize-VirtualEnvironment $pythonCmd
    
    # Execute Python script with all arguments
    & python $PYTHON_SCRIPT @Arguments
}

# Run main function
Main