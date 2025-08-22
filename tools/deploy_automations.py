#!/usr/bin/env python3
"""
🚀 Automation Templates Deployment Tool
Deploys reusable automations to target repositories while keeping logic centralized
"""

import argparse
import json
import os
import shutil
import sys
import tempfile
import yaml
from pathlib import Path
from typing import Dict, List, Optional, Set
import subprocess
import logging

# Configuration
TEMPLATE_REPO = "bauer-group/automation-templates"
SCRIPT_DIR = Path(__file__).parent
DEFAULT_CONFIG = SCRIPT_DIR / "deploy-config.yml"

# Logging setup
logging.basicConfig(
    level=logging.INFO,
    format='%(message)s'
)
logger = logging.getLogger(__name__)

class Colors:
    """Terminal colors for output"""
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    NC = '\033[0m'  # No Color

def log_info(msg: str):
    logger.info(f"{Colors.BLUE}ℹ️  {msg}{Colors.NC}")

def log_success(msg: str):
    logger.info(f"{Colors.GREEN}✅ {msg}{Colors.NC}")

def log_warning(msg: str):
    logger.info(f"{Colors.YELLOW}⚠️  {msg}{Colors.NC}")

def log_error(msg: str):
    logger.error(f"{Colors.RED}❌ {msg}{Colors.NC}")

class DeploymentConfig:
    """Handles loading and parsing of deployment configuration"""
    
    def __init__(self, config_file: Path):
        self.config_file = config_file
        self.config = self._load_config()
    
    def _load_config(self) -> Dict:
        """Load configuration from YAML file"""
        if not self.config_file.exists():
            raise FileNotFoundError(f"Configuration file not found: {self.config_file}")
        
        with open(self.config_file, 'r', encoding='utf-8') as f:
            return yaml.safe_load(f)
    
    def get_profile(self, profile_name: str) -> Dict:
        """Get profile configuration by name"""
        profiles = self.config.get('profiles', {})
        if profile_name not in profiles:
            raise ValueError(f"Unknown profile: {profile_name}")
        return profiles[profile_name]
    
    def list_profiles(self) -> List[str]:
        """Get list of available profiles"""
        return list(self.config.get('profiles', {}).keys())

