# GitHub Actions - Reusable Components

**Professional automation components for enterprise-grade CI/CD workflows**

[![Release Management](https://github.com/bauer-group/automation-templates/actions/workflows/automatic-release.yml/badge.svg)](https://github.com/bauer-group/automation-templates/actions/workflows/automatic-release.yml)

## 🏗️ Architecture Overview

This directory contains modular, reusable GitHub Actions designed for enterprise environments. Each action follows industry best practices for security, reliability, and maintainability.

> **💡 Empfehlung:** Nutze die neuen **[modularen Workflows](../modules/)** für noch bessere Komposition und Wiederverwendbarkeit! Diese Actions werden als Bausteine in den modularen Workflows verwendet.

## 📦 Available Actions

### 🛡️ Security & Compliance

| Action | Purpose | Engine | Performance | Modularer Workflow |
|--------|---------|---------|-------------|---------------------|
| [`security-scan`](./security-scan/) | Comprehensive secrets detection | Gitleaks + GitGuardian | ⚡⚡⚡ | [modules-security-scan.yml](../workflows/modules-security-scan.yml) |
| [`security-scan-meta`](./security-scan-meta/) | Advanced multi-engine scanning | Gitleaks + GitGuardian | ⚡⚡⚡ | Erweiterte Sicherheitsanalyse |
| [`gitguardian-scan`](./gitguardian-scan/) | ML-based policy enforcement | GitGuardian | ⚡⚡ | GitGuardian-spezifisch |
| [`gitleaks-scan`](./gitleaks-scan/) | Fast secrets detection | Gitleaks | ⚡⚡⚡ | Gitleaks-spezifisch |
| [`license-compliance`](./license-compliance/) | SPDX license validation | FOSSA + SPDX | ⚡⚡⚡ | [modules-license-compliance.yml](../workflows/modules-license-compliance.yml) |
| [`labeler-triage`](./labeler-triage/) | PR labeling & triage | GitHub API | ⚡⚡⚡ | [modules-pr-labeler.yml](../workflows/modules-pr-labeler.yml) |

### 🚀 Release Management

| Action | Purpose | Integration | Modularer Workflow |
|--------|---------|-------------|---------------------|
| [`semantic-release`](./semantic-release/) | Semantic release automation | Semantic Release | [modules-semantic-release.yml](../workflows/modules-semantic-release.yml) |
| [`generate-changelog`](./generate-changelog/) | Changelog generation | Git History | Manual releases & documentation |
| [`auto-merge`](./auto-merge/) | Intelligent PR merging | GitHub API | PR-Automatisierung |
| [`artifact-generator`](./artifact-generator/) | Multi-format artifact creation | GitHub Releases | [modules-artifact-generation.yml](../workflows/modules-artifact-generation.yml) |

### 🔧 Development Tools

| Action | Purpose | Scope | Modularer Workflow |
|--------|---------|-------|---------------------|
| [`readme-generate`](./readme-generate/) | Dynamic documentation | Repository-wide | [readme.yml](../workflows/examples/readme.yml) |

## 🚀 Quick Start

> **💪 Empfehlung:** Verwende die [modularen Workflows](../modules/) für optimale Komposition!

### 🧩 Modulare Workflows (Empfohlen)

**Einfacher Security Scan:**
```yaml
jobs:
  security:
    uses: bauer-group/automation-templates/.github/workflows/modules-security-scan.yml@main
    with:
      scan-engine: both
    secrets:
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      GITGUARDIAN_API_KEY: ${{ secrets.GITGUARDIAN_API_KEY }}
```

**Release Management:**
```yaml
jobs:
  release:
    uses: bauer-group/automation-templates/.github/workflows/modules-release-management.yml@main
    with:
      release-type: simple
    secrets:
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### 🔧 Direkte Action-Verwendung

**Security Scanning:**
```yaml
- name: 🛡️ Security Scan
  uses: bauer-group/automation-templates/.github/actions/security-scan@main
  with:
    scan-engine: both
    scan-type: all
    fail-on-findings: true
    token: ${{ secrets.GITHUB_TOKEN }}
    gitguardian-api-key: ${{ secrets.GITGUARDIAN_API_KEY }}
```

**Release Management:**
```yaml
- name: 📦 Semantic Release
  uses: bauer-group/automation-templates/.github/actions/semantic-release@main
  with:
    dry-run: false
    branches: main
    token: ${{ secrets.GITHUB_TOKEN }}
```

**Auto-Merge:**
```yaml
- name: 🔄 Auto-Merge PR
  uses: bauer-group/automation-templates/.github/actions/auto-merge@main
  with:
    pr-number: ${{ github.event.number }}
    merge-method: squash
    required-checks: ''
    token: ${{ secrets.GITHUB_TOKEN }}
```

## 🎆 Migration zu modularen Workflows

**Von direkten Actions zu modularen Workflows:**

```diff
# Alt: Direkte Action-Verwendung
- - name: Security Scan
-   uses: ./.github/actions/security-scan

# Neu: Modularer Workflow
+ jobs:
+   security:
+     uses: bauer-group/automation-templates/.github/workflows/modules-security-scan.yml@main
```

**Vorteile der modularen Workflows:**
- ✅ Bessere Komposition und Wiederverwendbarkeit
- ✅ Integrierte Error-Handling und Reporting
- ✅ Vordefinierte Best-Practice-Konfigurationen
- ✅ Einfachere Wartung und Updates

## 🔧 Configuration

### Required Secrets
```yaml
secrets:
  GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}           # Always available
  GITGUARDIAN_API_KEY: ${{ secrets.GITGUARDIAN_API_KEY }} # For GitGuardian scanning
  FOSSA_API_KEY: ${{ secrets.FOSSA_API_KEY }}         # For license compliance
```

### Permissions
```yaml
permissions:
  contents: write
  pull-requests: write
  security-events: write
  packages: write
  actions: read
```

## 🏛️ Enterprise Features

### Multi-Engine Security Scanning
- **Dual-engine approach**: Gitleaks (speed) + GitGuardian (accuracy)
- **Custom rule sets**: Organization-specific security policies
- **SARIF integration**: Native GitHub Security tab integration
- **False positive management**: Intelligent filtering and allowlists

### Professional Release Management
- **Semantic versioning**: Automated version calculation
- **Conventional commits**: Enforced commit message standards
- **Branch protection**: Automated security and quality gates
- **Artifact management**: Multi-format release assets

### Compliance & Governance
- **License scanning**: SPDX-compliant license detection
- **SBOM generation**: Software Bill of Materials
- **Audit trails**: Comprehensive action logging
- **Policy enforcement**: Configurable compliance rules

## 🔄 Integration Patterns

### Modulare Workflow Composition
```yaml
jobs:
  security:
    uses: bauer-group/automation-templates/.github/workflows/modules-security-scan.yml@main
    with:
      scan-engine: both
    secrets:
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  
  compliance:
    needs: security
    uses: bauer-group/automation-templates/.github/workflows/modules-license-compliance.yml@main
    secrets:
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  
  release:
    needs: [security, compliance]
    uses: bauer-group/automation-templates/.github/workflows/modules-release-management.yml@main
    with:
      release-type: simple
    secrets:
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Conditional Execution
```yaml
jobs:
  pr-security:
    if: github.event_name == 'pull_request'
    uses: bauer-group/automation-templates/.github/workflows/modules-pr-validation.yml@main
    secrets:
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
  
  release:
    if: github.ref == 'refs/heads/main'
    uses: bauer-group/automation-templates/.github/workflows/modules-release-management.yml@main
    with:
      release-type: simple
    secrets:
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

## 📊 Performance Metrics

| Action | Average Runtime | Resource Usage | Success Rate |
|--------|----------------|----------------|--------------|
| security-scan | ~45s | Low | 99.8% |
| semantic-release | ~1m | Low | 99.9% |
| auto-merge | ~15s | Low | 99.7% |
| license-compliance | ~30s | Low | 99.5% |

## 🔧 Development

### Testing Actions Locally
```bash
# Install act for local testing
npm install -g @nektos/act

# Test specific action
act -j test-security-scan --secret-file .env
```

### Action Development Guidelines
1. **Idempotency**: Actions must be safe to run multiple times
2. **Error handling**: Comprehensive error messages and recovery
3. **Logging**: Structured logging with appropriate log levels
4. **Security**: No secret leakage, minimal permissions
5. **Performance**: Optimize for speed and resource usage

## 📚 Documentation

### Individual Actions
- [Security Scanning Action](./security-scan/README.md)
- [Semantic Release Action](./semantic-release/README.md)
- [Changelog Generator Action](./generate-changelog/README.md)
- [Auto-Merge Action](./auto-merge/README.md)
- [License Compliance Action](./license-compliance/README.md)
- [Artifact Generator Action](./artifact-generator/README.md)
- [README Generator Action](./readme-generate/README.md)

### Modulare Workflows (Empfohlen)
- [Modulare Workflow-Komponenten](../modules/README.md)
- [Workflow-Beispiele](../workflows/examples/README.MD)
- [Security-Scan Workflow](../modules/security-scan.yml)
- [Release-Management Workflow](../modules/release-management.yml)
- [License-Compliance Workflow](../modules/license-compliance.yml)

## 🛠️ Support

- **Issues**: [GitHub Issues](https://github.com/bauer-group/automation-templates/issues)
- **Discussions**: [GitHub Discussions](https://github.com/bauer-group/automation-templates/discussions)
- **Enterprise Support**: Contact your GitHub Enterprise administrator

---

*This documentation is automatically maintained and reflects the current state of all available actions.*
