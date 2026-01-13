# Self-Hosted Runner Support

## Overview

All reusable workflows in this repository support self-hosted GitHub Actions runners. This allows organizations to run workflows on their own infrastructure instead of GitHub-hosted runners, providing:

- **Cost Control**: No GitHub Actions minutes consumption
- **Custom Hardware**: Use specialized hardware (GPU, high memory, etc.)
- **Network Access**: Access to internal networks and resources
- **Compliance**: Keep builds within your infrastructure
- **Performance**: Potentially faster builds with local caching

## Configuration

### The `runs-on` Input Parameter

Every reusable workflow accepts a `runs-on` input parameter that determines which runner executes the workflow:

```yaml
runs-on:
  description: 'Runner to use. Use string for GitHub-hosted (e.g., "ubuntu-latest") or JSON array for self-hosted (e.g., ["self-hosted", "linux"])'
  required: false
  type: string
  default: 'ubuntu-latest'
```

### Usage Examples

#### GitHub-Hosted Runner (Default)

```yaml
jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/dotnet-build.yml@main
    with:
      project-path: 'src/MyApp.csproj'
      # runs-on defaults to 'ubuntu-latest'
```

#### Self-Hosted Linux Runner

```yaml
jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/dotnet-build.yml@main
    with:
      project-path: 'src/MyApp.csproj'
      runs-on: '["self-hosted", "linux"]'
```

#### Self-Hosted Windows Runner

```yaml
jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/dotnet-desktop-build.yml@main
    with:
      solution-path: 'src/MyApp.sln'
      runs-on: '["self-hosted", "Windows"]'
```

#### Self-Hosted with Custom Labels

```yaml
jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/docker-build.yml@main
    with:
      image-name: 'myapp'
      runs-on: '["self-hosted", "linux", "docker", "high-memory"]'
```

## Input Format

The `runs-on` parameter accepts two formats:

### 1. Simple String (GitHub-Hosted)

For GitHub-hosted runners, use a simple string:

```yaml
runs-on: 'ubuntu-latest'      # Linux
runs-on: 'ubuntu-24.04'       # Specific Ubuntu version
runs-on: 'windows-latest'     # Windows
runs-on: 'windows-2022'       # Specific Windows version
runs-on: 'macos-latest'       # macOS
runs-on: 'macos-14'           # Specific macOS version
```

### 2. JSON Array (Self-Hosted)

For self-hosted runners, use a JSON array with labels:

```yaml
runs-on: '["self-hosted"]'                        # Any self-hosted runner
runs-on: '["self-hosted", "linux"]'               # Linux self-hosted
runs-on: '["self-hosted", "Windows"]'             # Windows self-hosted
runs-on: '["self-hosted", "macOS"]'               # macOS self-hosted
runs-on: '["self-hosted", "linux", "x64"]'        # Linux x64 self-hosted
runs-on: '["self-hosted", "linux", "gpu"]'        # Linux with GPU
runs-on: '["self-hosted", "linux", "docker"]'     # Linux with Docker
```

## Supported Workflows

All reusable workflows support the `runs-on` parameter:

### Build Workflows

| Workflow | Default Runner | Notes |
|----------|----------------|-------|
| `dotnet-build.yml` | `ubuntu-latest` | Cross-platform |
| `dotnet-desktop-build.yml` | `windows-latest` | Windows required |
| `nodejs-build.yml` | `ubuntu-latest` | Cross-platform |
| `php-build.yml` | `ubuntu-latest` | Linux recommended |
| `python-build.yml` | `ubuntu-latest` | Cross-platform |
| `docker-build.yml` | `ubuntu-latest` | Docker required |
| `zephyr-build.yml` | `ubuntu-latest` | Linux recommended |
| `shopware5-build.yml` | `ubuntu-latest` | PHP environment |
| `makefile-build.yml` | `ubuntu-latest` | Make required |

### Module Workflows

| Workflow | Default Runner | Notes |
|----------|----------------|-------|
| `modules-security-scan.yml` | `ubuntu-latest` | Security tools |
| `modules-license-compliance.yml` | `ubuntu-latest` | License scanning |
| `modules-pr-validation.yml` | `ubuntu-latest` | PR checks |
| `modules-semantic-release.yml` | `ubuntu-latest` | Release automation |
| `modules-artifact-generation.yml` | `ubuntu-latest` | Build artifacts |

### Utility Workflows

| Workflow | Default Runner | Notes |
|----------|----------------|-------|
| `documentation.yml` | `ubuntu-latest` | Doc generation |
| `security-management.yml` | `ubuntu-latest` | Security policy |
| `teams-notifications.yml` | `ubuntu-latest` | MS Teams |
| `coolify-deploy.yml` | `ubuntu-latest` | Coolify deployment |
| `claude-code.yml` | `ubuntu-latest` | AI assistant |

## Runner Deployment Options

### Option 1: Docker-in-Docker (Recommended)

For production environments, use our dedicated containerized runner solution with true Docker-in-Docker isolation:

