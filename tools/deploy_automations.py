#!/usr/bin/env python3
"""
🚀 Automation Templates Deployment Tool
Deploys reusable automations to target repositories while keeping logic centralized

DEPRECATED - kept because it is unknown who still uses it. For a new
repository copy the caller from the workflow's documentation (docs/workflows/)
or from github/workflows/examples/. See tools/README.md.
"""

import argparse
import json
import os
import re
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
TEMPLATE_ROOT = SCRIPT_DIR.parent
DEFAULT_CONFIG = SCRIPT_DIR / "deploy-config.yml"

DEPRECATION_NOTICE = (
    "deploy_automations.py is deprecated. For a new repository copy the caller "
    "from the workflow's documentation (docs/workflows/) or from "
    "github/workflows/examples/ - those carry the triggers, inputs and permissions "
    "the template expects. The callers generated here start, but run on manual "
    "dispatch only."
)

# GitHub token scope levels, ordered by what they grant.
PERMISSION_LEVEL = {"none": 0, "read": 1, "write": 2}
# A job's `uses:` that calls another workflow of this repository.
NESTED_WORKFLOW = re.compile(
    r"^(?:\./|" + re.escape(TEMPLATE_REPO) + r"/)\.github/workflows/([\w.-]+\.ya?ml)(?:@\S+)?$")


def load_yaml(path: Path):
    with open(path, 'r', encoding='utf-8') as f:
        return yaml.safe_load(f)


def workflow_triggers(doc) -> Dict:
    """The `on:` block as a mapping of event -> config.

    YAML 1.1 reads a bare `on` key as boolean True. The short forms
    `on: workflow_call` and `on: [workflow_call, push]` mean the same events
    without configuration.
    """
    if not isinstance(doc, dict):
        return {}
    triggers = doc.get("on", doc.get(True))
    if isinstance(triggers, str):
        return {triggers: None}
    if isinstance(triggers, list):
        return {str(event): None for event in triggers}
    return triggers if isinstance(triggers, dict) else {}


def normalize_permissions(value, where: str = "") -> Optional[Dict[str, str]]:
    """A `permissions:` value as {scope: level}; None when there is none."""
    if value is None:
        return None
    if value in ({}, ""):
        return {}
    if isinstance(value, dict):
        return {str(k): str(v) for k, v in value.items()}
    if value in ("read-all", "write-all"):
        # The set of scopes behind these changes as GitHub adds and retires
        # scopes; expanding it from a list here would go stale and grant less
        # than the template requests.
        raise ValueError(f"{where}: requests `permissions: {value}`, which this tool cannot "
                         "turn into an explicit grant - write that caller by hand")
    raise ValueError(f"{where}: unknown permissions value {value!r}")


