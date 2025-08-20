<!-- AUTO-GENERATED FILE. DO NOT EDIT. Edit docs/README.template.MD instead. -->
<!-- Generated on 2025-08-20 22:10:28 UTC -->

# BAUER GROUP - Automation Templates

## Overview

Professional automation templates and workflows for GitHub repositories, providing enterprise-grade security scanning, release management, and repository maintenance tools.

**Repository Information:**

- **Version:** 0.8.0 (2025-08-20)
- **Repository:** [bauer-group/automation-templates](https://github.com/bauer-group/automation-templates)
- **Branch:** main

[![🔄 CI/CD Pipeline (Automatic Release)](https://github.com/bauer-group/automation-templates/actions/workflows/automatic-release.yml/badge.svg)](https://github.com/bauer-group/automation-templates/actions/workflows/automatic-release.yml)
[![📄 Documentation Management](https://github.com/bauer-group/automation-templates/actions/workflows/documentation.yml/badge.svg)](https://github.com/bauer-group/automation-templates/actions/workflows/documentation.yml)

## 🛡️ Security Scanning

### Comprehensive Security Action

```yaml
- name: 🛡️ Multi-Engine Security Scan
  uses: bauer-group/automation-templates/.github/actions/security-scan@main
  with:
    scan-engines: 'gitleaks,gitguardian'
    scan-scope: 'all'
    fail-on-findings: true
    github-token: $
    gitguardian-api-key: $
```

### Individual Engines

#### Gitleaks (Open Source)

```yaml
- name: ⚡ Fast Secrets Scan
  uses: gitleaks/gitleaks-action@v2
  env:
    GITHUB_TOKEN: $
```

#### GitGuardian (Enterprise)

```yaml
- name: 🛡️ Advanced Security Scan
  uses: GitGuardian/ggshield-action@v1
  with:
    api-key: $
    args: secret scan path .
```

## 📦 Release Management

### Automatic Release Workflow

```yaml
name: 🚀 Automatic Release

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      security-scan-engines:
        type: choice
        default: 'both'
        options: ['gitleaks', 'gitguardian', 'both']

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: 🚀 Semantic Release
        uses: bauer-group/automation-templates/.github/actions/semantic-release@main
        with:
          dry-run: false
          branches: main
          token: $
```

## 🏗️ Repository Structure

```text
├── .github/
│   ├── actions/               # Reusable GitHub Actions
│   │   ├── security-scan/     # Multi-engine security scanning
│   │   ├── license-compliance/ # SPDX license compliance
│   │   ├── artifact-generator/ # Multi-format artifact generation
│   │   └── readme-generate/   # Professional README generation
│   ├── config/               # Configuration files
│   │   └── commitlint.config.js # Commit linting rules
│   └── workflows/            # Production-ready workflows
│       ├── modules/          # 🧩 Modulare Workflow-Komponenten
│       │   ├── security-scan.yml      # Sicherheitsanalyse
│       │   ├── license-compliance.yml # Lizenz-Compliance
│       │   ├── release-management.yml # Release-Automatisierung
│       │   ├── artifact-generation.yml # Artefakt-Erstellung
│       │   └── pr-validation.yml      # Pull Request-Validierung
│       ├── examples/         # 📋 Verwendungsbeispiele
│       │   ├── simple-release.yml     # Einfacher Release-Workflow
│       │   ├── comprehensive-ci-cd.yml # Vollständige CI/CD-Pipeline
│       │   ├── security-focused.yml   # Security-zentrierte Pipeline
│       │   ├── nodejs-project.yml     # Node.js-spezifischer Workflow
│       │   └── readme.yml             # README-Generator
│       ├── automatic-release.yml # Legacy: Monolithischer Workflow
│       ├── manual-release.yml    # Legacy: Manual release controls
│       └── readme.yml           # Documentation automation
├── github/                   # Repository management tools
│   ├── branch-protect/       # Branch protection automation
│   ├── cleanup/             # Repository cleanup utilities
│   └── runner/              # Self-hosted runner management
├── docs/                    # Documentation templates
└── scripts/                 # Utility scripts
```

## 🧩 Modulare Workflow-Architektur

**NEU:** Dieses Repository bietet jetzt **modulare, wiederverwendbare Workflow-Komponenten** anstatt monolithischer Workflows.

### Verfügbare Module

| Modul | Zweck | Verwendung |
|-------|-------|------------|
| **🛡️ modules-security-scan.yml** | Sicherheitsanalyse | `uses: bauer-group/automation-templates/.github/workflows/modules-security-scan.yml@main` |
| **📋 modules-license-compliance.yml** | Lizenz-Compliance | `uses: bauer-group/automation-templates/.github/workflows/modules-license-compliance.yml@main` |
| **🚀 modules-release-management.yml** | Release-Automatisierung | `uses: bauer-group/automation-templates/.github/workflows/modules-release-management.yml@main` |
| **🔨 modules-artifact-generation.yml** | Artefakt-Erstellung | `uses: bauer-group/automation-templates/.github/workflows/modules-artifact-generation.yml@main` |
| **🔍 modules-pr-validation.yml** | Pull Request-Validierung | `uses: bauer-group/automation-templates/.github/workflows/modules-pr-validation.yml@main` |

### Quick Start: Einfacher Release-Workflow

```yaml
name: 🚀 Simple Release

on:
  push:
    branches: [main]

jobs:
  release:
    uses: bauer-group/automation-templates/.github/workflows/modules-release-management.yml@main
    with:
      release-type: 'simple'
    secrets:
      GITHUB_TOKEN: $
```

### Beispiele für verschiedene Projekttypen

- **[Simple Release](https://github.com/bauer-group/automation-templates/blob/main/github/workflows/examples/simple-release.yml)** - Minimaler Release-Workflow
- **[Comprehensive CI/CD](https://github.com/bauer-group/automation-templates/blob/main/github/workflows/examples/comprehensive-ci-cd.yml)** - Vollständige Pipeline
- **[Security-Focused](https://github.com/bauer-group/automation-templates/blob/main/github/workflows/examples/security-focused.yml)** - Security-zentriert
- **[Node.js Project](https://github.com/bauer-group/automation-templates/blob/main/github/workflows/examples/nodejs-project.yml)** - Node.js-spezifisch

## 🔧 Configuration

### Security Engine Configuration

#### Gitleaks Configuration (.gitleaks.toml)

```toml
[extend]
useDefault = true

[allowlist]
paths = [
  ".git/**",
  "node_modules/**",
  "vendor/**"
]

regexes = [
  '''password\s*=\s*["']?(test|demo|example)["']?''',
  '''key\s*=\s*["']?(your[_-]?key[_-]?here)["']?'''
]
```

#### GitGuardian Configuration (.gitguardian.yaml)

```yaml
version: 2

paths-ignore:
  - .git/**
  - node_modules/**
  - vendor/**

secret:
  minimum-severity: medium
  ignore-known-secrets: false

policies:
  all-policies: true
```

### Commit Lint Configuration

**.github/config/commitlint.config.js**

```javascript
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [2, 'always', [
      'feat', 'fix', 'docs', 'style', 'refactor',
      'test', 'chore', 'ci', 'build', 'revert', 'perf'
    ]],
    'subject-max-length': [2, 'always', 72],
    'header-max-length': [2, 'always', 100]
  }
};
```

## 🚀 Getting Started

### Quick Setup

1. **Use as template:**

   ```bash
   gh repo create my-project --template bauer-group/automation-templates
   ```

2. **Configure secrets:**

   ```bash
   # Required
   gh secret set GITHUB_TOKEN --body "$"

   # Optional (for GitGuardian)
   gh secret set GITGUARDIAN_API_KEY --body "your-api-key"
   ```

3. **Customize workflows:**

   ```bash
   # Copy example workflows
   cp .github/workflows/examples/* .github/workflows/

   # Edit configuration
   vim .github/config/commitlint.config.js
   ```

### Using Individual Actions

#### Security Scanning

```yaml
jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Security Scan
        uses: bauer-group/automation-templates/.github/actions/security-scan@main
        with:
          scan-engines: 'both'
          fail-on-findings: true
```

#### License Compliance

```yaml
- name: License Compliance Check
  uses: bauer-group/automation-templates/.github/actions/license-compliance@main
  with:
    fossa-api-key: $
    fail-on-issues: true
```

#### README Generation

```yaml
- name: Generate README
  uses: bauer-group/automation-templates/.github/actions/readme-generate@main
  with:
    template-path: 'docs/README.template.MD'
    project-name: 'My Project'
    company-name: 'My Company'
```

## 🔄 Best Practices

### Security

- **Layered approach**: Use multiple scanning engines for comprehensive coverage
- **Pre-commit hooks**: Implement client-side scanning with Gitleaks
- **Continuous monitoring**: Enable GitGuardian for production environments
- **Secret management**: Store all sensitive data in GitHub Secrets

### Release Management

- **Conventional commits**: Use structured commit messages for automatic versioning
- **Branch protection**: Enable required status checks and reviews
- **Automated testing**: Implement comprehensive test suites
- **Semantic versioning**: Follow semver principles for version numbering

### Documentation

- **Template-based**: Use consistent documentation templates
- **Auto-generation**: Automate README updates with workflows
- **Comprehensive coverage**: Document all features and configurations
- **Regular updates**: Keep documentation current with changes

## 🏛️ Enterprise Features

### Multi-Repository Management

```yaml
# Organization-wide security scanning
name: Organization Security Audit

on:
  schedule:
    - cron: '0 2 * * 1'  # Weekly Monday 2 AM

jobs:
  audit:
    strategy:
      matrix:
        repository: [repo1, repo2, repo3]
    runs-on: ubuntu-latest
    steps:
      - name: Security scan
        uses: bauer-group/automation-templates/.github/actions/security-scan@main
        with:
          scan-engines: 'both'
          report-format: 'sarif'
```

### Policy Enforcement

- **Branch protection**: Automated branch protection rules
- **Required checks**: Enforce security and quality gates
- **Compliance reporting**: Generate audit-ready reports
- **Custom policies**: Implement organization-specific rules

## 📊 Repository Management Tools

### Branch Protection

```bash
# Configure branch protection for multiple repositories
cd github/branch-protect
python protect_main.py \
  --repositories "org/repo1,org/repo2" \
  --require-reviews 2 \
  --require-status-checks
```

### Repository Cleanup

```bash
# Clean up stale branches and releases
cd github/cleanup
python github_cleanup.py \
  --organization "your-org" \
  --cleanup-branches \
  --cleanup-releases \
  --dry-run
```

### Self-Hosted Runner Management

```bash
# Deploy self-hosted runners
cd github/runner
docker-compose up -d

# Scale runners based on load
./scripts/manage.sh scale --instances 5
```

## 🔧 Troubleshooting

### Common Issues

1. **Security scan failures**: Check scan configuration and token permissions
2. **Release automation issues**: Validate commit format and semantic-release configuration
3. **Workflow permissions**: Ensure proper GITHUB_TOKEN permissions
4. **Template rendering**: Verify all required variables are provided

### Debug Commands

```bash
# Test security scan configuration
cat .gitleaks.toml
cat .gitguardian.yaml

# Validate commit format
git log --oneline -10

# Check workflow permissions
gh auth status --show-token
```

## 📚 Documentation

- [GitHub Actions Documentation](.github/actions/README.md)
- [Security Scan Action](.github/actions/security-scan-meta/README.md)
- [License Compliance Action](.github/actions/license-compliance/README.md)
- [Artifact Generator Action](.github/actions/artifact-generator/README.md)
- [README Generator Action](.github/actions/readme-generate/README.md)
- [Semantic Release Action](.github/actions/semantic-release/README.md)
- [Workflow Configuration](.github/config/README.md)
- [Branch Protection Tools](github/branch-protect/README.md)
- [Repository Cleanup Tools](github/cleanup/README.md)
- [Self-Hosted Runner Setup](github/runner/README.md)

## 📞 Support

- **Issues:** [GitHub Issues](https://github.com/bauer-group/automation-templates/issues)
- **Documentation:** [Project Wiki](https://github.com/bauer-group/automation-templates/wiki)
- **Security:** [Security Policy](https://github.com/bauer-group/automation-templates/security/policy)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

*Generated on 2025-08-20 22:10:28 UTC from [docs/README.template.MD](docs/README.template.MD)*
