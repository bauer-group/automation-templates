# Enhanced Release Workflow Beispiel

Enterprise-Workflow mit vollständigen Security-, Compliance- und Artifact-Features.

## Workflow Datei (.github/workflows/enhanced-release.yml)

```yaml
name: 🚀 Enhanced Release Management

on:
  push:
    branches: [ $default-branch ]
    paths-ignore:
      - '**.MD'
      - 'docs/**'
      - '.github/workflows/**'
      - '.github/actions/**'
  pull_request:
    types: [ closed ]
    branches: [ $default-branch ]
  workflow_dispatch:
    inputs:
      release-type:
        description: "Type of release"
        required: false
        default: 'simple'
        type: choice
        options:
          - simple
          - node
          - python
          - rust
          - java
          - go
          - docker
      security-scan-engine:
        description: "Security scanning engine"
        type: choice
        default: 'both'
        options:
          - gitleaks
          - gitguardian  
          - both
      license-check:
        description: "Enable license compliance check"
        type: boolean
        default: true
      artifact-generation:
        description: "Enable artifact generation"
        type: boolean
        default: true
      auto-merge-pr:
        description: "Auto-merge release PR when created"
        type: boolean
        default: false

permissions:
  contents: write
  pull-requests: write
  issues: write
  actions: read
  security-events: write
  packages: write

env:
  ENABLE_SECURITY_SCAN: ${{ github.event_name == 'workflow_dispatch' && inputs.security-scan-engine != '' || 'true' }}
  SECURITY_SCAN_ENGINE: ${{ github.event_name == 'workflow_dispatch' && inputs.security-scan-engine || 'both' }}
  ENABLE_LICENSE_CHECK: ${{ github.event_name == 'workflow_dispatch' && inputs.license-check || 'true' }}
  ENABLE_ARTIFACTS: ${{ github.event_name == 'workflow_dispatch' && inputs.artifact-generation || 'true' }}
  ENABLE_AUTO_MERGE: ${{ github.event_name == 'workflow_dispatch' && inputs.auto-merge-pr || 'false' }}

jobs:
  # Pre-flight checks for pull requests
  pr-validation:
    name: 🔍 PR Validation
    if: github.event_name == 'pull_request' && github.event.pull_request.merged == false
    runs-on: ubuntu-latest
    
    steps:
      - name: 🚀 Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: 📋 Validate Conventional Commits
        uses: wagoid/commitlint-github-action@v5
        with:
          configFile: .github/config/commitlint.config.js

      - name: 🛡️ Security Pre-Check
        if: env.ENABLE_SECURITY_SCAN == 'true'
        uses: ./.github/actions/security-scan-meta
        with:
          scan-engine: ${{ env.SECURITY_SCAN_ENGINE }}
          scan-type: 'secrets'
          fail-on-findings: 'true'
          github-token: ${{ secrets.GITHUB_TOKEN }}

      - name: 📋 License Pre-Check
        if: env.ENABLE_LICENSE_CHECK == 'true'
        uses: ./.github/actions/license-compliance
        with:
          fail-on-forbidden: 'true'
          fail-on-unknown: 'false'
          scan-dependencies: 'false'
          generate-sbom: 'false'
          token: ${{ secrets.GITHUB_TOKEN }}

  # Main release management job
  release-management:
    name: 📦 Release Management
    if: |
      (github.event_name == 'push' && !contains(github.event.head_commit.message, 'chore(main): release')) ||
      (github.event_name == 'pull_request' && github.event.pull_request.merged == true) ||
      github.event_name == 'workflow_dispatch'
    runs-on: ubuntu-latest
    outputs:
      release_created: ${{ steps.enhanced-release.outputs.release_created }}
      tag_name: ${{ steps.enhanced-release.outputs.tag_name }}
      version: ${{ steps.enhanced-release.outputs.version }}
      upload_url: ${{ steps.enhanced-release.outputs.upload_url }}
    
    steps:
      - name: 🚀 Checkout Repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: 🚀 Enhanced Release Please
        id: enhanced-release
        uses: ./.github/actions/release-please
        with:
          release-type: ${{ env.RELEASE_TYPE }}
          security-scan-engine: ${{ env.SECURITY_SCAN_ENGINE }}
          security-scan-enabled: ${{ env.ENABLE_SECURITY_SCAN }}
          license-check-enabled: ${{ env.ENABLE_LICENSE_CHECK }}
          artifact-generation-enabled: ${{ env.ENABLE_ARTIFACTS }}
          auto-merge-enabled: ${{ env.ENABLE_AUTO_MERGE }}
          token: ${{ secrets.GITHUB_TOKEN }}

  # Extended artifact generation
  extended-artifacts:
    name: 🔨 Extended Artifact Generation
    if: needs.release-management.outputs.release_created == 'true'
    needs: release-management
    runs-on: ubuntu-latest
    
    steps:
      - name: 🚀 Checkout
        uses: actions/checkout@v4

      - name: 🔨 Generate Artifacts
        uses: ./.github/actions/artifact-generator
        with:
          artifact-types: 'source,binaries'
          tag-name: ${{ needs.release-management.outputs.tag_name }}
          version: ${{ needs.release-management.outputs.version }}
          upload-url: ${{ needs.release-management.outputs.upload_url }}
          token: ${{ secrets.GITHUB_TOKEN }}

  # Post-release actions
  post-release:
    name: 🎯 Post-Release Actions
    if: needs.release-management.outputs.release_created == 'true'
    needs: [release-management, extended-artifacts]
    runs-on: ubuntu-latest
    
    steps:
      - name: 🚀 Checkout
        uses: actions/checkout@v4

      - name: 📢 Release Notification
        uses: actions/github-script@v7
        with:
          script: |
            console.log('🎉 Enhanced release created successfully!');
            console.log('Version: ${{ needs.release-management.outputs.version }}');
            console.log('Features: Security ✅ | License ✅ | Artifacts ✅');
```

