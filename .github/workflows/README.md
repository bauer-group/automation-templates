# GitHub Workflows - Enterprise Automation Templates

**Professional CI/CD workflow templates for enterprise-grade development processes**

## 📋 Overview

This directory contains production-ready GitHub Actions workflows that implement industry best practices for continuous integration, security, and release management.

## 🚀 Available Workflows

### Core Workflows

| Workflow | Purpose | Trigger | Features |
|----------|---------|---------|----------|
| [`automatic-release.yml`](./automatic-release.yml) | Automated semantic releases | Push to main, PR merge | Security scanning, auto-merge, artifacts |
| [`manual-release.yml`](./manual-release.yml) | Manual release management | Workflow dispatch | Version control, security validation |

### Workflow Features

#### Automatic Release Management
- **Semantic versioning** with conventional commits
- **Dual-engine security scanning** (Gitleaks + GitGuardian)
- **License compliance checking** with SPDX validation
- **Intelligent auto-merge** for release PRs
- **Multi-format artifact generation**
- **Branch cleanup automation**

#### Manual Release Management
- **Custom version specification** (major, minor, patch)
- **Security pre-validation** before release
- **Configurable scanning engines**
- **License compliance checks**
- **Debug information** for troubleshooting

## 🔧 Configuration

### Required Repository Secrets

```yaml
secrets:
  GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}           # Automatically provided
  GITGUARDIAN_API_KEY: ${{ secrets.GITGUARDIAN_API_KEY }} # Optional - for GitGuardian scanning
  GITLEAKS_LICENSE: ${{ secrets.GITLEAKS_LICENSE }}   # Optional - for Gitleaks Pro features
  FOSSA_API_KEY: ${{ secrets.FOSSA_API_KEY }}         # Optional - for license compliance
```

### Repository Permissions

```yaml
permissions:
  contents: write           # For creating releases and updating files
  pull-requests: write      # For managing release PRs
  security-events: write    # For SARIF uploads
  packages: write          # For artifact publishing
  actions: read           # For workflow status checks
  issues: write           # For creating issues (if needed)
```

## 🛡️ Security Features

### Multi-Engine Scanning
- **Gitleaks**: Fast pattern-based secret detection
- **GitGuardian**: ML-enhanced secret detection with policy enforcement
- **Configurable engines**: Choose between gitleaks, gitguardian, or both
- **SARIF integration**: Results appear in GitHub Security tab

### Compliance Validation
- **License scanning**: SPDX-compliant license detection
- **Dependency analysis**: Security vulnerability assessment
- **Policy enforcement**: Configurable compliance rules

## 🚀 Usage Examples

### Basic Automatic Release

```yaml
name: Release Management

on:
  push:
    branches: [ main ]

jobs:
  release:
    uses: bauer-group/automation-templates/.github/workflows/automatic-release.yml@main
    secrets:
      GITGUARDIAN_API_KEY: ${{ secrets.GITGUARDIAN_API_KEY }}
```

### Advanced Configuration

```yaml
name: Advanced Release

on:
  push:
    branches: [ main ]
  workflow_dispatch:
    inputs:
      security-scan-engine:
        type: choice
        default: 'both'
        options: [gitleaks, gitguardian, both]
      auto-merge-pr:
        type: boolean
        default: true

jobs:
  release:
    uses: bauer-group/automation-templates/.github/workflows/automatic-release.yml@main
    with:
      security-scan-engine: ${{ inputs.security-scan-engine || 'both' }}
      auto-merge-pr: ${{ inputs.auto-merge-pr || true }}
    secrets:
      GITGUARDIAN_API_KEY: ${{ secrets.GITGUARDIAN_API_KEY }}
      GITLEAKS_LICENSE: ${{ secrets.GITLEAKS_LICENSE }}
```

### Manual Release Workflow

