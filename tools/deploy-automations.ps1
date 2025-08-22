# 🚀 Automation Templates Deployment Tool (PowerShell)
# Deploys reusable automations to target repositories while keeping logic centralized

param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$TargetRepo,
    
    [Parameter()]
    [string]$Profile = "",
    
    [Parameter()]
    [string]$Workflows = "",
    
    [Parameter()]
    [string]$Actions = "",
    
    [Parameter()]
    [string]$ConfigFile = "",
    
    [Parameter()]
    [switch]$Force,
    
    [Parameter()]
    [switch]$DryRun,
    
    [Parameter()]
    [switch]$Help
)

# Configuration
$TEMPLATE_REPO = "bauer-group/automation-templates"
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
if ($ConfigFile -eq "") {
    $ConfigFile = Join-Path $SCRIPT_DIR "deploy-config.yml"
}

# Helper functions
function Write-Info { param($Message) Write-Host "ℹ️  $Message" -ForegroundColor Blue }
function Write-Success { param($Message) Write-Host "✅ $Message" -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host "⚠️  $Message" -ForegroundColor Yellow }
function Write-Error { param($Message) Write-Host "❌ $Message" -ForegroundColor Red }

function Show-Help {
    @"
🚀 Automation Templates Deployment Tool

USAGE:
    .\deploy-automations.ps1 [OPTIONS] <target-repo>

ARGUMENTS:
    target-repo         Target repository (owner/repo format)

OPTIONS:
    -Profile PROFILE        Use deployment profile (see deploy-config.yml)
    -Workflows LIST         Comma-separated list of workflows to deploy
    -Actions LIST           Comma-separated list of actions to deploy
    -ConfigFile PATH        Path to configuration file
    -Force                  Force deployment (overwrite existing files)
    -DryRun                 Show what would be deployed without making changes
    -Help                   Show this help message

PROFILES:
    basic                   Core workflows (CI/CD, security, docs)
    complete               All available automations
    security-focused       Security and compliance workflows only
    docs-only              Documentation automation only
    custom                 Use custom workflow/action selection

EXAMPLES:
    # Deploy basic profile to a repository
    .\deploy-automations.ps1 -Profile basic owner/my-repo

    # Deploy specific workflows
    .\deploy-automations.ps1 -Workflows "ci-cd,security-management" owner/my-repo

    # Dry run to see what would be deployed
    .\deploy-automations.ps1 -Profile complete -DryRun owner/my-repo

    # Force deployment with custom config
    .\deploy-automations.ps1 -ConfigFile .\my-config.yml -Force owner/my-repo

CONFIGURATION:
    Edit deploy-config.yml to customize deployment profiles and settings.
    See tools/deploy-config.yml for examples.

"@
}

function Get-DeploymentItems {
    switch ($Profile) {
        "basic" {
            $script:Workflows = "ci-cd,security-management,documentation,teams-notifications"
            $script:Actions = "teams-notification,security-generate,readme-generate"
        }
        "complete" {
            $script:Workflows = "ci-cd,security-management,documentation,teams-notifications,docker-hub,release-management"
            $script:Actions = "teams-notification,security-generate,readme-generate,docker-build,version-bump"
        }
        "security-focused" {
            $script:Workflows = "security-management,teams-notifications"
            $script:Actions = "security-generate,teams-notification"
        }
        "docs-only" {
            $script:Workflows = "documentation"
            $script:Actions = "readme-generate,security-generate"
        }
        "custom" {
            # Use provided workflows and actions
        }
        "" {
            if ($Workflows -eq "" -and $Actions -eq "") {
                Write-Error "Either provide a profile or specify workflows/actions"
                exit 1
            }
        }
        default {
            Write-Error "Unknown profile: $Profile"
            exit 1
        }
    }
}

