#!/usr/bin/env python3

# Workflow testing - documentation workflow trigger test
import os
import json
import subprocess
from datetime import datetime, timezone
from typing import Optional, Dict, Any
import urllib.request
import re

TEMPLATE_PATH = "docs/README.template.MD"
OUTPUT_PATH = "README.MD"

def get_initial_version() -> str:
    """
    Returns the initial semantic version to use when no tag exists.
    Can be overridden with the INIT_VERSION environment variable.
    Default: 0.1.0 (pre-1.0 development).
    """
    return os.getenv("INIT_VERSION", "0.1.0")

def get_latest_tag() -> Optional[str]:
    """
    Returns the latest tag (without leading 'v') or None if no tag exists.
    """
    try:
        tag = subprocess.check_output(
            ["git", "describe", "--tags", "--abbrev=0"],
            stderr=subprocess.STDOUT,
        ).decode().strip()
        return tag.lstrip("v")
    except Exception:
        return None

def get_git_info() -> Dict[str, str]:
    """
    Get git repository information
    """
    try:
        # Get remote URL
        remote_url = subprocess.check_output(
            ["git", "config", "--get", "remote.origin.url"],
            stderr=subprocess.STDOUT,
        ).decode().strip()
        
        # Parse GitHub URL
        if "github.com" in remote_url:
            # Extract owner/repo from various URL formats
            if remote_url.startswith("git@"):
                # git@github.com:owner/repo.git
                match = re.search(r"github\.com:([^/]+)/(.+?)(?:\.git)?$", remote_url)
            else:
                # https://github.com/owner/repo.git
                match = re.search(r"github\.com/([^/]+)/(.+?)(?:\.git)?$", remote_url)
            
            if match:
                owner, repo = match.groups()
                return {
                    "REPO_OWNER": owner,
                    "REPO_NAME": repo,
                    "REPO_URL": f"https://github.com/{owner}/{repo}",
                    "REPO_FULL_NAME": f"{owner}/{repo}"
                }
        
        # Get current branch
        current_branch = subprocess.check_output(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            stderr=subprocess.STDOUT,
        ).decode().strip()
        
        # Get commit count
        commit_count = subprocess.check_output(
            ["git", "rev-list", "--count", "HEAD"],
            stderr=subprocess.STDOUT,
        ).decode().strip()
        
        # Get last commit hash (short)
        last_commit = subprocess.check_output(
            ["git", "rev-parse", "--short", "HEAD"],
            stderr=subprocess.STDOUT,
        ).decode().strip()
        
        return {
            "REPO_OWNER": "unknown",
            "REPO_NAME": "unknown", 
            "REPO_URL": remote_url,
            "REPO_FULL_NAME": "unknown/unknown",
            "CURRENT_BRANCH": current_branch,
            "COMMIT_COUNT": commit_count,
            "LAST_COMMIT": last_commit
        }
        
    except Exception as e:
        print(f"Warning: Could not get git info: {e}")
        return {
            "REPO_OWNER": "unknown",
            "REPO_NAME": "unknown",
            "REPO_URL": "unknown",
            "REPO_FULL_NAME": "unknown/unknown",
            "CURRENT_BRANCH": "unknown",
            "COMMIT_COUNT": "0",
            "LAST_COMMIT": "unknown"
        }