```yaml
name: Manual Release

on:
  workflow_dispatch:
    inputs:
      version_bump:
        description: 'Version bump type'
        type: choice
        default: 'patch'
        options: [major, minor, patch]
      security_scan_engine:
        description: 'Security scanning engine'
        type: choice
        default: 'both'
        options: [gitleaks, gitguardian, both]

jobs:
  manual-release:
    uses: bauer-group/automation-templates/.github/workflows/manual-release.yml@main
    with:
      version_bump: ${{ inputs.version_bump }}
      security_scan_engine: ${{ inputs.security_scan_engine }}
    secrets:
      GITGUARDIAN_API_KEY: ${{ secrets.GITGUARDIAN_API_KEY }}
```

## 🔄 Workflow Triggers

### Automatic Release Triggers
- **Push to main**: Initiates release process for new commits
- **PR merge**: Processes merged release PRs
- **Workflow dispatch**: Manual trigger with configuration options

### Manual Release Triggers
- **Workflow dispatch only**: Provides full control over release process

## 📊 Workflow Outputs

### Release Information
- `release_created`: Boolean indicating if release was created
- `tag_name`: Git tag of the release
- `version`: Semantic version number
- `html_url`: GitHub release URL
- `upload_url`: URL for uploading release assets

### Security & Compliance
- `security_score`: Overall security assessment score
- `license_compliance`: License compliance status
- `artifacts_generated`: Artifact generation status

## 🏗️ Integration Patterns

### Repository Setup

1. **Copy workflows** to your `.github/workflows/` directory
2. **Configure secrets** in repository settings
3. **Set permissions** for the GITHUB_TOKEN
4. **Customize inputs** as needed for your project

### Conventional Commits

Use conventional commit messages for automatic version bumping:

```
feat: add new feature (minor version bump)
fix: resolve bug (patch version bump)
feat!: breaking change (major version bump)
docs: update documentation (no version bump)
chore: maintenance tasks (no version bump)
```

### Branch Protection

Recommended branch protection rules:

- **Require status checks**: Ensure security scans pass
- **Require reviews**: At least 1 reviewer for release PRs
- **Restrict pushes**: Only allow through pull requests
- **Include administrators**: Apply rules to repository admins

## 🔧 Customization

### Workflow Modification

1. **Fork this repository** or copy workflows
2. **Modify parameters** in workflow files
3. **Adjust triggers** based on your branching strategy
4. **Configure actions** with your specific requirements

### Action Customization

Workflows use modular actions that can be customized:

- **Security scanning**: Modify `.github/actions/security-scan/`
- **Release management**: Customize `.github/actions/release-please/`
- **Auto-merge logic**: Adjust `.github/actions/auto-merge/`

## 📚 Documentation

### Detailed Guides
- [Action Documentation](../.github/actions/README.md)
- [Security Configuration](../docs/security-setup.md)
- [Release Process Guide](../docs/release-guide.md)

### Best Practices
- **Semantic versioning**: Follow semver.org specifications
- **Conventional commits**: Use standardized commit messages
- **Security scanning**: Enable both engines for comprehensive coverage
- **Branch protection**: Implement proper access controls

## 🛠️ Troubleshooting

### Common Issues

1. **Permission errors**: Verify repository permissions and secrets
2. **Security scan failures**: Check API keys and network access
3. **Release creation failures**: Validate conventional commit format
4. **Auto-merge issues**: Review branch protection rules

### Debug Information

Both workflows include comprehensive debug logging. Enable by:

1. Setting repository variable `ACTIONS_STEP_DEBUG=true`
2. Reviewing workflow run logs for detailed information
3. Checking action outputs for specific error messages

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/bauer-group/automation-templates/issues)
- **Discussions**: [GitHub Discussions](https://github.com/bauer-group/automation-templates/discussions)
- **Enterprise Support**: Contact your GitHub Enterprise administrator

---

*These workflows are production-tested and used in enterprise environments. They follow security best practices and industry standards.*
