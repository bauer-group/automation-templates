#!/bin/bash

# 🚀 Automation Templates Deployment Tool
# Deploys reusable automations to target repositories while keeping logic centralized

set -euo pipefail

# Configuration
TEMPLATE_REPO="bauer-group/automation-templates"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/deploy-config.yml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

show_help() {
    cat << EOF
🚀 Automation Templates Deployment Tool

USAGE:
    $0 [OPTIONS] <target-repo>

ARGUMENTS:
    target-repo         Target repository (owner/repo format)

OPTIONS:
    -p, --profile PROFILE    Use deployment profile (see deploy-config.yml)
    -w, --workflows LIST     Comma-separated list of workflows to deploy
    -a, --actions LIST       Comma-separated list of actions to deploy
    -c, --config PATH        Path to configuration file
    -f, --force             Force deployment (overwrite existing files)
    -d, --dry-run           Show what would be deployed without making changes
    -h, --help              Show this help message

PROFILES:
    basic                   Core workflows (CI/CD, security, docs)
    complete               All available automations
    security-focused       Security and compliance workflows only
    docs-only              Documentation automation only
    custom                 Use custom workflow/action selection

EXAMPLES:
    # Deploy basic profile to a repository
    $0 --profile basic owner/my-repo

    # Deploy specific workflows
    $0 --workflows "ci-cd,security-management" owner/my-repo

    # Dry run to see what would be deployed
    $0 --profile complete --dry-run owner/my-repo

    # Force deployment with custom config
    $0 --config ./my-config.yml --force owner/my-repo

CONFIGURATION:
    Edit deploy-config.yml to customize deployment profiles and settings.
    See tools/deploy-config.yml for examples.

EOF
}

# Parse command line arguments
parse_arguments() {
    PROFILE=""
    WORKFLOWS=""
    ACTIONS=""
    CONFIG_FILE="$SCRIPT_DIR/deploy-config.yml"
    FORCE=false
    DRY_RUN=false
    TARGET_REPO=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--profile)
                PROFILE="$2"
                shift 2
                ;;
            -w|--workflows)
                WORKFLOWS="$2"
                shift 2
                ;;
            -a|--actions)
                ACTIONS="$2"
                shift 2
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -f|--force)
                FORCE=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
            *)
                if [[ -z "$TARGET_REPO" ]]; then
                    TARGET_REPO="$1"
                else
                    log_error "Too many arguments: $1"
                    show_help
                    exit 1
                fi
                shift
                ;;
        esac
    done

    if [[ -z "$TARGET_REPO" ]]; then
        log_error "Target repository is required"
        show_help
        exit 1
    fi
}

# Load configuration
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi

    log_info "Loading configuration from $CONFIG_FILE"
}

# Get workflows and actions based on profile
get_deployment_items() {
    case "$PROFILE" in
        basic)
            WORKFLOWS="ci-cd,security-management,documentation,teams-notifications"
            ACTIONS="teams-notification,security-generate,readme-generate"
            ;;
        complete)
            WORKFLOWS="ci-cd,security-management,documentation,teams-notifications,docker-hub,release-management"
            ACTIONS="teams-notification,security-generate,readme-generate,docker-build,version-bump"
            ;;
        security-focused)
            WORKFLOWS="security-management,teams-notifications"
            ACTIONS="security-generate,teams-notification"
            ;;
        docs-only)
            WORKFLOWS="documentation"
            ACTIONS="readme-generate,security-generate"
            ;;
        custom)
            # Use provided workflows and actions
            ;;
        "")
            if [[ -z "$WORKFLOWS" && -z "$ACTIONS" ]]; then
                log_error "Either provide a profile or specify workflows/actions"
                exit 1
            fi
            ;;
        *)
            log_error "Unknown profile: $PROFILE"
            exit 1
            ;;
    esac
}

# Generate workflow file for target repository
generate_workflow() {
    local workflow_name="$1"
    local target_file="$2"
    
    cat > "$target_file" << EOF
name: 🔄 $workflow_name (via Automation Templates)

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
    uses: $TEMPLATE_REPO/.github/workflows/$workflow_name.yml@main
    secrets: inherit
    with:
      # Pass any additional parameters here
      repository-name: \${{ github.repository }}
EOF
}

# Generate action reference for target repository
generate_action_reference() {
    local action_name="$1"
    local target_dir="$2"
    
    mkdir -p "$target_dir"
    
    cat > "$target_dir/action.yml" << EOF
name: '$action_name (via Automation Templates)'
description: 'Centralized $action_name action from automation templates'

# This action references the centralized automation templates
# Source: https://github.com/$TEMPLATE_REPO/.github/actions/$action_name

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
      uses: $TEMPLATE_REPO/.github/actions/$action_name@main
      with:
        # Pass through all inputs
        config-file: \${{ inputs.config-file }}
EOF
}

