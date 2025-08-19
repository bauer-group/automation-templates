#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Schnell-Start Skript für GitHub Repository Cleanup mit OAuth

.DESCRIPTION
    Vereinfachtes Skript zum schnellen Bereinigen von Repositories mit Browser-Login.

.PARAMETER Repository
    Repository im Format "owner/repo" (z.B. "bauer-group/automation-templates")

.PARAMETER DryRun
    Nur anzeigen was gelöscht werden würde (empfohlen für den ersten Lauf)

.EXAMPLE
    .\quick_cleanup.ps1 -Repository "bauer-group/automation-templates" -DryRun

.EXAMPLE
    .\quick_cleanup.ps1 -Repository "bauer-group/automation-templates"
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$Repository,
    
    [switch]$DryRun
)

# Farben für Ausgabe
$Red = "`e[31m"
$Green = "`e[32m"
$Yellow = "`e[33m"
$Blue = "`e[34m"
$Cyan = "`e[36m"
$Bold = "`e[1m"
$Reset = "`e[0m"

function Write-ColorOutput {
    param([string]$Message, [string]$Color = $Reset)
    Write-Host "$Color$Message$Reset"
}

function Show-Banner {
    Write-ColorOutput "$Bold" $Cyan
    Write-ColorOutput "  ┌─────────────────────────────────────────┐" $Cyan
    Write-ColorOutput "  │    🧹 GitHub Repository Cleanup        │" $Cyan  
    Write-ColorOutput "  │       mit OAuth-Authentifizierung      │" $Cyan
    Write-ColorOutput "  └─────────────────────────────────────────┘" $Cyan
    Write-ColorOutput "$Reset"
}

function Validate-Repository {
    param([string]$Repo)
    
    if ($Repo -notmatch "^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$") {
        Write-ColorOutput "❌ Ungültiges Repository-Format!" $Red
        Write-ColorOutput "💡 Verwenden Sie das Format: owner/repo" $Yellow
        Write-ColorOutput "📋 Beispiel: bauer-group/automation-templates" $Cyan
        exit 1
    }
    
    $parts = $Repo -split "/"
    return @{
        Owner = $parts[0]
        Repo = $parts[1]
    }
}

function Invoke-Cleanup {
    param($Owner, $Repo, $IsDryRun)
    
    $scriptFile = Join-Path $PSScriptRoot "github_cleanup.py"
    
    if (-not (Test-Path $scriptFile)) {
        Write-ColorOutput "❌ github_cleanup.py nicht gefunden!" $Red
        Write-ColorOutput "💡 Stellen Sie sicher, dass Sie im richtigen Verzeichnis sind" $Yellow
        exit 1
    }
    
    # Build arguments
    $args = @(
        $scriptFile,
        "--owner", $Owner,
        "--repo", $Repo
    )
    
    if ($IsDryRun) {
        $args += "--dry-run"
    }
    
    Write-ColorOutput "🚀 Starte Cleanup für $Owner/$Repo..." $Blue
    
    if ($IsDryRun) {
        Write-ColorOutput "🔍 DRY-RUN Modus aktiviert - keine Änderungen werden vorgenommen" $Yellow
    } else {
        Write-ColorOutput "⚠️  ACHTUNG: Alle Workflow-Runs, Releases, Tags und Branches (außer main/master) werden gelöscht!" $Red
        Write-ColorOutput "🔐 Browser öffnet sich für GitHub-Anmeldung..." $Cyan
    }
    
    try {
        python @args
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "✅ Cleanup erfolgreich abgeschlossen!" $Green
            
            if ($IsDryRun) {
                Write-ColorOutput "💡 Führen Sie das Skript ohne -DryRun aus, um die Änderungen anzuwenden" $Cyan
            }
        } else {
            Write-ColorOutput "❌ Cleanup mit Fehlern beendet" $Red
            exit $LASTEXITCODE
        }
    }
    catch {
        Write-ColorOutput "❌ Fehler beim Ausführen: $($_.Exception.Message)" $Red
        exit 1
    }
}

function Install-Dependencies {
    Write-ColorOutput "📦 Prüfe Python-Abhängigkeiten..." $Blue
    
    $requirementsFile = Join-Path $PSScriptRoot "requirements.txt"
    
    if (-not (Test-Path $requirementsFile)) {
        Write-ColorOutput "❌ requirements.txt nicht gefunden!" $Red
        exit 1
    }
    
    try {
        python -m pip install -r $requirementsFile --quiet --user
        Write-ColorOutput "✅ Abhängigkeiten sind verfügbar" $Green
    }
    catch {
        Write-ColorOutput "⚠️  Installiere Abhängigkeiten..." $Yellow
        python -m pip install -r $requirementsFile --user
    }
}

# Main execution
Show-Banner

# Validate repository format
$repoInfo = Validate-Repository $Repository

Write-ColorOutput "📂 Repository: $($repoInfo.Owner)/$($repoInfo.Repo)" $Blue

if ($DryRun) {
    Write-ColorOutput "🔍 Modus: Simulation (Dry Run)" $Yellow
} else {
    Write-ColorOutput "🔧 Modus: Echte Bereinigung" $Red
}

Write-ColorOutput ""

# Install dependencies
Install-Dependencies

Write-ColorOutput ""

# Run cleanup
Invoke-Cleanup $repoInfo.Owner $repoInfo.Repo $DryRun

Write-ColorOutput ""
Write-ColorOutput "🎉 Vorgang abgeschlossen!" $Green

if ($DryRun) {
    Write-ColorOutput ""
    Write-ColorOutput "📋 Nächste Schritte:" $Cyan
    Write-ColorOutput "  1. Überprüfen Sie die angezeigten Aktionen" $Cyan
    Write-ColorOutput "  2. Führen Sie das Skript ohne -DryRun aus:" $Cyan
    Write-ColorOutput "     .\quick_cleanup.ps1 -Repository '$Repository'" $Yellow
}
