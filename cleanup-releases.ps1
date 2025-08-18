# PowerShell script to cleanup all releases and tags
# This script will delete all GitHub releases and git tags

$owner = "bauer-group"
$repo = "automation-templates"

# Get GitHub token from environment or prompt
$token = $env:GITHUB_TOKEN
if (-not $token) {
    $token = Read-Host "Geben Sie Ihr GitHub Personal Access Token ein" -AsSecureString
    $token = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($token))
}

$headers = @{
    "Authorization" = "token $token"
    "Accept" = "application/vnd.github.v3+json"
}

Write-Host "🧹 Bereinige alle GitHub Releases und Tags..." -ForegroundColor Yellow

# Get all releases
try {
    $releases = Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repo/releases" -Headers $headers -Method Get
    
    foreach ($release in $releases) {
        Write-Host "🗑️  Lösche Release: $($release.tag_name) (ID: $($release.id))" -ForegroundColor Red
        try {
            Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repo/releases/$($release.id)" -Headers $headers -Method Delete
            Write-Host "✅ Release $($release.tag_name) gelöscht" -ForegroundColor Green
        }
        catch {
            Write-Host "❌ Fehler beim Löschen von Release $($release.tag_name): $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}
catch {
    Write-Host "❌ Fehler beim Abrufen der Releases: $($_.Exception.Message)" -ForegroundColor Red
}

# Get all tags
Write-Host "🏷️  Bereinige Git Tags..." -ForegroundColor Yellow

try {
    $tags = git tag -l
    foreach ($tag in $tags) {
        if ($tag) {
            Write-Host "🗑️  Lösche Tag: $tag" -ForegroundColor Red
            
            # Delete from remote
            git push origin --delete $tag 2>$null
            
            # Delete locally
            git tag -d $tag 2>$null
            
            Write-Host "✅ Tag $tag gelöscht" -ForegroundColor Green
        }
    }
}
catch {
    Write-Host "❌ Fehler beim Löschen der Tags: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "🧽 Bereinige lokales Repository..." -ForegroundColor Yellow

# Reset release-please state files
Write-Host "📝 Setze Release Please Konfiguration zurück..." -ForegroundColor Yellow

# Update manifest to start fresh
$manifestPath = ".\.github\config\.release-please-manifest.json"
if (Test-Path $manifestPath) {
    $manifestContent = @{
        "." = "0.1.0"
    }
    $manifestContent | ConvertTo-Json | Set-Content $manifestPath -Encoding UTF8
    Write-Host "✅ Release-Please Manifest auf 0.1.0 zurückgesetzt" -ForegroundColor Green
}

# Clear CHANGELOG
$changelogPath = ".\CHANGELOG.MD"
if (Test-Path $changelogPath) {
    "" | Set-Content $changelogPath -Encoding UTF8
    Write-Host "✅ CHANGELOG.MD geleert" -ForegroundColor Green
}

Write-Host "✨ Bereinigung abgeschlossen! Repository ist bereit für einen Neustart." -ForegroundColor Green
Write-Host "💡 Führen Sie 'git add .' und 'git commit' aus, um die Änderungen zu übernehmen." -ForegroundColor Cyan