class AutomationDeployer:
    """Main deployment class"""
    
    def __init__(self, config: DeploymentConfig):
        self.config = config
        self.template_repo = TEMPLATE_REPO
        self.script_dir = SCRIPT_DIR
    
    def get_deployment_items(self, profile: str = "", workflows: str = "", 
                           actions: str = "") -> tuple[List[str], List[str]]:
        """Get workflows and actions based on profile or explicit selection"""
        
        if profile:
            profile_config = self.config.get_profile(profile)
            workflow_list = profile_config.get('workflows', [])
            action_list = profile_config.get('actions', [])
        else:
            workflow_list = [w.strip() for w in workflows.split(',') if w.strip()] if workflows else []
            action_list = [a.strip() for a in actions.split(',') if a.strip()] if actions else []
        
        if not workflow_list and not action_list:
            raise ValueError("Either provide a profile or specify workflows/actions")
        
        return workflow_list, action_list
    
    def generate_workflow(self, workflow_name: str) -> str:
        """Generate workflow file content for target repository"""
        return f"""name: 🔄 {workflow_name} (via Automation Templates)

# This workflow uses centralized automation templates
# Source: https://github.com/{self.template_repo}
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
    uses: {self.template_repo}/.github/workflows/{workflow_name}.yml@main
    secrets: inherit
    with:
      # Pass any additional parameters here
      repository-name: ${{{{ github.repository }}}}
"""
    
    def generate_action_reference(self, action_name: str) -> str:
        """Generate action reference for target repository"""
        return f"""name: '{action_name} (via Automation Templates)'
description: 'Centralized {action_name} action from automation templates'

# This action references the centralized automation templates
# Source: https://github.com/{self.template_repo}/.github/actions/{action_name}

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
      uses: {self.template_repo}/.github/actions/{action_name}@main
      with:
        # Pass through all inputs
        config-file: ${{{{ inputs.config-file }}}}
"""
    
    def copy_workflow_configs(self, target_dir: Path, workflows: List[str], project_type: str = ""):
        """Copy required configuration files for workflows"""
        config_base = target_dir / ".github" / "config"
        log_info("Copying required configuration files...")
        
        # Security policy config
        if any("security" in w for w in workflows):
            self._copy_directory_configs(config_base, "security-policy")
            self._copy_directory_configs(config_base, "security")
        
        # Teams notification configs
        if any("teams" in w for w in workflows):
            self._copy_directory_configs(config_base, "teams-notification")
        
        # Docker configs
        if any("docker" in w for w in workflows):
            self._copy_directory_configs(config_base, "docker-build")
        
        # Language-specific configs
        if project_type:
            self._copy_project_type_configs(config_base, project_type)
        
        # Additional configs based on workflows
        self._copy_workflow_specific_configs(config_base, workflows)
    
    def _copy_directory_configs(self, target_base: Path, config_dir: str):
        """Copy entire config directories"""
        source_dir = self.script_dir.parent / ".github" / "config" / config_dir
        target_dir = target_base / config_dir
        
        if source_dir.exists():
            log_info(f"  Copying {config_dir} configs...")
            target_dir.mkdir(parents=True, exist_ok=True)
            try:
                if target_dir.exists():
                    shutil.rmtree(target_dir)
                shutil.copytree(source_dir, target_dir)
            except Exception as e:
                log_warning(f"Could not copy all files from {config_dir}: {e}")
        else:
            log_warning(f"Source directory {source_dir} not found")
    
    def _copy_project_type_configs(self, config_base: Path, project_type: str):
        """Copy project-type specific configurations"""
        type_mapping = {
            "nodejs": ["nodejs-build"],
            "dotnet": ["dotnet-build", "dotnet-desktop-build"],
            "python": ["python-build"],
            "php": ["php-build"]
        }
        
        config_dirs = type_mapping.get(project_type, [])
        for config_dir in config_dirs:
            self._copy_directory_configs(config_base, config_dir)
    
    def _copy_workflow_specific_configs(self, config_base: Path, workflows: List[str]):
        """Copy workflow-specific configurations"""
        workflow_mapping = {
            "release": ["release"],
            "pr": ["pr-labeler"],
            "pull": ["pr-labeler"],
            "issue": ["issues"],
            "triage": ["issues"],
            "cleanup": ["repository-cleanup"],
            "maintenance": ["repository-cleanup"]
        }
        
        copied_dirs = set()
        for workflow in workflows:
            for keyword, config_dirs in workflow_mapping.items():
                if keyword in workflow.lower():
                    for config_dir in config_dirs:
                        if config_dir not in copied_dirs:
                            self._copy_directory_configs(config_base, config_dir)
                            copied_dirs.add(config_dir)
        
        # Always copy license configs
        self._copy_directory_configs(config_base, "license")
    
    def create_config_template(self, target_dir: Path) -> str:
        """Create main configuration template for target repository"""
        config_dir = target_dir / ".github" / "config" / "automation-templates"
        config_dir.mkdir(parents=True, exist_ok=True)
        
        content = f"""# 🚀 Automation Templates Configuration
# Configuration for centralized automation templates from:
# https://github.com/{self.template_repo}

# Repository Information
repository:
  name: ${{{{ github.repository }}}}
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
"""
        
        config_file = config_dir / "config.yml"
        with open(config_file, 'w', encoding='utf-8') as f:
            f.write(content)
        
        return str(config_file)
    
    def create_setup_docs(self, target_dir: Path, workflows: List[str], actions: List[str]) -> str:
        """Create setup documentation"""
        workflows_md = '\n'.join(f"- {w}" for w in workflows)
        actions_md = '\n'.join(f"- {a}" for a in actions)
        
        content = f"""# 🚀 Automation Templates Setup

This repository uses centralized automation templates from [`{self.template_repo}`](https://github.com/{self.template_repo}).

## 📋 What's Deployed

### Workflows
{workflows_md}

### Actions
{actions_md}

## ⚙️ Configuration

### Required Secrets
Add these secrets to your repository:

| Secret | Description | Required For |
|--------|-------------|--------------|
| `TEAMS_WEBHOOK_URL` | Microsoft Teams webhook URL | Teams notifications |
| `DOCKER_PASSWORD` | Docker Hub password/token | Docker workflows |
| `GITGUARDIAN_API_KEY` | GitGuardian API key | Security scanning |

### Repository Variables
Configure these repository variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `TEAMS_NOTIFICATION_LEVEL` | Notification level (all/errors-only) | errors-only |
| `TEAMS_MENTION_ON_FAILURE` | Users to mention on failures | |
| `TEAMS_MENTION_ON_PR_REVIEW` | Users to mention for PR reviews | |

### Configuration File
Customize the automation behavior by editing:
`.github/config/automation-templates/config.yml`

## 🔄 Updating Automations

The automations are centrally maintained. No local updates needed!
All workflows automatically use the latest version from the main repository.

## 🛠️ Troubleshooting

1. **Workflows not running**: Check if secrets are properly configured
2. **Permission errors**: Ensure workflows have necessary permissions
3. **Configuration issues**: Validate YAML syntax in config files

## 📞 Support

- **Documentation**: [Automation Templates Documentation](https://github.com/{self.template_repo})
- **Issues**: [Report Issues](https://github.com/{self.template_repo}/issues)
- **Updates**: [Check Releases](https://github.com/{self.template_repo}/releases)

---

**🎯 All automation logic remains centralized for easy maintenance and updates!**
"""
        
        setup_file = target_dir / "AUTOMATION-SETUP.md"
        with open(setup_file, 'w', encoding='utf-8') as f:
            f.write(content)
        
        return str(setup_file)
    
    def deploy_automations(self, target_repo: str, profile: str = "", workflows: str = "", 
                          actions: str = "", project_type: str = "", force: bool = False, 
                          dry_run: bool = False) -> Dict:
        """Deploy automations to target repository"""
        
        log_info(f"Deploying automations to {target_repo}")
        
        # Get deployment items
        workflow_list, action_list = self.get_deployment_items(profile, workflows, actions)
        
        # Create temporary directory
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            workflows_dir = temp_path / ".github" / "workflows"
            actions_dir = temp_path / ".github" / "actions"
            
            workflows_dir.mkdir(parents=True, exist_ok=True)
            actions_dir.mkdir(parents=True, exist_ok=True)
            
            created_files = []
            
            # Generate workflows
            if workflow_list:
                log_info(f"Generating workflows: {', '.join(workflow_list)}")
                for workflow in workflow_list:
                    log_info(f"  - {workflow}")
                    workflow_content = self.generate_workflow(workflow)
                    workflow_file = workflows_dir / f"{workflow}.yml"
                    
                    with open(workflow_file, 'w', encoding='utf-8') as f:
                        f.write(workflow_content)
                    created_files.append(str(workflow_file.relative_to(temp_path)))
            
            # Generate action references
            if action_list:
                log_info(f"Generating action references: {', '.join(action_list)}")
                for action in action_list:
                    log_info(f"  - {action}")
                    action_dir = actions_dir / action
                    action_dir.mkdir(parents=True, exist_ok=True)
                    
                    action_content = self.generate_action_reference(action)
                    action_file = action_dir / "action.yml"
                    
                    with open(action_file, 'w', encoding='utf-8') as f:
                        f.write(action_content)
                    created_files.append(str(action_file.relative_to(temp_path)))
            
            # Copy configuration files
            self.copy_workflow_configs(temp_path, workflow_list, project_type)
            
            # Find all created config files
            config_dir = temp_path / ".github" / "config"
            if config_dir.exists():
                for config_file in config_dir.rglob("*"):
                    if config_file.is_file():
                        created_files.append(str(config_file.relative_to(temp_path)))
            
            # Create configuration template
            config_file = self.create_config_template(temp_path)
            created_files.append(str(Path(config_file).relative_to(temp_path)))
            
            # Create setup documentation
            setup_file = self.create_setup_docs(temp_path, workflow_list, action_list)
            created_files.append(str(Path(setup_file).relative_to(temp_path)))
            
            if dry_run:
                log_info("DRY RUN - Files that would be created:")
                for file_path in sorted(created_files):
                    print(f"  {file_path}")
                return {
                    "status": "dry_run",
                    "files": created_files,
                    "temp_dir": None
                }
            
            # For now, copy to a local directory for manual deployment
            output_dir = Path.cwd() / f"deployment-{target_repo.replace('/', '-')}"
            if output_dir.exists() and not force:
                log_error(f"Output directory exists: {output_dir}")
                log_info("Use --force to overwrite")
                return {"status": "error", "message": "Output directory exists"}
            
            if output_dir.exists():
                shutil.rmtree(output_dir)
            
            shutil.copytree(temp_path, output_dir)
            
            log_success("Deployment preparation completed!")
            log_info(f"Generated files in: {output_dir}")
            log_info("You can manually copy these files to your target repository")
            
            return {
                "status": "success",
                "files": created_files,
                "output_dir": str(output_dir),
                "workflows": workflow_list,
                "actions": action_list
            }