def get_package_info() -> Dict[str, str]:
    """
    Get package information from package.json, setup.py, etc.
    """
    package_info = {
        "PACKAGE_NAME": "",
        "PACKAGE_VERSION": "",
        "PACKAGE_DESCRIPTION": "",
        "PACKAGE_AUTHOR": "",
        "PACKAGE_LICENSE": "",
        "PACKAGE_HOMEPAGE": "",
        "NODE_VERSION": "",
        "PYTHON_VERSION": ""
    }
    
    # Try package.json
    if os.path.exists("package.json"):
        try:
            with open("package.json", "r", encoding="utf-8") as f:
                pkg = json.load(f)
                package_info.update({
                    "PACKAGE_NAME": pkg.get("name", ""),
                    "PACKAGE_VERSION": pkg.get("version", ""),
                    "PACKAGE_DESCRIPTION": pkg.get("description", ""),
                    "PACKAGE_AUTHOR": pkg.get("author", ""),
                    "PACKAGE_LICENSE": pkg.get("license", ""),
                    "PACKAGE_HOMEPAGE": pkg.get("homepage", ""),
                    "NODE_VERSION": pkg.get("engines", {}).get("node", "")
                })
        except Exception:
            pass
    
    # Try requirements.txt for Python version
    if os.path.exists("requirements.txt"):
        try:
            with open("requirements.txt", "r", encoding="utf-8") as f:
                content = f.read()
                python_match = re.search(r"python[>=<~]+([0-9.]+)", content, re.IGNORECASE)
                if python_match:
                    package_info["PYTHON_VERSION"] = python_match.group(1)
        except Exception:
            pass
    
    return package_info

def get_workflow_badges(repo_full_name: str) -> Dict[str, str]:
    """
    Generate workflow badge URLs
    """
    if repo_full_name == "unknown/unknown":
        return {}
    
    base_url = f"https://github.com/{repo_full_name}"
    
    return {
        "BADGE_RELEASE": f"[![Release]({base_url}/actions/workflows/release-please.yml/badge.svg)]({base_url}/actions/workflows/release-please.yml)"
    }

def get_contributors_info(repo_full_name: str) -> Dict[str, str]:
    """
    Get contributors information (basic implementation)
    """
    if repo_full_name == "unknown/unknown":
        return {"CONTRIBUTORS": ""}
    
    # Try to get contributor count from GitHub API (without auth, limited)
    try:
        url = f"https://api.github.com/repos/{repo_full_name}/contributors"
        req = urllib.request.Request(url)
        req.add_header('User-Agent', 'README-Generator/1.0')
        
        with urllib.request.urlopen(req, timeout=5) as response:
            if response.getcode() == 200:
                contributors = json.loads(response.read().decode())
                if isinstance(contributors, list):
                    contributor_count = len(contributors)
                    return {
                        "CONTRIBUTOR_COUNT": str(contributor_count),
                        "CONTRIBUTORS": f"{contributor_count} contributors"
                    }
    except Exception:
        pass
    
    return {
        "CONTRIBUTOR_COUNT": "0",
        "CONTRIBUTORS": ""
    }

def get_environment_vars() -> Dict[str, str]:
    """
    Get environment variables for CI/CD context
    """
    env_vars = {}
    
    # GitHub Actions environment variables
    github_vars = [
        "GITHUB_ACTOR", "GITHUB_REPOSITORY", "GITHUB_REF", "GITHUB_SHA",
        "GITHUB_WORKFLOW", "GITHUB_RUN_ID", "GITHUB_RUN_NUMBER"
    ]
    
    for var in github_vars:
        value = os.getenv(var, "")
        if value:
            env_vars[var] = value
    
    # Custom environment variables
    custom_vars = [
        "PROJECT_NAME", "PROJECT_DESCRIPTION", "COMPANY_NAME",
        "CONTACT_EMAIL", "DOCUMENTATION_URL", "SUPPORT_URL"
    ]
    
    for var in custom_vars:
        value = os.getenv(var, "")
        if value:
            env_vars[var] = value
    
    return env_vars

