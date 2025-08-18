#!/usr/bin/env pwsh
<#
.SYNOPSIS
    GitHub Repository Cleanup Tool - PowerShell Wrapper mit OAuth-Support

.DESCRIPTION
    PowerShell wrapper für das GitHub cleanup tool mit Browser-basierter Authentifizierung.

.PARAMETER Owner
    GitHub repository owner/organization (erforderlich)

.PARAMETER Repo
    GitHub repository name (erforderlich)

.PARAMETER Token
    GitHub Personal Access Token (optional - verwenden Sie OAuth stattdessen)

.PARAMETER OAuth
    Browser-basierte OAuth-Authentifizierung verwenden (empfohlen)

.PARAMETER DryRun
    Zeigt was gelöscht werden würde ohne tatsächlich zu löschen

.PARAMETER Verbose
    Ausführliche Ausgabe aktivieren

.EXAMPLE
    .\cleanup_oauth.ps1 -Owner "myorg" -Repo "myrepo" -OAuth -DryRun

.EXAMPLE
    .\cleanup_oauth.ps1 -Owner "myorg" -Repo "myrepo" -Token "ghp_xxxx"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Owner,
    
    [Parameter(Mandatory=$true)]
    [string]$Repo,
    
    [string]$Token,
    [switch]$OAuth,
    [switch]$DryRun,
    [switch]$Verbose
)

# Farben für Ausgabe
$Red = "`e[31m"
$Green = "`e[32m"
$Yellow = "`e[33m"
$Blue = "`e[34m"
$Cyan = "`e[36m"
$Reset = "`e[0m"

function Write-ColorOutput {
    param([string]$Message, [string]$Color = $Reset)
    Write-Host "$Color$Message$Reset"
}

function Test-PythonInstallation {
    Write-ColorOutput "🔍 Prüfe Python-Installation..." $Blue
    
    $pythonCommands = @("python", "python3", "py")
    $pythonCmd = $null
    
    foreach ($cmd in $pythonCommands) {
        try {
            $version = & $cmd --version 2>$null
            if ($LASTEXITCODE -eq 0) {
                $pythonCmd = $cmd
                Write-ColorOutput "✅ Python gefunden: $version ($cmd)" $Green
                break
            }
        }
        catch {
            continue
        }
    }
    
    if (-not $pythonCmd) {
        Write-ColorOutput "❌ Python nicht gefunden!" $Red
        Write-ColorOutput "💡 Bitte installieren Sie Python von https://python.org" $Yellow
        exit 1
    }
    
    return $pythonCmd
}

function Install-Requirements {
    param([string]$PythonCmd)
    
    $requirementsFile = Join-Path $PSScriptRoot "requirements.txt"
    
    if (-not (Test-Path $requirementsFile)) {
        Write-ColorOutput "❌ requirements.txt nicht gefunden!" $Red
        exit 1
    }
    
    Write-ColorOutput "📦 Installiere Python-Abhängigkeiten..." $Blue
    
    try {
        & $PythonCmd -m pip install --upgrade pip --quiet
        & $PythonCmd -m pip install -r $requirementsFile --quiet
        
        if ($LASTEXITCODE -ne 0) {
            throw "pip install fehlgeschlagen"
        }
        
        Write-ColorOutput "✅ Abhängigkeiten erfolgreich installiert" $Green
    }
    catch {
        Write-ColorOutput "❌ Fehler bei der Installation der Abhängigkeiten: $($_.Exception.Message)" $Red
        Write-ColorOutput "💡 Versuchen Sie: $PythonCmd -m pip install -r requirements.txt" $Yellow
        exit 1
    }
}

function Invoke-CleanupTool {
    param([string]$PythonCmd)
    
    $scriptFile = Join-Path $PSScriptRoot "github_cleanup.py"
    
    if (-not (Test-Path $scriptFile)) {
        Write-ColorOutput "❌ github_cleanup.py nicht gefunden!" $Red
        exit 1
    }
    
    # Build arguments for Python script
    $PythonArgs = @("$scriptFile", "--owner", $Owner, "--repo", $Repo)
    
    if ($Token) {
        $PythonArgs += @("--token", $Token)
    }
    
    if ($OAuth) {
        $PythonArgs += "--oauth"
        Write-ColorOutput "🔐 OAuth-Authentifizierung wird verwendet" $Cyan
        Write-ColorOutput "🌐 Der Browser öffnet sich automatisch für die Anmeldung" $Cyan
    }
    
    if ($DryRun) {
        $PythonArgs += "--dry-run"
    }
    
    if ($Verbose) {
        $PythonArgs += "--verbose"
    }
    
    Write-ColorOutput "🚀 Starte GitHub Cleanup Tool..." $Blue
    Write-ColorOutput "📂 Repository: $Owner/$Repo" $Blue
    
    if ($DryRun) {
        Write-ColorOutput "🔍 DRY-RUN Modus - keine Änderungen werden vorgenommen" $Yellow
    }
    
    try {
        & $PythonCmd @PythonArgs
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✅ Cleanup erfolgreich abgeschlossen!" $Green
        } else {
            Write-ColorOutput "❌ Cleanup mit Fehlern beendet (Exit Code: $LASTEXITCODE)" $Red
            exit $LASTEXITCODE
        }
    }
    catch {
        Write-ColorOutput "❌ Fehler beim Ausführen des Cleanup-Tools: $($_.Exception.Message)" $Red
        exit 1
    }
}

function Show-Usage {
    Write-ColorOutput "🧹 GitHub Repository Cleanup Tool mit OAuth" $Blue
    Write-ColorOutput "===========================================" $Blue
    Write-ColorOutput ""
    Write-ColorOutput "🔐 Authentifizierungsoptionen:" $Cyan
    Write-ColorOutput "  --OAuth      Browser-basierte Anmeldung (empfohlen)" $Green
    Write-ColorOutput "  --Token      Personal Access Token" $Yellow
    Write-ColorOutput ""
    Write-ColorOutput "📝 Beispiele:" $Cyan
    Write-ColorOutput "  .\cleanup_oauth.ps1 -Owner myorg -Repo myrepo -OAuth -DryRun" $Green
    Write-ColorOutput "  .\cleanup_oauth.ps1 -Owner myorg -Repo myrepo -Token ghp_xxxx" $Yellow
    Write-ColorOutput ""
    
    if (-not $OAuth -and -not $Token) {
        Write-ColorOutput "⚠️  Keine Authentifizierungsmethode angegeben!" $Yellow
        Write-ColorOutput "💡 Verwenden Sie --OAuth für Browser-Login oder --Token für PAT" $Cyan
        exit 1
    }
}

# Main execution
Write-ColorOutput "🧹 GitHub Repository Cleanup Tool mit OAuth-Support" $Blue
Write-ColorOutput "=================================================" $Blue

# Validate authentication method
if (-not $OAuth -and -not $Token) {
    Show-Usage
}

$pythonCmd = Test-PythonInstallation
Install-Requirements $pythonCmd
Invoke-CleanupTool $pythonCmd

Write-ColorOutput "🎉 Fertig!" $Green