## Features des Enhanced Workflows

### 🛡️ Security Features
- **Dual-Engine Security Scanning**: Gitleaks + GitGuardian
- **Pre-Commit Hooks**: Security-Checks vor Release
- **SARIF Integration**: Security Analysis Results Interchange Format
- **Custom Pattern Support**: Erweiterte Secret-Detection

### 📋 License Compliance
- **SPDX Validation**: Standardisierte Lizenz-Identifier
- **Forbidden License Detection**: Automatische Erkennung inkompatibel Lizenzen
- **SBOM Generation**: Software Bill of Materials
- **Dependency Scanning**: npm, pip, go mod, Maven Support

### 📦 Artifact Generation
- **Source Archives**: ZIP, TAR.GZ, TAR.XZ
- **Binary Packaging**: Cross-Platform Binary Support
- **Docker Images**: Automatisches Build & Registry Push
- **Checksums**: SHA256, SHA512, MD5 Verification

### 🔄 Auto-Merge
- **Smart Merging**: Intelligente PR-Merge-Entscheidungen
- **Author Whitelist**: Vertrauenswürdige Bots und Services
- **Label Controls**: Erforderliche und verbotene Labels
- **Status Check Waiting**: CI/CD-Pipeline-Completion

## Repository Secrets

Für den Enhanced Workflow sind diese Secrets erforderlich:

```yaml
# Required
GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}  # Automatisch verfügbar

# Optional für erweiterte Features
GITLEAKS_LICENSE_KEY: ${{ secrets.GITLEAKS_LICENSE_KEY }}      # Gitleaks Pro
GITGUARDIAN_API_KEY: ${{ secrets.GITGUARDIAN_API_KEY }}        # GitGuardian Enterprise
```

## Konfigurationsdateien

### .github/config/enhanced-release-please-config.json

```json
{
  "packages": {
    ".": {
      "release-type": "node",
      "package-name": "my-enterprise-project",
      "bump-minor-pre-major": false,
      "bump-patch-for-minor-pre-major": false,
      "draft": false,
      "prerelease": false,
      "include-v-in-tag": false,
      "include-component-in-tag": false,
      "extra-files": [
        {
          "type": "json",
          "path": "package.json",
          "jsonpath": "$.version"
        }
      ]
    }
  },
  "$schema": "https://raw.githubusercontent.com/googleapis/release-please/main/schemas/config.json"
}
```

### .gitleaks.toml

```toml
[extend]
useDefault = true

[[rules]]
description = "Custom API Key Pattern"
id = "custom-api-key"
regex = '''(?i)api[_-]?key['\s]*[=:]['\s]*[0-9a-z]{32,}'''
keywords = ["api", "key"]

[allowlist]
description = "Allowlist for test files"
paths = [
  '''test/.*''',
  '''tests/.*''',
  '''spec/.*'''
]
```

### .gitguardian.yml

```yaml
version: 2
api_url: https://dashboard.gitguardian.com
ignored_matches:
  - name: "Test files"
    match: "test/**/*"
  - name: "Documentation"
    match: "docs/**/*"

paths-ignore:
  - "test/**/*"
  - "tests/**/*"
  - "*.md"
  - "docs/**/*"
```

## Trigger Conditions

1. **Push auf main**: Mit releasable Commits
2. **PR merged**: Nach erfolgreichem Merge
3. **Manual**: workflow_dispatch mit umfassenden Optionen

## Workflow-Auswahl Guide

### Verwende Enhanced Release wenn:
- ✅ Enterprise-Security-Anforderungen
- ✅ Compliance-kritische Projekte
- ✅ Umfassende Artifact-Generierung benötigt
- ✅ Automatisiertes PR-Management gewünscht
- ✅ Detaillierte Security & License Reports erforderlich