# Create configuration template for target repository
create_config_template() {
    local target_dir="$1"
    
    mkdir -p "$target_dir/.github/config/automation-templates"
    
    cat > "$target_dir/.github/config/automation-templates/config.yml" << EOF
# 🚀 Automation Templates Configuration
# Configuration for centralized automation templates from:
# https://github.com/$TEMPLATE_REPO

# Repository Information
repository:
  name: \${{ github.repository }}
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
EOF
}

# Create setup documentation
create_setup_docs() {
    local target_dir="$1"
    
    cat > "$target_dir/AUTOMATION-SETUP.md" << EOF
# 🚀 Automation Templates Setup

This repository uses centralized automation templates from [\`$TEMPLATE_REPO\`](https://github.com/$TEMPLATE_REPO).

## 📋 What's Deployed

### Workflows
$(echo "$WORKFLOWS" | tr ',' '\n' | sed 's/^/- /')

### Actions
$(echo "$ACTIONS" | tr ',' '\n' | sed 's/^/- /')

## ⚙️ Configuration

### Required Secrets
Add these secrets to your repository:

| Secret | Description | Required For |
|--------|-------------|--------------|
| \`TEAMS_WEBHOOK_URL\` | Microsoft Teams webhook URL | Teams notifications |
| \`DOCKER_PASSWORD\` | Docker Hub password/token | Docker workflows |
| \`GITGUARDIAN_API_KEY\` | GitGuardian API key | Security scanning |

### Repository Variables
Configure these repository variables:

| Variable | Description | Default |
|----------|-------------|---------|
| \`TEAMS_NOTIFICATION_LEVEL\` | Notification level (all/errors-only) | errors-only |
| \`TEAMS_MENTION_ON_FAILURE\` | Users to mention on failures | |
| \`TEAMS_MENTION_ON_PR_REVIEW\` | Users to mention for PR reviews | |

### Configuration File
Customize the automation behavior by editing:
\`.github/config/automation-templates/config.yml\`

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
EOF
}

# Deploy to target repository
deploy_automations() {
    local target_repo="$1"
    
    log_info "Deploying automations to $target_repo"
    
    # Create temporary directory for deployment files
    local temp_dir=$(mktemp -d)
    local workflows_dir="$temp_dir/.github/workflows"
    local actions_dir="$temp_dir/.github/actions"
    
    mkdir -p "$workflows_dir" "$actions_dir"
    
    # Generate workflows
    if [[ -n "$WORKFLOWS" ]]; then
        log_info "Generating workflows: $WORKFLOWS"
        IFS=',' read -ra WORKFLOW_ARRAY <<< "$WORKFLOWS"
        for workflow in "${WORKFLOW_ARRAY[@]}"; do
            workflow=$(echo "$workflow" | xargs)  # trim whitespace
            log_info "  - $workflow"
            generate_workflow "$workflow" "$workflows_dir/$workflow.yml"
        done
    fi
    
    # Generate action references
    if [[ -n "$ACTIONS" ]]; then
        log_info "Generating action references: $ACTIONS"
        IFS=',' read -ra ACTION_ARRAY <<< "$ACTIONS"
        for action in "${ACTION_ARRAY[@]}"; do
            action=$(echo "$action" | xargs)  # trim whitespace
            log_info "  - $action"
            generate_action_reference "$action" "$actions_dir/$action"
        done
    fi
    
    # Create configuration template
    create_config_template "$temp_dir"
    
    # Create setup documentation
    create_setup_docs "$temp_dir"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY RUN - Files that would be created:"
        find "$temp_dir" -type f | sed "s|$temp_dir||g" | sort
        rm -rf "$temp_dir"
        return
    fi
    
    # Here you would implement the actual deployment logic
    # This could use git commands, GitHub CLI, or GitHub API
    log_warning "Actual deployment to repository not implemented yet"
    log_info "Generated files are in: $temp_dir"
    log_info "You can manually copy these files to your target repository"
    
    # For now, just show what was generated
    log_success "Deployment preparation completed!"
    log_info "Generated files:"
    find "$temp_dir" -type f | sed "s|$temp_dir||g" | sort
}

# Main execution
main() {
    log_info "🚀 Automation Templates Deployment Tool"
    
    parse_arguments "$@"
    load_config
    get_deployment_items
    
    log_info "Target repository: $TARGET_REPO"
    log_info "Profile: ${PROFILE:-custom}"
    log_info "Workflows: ${WORKFLOWS:-none}"
    log_info "Actions: ${ACTIONS:-none}"
    
    deploy_automations "$TARGET_REPO"
}

# Run main function with all arguments
main "$@"