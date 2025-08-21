# Workflow Validation Script
$ErrorActionPreference = "Stop"

Write-Host "Validating GitHub Actions Workflows" -ForegroundColor Cyan
Write-Host ""

$workflowPath = Join-Path (Join-Path (Join-Path $PSScriptRoot "..") ".github") "workflows"
$workflows = @(
    "dotnet-desktop-build.yml",
    "dotnet-build.yml", 
    "nodejs-build.yml"
)

$issues = @()

foreach ($workflow in $workflows) {
    $file = Join-Path $workflowPath $workflow
    
    if (Test-Path $file) {
        Write-Host "Checking: $workflow" -ForegroundColor Yellow
        
        $content = Get-Content $file -Raw
        
        # Check for secrets in if conditions
        if ($content -match 'if:\s*.*\$\{\{\s*secrets\.') {
            $issues += "$workflow : Contains secrets in if conditions"
        }
        
        # Check for GITHUB_TOKEN as secret name
        if ($content -match 'secrets:\s*GITHUB_TOKEN:') {
            $issues += "$workflow : Uses reserved name GITHUB_TOKEN in secrets"
        }
        
        Write-Host "  Validated" -ForegroundColor Green
    } else {
        Write-Host "  File not found: $file" -ForegroundColor Yellow
    }
}

Write-Host ""

if ($issues.Count -gt 0) {
    Write-Host "Validation Issues Found:" -ForegroundColor Red
    foreach ($issue in $issues) {
        Write-Host "  - $issue" -ForegroundColor Red
    }
    exit 1
} else {
    Write-Host "All workflows validated successfully!" -ForegroundColor Green
}