def merge_permissions(a: Dict[str, str], b: Dict[str, str]) -> Dict[str, str]:
    """Per scope the higher of the two levels."""
    merged = dict(a)
    for scope, level in b.items():
        if PERMISSION_LEVEL.get(level, 0) > PERMISSION_LEVEL.get(merged.get(scope, "none"), 0):
            merged[scope] = level
    return merged

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
    
    def __init__(self, config: DeploymentConfig, template_root: Path = TEMPLATE_ROOT):
        self.config = config
        self.template_repo = TEMPLATE_REPO
        self.template_root = Path(template_root)
        self._permission_cache: Dict[str, Dict[str, str]] = {}

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
    
    def _workflow_doc(self, file: str):
        path = self.template_root / ".github" / "workflows" / file
        return load_yaml(path) if path.is_file() else None

    def resolve_workflow(self, workflow_name: str) -> str:
        """File name of the reusable template behind `workflow_name`.

        Registry entries name their file; any other name must be a workflow
        file of this repository. Only templates with a `workflow_call` trigger
        can be called from another repository - GitHub rejects the run otherwise.
        """
        entry = self.config.config.get('workflows', {}).get(workflow_name) or {}
        file = entry.get('file') or f"{workflow_name}.yml"
        doc = self._workflow_doc(file)
        if doc is None:
            raise ValueError(f"Workflow '{workflow_name}': .github/workflows/{file} does not exist")
        if 'workflow_call' not in workflow_triggers(doc):
            raise ValueError(f"Workflow '{workflow_name}': {file} has no workflow_call trigger "
                             "and cannot be called from another repository")
        return file

    def required_permissions(self, file: str, _stack: tuple = ()) -> Dict[str, str]:
        """Every scope a template's jobs request, including the workflows it calls.

        A caller must grant at least this: a called workflow can only narrow
        the caller's permissions, and GitHub refuses to start the run
        (startup_failure) when a job asks for more than it was given.
        """
        if file in self._permission_cache:
            return self._permission_cache[file]
        doc = self._workflow_doc(file)
        if doc is None or file in _stack:
            return {}
        workflow_grant = normalize_permissions(doc.get('permissions'), file)
        total: Dict[str, str] = {}
        for job_id, job in (doc.get('jobs') or {}).items():
            if not isinstance(job, dict):
                continue
            grant = normalize_permissions(job.get('permissions'), f"{file} job {job_id}")
            if grant is None:
                grant = workflow_grant
            if grant is not None:
                total = merge_permissions(total, grant)
            nested = NESTED_WORKFLOW.match(str(job.get('uses') or ''))
            if nested and grant is None:
                # The nested call inherits what this job gets - from the caller.
                total = merge_permissions(total, self.required_permissions(nested.group(1), _stack + (file,)))
        self._permission_cache[file] = total
        return total

    def inheriting_jobs(self, file: str, _stack: tuple = ()) -> List[str]:
        """Jobs that set no permissions anywhere and so run with the caller's grant.

        What they need cannot be read from the template; the registry states
        it as `caller_permissions`.
        """
        doc = self._workflow_doc(file)
        if doc is None or file in _stack or doc.get('permissions') is not None:
            return []
        found: List[str] = []
        for job_id, job in (doc.get('jobs') or {}).items():
            if not isinstance(job, dict) or job.get('permissions') is not None:
                continue
            nested = NESTED_WORKFLOW.match(str(job.get('uses') or ''))
            if nested:
                found += self.inheriting_jobs(nested.group(1), _stack + (file,))
            else:
                found.append(f"{file}:{job_id}")
        return found

    def generate_workflow(self, workflow_name: str) -> str:
        """Generate workflow file content for target repository"""
        file = self.resolve_workflow(workflow_name)
        call = workflow_triggers(self._workflow_doc(file)).get('workflow_call') or {}
        entry = self.config.config.get('workflows', {}).get(workflow_name) or {}

        # contents: read as the floor - checkout needs it. Jobs of the template
        # without a permissions block run with exactly this grant; what they
        # need comes from the registry (caller_permissions).
        permissions = merge_permissions({"contents": "read"}, self.required_permissions(file))
        inheriting = self.inheriting_jobs(file)
        if inheriting:
            declared = entry.get('caller_permissions')
            if declared is None:
                log_warning(f"{workflow_name}: {', '.join(inheriting)} set no permissions and run with "
                            "the caller's grant - check what they need and extend the generated block")
            else:
                permissions = merge_permissions(permissions, normalize_permissions(declared, workflow_name) or {})
        permission_lines = "\n".join(f"      {scope}: {level}" for scope, level in sorted(permissions.items()))

        notes = ["    # What the called template and the workflows it calls request.",
                 "    # GitHub refuses to start the run when the caller grants less."]
        if inheriting:
            notes.append("    # Jobs without a permissions block of their own run with exactly these.")
        if inheriting and entry.get('caller_permissions') is None:
            notes.append("    # TODO: they may need more - see the template's documentation.")
        for line in str(entry.get('permissions_note') or '').strip().splitlines():
            notes.append(f"    # {line}")
        note_lines = "\n".join(notes)

        # Only inputs the template declares; a required one without a default
        # gets a placeholder the deploying user has to fill in.
        placeholders = {"boolean": "false", "number": "0"}
        input_lines = []
        for name, spec in (call.get('inputs') or {}).items():
            if isinstance(spec, dict) and spec.get('required') is True and 'default' not in spec:
                hint = str(spec.get('description') or '').strip().splitlines()
                hint = f" - {hint[0]}" if hint else ""
                value = placeholders.get(spec.get('type'), "''")
                input_lines.append(f"      {name}: {value}  # TODO: required{hint}")
        with_block = "    with:\n" + "\n".join(input_lines) + "\n" if input_lines else ""

        return f"""# Generated by tools/deploy_automations.py from {self.template_repo}.
# Runs on manual dispatch only: add the events it should react to under `on:`.
# The template's documentation lists the ones it expects.
name: 🔄 {workflow_name} (via Automation Templates)

on:
  workflow_dispatch:
  workflow_call:

permissions: {{}}

jobs:
  delegate-to-automation-templates:
    name: 🚀 Execute via Automation Templates
{note_lines}
    permissions:
{permission_lines}
    uses: {self.template_repo}/.github/workflows/{file}@main
    secrets: inherit
{with_block}"""

    def resolve_action(self, action_name: str) -> str:
        """Repository path of the action behind `action_name`."""
        entry = self.config.config.get('actions', {}).get(action_name) or {}
        path = (entry.get('path') or f".github/actions/{action_name}").strip('/')
        if not any((self.template_root / path / f).is_file() for f in ("action.yml", "action.yaml")):
            raise ValueError(f"Action '{action_name}': {path}/action.yml does not exist")
        return path

    def action_usage(self, action_name: str) -> str:
        """The step that uses the central action, for the setup documentation.

        No wrapper action is generated: a pass-through has to forward every
        input, and forwarding one always sends a value - the wrapper's frozen
        copy of the default, so a later default change in the central action
        never arrives. Referencing the action directly has no such copy.
        """
        path = self.resolve_action(action_name)
        meta_file = next(self.template_root / path / f for f in ("action.yml", "action.yaml")
                         if (self.template_root / path / f).is_file())
        meta = load_yaml(meta_file) or {}
        lines = [f"- uses: {self.template_repo}/{path}@main"]
        required = [(name, spec) for name, spec in (meta.get('inputs') or {}).items()
                    if isinstance(spec, dict) and spec.get('required') is True and 'default' not in spec]
        if required:
            lines.append("  with:")
            for name, spec in required:
                hint = str(spec.get('description') or '').strip().splitlines()
                hint = f" - {hint[0]}" if hint else ""
                lines.append(f"    {name}: ''  # TODO: required{hint}")
        return "\n".join(lines)

    def copy_workflow_configs(self, target_dir: Path, workflows: List[str], project_type: str = ""):
        """Copy required configuration files for workflows"""
        config_base = target_dir / ".github" / "config"
        log_info("Copying required configuration files...")
        
        # Security policy config
        if any("security" in w for w in workflows):
            self._copy_directory_configs(config_base, "security-policy")
        
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
        source_dir = self.template_root / ".github" / "config" / config_dir
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
        if actions:
            snippets = '\n\n'.join(f"`{a}`:\n\n```yaml\n{self.action_usage(a)}\n```" for a in actions)
            actions_md = ("Use these as steps in your own workflows. They point at the central\n"
                          "actions directly, so a default changed there reaches you on the next run.\n\n"
                          + snippets)
        else:
            actions_md = "- none"

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
            workflows_dir.mkdir(parents=True, exist_ok=True)

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
            
            # Actions are referenced directly; AUTOMATION-SETUP.md lists the steps
            if action_list:
                log_info(f"Listing action usage in AUTOMATION-SETUP.md: {', '.join(action_list)}")

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
  %(prog)s --workflows "documentation,security-management" owner/my-repo

  # Dry run to see what would be deployed
  %(prog)s --profile complete --dry-run owner/my-repo

  # Deploy with project type
  %(prog)s --profile basic --project-type nodejs owner/my-repo
        """
    )
    
    # Optional here so --list-profiles works on its own; required for a deployment below.
    parser.add_argument("target_repo", nargs="?", help="Target repository (owner/repo format)")
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
    if not args.list_profiles and not args.target_repo:
        parser.error("the following arguments are required: target_repo")
    log_warning(DEPRECATION_NOTICE)
    
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