function New-WorkflowFile {
    param(
        [string]$WorkflowName,
        [string]$TargetFile
    )
    
    $content = @"
name: 🔄 $WorkflowName (via Automation Templates)

# This workflow uses centralized automation templates
# Source: https://github.com/$TEMPLATE_REPO
# Configuration: Customize via repository variables and secrets

on:
  workflow_call:
    secrets:
      TEAMS_WEBHOOK_URL:
        required: false
      DOCKER_PASSWORD:
        required: false
      GITGUARDIAN_API_KEY:
        required: false

  # Enable manual triggers for testing
  workflow_dispatch:

jobs:
  delegate-to-automation-templates:
    name: 🚀 Execute via Automation Templates
    uses: $TEMPLATE_REPO/.github/workflows/$WorkflowName.yml@main
    secrets: inherit
    with:
      # Pass any additional parameters here
      repository-name: `${{ github.repository }}
"@
    
    $content | Out-File -FilePath $TargetFile -Encoding UTF8
}

function New-ActionReference {
    param(
        [string]$ActionName,
        [string]$TargetDir
    )
    
    New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
    
    $content = @"
name: '$ActionName (via Automation Templates)'
description: 'Centralized $ActionName action from automation templates'

# This action references the centralized automation templates
# Source: https://github.com/$TEMPLATE_REPO/.github/actions/$ActionName

inputs:
  # Add any required inputs here - these will be passed through
  config-file:
    description: 'Configuration file path'
    required: false
    default: '.github/config/automation-templates/config.yml'

runs:
  using: 'composite'
  steps:
    - name: 🚀 Execute Centralized Action
      uses: $TEMPLATE_REPO/.github/actions/$ActionName@main
      with:
        # Pass through all inputs
        config-file: `${{ inputs.config-file }}
"@
    
    $actionFile = Join-Path $TargetDir "action.yml"
    $content | Out-File -FilePath $actionFile -Encoding UTF8
}

