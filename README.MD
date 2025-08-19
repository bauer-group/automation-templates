<!-- AUTO-GENERATED FILE. DO NOT EDIT. Edit docs/README.template.MD instead. -->
<!-- Generated on 2025-08-19 13:22:45 UTC -->

# BAUER GROUP - Automation Templates

## Overview

Professional automation templates and workflows for GitHub repositories, providing enterprise-grade security scanning, release management, and repository maintenance tools.

**Repository Information:**

- **Version:** 0.1.5 (2025-08-19)
- **Repository:** [bauer-group/automation-templates](https://github.com/bauer-group/automation-templates)
- **Branch:** main

[![🚀 Automatic Release Management](https://github.com/bauer-group/automation-templates/actions/workflows/automatic-release.yml/badge.svg)](https://github.com/bauer-group/automation-templates/actions/workflows/automatic-release.yml)
[![📄 README Documentation Management](https://github.com/bauer-group/automation-templates/actions/workflows/readme.yml/badge.svg)](https://github.com/bauer-group/automation-templates/actions/workflows/readme.yml)

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

      - name: 🚀 Enhanced Release Management
        uses: bauer-group/automation-templates/.github/actions/release-please@main
        with:
          release-type: simple
          security-engines: $
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
│       ├── automatic-release.yml # Automated release management
│       ├── manual-release.yml    # Manual release controls
│       └── readme.yml           # Documentation automation
├── github/                   # Repository management tools
│   ├── branch-protect/       # Branch protection automation
│   ├── cleanup/             # Repository cleanup utilities
│   └── runner/              # Self-hosted runner management
├── docs/                    # Documentation templates
└── scripts/                 # Utility scripts
```

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
2. **Release automation issues**: Validate commit format and release-please configuration
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

- [Security Scanning Guide](.github/actions/security-scan/README.md)
- [Release Management Guide](.github/workflows/README.md)
- [Repository Tools Guide](github/README.md)
- [Contributing Guidelines](CONTRIBUTING.md)

## 📞 Support

- **Issues:** [GitHub Issues](https://github.com/bauer-group/automation-templates/issues)
- **Documentation:** [Project Wiki](https://github.com/bauer-group/automation-templates/wiki)
- **Security:** [Security Policy](https://github.com/bauer-group/automation-templates/security/policy)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

*Professional automation templates for enterprise GitHub workflows. Generated on 2025-08-19 13:22:45 UTC from [docs/README.template.MD](docs/README.template.MD)*
