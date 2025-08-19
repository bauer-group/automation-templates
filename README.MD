# Bauer Group - Automation Templates

**Professional automation templates and workflows for GitHub repositories**

## 🛡️ Overview

This repository provides enterprise-grade automation templates, security scanning tools, and workflow configurations for professional software development. Our solution enables organizations to implement consistent, secure, and efficient development practices across all repositories.

## 🏗️ Architecture

### Core Components

```text
├── .github/
│   ├── actions/               # Reusable GitHub Actions
│   │   ├── security-scan/     # Multi-engine security scanning
│   │   ├── license-compliance/ # SPDX license compliance
│   │   ├── artifact-generator/ # Multi-format artifact generation
│   │   └── auto-merge/        # Intelligent auto-merge capabilities
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

## 🛡️ Security Scanning - Dual Engine Approach

### Comprehensive Security Action

```yaml
- name: 🛡️ Multi-Engine Security Scan
  uses: ./.github/actions/security-scan
  with:
    scan-engines: 'gitleaks,gitguardian'  # or 'gitleaks' or 'gitguardian'
    scan-scope: 'all'                     # secrets, vulnerabilities, all
    fail-on-findings: true
    github-token: ${{ secrets.GITHUB_TOKEN }}
    gitguardian-api-key: ${{ secrets.GITGUARDIAN_API_KEY }}  # Optional
```

### Engine Comparison

| Engine | Speed | Coverage | Enterprise Features | Cost |
|--------|-------|----------|-------------------|------|
| **Gitleaks** | ⚡⚡⚡⚡ | Pattern-based | Basic | Free |
| **GitGuardian** | ⚡⚡⚡ | ML-enhanced | Advanced | Commercial |
| **Both** | ⚡⚡⚡ | Comprehensive | Complete | Hybrid |

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
      enable-auto-merge:
        type: boolean
        default: false

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
          
      - name: 🚀 Enhanced Release Management
        uses: ./.github/actions/release-please
        with:
          release-type: simple
          security-engines: ${{ inputs.security-scan-engines || 'both' }}
          auto-merge: ${{ inputs.enable-auto-merge || 'false' }}
          token: ${{ secrets.GITHUB_TOKEN }}
```

### Manual Release Controls

```yaml
- name: 🎯 Manual Release Trigger
  uses: ./.github/workflows/manual-release.yml
  with:
    release-version: "1.2.3"
    release-notes: "Custom release notes"
    pre-release: false
    security-validation: true
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

[[rules]]
id = "custom-api-key"
description = "Custom API key pattern"
regex = '''(?i)(api[_-]?key|apikey)\s*[:=]\s*["']?([a-zA-Z0-9]{32,})["']?'''
```

#### GitGuardian Configuration (.gitguardian.yaml)

```yaml
version: 2

paths-ignore:
  - .git/**
  - node_modules/**
  - vendor/**
  - "**/*.min.js"
  
secret:
  minimum-severity: medium
  ignore-known-secrets: false
  show-secrets: false
  
policies:
  all-policies: true
  
exclusions:
  - pattern: "password.*=.*test"
    type: "regex"
  - pattern: "demo-api-key"
    type: "literal"
```

### Commit Lint Configuration

**`.github/config/commitlint.config.js`**

```javascript
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [2, 'always', [
      'feat',     // New features
      'fix',      // Bug fixes
      'docs',     // Documentation changes
      'style',    // Code style changes
      'refactor', // Code refactoring
      'test',     // Adding tests
      'chore',    // Maintenance tasks
      'ci',       // CI/CD changes
      'build',    // Build system changes
      'revert',   // Reverting changes
      'perf'      // Performance improvements
    ]],
    'subject-max-length': [2, 'always', 72],
    'header-max-length': [2, 'always', 100]
  }
};
```

## 🚀 Getting Started

### Quick Setup

1. **Fork or use as template**:
   ```bash
   gh repo create my-project --template bauer-group/automation-templates
   ```

2. **Configure secrets**:
   ```bash
   # Required
   gh secret set GITHUB_TOKEN --body "${{ secrets.GITHUB_TOKEN }}"
   
   # Optional (for GitGuardian)
   gh secret set GITGUARDIAN_API_KEY --body "your-api-key"
   
   # Optional (for license compliance)
   gh secret set FOSSA_API_KEY --body "your-fossa-key"
   ```

3. **Customize workflows**:
   ```bash
   # Copy example workflows
   cp .github/workflows/examples/* .github/workflows/
   
   # Edit configuration
   vim .github/config/commitlint.config.js
   ```

### Using Individual Actions