function New-ConfigTemplate {
    param([string]$TargetDir)
    
    $configDir = Join-Path $TargetDir ".github\config\automation-templates"
    New-Item -ItemType Directory -Path $configDir -Force | Out-Null
    
    $content = @"
# 🚀 Automation Templates Configuration
# Configuration for centralized automation templates from:
# https://github.com/$TEMPLATE_REPO

# Repository Information
repository:
  name: `${{ github.repository }}
  description: "Your repository description"
  
# Teams Notifications
teams:
  notification_level: "errors-only"  # or "all"
  webhook_url_secret: "TEAMS_WEBHOOK_URL"
  
# Security Policy
security:
  policy_version: "1.0.0"
  review_cycle: 12  # months
  
# Documentation
documentation:
  auto_update: true
  include_security: true
  include_contributing: true
  
# Docker Hub Integration
docker:
  enabled: false
  registry_secret: "DOCKER_PASSWORD"
  
# Release Management
releases:
  auto_tag: true
  semantic_versioning: true

# Custom Variables (add your specific configuration here)
custom:
  # Example: project_type: "web-application"
  # Example: deployment_environment: "production"
"@
    
    $configFile = Join-Path $configDir "config.yml"
    $content | Out-File -FilePath $configFile -Encoding UTF8
}

function New-SetupDocs {
    param([string]$TargetDir)
    
    $content = @"
# 🚀 Automation Templates Setup

This repository uses centralized automation templates from [``$TEMPLATE_REPO``](https://github.com/$TEMPLATE_REPO).

## 📋 What's Deployed

### Workflows
$($Workflows -split ',' | ForEach-Object { "- $_" } | Out-String)

### Actions
$($Actions -split ',' | ForEach-Object { "- $_" } | Out-String)

## ⚙️ Configuration

### Required Secrets
Add these secrets to your repository:

| Secret | Description | Required For |
|--------|-------------|--------------|
| ``TEAMS_WEBHOOK_URL`` | Microsoft Teams webhook URL | Teams notifications |
| ``DOCKER_PASSWORD`` | Docker Hub password/token | Docker workflows |
| ``GITGUARDIAN_API_KEY`` | GitGuardian API key | Security scanning |

### Repository Variables
Configure these repository variables:

| Variable | Description | Default |
|----------|-------------|---------|
| ``TEAMS_NOTIFICATION_LEVEL`` | Notification level (all/errors-only) | errors-only |
| ``TEAMS_MENTION_ON_FAILURE`` | Users to mention on failures | |
| ``TEAMS_MENTION_ON_PR_REVIEW`` | Users to mention for PR reviews | |

### Configuration File
Customize the automation behavior by editing:
``.github/config/automation-templates/config.yml``

## 🔄 Updating Automations

The automations are centrally maintained. No local updates needed!
All workflows automatically use the latest version from the main repository.

## 🛠️ Troubleshooting

1. **Workflows not running**: Check if secrets are properly configured
2. **Permission errors**: Ensure workflows have necessary permissions
3. **Configuration issues**: Validate YAML syntax in config files

## 📞 Support

- **Documentation**: [Automation Templates Documentation](https://github.com/$TEMPLATE_REPO)
- **Issues**: [Report Issues](https://github.com/$TEMPLATE_REPO/issues)
- **Updates**: [Check Releases](https://github.com/$TEMPLATE_REPO/releases)

---

**🎯 All automation logic remains centralized for easy maintenance and updates!**
"@
    
    $setupFile = Join-Path $TargetDir "AUTOMATION-SETUP.md"
    $content | Out-File -FilePath $setupFile -Encoding UTF8
}

function Deploy-Automations {
    param([string]$TargetRepo)
    
    Write-Info "Deploying automations to $TargetRepo"
    
    # Create temporary directory for deployment files
    $tempDir = [System.IO.Path]::GetTempPath() + [System.Guid]::NewGuid().ToString()
    $workflowsDir = Join-Path $tempDir ".github\workflows"
    $actionsDir = Join-Path $tempDir ".github\actions"
    
    New-Item -ItemType Directory -Path $workflowsDir -Force | Out-Null
    New-Item -ItemType Directory -Path $actionsDir -Force | Out-Null
    
    # Generate workflows
    if ($Workflows -ne "") {
        Write-Info "Generating workflows: $Workflows"
        $workflowArray = $Workflows -split ','
        foreach ($workflow in $workflowArray) {
            $workflow = $workflow.Trim()
            Write-Info "  - $workflow"
            $targetFile = Join-Path $workflowsDir "$workflow.yml"
            New-WorkflowFile $workflow $targetFile
        }
    }
    
    # Generate action references
    if ($Actions -ne "") {
        Write-Info "Generating action references: $Actions"
        $actionArray = $Actions -split ','
        foreach ($action in $actionArray) {
            $action = $action.Trim()
            Write-Info "  - $action"
            $targetDir = Join-Path $actionsDir $action
            New-ActionReference $action $targetDir
        }
    }
    
    # Create configuration template
    New-ConfigTemplate $tempDir
    
    # Create setup documentation
    New-SetupDocs $tempDir
    
    if ($DryRun) {
        Write-Info "DRY RUN - Files that would be created:"
        Get-ChildItem -Path $tempDir -Recurse -File | ForEach-Object {
            $_.FullName.Replace($tempDir, "")
        } | Sort-Object
        Remove-Item -Path $tempDir -Recurse -Force
        return
    }
    
    # Here you would implement the actual deployment logic
    # This could use git commands, GitHub CLI, or GitHub API
    Write-Warning "Actual deployment to repository not implemented yet"
    Write-Info "Generated files are in: $tempDir"
    Write-Info "You can manually copy these files to your target repository"
    
    # For now, just show what was generated
    Write-Success "Deployment preparation completed!"
    Write-Info "Generated files:"
    Get-ChildItem -Path $tempDir -Recurse -File | ForEach-Object {
        $_.FullName.Replace($tempDir, "")
    } | Sort-Object
}

# Main execution
function Main {
    Write-Info "🚀 Automation Templates Deployment Tool"
    
    if ($Help) {
        Show-Help
        exit 0
    }
    
    if (!(Test-Path $ConfigFile)) {
        Write-Error "Configuration file not found: $ConfigFile"
        exit 1
    }
    
    Get-DeploymentItems
    
    Write-Info "Target repository: $TargetRepo"
    Write-Info "Profile: $(if ($Profile) { $Profile } else { 'custom' })"
    Write-Info "Workflows: $(if ($Workflows) { $Workflows } else { 'none' })"
    Write-Info "Actions: $(if ($Actions) { $Actions } else { 'none' })"
    
    Deploy-Automations $TargetRepo
}

# Run main function
Main