def main():
    """Main entry point"""
    parser = argparse.ArgumentParser(
        description="🚀 Automation Templates Deployment Tool",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Deploy basic profile to a repository
  %(prog)s --profile basic owner/my-repo

  # Deploy specific workflows
  %(prog)s --workflows "ci-cd,security-management" owner/my-repo

  # Dry run to see what would be deployed
  %(prog)s --profile complete --dry-run owner/my-repo

  # Deploy with project type
  %(prog)s --profile basic --project-type nodejs owner/my-repo
        """
    )
    
    parser.add_argument("target_repo", help="Target repository (owner/repo format)")
    parser.add_argument("-p", "--profile", help="Use deployment profile")
    parser.add_argument("-w", "--workflows", help="Comma-separated list of workflows to deploy")
    parser.add_argument("-a", "--actions", help="Comma-separated list of actions to deploy")
    parser.add_argument("-t", "--project-type", help="Project type (nodejs, dotnet, python, php)")
    parser.add_argument("-c", "--config", default=DEFAULT_CONFIG, type=Path, 
                       help="Path to configuration file")
    parser.add_argument("-f", "--force", action="store_true", 
                       help="Force deployment (overwrite existing files)")
    parser.add_argument("-d", "--dry-run", action="store_true",
                       help="Show what would be deployed without making changes")
    parser.add_argument("--list-profiles", action="store_true",
                       help="List available deployment profiles")
    
    args = parser.parse_args()
    
    try:
        # Load configuration
        config = DeploymentConfig(args.config)
        
        if args.list_profiles:
            log_info("Available deployment profiles:")
            for profile in config.list_profiles():
                profile_config = config.get_profile(profile)
                print(f"  {profile:<15} - {profile_config.get('description', 'No description')}")
            return 0
        
        # Create deployer
        deployer = AutomationDeployer(config)
        
        log_info("🚀 Automation Templates Deployment Tool")
        log_info(f"Target repository: {args.target_repo}")
        log_info(f"Profile: {args.profile or 'custom'}")
        log_info(f"Project type: {args.project_type or 'none'}")
        
        # Deploy
        result = deployer.deploy_automations(
            target_repo=args.target_repo,
            profile=args.profile or "",
            workflows=args.workflows or "",
            actions=args.actions or "",
            project_type=args.project_type or "",
            force=args.force,
            dry_run=args.dry_run
        )
        
        if result["status"] == "error":
            log_error(result.get("message", "Unknown error"))
            return 1
        
        return 0
        
    except Exception as e:
        log_error(f"Deployment failed: {e}")
        return 1

if __name__ == "__main__":
    sys.exit(main())