**Repository:** [bauer-group/GitHubRunner](https://github.com/bauer-group/GitHubRunner)

**Key Features:**
- True Docker-in-Docker isolation (workflows can't affect host)
- Ephemeral runners (auto-destroy after each job)
- High performance (configurable: 16 CPU, 32GB RAM default)
- Auto-scaling with `docker compose --scale`
- GitHub App support for secure authentication

**Quick Start:**

```bash
# Clone the dedicated runner repository
git clone https://github.com/bauer-group/GitHubRunner.git
cd GitHubRunner

# Run interactive setup
./scripts/deploy.sh --init

# Start runners
./scripts/start.sh 4  # Start 4 runners
```

**Architecture:**

```text
┌─────────────────────────────────────────────────────────────┐
│                        Host System                          │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Docker Engine (Host)                    │   │
│  │  ┌────────────────────────────────────────────────┐ │   │
│  │  │           Isolated Runner Network              │ │   │
│  │  │  ┌──────────────┐    ┌───────────────────┐   │ │   │
│  │  │  │   DinD       │    │  GitHub Runner    │   │ │   │
│  │  │  │  Container   │◄───│    Container      │   │ │   │
│  │  │  │  (Docker     │    │  (myoung34/       │   │ │   │
│  │  │  │   Daemon)    │    │   github-runner)  │   │ │   │
│  │  │  └──────────────┘    └───────────────────┘   │ │   │
│  │  └────────────────────────────────────────────────┘ │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Option 2: Bare-Metal / VM

For environments where Docker is not available, see the [Runner Management Guide](../github/runner/README.md).

---

## Self-Hosted Runner Requirements

### Linux Runner

Ensure your self-hosted Linux runner has:

- **Docker** (for container workflows)
- **Git** (for checkout)
- **curl/wget** (for downloads)
- **Node.js** (for many actions)
- **Required SDKs** (.NET, Python, Node.js, etc.)

```bash
# Example setup script for Ubuntu
sudo apt-get update
sudo apt-get install -y \
  docker.io \
  git \
  curl \
  nodejs \
  npm

# Add runner user to docker group
sudo usermod -aG docker $USER
```

### Windows Runner

Ensure your self-hosted Windows runner has:

- **Git for Windows**
- **PowerShell 7+**
- **Visual Studio Build Tools** (for .NET desktop)
- **Required SDKs**

```powershell
# Example setup using winget
winget install Git.Git
winget install Microsoft.PowerShell
winget install Microsoft.VisualStudio.2022.BuildTools
winget install Microsoft.DotNet.SDK.8
```

### macOS Runner

Ensure your self-hosted macOS runner has:

- **Xcode Command Line Tools**
- **Homebrew**
- **Required SDKs**

```bash
# Install Xcode CLI tools
xcode-select --install

# Install Homebrew
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

## Best Practices

### 1. Use Descriptive Labels

```yaml
# Good: Specific labels
runs-on: '["self-hosted", "linux", "docker", "production"]'

# Avoid: Generic labels only
runs-on: '["self-hosted"]'
```

### 2. Match Runner to Workflow

```yaml
# .NET Desktop requires Windows
- uses: bauer-group/automation-templates/.github/workflows/dotnet-desktop-build.yml@main
  with:
    runs-on: '["self-hosted", "Windows", "vs2022"]'

# Docker build requires Docker
- uses: bauer-group/automation-templates/.github/workflows/docker-build.yml@main
  with:
    runs-on: '["self-hosted", "linux", "docker"]'
```

### 3. Fallback Strategy

For critical workflows, consider a fallback:

```yaml
jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/dotnet-build.yml@main
    with:
      # Use self-hosted if available, otherwise GitHub-hosted
      runs-on: ${{ vars.USE_SELF_HOSTED == 'true' && '["self-hosted", "linux"]' || 'ubuntu-latest' }}
```

### 4. Repository Variables

Use repository or organization variables for consistent configuration:

```yaml
# In your workflow
jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/dotnet-build.yml@main
    with:
      runs-on: ${{ vars.RUNNER_CONFIG || 'ubuntu-latest' }}
```

Then set `RUNNER_CONFIG` in your repository settings:
- **Settings** > **Secrets and variables** > **Actions** > **Variables**
- Name: `RUNNER_CONFIG`
- Value: `["self-hosted", "linux"]`

## Troubleshooting

### Runner Not Picking Up Jobs

1. Verify runner labels match your configuration
2. Check runner is online and idle
3. Ensure labels are case-sensitive (e.g., `Windows` not `windows`)

### Missing Dependencies

```yaml
# Add setup steps if needed
- name: Setup .NET
  uses: actions/setup-dotnet@v5
  with:
    dotnet-version: '8.0.x'
```

### Docker Not Available

Ensure Docker daemon is running:

```bash
sudo systemctl start docker
sudo systemctl enable docker
```

### Permission Issues

```bash
# Fix Docker permissions
sudo usermod -aG docker $(whoami)
newgrp docker
```

## Security Considerations

1. **Isolate runners** - Use dedicated runners for sensitive workflows
2. **Update regularly** - Keep runner software and dependencies updated
3. **Network security** - Restrict network access appropriately
4. **Secrets management** - Use GitHub Secrets, not environment variables
5. **Audit logs** - Monitor runner activity

## Migration Guide

### From GitHub-Hosted to Self-Hosted

1. **Set up runners** with required labels
2. **Test with one workflow** first
3. **Update `runs-on` parameter** in workflow calls
4. **Monitor for issues** and adjust as needed

```yaml
# Before (GitHub-hosted)
jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/dotnet-build.yml@main
    with:
      project-path: 'src/MyApp.csproj'

# After (Self-hosted)
jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/dotnet-build.yml@main
    with:
      project-path: 'src/MyApp.csproj'
      runs-on: '["self-hosted", "linux", "dotnet"]'
```

## Support

- [Docker-in-Docker Runner Solution](https://github.com/bauer-group/GitHubRunner) - Recommended for production
- [Runner Management Guide](../github/runner/README.md) - Bare-metal and VM deployment
- [GitHub Self-Hosted Runners Documentation](https://docs.github.com/en/actions/hosting-your-own-runners)
- [Issues](https://github.com/bauer-group/automation-templates/issues)
- [Discussions](https://github.com/bauer-group/automation-templates/discussions)