#### Security Scanning

```yaml
# In your workflow
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
    fossa-api-key: ${{ secrets.FOSSA_API_KEY }}
    fail-on-issues: true
    generate-report: true
```

#### Artifact Generation

```yaml
- name: Generate Release Artifacts
  uses: bauer-group/automation-templates/.github/actions/artifact-generator@main
  with:
    artifact-types: 'source,docker,checksums'
    compression: 'zip'
    include-metadata: true
```

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
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          repository: ${{ github.repository_owner }}/${{ matrix.repository }}
          
      - name: Security scan
        uses: bauer-group/automation-templates/.github/actions/security-scan@main
        with:
          scan-engines: 'both'
          report-format: 'sarif'
```

### Policy Enforcement

```yaml
# Branch protection with custom rules
- name: Enforce Branch Protection
  uses: bauer-group/automation-templates/github/branch-protect@main
  with:
    branch-pattern: 'main,develop,release/*'
    require-reviews: 2
    dismiss-stale-reviews: true
    require-code-owner-reviews: true
    require-status-checks: true
    required-checks: 'security-scan,tests,license-check'
```

### Compliance Reporting

```yaml
# Generate compliance reports
- name: Compliance Report
  uses: bauer-group/automation-templates/.github/actions/compliance-report@main
  with:
    standards: 'sox,pci-dss,gdpr'
    output-format: 'pdf,json'
    include-remediation: true
```

## 📊 Repository Management Tools

### Branch Protection Automation

```bash
# Configure branch protection for multiple repositories
cd github/branch-protect
python protect_main.py \
  --repositories "org/repo1,org/repo2" \
  --require-reviews 2 \
  --require-status-checks \
  --enforce-admins
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

## 🔄 Best Practices

### 1. **Layered Security**

- **Pre-commit**: Client-side scanning with Gitleaks
- **CI/CD**: Comprehensive scanning with both engines
- **Production**: Continuous monitoring with GitGuardian

### 2. **Release Management**

- Use **conventional commits** for automatic versioning
- Enable **branch protection** for main branches
- Implement **automated testing** before releases
- Use **semantic versioning** for consistency

### 3. **Configuration Management**

- Store sensitive configuration in **GitHub Secrets**
- Use **environment-specific** configuration files
- Implement **configuration validation** in workflows
- Document all **configuration options**

### 4. **Monitoring and Alerting**

```yaml
# Workflow failure notifications
- name: Notify on Failure
  if: failure()
  uses: actions/slack@v1
  with:
    webhook-url: ${{ secrets.SLACK_WEBHOOK }}
    message: "Security scan failed in ${{ github.repository }}"
```

## 📈 Metrics and Analytics

### Security Metrics

- **Vulnerability detection rate**: Track security findings over time
- **False positive rate**: Monitor scan accuracy
- **Resolution time**: Measure time to fix security issues
- **Coverage metrics**: Ensure comprehensive scanning

### Release Metrics

- **Release frequency**: Track deployment velocity
- **Lead time**: Measure time from commit to production
- **Rollback rate**: Monitor release stability
- **Automation rate**: Track manual vs. automated releases

## 🔧 Troubleshooting

### Common Issues

1. **Security scan failures**:
   ```bash
   # Check scan configuration
   cat .gitleaks.toml
   cat .gitguardian.yaml
   
   # Validate token permissions
   gh auth status --show-token
   ```

2. **Release automation issues**:
   ```bash
   # Check release-please configuration
   cat .release-please-config.json
   
   # Validate commit format
   git log --oneline -10
   ```

3. **Workflow permissions**:
   ```yaml
   permissions:
     contents: write
     security-events: write
     actions: read
     checks: write
   ```

### Debug Mode

```yaml
# Enable debug logging
- name: Debug Security Scan
  uses: ./.github/actions/security-scan
  with:
    debug: true
    verbose: true
  env:
    ACTIONS_STEP_DEBUG: true
```

## 📚 Documentation

- [Security Scanning Guide](.github/actions/security-scan/README.md)
- [Release Management Guide](.github/workflows/README.md)
- [Repository Tools Guide](github/README.md)
- [Contributing Guidelines](CONTRIBUTING.md)

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/bauer-group/automation-templates/issues)
- **Documentation**: [Project Wiki](https://github.com/bauer-group/automation-templates/wiki)
- **Security**: [Security Policy](SECURITY.md)
- **Community**: [Discussions](https://github.com/bauer-group/automation-templates/discussions)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

*Professional automation templates for enterprise GitHub workflows. Maintained by the Bauer Group Development Team.*