def render_template(template: str, vars: dict) -> str:
    """
    Render template with variable substitution and conditional blocks
    """
    out = template
    
    # Simple variable substitution - only replace variables that have values
    for k, v in vars.items():
        if v and str(v).strip():  # Only replace if value is not empty
            out = out.replace("{{" + k + "}}", str(v))
    
    # Conditional blocks: {{#IF VARIABLE}}content{{/IF}}
    import re
    
    # Process IF blocks
    if_pattern = r'\{\{#IF\s+(\w+)\}\}(.*?)\{\{/IF\}\}'
    matches = re.findall(if_pattern, out, re.DOTALL)
    
    for var_name, content in matches:
        if vars.get(var_name) and str(vars.get(var_name)).strip():
            # Variable exists and is not empty, keep content
            out = re.sub(
                r'\{\{#IF\s+' + re.escape(var_name) + r'\}\}.*?\{\{/IF\}\}',
                content,
                out,
                flags=re.DOTALL
            )
        else:
            # Variable doesn't exist or is empty, remove block
            out = re.sub(
                r'\{\{#IF\s+' + re.escape(var_name) + r'\}\}.*?\{\{/IF\}\}',
                '',
                out,
                flags=re.DOTALL
            )
    
    # Remove any remaining unresolved placeholders
    out = re.sub(r'\{\{[^}]*\}\}', '', out)
    
    # Clean up extra whitespace and empty lines
    lines = out.split('\n')
    cleaned_lines = []
    prev_empty = False
    
    for line in lines:
        is_empty = not line.strip()
        
        if not is_empty:
            cleaned_lines.append(line)
            prev_empty = False
        elif not prev_empty:  # Keep only one empty line
            cleaned_lines.append('')
            prev_empty = True
    
    return '\n'.join(cleaned_lines).strip() + '\n'

def main():
    # Priority:
    # 1) RELEASE_VERSION from semantic-release prepare step
    # 2) latest git tag
    # 3) initial fallback (INIT_VERSION or 0.1.0)
    version = os.getenv("RELEASE_VERSION")
    if not version:
        version = get_latest_tag() or get_initial_version()

    # Get current date and time in various formats
    now = datetime.now(timezone.utc)
    
    # Collect all variables
    variables = {
        "VERSION": version,
        "DATE": now.strftime("%Y-%m-%d"),
        "DATETIME": now.strftime("%Y-%m-%d %H:%M:%S UTC"),
        "YEAR": now.strftime("%Y"),
        "MONTH": now.strftime("%m"),
        "DAY": now.strftime("%d"),
        "ISO_DATE": now.isoformat(),
        "TIMESTAMP": str(int(now.timestamp()))
    }
    
    # Add git information
    variables.update(get_git_info())
    
    # Add package information
    variables.update(get_package_info())
    
    # Add workflow badges
    variables.update(get_workflow_badges(variables.get("REPO_FULL_NAME", "")))
    
    # Add contributors info
    variables.update(get_contributors_info(variables.get("REPO_FULL_NAME", "")))
    
    # Add environment variables with defaults for missing variables
    env_vars = get_environment_vars()
    variables.update(env_vars)
    
    # Set default values for commonly missing variables
    defaults = {
        "COMPANY_NAME": "BAUER GROUP",
        "PROJECT_NAME": variables.get("REPO_NAME", ""),
        "PROJECT_DESCRIPTION": "",
        "CONTACT_EMAIL": "",
        "DOCUMENTATION_URL": "",
        "SUPPORT_URL": "",
        "CURRENT_BRANCH": variables.get("CURRENT_BRANCH", "main")
    }
    
    # Only set defaults for variables that are empty or missing
    for key, default_value in defaults.items():
        if not variables.get(key) or not str(variables.get(key)).strip():
            variables[key] = default_value
    
    # Read template
    try:
        with open(TEMPLATE_PATH, "r", encoding="utf-8") as f:
            template = f.read()
    except FileNotFoundError:
        print(f"Error: Template file {TEMPLATE_PATH} not found")
        return 1
    except Exception as e:
        print(f"Error reading template: {e}")
        return 1

    # Render template
    content = render_template(template, variables)

    # Write output
    banner = f"<!-- AUTO-GENERATED FILE. DO NOT EDIT. Edit {TEMPLATE_PATH} instead. -->\n"
    banner += f"<!-- Generated on {variables['DATETIME']} -->\n\n"
    
    try:
        with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
            f.write(banner + content)
        print(f"README generated successfully: {OUTPUT_PATH}")
        return 0
    except Exception as e:
        print(f"Error writing output: {e}")
        return 1

if __name__ == "__main__":
    exit(main())
