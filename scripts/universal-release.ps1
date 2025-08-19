# 🚀 Universal Release Script (PowerShell)
# Works with ANY repository, regardless of commit history

param(
    [string]$BumpType = "auto",
    [string]$CustomVersion = "",
    [switch]$DryRun = $false,
    [switch]$Force = $false
)

# Configuration
$RepoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$ManifestFile = Join-Path $RepoRoot ".github\config\.release-please-manifest.json"
$ConfigFile = Join-Path $RepoRoot ".github\config\release-please-config.json"

# Colors for output
$Colors = @{
    Red    = "Red"
    Green  = "Green"
    Yellow = "Yellow"
    Blue   = "Blue"
    Cyan   = "Cyan"
}

function Write-Log {
    param([string]$Message, [string]$Color = "Blue")
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message" -ForegroundColor $Colors[$Color]
}

function Write-Warning-Custom {
    param([string]$Message)
    Write-Host "[WARNING] $Message" -ForegroundColor $Colors["Yellow"]
}

function Write-Error-Custom {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor $Colors["Red"]
}

function Write-Success {
    param([string]$Message)
    Write-Host "[SUCCESS] $Message" -ForegroundColor $Colors["Green"]
}

# Function to get current version
function Get-CurrentVersion {
    $version = "0.0.0"
    
    # Try manifest file first
    if (Test-Path $ManifestFile) {
        try {
            $manifest = Get-Content $ManifestFile | ConvertFrom-Json
            if ($manifest."." -and $manifest."." -ne "null") {
                $version = $manifest."."
            }
        }
        catch {
            Write-Warning-Custom "Could not parse manifest file: $_"
        }
    }
    
    # Fallback to git tags
    if ($version -eq "0.0.0") {
        try {
            $tag = git describe --tags --abbrev=0 2>$null
            if ($tag) {
                $version = $tag -replace '^v', ''
            }
        }
        catch {
            Write-Warning-Custom "Could not get git tags: $_"
        }
    }
    
    return $version
}

# Function to increment version
function Step-Version {
    param(
        [string]$Version,
        [string]$BumpType = "patch"
    )
    
    $parts = $Version -split '\.'
    $major = [int]$parts[0]
    $minor = [int]$parts[1]
    $patch = [int]$parts[2]
    
    switch ($BumpType.ToLower()) {
        "major" { 
            return "$($major + 1).0.0" 
        }
        "minor" { 
            return "$major.$($minor + 1).0" 
        }
        "patch" { 
            return "$major.$minor.$($patch + 1)" 
        }
        default { 
            return $Version 
        }
    }
}

# Function to detect bump type from commits
function Get-BumpType {
    try {
        $lastTag = git describe --tags --abbrev=0 2>$null
        if (-not $lastTag) {
            $lastTag = git rev-list --max-parents=0 HEAD
        }
        
        # Get commits since last release
        $commits = git log "$lastTag..HEAD" --pretty=format:"%s" 2>$null
        if (-not $commits) {
            $commits = git log --pretty=format:"%s" -10
        }
        
        # Check for breaking changes or major features
        if ($commits -match "(?i)(BREAKING|major|breaking change)") {
            return "major"
        }
        
        # Check for new features
        if ($commits -match "(?i)(feat|feature|add|new)") {
            return "minor"
        }
        
        # Default to patch
        return "patch"
    }
    catch {
        Write-Warning-Custom "Could not detect bump type: $_"
        return "patch"
    }
}

# Function to generate changelog
function New-Changelog {
    param(
        [string]$Version,
        [string]$CurrentVersion
    )
    
    try {
        $lastTag = git describe --tags --abbrev=0 2>$null
        if (-not $lastTag) {
            $lastTag = git rev-list --max-parents=0 HEAD
        }
        
        $commits = git log "$lastTag..HEAD" --pretty=format:"- %s" --reverse 2>$null
        if (-not $commits) {
            $commits = git log --pretty=format:"- %s" -10
        }
        
        $repoUrl = "https://github.com/$($env:GITHUB_REPOSITORY)"
        if (-not $env:GITHUB_REPOSITORY) {
            $origin = git remote get-url origin 2>$null
            if ($origin -match "github\.com[:/]([^/]+/[^/]+)") {
                $repoUrl = "https://github.com/$($matches[1])"
            }
        }
        
        $changelog = @"
## 🚀 What's Changed in v$Version

### 📋 Changes since v$CurrentVersion

$($commits -join "`n")

### 🔗 Full Changelog

**Full Changelog**: $repoUrl/compare/v$CurrentVersion...v$Version

---

*This release was created using the Universal Release Script (PowerShell).*
"@
        
        return $changelog
    }
    catch {
        Write-Warning-Custom "Could not generate changelog: $_"
        return "## 🚀 Release v$Version`n`nAutomated release creation."
    }
}

