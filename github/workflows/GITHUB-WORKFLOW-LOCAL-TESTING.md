# 🏃‍♂️ Local GitHub Workflow Testing with nektos/act

This guide explains how to run and debug GitHub Actions workflows locally using [nektos/act](https://github.com/nektos/act) and the VS Code extension.

## 📋 Table of Contents

- [Overview](#overview)
- [Installation](#installation)
- [Configuration](#configuration)
- [Running Workflows](#running-workflows)
- [VS Code Integration](#vs-code-integration)
- [Debugging](#debugging)
- [Common Issues](#common-issues)
- [Best Practices](#best-practices)

## 🎯 Overview

**nektos/act** allows you to run GitHub Actions locally using Docker. This is extremely useful for:

- 🔍 Testing workflows before pushing to GitHub
- 🐛 Debugging workflow issues locally
- ⚡ Faster iteration cycles
- 💰 Reducing GitHub Actions minutes usage
- 🔒 Testing sensitive workflows privately

## 📦 Installation

### Prerequisites

- [Docker](https://www.docker.com/get-started) installed and running
- [Git](https://git-scm.com/) installed
- [VS Code](https://code.visualstudio.com/) (optional, for enhanced debugging)

### Install nektos/act

#### Windows (using Chocolatey)
```powershell
choco install act-cli
```

#### Windows (using Scoop)
```powershell
scoop install act
```

#### macOS (using Homebrew)
```bash
brew install act
```

#### Linux (using curl)
```bash
curl https://raw.githubusercontent.com/nektos/act/master/install.sh | sudo bash
```

#### Manual Installation
Download the latest release from [GitHub Releases](https://github.com/nektos/act/releases) and add to your PATH.

### Verify Installation
```bash
act --version
```

## ⚙️ Configuration

### 1. Create `.actrc` Configuration File

Create a `.actrc` file in your repository root:

```bash
# .actrc - Configuration for nektos/act

# Use GitHub's larger runner image for better compatibility
-P ubuntu-latest=catthehacker/ubuntu:act-latest
-P ubuntu-24.04=catthehacker/ubuntu:act-24.04
-P ubuntu-22.04=catthehacker/ubuntu:act-22.04
-P ubuntu-20.04=catthehacker/ubuntu:act-20.04

# Set platform for Windows runners (if needed)
-P windows-latest=catthehacker/windows:act-latest

# Verbose output for debugging
--verbose

# Set artifact server (for workflow artifacts)
--artifact-server-path /tmp/artifacts

# Use .env file for secrets
--env-file .env.local
```

### 2. Create Local Environment File

Create `.env.local` for secrets and environment variables:

```bash
# .env.local - Local environment variables for act
# DO NOT COMMIT THIS FILE TO VERSION CONTROL

# GitHub Token (for API access)
GITHUB_TOKEN=your_github_personal_access_token

# Repository secrets (if needed)
NPM_TOKEN=your_npm_token
DOCKER_USERNAME=your_docker_username
DOCKER_PASSWORD=your_docker_password

# Custom environment variables
NODE_ENV=development
```

### 3. Update `.gitignore`

Add to your `.gitignore`:

```gitignore
# Local testing files
.env.local
.actrc.local
/tmp/artifacts/
```

## 🚀 Running Workflows

### Basic Commands

```bash
# List all available workflows
act -l

# Run all workflows
act

# Run specific workflow
act -W .github/workflows/ci.yml

# Run specific job
act -j build

# Run with specific event
act push
act pull_request
act workflow_dispatch

# Run with custom input (for workflow_dispatch)
act workflow_dispatch --input security-engine=gitleaks
```

### Advanced Usage

```bash
# Run with custom runner image
act -P ubuntu-latest=node:16-bullseye

# Run with bind mounts (access local files)
act --bind

# Run with custom workflow file
act -W /path/to/custom/workflow.yml

# Dry run (don't actually execute)
act --dry-run

# Use specific Docker platform
act --platform linux/amd64
```

## 🔌 VS Code Integration

### Install VS Code Extension

1. Install the **GitHub Actions** extension by GitHub
2. Install the **Act** extension (if available) or use integrated terminal

### VS Code Configuration

Create `.vscode/settings.json`:

```json
{
    "github-actions.workflows.pinned.workflows": [
        ".github/workflows/automatic-release.yml",
        ".github/workflows/documentation.yml",
        ".github/workflows/security-management.yml"
    ],
    "github-actions.workflows.pinned.refresh.enabled": true,
    "terminal.integrated.env.windows": {
        "ACT_LOG": "debug"
    },
    "terminal.integrated.env.linux": {
        "ACT_LOG": "debug"
    },
    "terminal.integrated.env.osx": {
        "ACT_LOG": "debug"
    }
}
```

### VS Code Tasks

Create `.vscode/tasks.json`:

```json
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "Act: List Workflows",
            "type": "shell",
            "command": "act",
            "args": ["-l"],
            "group": "test",
            "presentation": {
                "echo": true,
                "reveal": "always",
                "panel": "new"
            }
        },
        {
            "label": "Act: Run CI Workflow",
            "type": "shell",
            "command": "act",
            "args": ["-W", ".github/workflows/automatic-release.yml", "--dry-run"],
            "group": "test",
            "presentation": {
                "echo": true,
                "reveal": "always",
                "panel": "new"
            }
        },
        {
            "label": "Act: Run Documentation Workflow",
            "type": "shell",
            "command": "act",
            "args": ["-W", ".github/workflows/documentation.yml"],
            "group": "test",
            "presentation": {
                "echo": true,
                "reveal": "always",
                "panel": "new"
            }
        },
        {
            "label": "Act: Debug Workflow (Verbose)",
            "type": "shell",
            "command": "act",
            "args": ["--verbose", "--dry-run"],
            "group": "test",
            "presentation": {
                "echo": true,
                "reveal": "always",
                "panel": "new"
            }
        }
    ]
}
```

## 🐛 Debugging

### Enable Debug Logging

```bash
# Set debug environment variable
export ACT_LOG=debug

# Or run with verbose flag
act --verbose
```

### Step-by-Step Debugging

```bash
# Dry run to see execution plan
act --dry-run

# List jobs and steps
act -l --verbose

# Run single job with debugging
act -j job-name --verbose
```

### Common Debugging Techniques

1. **Check Docker Images**:
   ```bash
   docker images | grep catthehacker
   ```

2. **Inspect Running Containers**:
   ```bash
   docker ps
   docker logs <container-id>
   ```

3. **Interactive Shell Access**:
   ```bash
   # Add this step to your workflow for debugging
   - name: Debug Shell
     run: |
       echo "Debug info:"
       pwd
       ls -la
       env | sort
   ```

### VS Code Debugging Setup

1. **Install Extensions**:
   - GitHub Actions
   - Docker
   - YAML

2. **Use Integrated Terminal**:
   - Run act commands directly in VS Code terminal
   - View logs with syntax highlighting

3. **File Watchers**:
   - Use VS Code's file watcher to auto-run act on workflow changes

## ⚠️ Common Issues

### Issue: "Error: Cannot find module"
**Solution**: Update to compatible runner image
```bash
act -P ubuntu-latest=catthehacker/ubuntu:act-latest
```

### Issue: "Permission denied" for Docker
**Solution**: Ensure Docker daemon is running and user has permissions
```bash
# Linux/macOS
sudo usermod -aG docker $USER
# Then logout/login

# Windows
# Run Docker Desktop as Administrator
```

### Issue: "Secrets not available"
**Solution**: Use `.env.local` file or pass secrets directly
```bash
act --secret GITHUB_TOKEN=your_token
# Or use .env.local file with --env-file flag
```

### Issue: "Workflow not triggering"
**Solution**: Specify correct event
```bash
# For push events
act push

# For pull request events
act pull_request

# For manual dispatch
act workflow_dispatch
```

### Issue: "Docker image pull errors"
**Solution**: Use specific platform or smaller images
```bash
act --platform linux/amd64
# Or use smaller images
act -P ubuntu-latest=catthehacker/ubuntu:act-runner
```

## ✅ Best Practices

### 1. Image Selection
- Use `catthehacker/ubuntu:act-latest` for most workflows
- Use `catthehacker/ubuntu:act-runner` for smaller/faster runs
- Use official images (`ubuntu:latest`) only for simple workflows

### 2. Secret Management
- Never commit `.env.local` to version control
- Use minimal permissions for GitHub tokens
- Rotate tokens regularly

### 3. Performance Optimization
```bash
# Use Docker BuildKit for faster builds
export DOCKER_BUILDKIT=1

# Cache Docker images locally
docker pull catthehacker/ubuntu:act-latest

# Use bind mounts for faster file access
act --bind
```

### 4. Workflow Design
- Test workflows locally before committing
- Use conditional steps for local testing:
  ```yaml
  - name: Local only step
    if: env.ACT == 'true'
    run: echo "Running locally with act"
  ```

### 5. CI/CD Integration
- Add act testing to pre-commit hooks
- Use act in development containers
- Document local testing procedures for team

## 📚 Examples

### Example 1: Test Documentation Workflow
```bash
# Test documentation generation locally
act -W .github/workflows/documentation.yml \
    --input force-update=true \
    --input custom-version=1.0.0-local
```

### Example 2: Test Security Workflow
```bash
# Test security management workflow
act -W .github/workflows/security-management.yml \
    --input force-update=true \
    --input policy-version=1.0.0
```

### Example 3: Test Release Workflow (Dry Run)
```bash
# Test release workflow without actually releasing
act -W .github/workflows/automatic-release.yml \
    --dry-run \
    --input force-release=true
```

## 🔗 Resources

- [nektos/act GitHub Repository](https://github.com/nektos/act)
- [act Documentation](https://github.com/nektos/act/blob/master/README.md)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Docker Hub - Runner Images](https://hub.docker.com/u/catthehacker)
- [VS Code GitHub Actions Extension](https://marketplace.visualstudio.com/items?itemName=GitHub.vscode-github-actions)

---

**💡 Pro Tip**: Start with dry runs (`--dry-run`) to understand workflow execution before running actual commands.

**🛡️ Security Note**: Always review what workflows will do before running them locally, especially with production secrets.

🧩 *Part of BAUER GROUP's modular workflow components*