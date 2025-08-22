<!-- AUTO-GENERATED FILE. DO NOT EDIT. Edit docs/README.template.MD instead. -->
<!-- Generated on 2025-08-22 22:29:04 UTC -->

# BAUER GROUP - Automation Templates

## Overview

Enterprise-grade GitHub Actions automation repository providing comprehensive CI/CD workflows, security scanning, and deployment automation for modern software development. This repository serves as a central template system for standardizing automation across multiple projects and teams.

**Repository Information:**

- **Version:** 0.22.0 (2025-08-22)
- **Repository:** [bauer-group/automation-templates](https://github.com/bauer-group/automation-templates)
- **Branch:** main
- **Architecture:** Modular, Reusable, Enterprise-Ready

[![🔄 CI/CD Pipeline (Automatic Release)](https://github.com/bauer-group/automation-templates/actions/workflows/automatic-release.yml/badge.svg)](https://github.com/bauer-group/automation-templates/actions/workflows/automatic-release.yml)
[![📄 Documentation Management](https://github.com/bauer-group/automation-templates/actions/workflows/documentation.yml/badge.svg)](https://github.com/bauer-group/automation-templates/actions/workflows/documentation.yml)
[![🛡️ Security Policy Management](https://github.com/bauer-group/automation-templates/actions/workflows/security-management.yml/badge.svg)](https://github.com/bauer-group/automation-templates/actions/workflows/security-management.yml)

## 📋 Project Resources

| Resource | Description | Link |
|----------|-------------|------|
| **🔒 Security Policy** | Vulnerability reporting and security guidelines | [SECURITY.MD](SECURITY.MD) |
| **🤝 Code of Conduct** | Community standards and behavior guidelines | [CODE_OF_CONDUCT.MD](CODE_OF_CONDUCT.MD) |
| **🛠️ Contributing Guide** | Development workflow and contribution standards | [CONTRIBUTING.MD](CONTRIBUTING.MD) |
| **📄 License** | Project licensing information | [LICENSE](LICENSE) |
| **📊 Issue Templates** | Structured issue reporting templates | [.github/ISSUE_TEMPLATE/](.github/ISSUE_TEMPLATE/) |

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
│   ├── actions/               # 🔧 Reusable Composite Actions
│   │   ├── docker-build/      # Docker build with security scanning
│   │   ├── python-setup/      # Python environment setup
│   │   ├── python-test/       # Python testing and coverage
│   │   ├── python-quality/    # Code quality and security scanning
│   │   ├── python-package/    # Python packaging and publishing
│   │   ├── security-scan/     # Multi-engine security scanning
│   │   ├── license-compliance/ # SPDX license compliance
│   │   ├── artifact-generator/ # Multi-format artifact generation
│   │   └── readme-generate/   # Professional README generation
│   ├── config/               # 📋 Configuration Templates
│   │   ├── docker-build/      # Docker build configurations
│   │   │   ├── default.yml         # Basic Docker configuration
│   │   │   ├── web-application.yml # Web app optimized
│   │   │   ├── microservice.yml    # Microservice configuration
│   │   │   └── enterprise.yml      # Enterprise-grade security
│   │   ├── python-build/      # Python build configurations
│   │   │   ├── default.yml         # Standard Python setup
│   │   │   ├── library.yml         # Python library
│   │   │   ├── application.yml     # Python application
│   │   │   └── data-science.yml    # Data science projects
│   │   └── commitlint.config.js # Commit linting rules
│   └── workflows/            # 🚀 Reusable Workflows
│       ├── docker-build.yml       # Docker build & deploy workflow
│       ├── python-build.yml       # Python build & test workflow
│       ├── python-publish.yml     # Python package publishing
│       ├── automatic-release.yml  # Automated release management
│       ├── documentation.yml      # Documentation automation
│       └── examples/         # 📋 Usage Examples
│           ├── docker/            # Docker build examples
│           │   ├── simple-docker-build.yml
│           │   ├── web-application-build.yml
│           │   ├── microservice-build.yml
│           │   ├── enterprise-build.yml
│           │   ├── multi-platform-build.yml
│           │   └── security-focused-build.yml
│           ├── python-build/      # Python project examples
│           │   ├── simple-library.yml
│           │   ├── web-application.yml
│           │   ├── data-science-project.yml
│           │   └── comprehensive-python.yml
│           ├── ci-cd/            # General CI/CD examples
│           │   ├── comprehensive-ci-cd.yml
│           │   └── security-focused.yml
│           └── documentation/     # Documentation examples
├── github/                   # 🛠️ Repository Management Tools
│   ├── branch-protect/       # Branch protection automation
│   ├── cleanup/             # Repository cleanup utilities
│   ├── runner/              # Self-hosted runner management
│   └── workflows/           # Legacy workflow examples
├── docs/                    # 📚 Comprehensive Documentation
│   ├── workflows/           # Workflow documentation
│   │   ├── docker-build.md       # Docker system documentation
│   │   ├── python-build.md       # Python system documentation
│   │   ├── dotnet-build.md       # .NET build documentation
│   │   ├── nodejs-build.md       # Node.js build documentation
│   │   └── php-build.md          # PHP build documentation
│   ├── README.template.MD    # This template file
│   └── SECRETS-NAMING-CONVENTION.md # Secret naming standards
└── scripts/                 # 🔨 Utility Scripts
```

## 🧩 Automation Systems Overview

This repository provides **comprehensive automation systems** for modern software development, featuring modular and reusable components for different technology stacks.

### 🐳 Docker Build System

Complete Docker automation with multi-platform builds, security scanning, and enterprise features.

| Component | Purpose | Usage |
|-----------|---------|-------|
| **🔧 docker-build action** | Multi-platform Docker builds | Composite action with security scanning |
| **🚀 docker-build workflow** | Complete Docker CI/CD | `uses: bauer-group/automation-templates/.github/workflows/docker-build.yml@main` |
| **📋 Configuration Templates** | Pre-configured setups | `default`, `web-application`, `microservice`, `enterprise` |

**Quick Start - Docker:**
```yaml
name: 🐳 Docker Build

on: [push]

jobs:
  docker:
    uses: bauer-group/automation-templates/.github/workflows/docker-build.yml@main
    with:
      config-file: 'web-application'
      image-name: 'my-app'
      image-tag: $
      security-scan: true
    secrets:
      REGISTRY_TOKEN: $
```

### 🐍 Python Build System

Comprehensive Python automation supporting multiple package managers and deployment targets.

| Component | Purpose | Usage |
|-----------|---------|-------|
| **🔧 python-setup action** | Multi-manager Python setup | Supports pip, poetry, pipenv, conda |
| **🧪 python-test action** | Testing and coverage | pytest, unittest, nose2, tox |
| **🔍 python-quality action** | Code quality and security | linting, formatting, security scanning |
| **📦 python-package action** | Packaging and publishing | PyPI, TestPyPI with trusted publishing |
| **🚀 python-build workflow** | Complete Python CI/CD | `uses: bauer-group/automation-templates/.github/workflows/python-build.yml@main` |
| **📤 python-publish workflow** | Package publishing | `uses: bauer-group/automation-templates/.github/workflows/python-publish.yml@main` |

**Quick Start - Python:**
```yaml
name: 🐍 Python Build

on: [push]

jobs:
  python:
    uses: bauer-group/automation-templates/.github/workflows/python-build.yml@main
    with:
      config-file: 'application'
      python-version: '3.11'
      package-manager: 'poetry'
      run-tests: true
      collect-coverage: true
    secrets:
      CODECOV_TOKEN: $
```

### 🛡️ Security & Compliance System

Enterprise-grade security scanning and compliance automation.

| Component | Purpose | Usage |
|-----------|---------|-------|
| **🛡️ security-scan action** | Multi-engine security scanning | Gitleaks, GitGuardian, Trivy |
| **📋 license-compliance action** | License compliance checks | SPDX, FOSSA integration |
| **🔍 Release Management** | Automated releases | Semantic versioning, changelog generation |

### 🏗️ Additional Systems

| System | Status | Description |
|--------|--------|-------------|
| **🟢 .NET Build** | Available | Complete .NET Core/Framework automation |
| **🟢 Node.js Build** | Available | Node.js and npm/yarn automation |
| **🟢 PHP Build** | Available | PHP and Composer automation |
| **🟡 Go Build** | Planned | Go module and build automation |
| **🟡 Rust Build** | Planned | Cargo and Rust build automation |

### 📋 Repository Management Workflows

| Workflow | Purpose | Auto-Generated Files |
|----------|---------|---------------------|
| **📄 Documentation Management** | Auto-generates README.MD from template | [README.MD](README.MD) |
| **🛡️ Security Policy Management** | Auto-generates SECURITY.MD from template | [SECURITY.MD](SECURITY.MD) |
| **🔔 Teams Notifications** | Sends workflow notifications to Microsoft Teams | - |
| **🚀 Automatic Release** | Automated semantic versioning and releases | [CHANGELOG.MD](CHANGELOG.MD) |

These workflows ensure that documentation stays current with version changes and repository updates.

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

1. **Use as template repository:**

   ```bash
   gh repo create my-project --template bauer-group/automation-templates
   cd my-project
   ```

2. **Choose your automation system:**

   ```bash
   # For Docker projects
   cp .github/workflows/examples/docker/web-application-build.yml .github/workflows/

   # For Python projects  
   cp .github/workflows/examples/python-build/web-application.yml .github/workflows/

   # For general CI/CD
   cp .github/workflows/examples/ci-cd/comprehensive-ci-cd.yml .github/workflows/
   ```

3. **Configure required secrets:**

   ```bash
   # Basic (always required)
   gh secret set GITHUB_TOKEN --body "$"

   # Docker builds
   gh secret set REGISTRY_TOKEN --body "your-registry-token"
   gh secret set COSIGN_PRIVATE_KEY --body "$(cat cosign.key)"
   gh secret set COSIGN_PASSWORD --body "your-cosign-password"

   # Python publishing
   gh secret set PYPI_API_TOKEN --body "your-pypi-token"
   gh secret set CODECOV_TOKEN --body "your-codecov-token"

   # Security scanning
   gh secret set GITGUARDIAN_API_KEY --body "your-gitguardian-key"
   ```

4. **Customize configuration:**

   ```bash
   # Edit Docker configuration
   vim .github/config/docker-build/web-application.yml

   # Edit Python configuration  
   vim .github/config/python-build/application.yml

   # Update commit linting rules
   vim .github/config/commitlint.config.js
   ```

### Quick Examples by Technology

#### 🐳 Docker Project Setup

```yaml
# .github/workflows/docker.yml
name: Docker Build & Deploy

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  docker:
    uses: bauer-group/automation-templates/.github/workflows/docker-build.yml@main
    with:
      config-file: 'web-application'
      image-name: 'my-webapp'
      image-tag: $-$
      platforms: 'linux/amd64,linux/arm64'
      security-scan: true
      generate-sbom: true
      sign-image: true
      deploy: $
    secrets:
      REGISTRY_TOKEN: $
      COSIGN_PRIVATE_KEY: $
      COSIGN_PASSWORD: $
```

#### 🐍 Python Project Setup

```yaml
# .github/workflows/python.yml
name: Python Build & Test

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/python-build.yml@main
    with:
      config-file: 'application'
      python-version: '3.11'
      package-manager: 'poetry'
      run-tests: true
      collect-coverage: true
      security-scan: true
      quality-checks: true
    secrets:
      CODECOV_TOKEN: $

  publish:
    if: github.ref == 'refs/heads/main'
    needs: build
    uses: bauer-group/automation-templates/.github/workflows/python-publish.yml@main
    with:
      config-file: 'application'
      package-manager: 'poetry'
      registry: 'pypi'
    secrets:
      PYPI_API_TOKEN: $
```

### Using Individual Actions

#### 🐳 Docker Build Action

```yaml
- name: Build Docker Image
  uses: bauer-group/automation-templates/.github/actions/docker-build@main
  with:
    image-name: 'my-app'
    image-tag: $
    platforms: 'linux/amd64,linux/arm64'
    security-scan: true
    fail-on-severity: 'HIGH'
    generate-sbom: true
    sign-image: true
```

#### 🐍 Python Setup Action

```yaml
- name: Setup Python Environment  
  uses: bauer-group/automation-templates/.github/actions/python-setup@main
  with:
    python-version: '3.11'
    package-manager: 'poetry'
    cache-enabled: true
    install-dependencies: true
```

#### 🛡️ Security Scanning Action

```yaml
- name: Security Scan
  uses: bauer-group/automation-templates/.github/actions/security-scan@main
  with:
    scan-engines: 'both'
    fail-on-findings: true
    github-token: $
    gitguardian-api-key: $
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

## 📚 Comprehensive Documentation

### 🚀 Workflow Systems Documentation

- [🐳 **Docker Build System**](docs/workflows/docker-build.md) - Complete Docker automation guide
- [🐍 **Python Build System**](docs/workflows/python-build.md) - Python project automation
- [🔨 **.NET Build System**](docs/workflows/dotnet-build.md) - .NET Core/Framework automation  
- [📦 **Node.js Build System**](docs/workflows/nodejs-build.md) - Node.js and npm/yarn automation
- [🐘 **PHP Build System**](docs/workflows/php-build.md) - PHP and Composer automation

### 🔧 Actions Documentation  

#### Docker Actions
- [🐳 **docker-build**](.github/actions/docker-build/README.md) - Multi-platform Docker builds with security

#### Python Actions
- [🔧 **python-setup**](.github/actions/python-setup/README.md) - Multi-manager Python environment setup
- [🧪 **python-test**](.github/actions/python-test/README.md) - Testing and coverage collection
- [🔍 **python-quality**](.github/actions/python-quality/README.md) - Code quality and security scanning
- [📦 **python-package**](.github/actions/python-package/README.md) - Package building and publishing

#### Security & Compliance Actions
- [🛡️ **security-scan**](.github/actions/security-scan/README.md) - Multi-engine security scanning
- [📋 **license-compliance**](.github/actions/license-compliance/README.md) - SPDX license compliance
- [🔨 **artifact-generator**](.github/actions/artifact-generator/README.md) - Multi-format artifact generation

#### Utility Actions
- [📝 **readme-generate**](.github/actions/readme-generate/README.md) - Professional README generation
- [🚀 **semantic-release**](.github/actions/semantic-release/README.md) - Automated release management

### 📋 Configuration References

- [🐳 **Docker Configurations**](.github/config/docker-build/) - Docker build configuration templates
- [🐍 **Python Configurations**](.github/config/python-build/) - Python project configuration templates
- [⚙️ **Workflow Configuration**](.github/config/README.md) - General workflow configuration guide
- [🔒 **Secrets Naming Convention**](docs/SECRETS-NAMING-CONVENTION.md) - Standardized secret naming

### 🛠️ Repository Management Tools

- [🔐 **Branch Protection Tools**](github/branch-protect/README.md) - Automated branch protection
- [🧹 **Repository Cleanup Tools**](github/cleanup/README.md) - Repository maintenance utilities  
- [🏃 **Self-Hosted Runner Setup**](github/runner/README.md) - Runner deployment and management

### 📖 Examples and Templates

- [🐳 **Docker Examples**](github/workflows/examples/docker/) - Complete Docker workflow examples
- [🐍 **Python Examples**](github/workflows/examples/python-build/) - Python project examples
- [🔄 **CI/CD Examples**](github/workflows/examples/ci-cd/) - General CI/CD pipeline examples
- [📝 **Documentation Examples**](github/workflows/examples/documentation/) - Documentation automation examples

## 📞 Support & Community

### 🆘 Getting Help

| Need Help With | Resource | Link |
|----------------|----------|------|
| **🐛 Bug Reports** | GitHub Issues with Bug Report template | [Report Bug](https://github.com/bauer-group/automation-templates/issues/new?template=BUG_REPORT.MD) |
| **✨ Feature Requests** | GitHub Issues with Feature Request template | [Request Feature](https://github.com/bauer-group/automation-templates/issues/new?template=FEATURE_REQUEST.MD) |
| **🛠️ Workflow Support** | GitHub Issues with Workflow Support template | [Get Support](https://github.com/bauer-group/automation-templates/issues/new?template=WORKFLOW_SUPPORT.MD) |
| **📚 Documentation Issues** | GitHub Issues with Documentation template | [Report Doc Issue](https://github.com/bauer-group/automation-templates/issues/new?template=DOCUMENTATION.MD) |
| **🔒 Security Vulnerabilities** | Security Advisories (preferred) or Email | [Security Policy](SECURITY.MD) |

### 🤝 Community

- **💬 Discussions:** [GitHub Discussions](https://github.com/bauer-group/automation-templates/discussions) - Ask questions and share ideas
- **🛠️ Contributing:** [Contributing Guide](CONTRIBUTING.MD) - Learn how to contribute
- **📋 Code of Conduct:** [Code of Conduct](CODE_OF_CONDUCT.MD) - Community standards
- **📧 Enterprise Support:** [support@bauer-group.com](mailto:support@bauer-group.com)
- **🌐 Support Portal:** [https://support.bauer-group.com](https://support.bauer-group.com)

### 📖 Documentation

- **📖 Project Wiki:** [https://github.com/bauer-group/automation-templates/wiki](https://github.com/bauer-group/automation-templates/wiki)
- **📝 Examples:** [github/workflows/examples/](github/workflows/examples/)
- **🔧 Configuration Templates:** [.github/config/](.github/config/)
- **⚙️ Action Documentation:** [.github/actions/](.github/actions/)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

*Generated on 2025-08-22 22:29:04 UTC from [docs/README.template.MD](docs/README.template.MD)*