# Function to create release
function New-Release {
    param(
        [string]$Version,
        [string]$Changelog,
        [string]$CurrentVersion
    )
    
    Write-Log "Creating release v$Version..." "Blue"
    
    if ($DryRun) {
        Write-Log "DRY RUN - Would create release v$Version" "Cyan"
        Write-Log "Changelog:`n$Changelog" "Cyan"
        return
    }
    
    try {
        # Ensure directories exist
        $manifestDir = Split-Path $ManifestFile -Parent
        if (-not (Test-Path $manifestDir)) {
            New-Item -ItemType Directory -Path $manifestDir -Force | Out-Null
        }
        
        $configDir = Split-Path $ConfigFile -Parent
        if (-not (Test-Path $configDir)) {
            New-Item -ItemType Directory -Path $configDir -Force | Out-Null
        }
        
        # Update manifest file
        $manifest = @{ "." = $Version }
        $manifest | ConvertTo-Json | Set-Content $ManifestFile -Encoding UTF8
        
        # Create minimal config if it doesn't exist
        if (-not (Test-Path $ConfigFile)) {
            $config = @{
                "`$schema" = "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json"
                "packages" = @{
                    "." = @{
                        "release-type" = "simple"
                    }
                }
                "release-search-depth" = 1
                "commit-search-depth" = 1
            }
            $config | ConvertTo-Json -Depth 5 | Set-Content $ConfigFile -Encoding UTF8
        }
        
        # Configure git
        $gitUserName = $env:GIT_USER_NAME
        if (-not $gitUserName) { $gitUserName = "github-actions[bot]" }
        
        $gitUserEmail = $env:GIT_USER_EMAIL
        if (-not $gitUserEmail) { $gitUserEmail = "41898282+github-actions[bot]@users.noreply.github.com" }
        
        git config --global user.name $gitUserName
        git config --global user.email $gitUserEmail
        
        # Update CHANGELOG.MD
        $changelogFile = Join-Path $RepoRoot "CHANGELOG.MD"
        if (Test-Path $changelogFile) {
            $existingChangelog = Get-Content $changelogFile -Raw
            $newChangelog = "$Changelog`n`n---`n`n$existingChangelog"
        }
        else {
            $newChangelog = $Changelog
        }
        Set-Content $changelogFile $newChangelog -Encoding UTF8
        
        # Commit changes
        git add .
        $status = git status --porcelain
        if ($status) {
            git commit -m "chore: release v$Version

- Update version to $Version
- Update CHANGELOG.MD with release notes
- Automated release creation

[skip ci]"
        }
        else {
            Write-Warning-Custom "No changes to commit"
        }
        
        # Create tag
        git tag -a "v$Version" -m "Release v$Version"
        
        # Push changes
        $currentBranch = git branch --show-current
        try {
            git push origin $currentBranch
        }
        catch {
            Write-Warning-Custom "Failed to push branch: $_"
        }
        
        try {
            git push origin "v$Version"
        }
        catch {
            Write-Warning-Custom "Failed to push tag: $_"
        }
        
        # Create GitHub release if gh CLI is available
        $ghExists = Get-Command gh -ErrorAction SilentlyContinue
        if ($ghExists) {
            Write-Log "Creating GitHub release..." "Blue"
            try {
                gh release create "v$Version" --title "🚀 Release v$Version" --notes $Changelog --latest
            }
            catch {
                Write-Warning-Custom "Failed to create GitHub release: $_"
            }
        }
        else {
            Write-Warning-Custom "GitHub CLI not available, skipping GitHub release creation"
        }
        
        Write-Success "Release v$Version created successfully!"
    }
    catch {
        Write-Error-Custom "Failed to create release: $_"
        throw
    }
}

# Main function
function Main {
    Write-Log "🚀 Starting Universal Release Process..." "Green"
    
    # Change to repository root
    Set-Location $RepoRoot
    
    # Get current version
    $currentVersion = Get-CurrentVersion
    Write-Log "Current version: $currentVersion" "Blue"
    
    # Determine bump type
    if ($CustomVersion) {
        $newVersion = $CustomVersion
        Write-Log "Using custom version: $newVersion" "Blue"
    }
    else {
        $bumpType = if ($BumpType -eq "auto") { Get-BumpType } else { $BumpType }
        Write-Log "Bump type: $bumpType" "Blue"
        
        $newVersion = Step-Version -Version $currentVersion -BumpType $bumpType
        Write-Log "New version: $newVersion" "Blue"
    }
    
    # Generate changelog
    $changelog = New-Changelog -Version $newVersion -CurrentVersion $currentVersion
    
    # Create release
    New-Release -Version $newVersion -Changelog $changelog -CurrentVersion $currentVersion
    
    Write-Success "🎉 Release process completed!"
}

# Script execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        Main
    }
    catch {
        Write-Error-Custom "Release script failed: $_"
        exit 1
    }
}
