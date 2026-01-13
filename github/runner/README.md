# GitHub Runner Management

**Self-hosted GitHub Actions runners with enterprise-grade security and scalability**

## Overview

This directory provides solutions for deploying and managing self-hosted GitHub Actions runners. Two deployment approaches are available:

| Approach | Best For | Repository |
|----------|----------|------------|
| **Docker-in-Docker (Recommended)** | Production, Full Docker support | [bauer-group/GitHubRunner](https://github.com/bauer-group/GitHubRunner) |
| **Bare-Metal / VM** | Legacy systems, Non-Docker workloads | This directory |

## Docker-in-Docker Solution (Recommended)

For production environments requiring full Docker capabilities, use our dedicated containerized runner solution:

**Repository:** [bauer-group/GitHubRunner](https://github.com/bauer-group/GitHubRunner)

### Key Features

- **True Docker-in-Docker isolation** - Workflow containers run inside DinD, not on host
- **Ephemeral runners** - Auto-destroy after each job (like GitHub-hosted)
- **High performance** - Configurable resources (default: 16 CPU, 32GB RAM)
- **Auto-scaling** - Scale runners with `docker compose --scale`
- **GitHub App support** - Secure authentication with minimal permissions
- **Professional scripts** - Deploy, scale, status, cleanup utilities

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        Host System                          │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              Docker Engine (Host)                    │   │
│  │  ┌────────────────────────────────────────────────┐ │   │
│  │  │           Isolated Runner Network              │ │   │
│  │  │  ┌──────────────┐    ┌───────────────────┐   │ │   │
│  │  │  │   DinD       │    │  GitHub Runner    │   │ │   │
│  │  │  │  Container   │◄───│    Container      │   │ │   │
│  │  │  │  ┌────────┐  │    │  myoung34/        │   │ │   │
│  │  │  │  │ Docker │  │    │  github-runner    │   │ │   │
│  │  │  │  │ Daemon │  │    └───────────────────┘   │ │   │
│  │  │  │  └────────┘  │                            │ │   │
│  │  │  │  ┌─────────┐ │                            │ │   │
│  │  │  │  │Workflow │ │                            │ │   │
│  │  │  │  │Containers│ │                            │ │   │
│  │  │  │  └─────────┘ │                            │ │   │
│  │  │  └──────────────┘                            │ │   │
│  │  └────────────────────────────────────────────────┘ │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### Quick Start (Docker-in-Docker)

```bash
# Clone the dedicated runner repository
git clone https://github.com/bauer-group/GitHubRunner.git
cd GitHubRunner

# Run interactive setup
./scripts/deploy.sh --init

# Start runners
./scripts/start.sh 4  # Start 4 runners

# Check status
./scripts/status.sh
```

### Why Docker-in-Docker?

| Feature | Docker Socket Mount | Docker-in-Docker |
|---------|---------------------|------------------|
| **Host Isolation** | Workflows can affect host | Complete isolation |
| **Security** | Docker daemon shared | Dedicated daemon |
| **Cleanup** | Manual cleanup needed | Auto-cleanup on restart |
| **Resource Control** | Limited | Full control |
| **Recommended** | Development only | Production |

For full documentation, see: [bauer-group/GitHubRunner](https://github.com/bauer-group/GitHubRunner)

---

## Bare-Metal / VM Deployment

For environments where containerization is not possible or desired, use the following approach.

### Components

```
github/runner/
├── cloud-init/          # Cloud VM auto-provisioning
│   └── user-data.yaml   # Cloud-init configuration
├── scripts/             # Management scripts
│   ├── install.sh       # Runner installation
│   ├── manage.sh        # Runtime management
│   └── uninstall.sh     # Clean uninstallation
├── systemd/             # Service configuration
│   └── gha-runners.service
├── windows/             # Windows support
│   └── setup.ps1        # PowerShell setup script
├── docker-compose.yml   # Simple Docker deployment
└── .env.example         # Environment template
```

### Installation

#### Option 1: Cloud VM with Cloud-Init

```bash
# Prepare cloud-init configuration
cp cloud-init/user-data.yaml user-data-configured.yaml

# Edit with your values
sed -i 's/YOUR_GITHUB_TOKEN/ghp_your_token_here/' user-data-configured.yaml
sed -i 's/YOUR_ORG_NAME/your-org/' user-data-configured.yaml

# Deploy on cloud provider (AWS, Azure, GCP, etc.)
# Use user-data-configured.yaml as user-data
```

#### Option 2: Manual Installation

```bash
# Download and run installation script
./scripts/install.sh

# Configure environment
cp .env.example .env
nano .env

# Start service
sudo systemctl enable gha-runners
sudo systemctl start gha-runners
```

#### Option 3: Simple Docker (Socket Mount)

> **Warning**: This approach mounts the host Docker socket. For production, use the [Docker-in-Docker solution](#docker-in-docker-solution-recommended).

```bash
# Configure environment
cp .env.example .env
nano .env

# Start with Docker Compose
docker-compose up -d

# Scale runners
docker-compose up -d --scale runner=5
```

### Environment Variables

Configure your `.env` file with the following variables:

```bash
# =============================================================================
# Authentication (choose ONE method)
# =============================================================================

# Option 1: Personal Access Token (requires admin:org scope)
GITHUB_PAT=ghp_xxxxxxxxxxxxxxxxxxxxx

# Option 2: GitHub App (recommended for production)
APP_ID=123456
APP_PRIVATE_KEY="-----BEGIN RSA PRIVATE KEY-----\n...\n-----END RSA PRIVATE KEY-----"
APP_LOGIN=your-org

# =============================================================================
# Runner Scope
# =============================================================================

RUNNER_SCOPE=org                         # org | repo | enterprise
ORG_NAME=your-organization               # For org scope
# REPO_URL=https://github.com/org/repo  # For repo scope
# ENTERPRISE_NAME=your-enterprise       # For enterprise scope

# =============================================================================
# Runner Configuration
# =============================================================================

RUNNER_NAME_PREFIX=linux                 # Prefix for runner names
RUNNER_LABELS=self-hosted,linux,docker   # Comma-separated labels
RUNNER_GROUP=Default                     # Runner group name
RUNNER_WORKDIR=/tmp/runner/work          # Working directory

# =============================================================================
# Scaling & Resources
# =============================================================================

RUNNER_COUNT=8                           # Number of runners to start
RUNNER_CPU_LIMIT=2.0                     # CPU limit per runner
RUNNER_MEMORY_LIMIT=8g                   # Memory limit per runner

# =============================================================================
# General
# =============================================================================

TZ=Europe/Berlin                         # Timezone
```

### Management Commands

The `manage.sh` script provides comprehensive runner management:

```bash
# Start all runners (uses RUNNER_COUNT from .env)
./scripts/manage.sh start

# Stop all runners
./scripts/manage.sh stop

# Restart all runners (pulls latest image)
./scripts/manage.sh restart

# Show runner status
./scripts/manage.sh status

# Scale to specific number of runners
./scripts/manage.sh scale 4

# View runner logs (follow mode)
./scripts/manage.sh logs

# Update runner images and restart
./scripts/manage.sh update

# Clean up stopped containers and unused images
./scripts/manage.sh cleanup

# Show help
./scripts/manage.sh help
```

**Systemd Service Commands:**

```bash
# View service logs
journalctl -u gha-runners -f

# Restart service
sudo systemctl restart gha-runners

# Check service status
sudo systemctl status gha-runners
```

### Windows Installation

```powershell
# Run PowerShell as Administrator
.\windows\setup.ps1 -Url "https://github.com/your-org" -Token "<REG_TOKEN>"

# With custom labels and runner group
.\windows\setup.ps1 `
  -Url "https://github.com/your-org" `
  -Token "<REG_TOKEN>" `
  -Labels "self-hosted,Windows,vs2022,dotnet" `
  -RunnerGroup "Windows-Runners" `
  -RunnerName "WIN-BUILD-01"

# With .NET SDK installation
.\windows\setup.ps1 `
  -Url "https://github.com/your-org" `
  -Token "<REG_TOKEN>" `
  -InstallDotNet `
  -DotNetVersions "Microsoft.DotNet.SDK.8","Microsoft.DotNet.SDK.9"
```

**Windows Parameters:**

| Parameter | Description | Default |
|-----------|-------------|---------|
| `-Url` | GitHub org/repo URL | Required |
| `-Token` | Registration token | Required |
| `-Labels` | Runner labels | `self-hosted,Windows,X64` |
| `-RunnerGroup` | Runner group name | `Default` |
| `-RunnerName` | Runner name | Hostname |
| `-InstallDotNet` | Install .NET SDKs | `false` |
| `-DotNetVersions` | .NET SDK versions | `Microsoft.DotNet.SDK.9` |

---

## Using Self-Hosted Runners in Workflows

### Basic Usage

```yaml
jobs:
  build:
    runs-on: [self-hosted, linux, docker]
    steps:
      - uses: actions/checkout@v4
      - run: echo "Running on self-hosted runner!"
```

### With Runner Groups (Organization)

```yaml
jobs:
  build:
    runs-on:
      group: Self-Hosted (BAUER GROUP)
      labels: [linux, docker]
    steps:
      - uses: actions/checkout@v4
```

### With Automation-Templates Workflows

All workflows in this repository support the `runs-on` parameter:

```yaml
jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/dotnet-build.yml@main
    with:
      project-path: 'src/MyApp.csproj'
      # Use self-hosted runner
      runs-on: '["self-hosted", "linux", "docker"]'
```

### Important: Cache Configuration

Self-hosted runners **cannot access** GitHub's cache infrastructure. For Docker builds, disable caching:

```yaml
jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/docker-build.yml@main
    with:
      runs-on: '["self-hosted", "linux", "docker"]'
      cache-enabled: false  # Required for self-hosted runners!
```

Without this setting, builds will fail with HTTP 502 errors when trying to access the GitHub Actions Cache.

See [Self-Hosted Runner Documentation](../../docs/self-hosted-runners.md) for complete workflow integration guide.

---

## Security Considerations

### Best Practices

1. **Use ephemeral runners** - Fresh environment for each job
2. **Limit runner scope** - Use repository-level runners when possible
3. **Rotate tokens regularly** - Use GitHub Apps for auto-rotation
4. **Restrict network access** - Only allow necessary outbound connections
5. **Monitor activity** - Enable audit logging
6. **Use runner groups** - Control which repos can use runners

### Docker-in-Docker vs Socket Mount

| Security Aspect | Socket Mount | Docker-in-Docker |
|-----------------|--------------|------------------|
| Host Docker access | Yes (risky) | No (isolated) |
| Container escape | Possible | Contained |
| Resource isolation | None | Full |
| Cleanup | Manual | Automatic |

**Recommendation**: Always use Docker-in-Docker for production.

---

## Troubleshooting

### Runner Not Registering

```bash
# Check token permissions
curl -H "Authorization: token $GITHUB_PAT" \
     https://api.github.com/orgs/YOUR_ORG/actions/runners

# Verify token scopes (need admin:org for org runners)
curl -sI -H "Authorization: token $GITHUB_PAT" \
     https://api.github.com | grep x-oauth-scopes
```

### Jobs Stuck in Queue

1. Verify runner is online in GitHub Settings
2. Check label matching - all labels must match
3. Check runner group permissions

### Docker Commands Failing

```bash
# For Docker-in-Docker
docker compose logs docker-in-docker

# For Socket Mount
docker ps
docker info
```

---

## Related Resources

- **Docker-in-Docker Runner**: [bauer-group/GitHubRunner](https://github.com/bauer-group/GitHubRunner)
- **Workflow Integration**: [Self-Hosted Runner Documentation](../../docs/self-hosted-runners.md)
- **GitHub Documentation**: [Self-hosted runners](https://docs.github.com/en/actions/hosting-your-own-runners)
- **myoung34/github-runner**: [Docker image](https://github.com/myoung34/docker-github-actions-runner)

---

## Support

- **Issues**: [GitHub Issues](https://github.com/bauer-group/automation-templates/issues)
- **Discussions**: [GitHub Discussions](https://github.com/bauer-group/automation-templates/discussions)
