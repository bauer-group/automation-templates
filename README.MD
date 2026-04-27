<!-- AUTO-GENERATED FILE. DO NOT EDIT. Edit docs/README.template.MD instead. -->
<!-- Generated on 2026-04-27 22:41:48 UTC -->

# BAUER GROUP - Automation Templates

## Overview

Enterprise-grade GitHub Actions automation repository providing comprehensive CI/CD workflows, security scanning, and deployment automation for modern software development. This repository serves as a central template system for standardizing automation across multiple projects and teams.

**Repository Information:**

- **Version:** 6.2.1 (2026-04-27)
- **Repository:** [bauer-group/automation-templates](https://github.com/bauer-group/automation-templates)
- **Branch:** main
- **Architecture:** Modular, Reusable, Enterprise-Ready

[![🔄 CI/CD](https://github.com/bauer-group/automation-templates/actions/workflows/automatic-release.yml/badge.svg)](https://github.com/bauer-group/automation-templates/actions/workflows/automatic-release.yml)
[![📄 Documentation](https://github.com/bauer-group/automation-templates/actions/workflows/documentation.yml/badge.svg)](https://github.com/bauer-group/automation-templates/actions/workflows/documentation.yml)
[![🛡️ Security Policy](https://github.com/bauer-group/automation-templates/actions/workflows/security-management.yml/badge.svg)](https://github.com/bauer-group/automation-templates/actions/workflows/security-management.yml)

## 📋 Project Resources

| Resource | Description | Link |
|----------|-------------|------|
| **🔒 Security Policy** | Vulnerability reporting and security guidelines | [SECURITY.MD](SECURITY.MD) |
| **🤝 Code of Conduct** | Community standards and behavior guidelines | [CODE_OF_CONDUCT.MD](CODE_OF_CONDUCT.md) |
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
    github-token: ${{ secrets.GITHUB_TOKEN }}
    gitguardian-api-key: ${{ secrets.GITGUARDIAN_API_KEY }}
```

### Individual Engines

#### Gitleaks (Open Source)

```yaml
- name: ⚡ Fast Secrets Scan
  uses: gitleaks/gitleaks-action@v2
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

#### GitGuardian (Enterprise)

```yaml
- name: 🛡️ Advanced Security Scan
  uses: GitGuardian/ggshield-action@v1
  with:
    api-key: ${{ secrets.GITGUARDIAN_API_KEY }}
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
          token: ${{ secrets.GITHUB_TOKEN }}
```

## 🏗️ Repository Structure

```text
├── .github/
│   ├── actions/               # 🔧 Reusable Composite Actions
│   │   ├── action-resolver/      # Dynamic action resolution
│   │   ├── artifact-generator/   # Multi-format artifact generation
│   │   ├── auto-merge/           # Automated PR merging
│   │   ├── claude-code/          # AI-powered code assistant
│   │   ├── docker-build/         # Docker build with security scanning
│   │   ├── generate-changelog/   # Changelog generation
│   │   ├── gitguardian-scan/     # GitGuardian security scanning
│   │   ├── gitleaks-scan/        # Gitleaks secret detection
│   │   ├── labeler-triage/       # Issue/PR labeling and triage
│   │   ├── license-compliance/   # SPDX license compliance
│   │   ├── makefile-build/       # Makefile build automation
│   │   ├── readme-generate/      # Professional README generation
│   │   ├── repository-cleanup/   # Repository maintenance automation
│   │   ├── security-generate/    # Security policy generation
│   │   ├── security-scan/        # Multi-engine security scanning
│   │   ├── security-scan-meta/   # Security scan metadata
│   │   ├── semantic-release/     # Automated semantic releases
│   │   ├── teams-notification/   # Microsoft Teams integration
│   │   ├── dotnet-nuget/         # .NET NuGet build and pack
│   │   ├── zephyr-build/         # Zephyr RTOS build automation
│   │   ├── esp32-build/          # ESP32 microcontroller build automation
│   │   ├── stm32-build/          # STM32 microcontroller build automation
│   │   └── platformio-build/     # PlatformIO cross-platform builds
│   ├── config/                # 📋 Configuration Templates
│   │   ├── claude-code/          # Claude Code Assistant configurations
│   │   ├── docker-build/         # Docker build configurations
│   │   ├── dotnet-build/         # .NET build configurations
│   │   ├── dotnet-desktop-build/ # .NET desktop build configurations
│   │   ├── issues/               # Issue template configurations
│   │   ├── makefile-build/       # Makefile build configurations
│   │   ├── meta-repository/      # Meta repository sync configurations
│   │   ├── nodejs-build/         # Node.js build configurations
│   │   ├── php-build/            # PHP build configurations
│   │   ├── pr-labeler/           # PR labeler configurations
│   │   ├── python-build/         # Python build configurations
│   │   ├── release/              # Release configurations
│   │   ├── repository-cleanup/   # Repository cleanup configurations
│   │   ├── security-policy/      # Security policy configurations
│   │   ├── shopware5-build/      # Shopware 5 plugin configurations
│   │   ├── teams-notification/   # Teams notification configurations
│   │   ├── zephyr-build/         # Zephyr RTOS configurations
│   │   ├── esp32-build/          # ESP32 microcontroller configurations
│   │   ├── stm32-build/          # STM32 microcontroller configurations
│   │   ├── platformio-build/     # PlatformIO build configurations
│   │   └── commitlint.config.js  # Commit linting rules
│   └── workflows/             # 🚀 Reusable Workflows
│       ├── ai-issue-summary.yml       # AI-powered issue summarization
│       ├── automatic-release.yml      # Automated release management
│       ├── claude-code.yml            # Claude Code AI assistant
│       ├── coolify-deploy.yml         # Coolify deployment automation
│       ├── docker-build.yml           # Docker build & deploy
│       ├── documentation.yml          # Documentation automation
│       ├── dotnet-build.yml           # .NET build & test
│       ├── dotnet-desktop-build.yml   # .NET desktop builds
│       ├── dotnet-publish-library.yml # .NET library NuGet publishing
│       ├── issue-automation.yml       # Automated issue management
│       ├── makefile-build.yml         # Makefile-based builds
│       ├── manual-release.yml         # Manual release workflow
│       ├── meta-repository-sync.yml   # Meta repository synchronization
│       ├── nodejs-build.yml           # Node.js build & test
│       ├── php-build.yml              # PHP build & test
│       ├── pr-labeler.yml             # Pull request labeling
│       ├── python-build.yml           # Python builds & testing
│       ├── python-semantic-release.yml # Python semantic releases
│       ├── repository-cleanup.yml     # Repository maintenance
│       ├── security-management.yml    # Security policy management
│       ├── shopware5-build.yml        # Shopware 5 plugin builds
│       ├── teams-notifications.yml    # Microsoft Teams notifications
│       ├── zephyr-build.yml           # Zephyr RTOS builds
│       ├── esp32-build.yml            # ESP32 microcontroller builds
│       ├── stm32-build.yml            # STM32 microcontroller builds
│       ├── platformio-build.yml       # PlatformIO cross-platform builds
│       ├── modules-validate-dockerfile.yml # Dockerfile validation (Hadolint)
│       ├── modules-validate-compose.yml    # Docker Compose validation
│       ├── modules-validate-shellscript.yml # Shell script validation (ShellCheck)
│       └── modules-*.yml              # Additional module workflows
├── github/                    # 🛠️ Repository Management Tools
│   ├── branch-protect/           # Branch protection automation
│   ├── claude-code/              # Claude Code documentation & tools
│   ├── cleanup/                  # Repository cleanup utilities
│   ├── runner/                   # Self-hosted runner management
│   └── workflows/                # Workflow examples & documentation
│       └── examples/             # 📋 Usage Examples
│           ├── ci-cd/                # General CI/CD examples
│           ├── claude-code/          # Claude Code assistant examples
│           ├── coolify-deploy/       # Coolify deployment examples
│           ├── docker/               # Docker build examples
│           ├── docker-compose/       # Docker Compose examples
│           ├── dockerfile-validation/ # Dockerfile linting examples
│           ├── documentation/        # Documentation examples
│           ├── dotnet-build/         # .NET project examples
│           ├── dotnet-desktop-build/ # .NET desktop examples
│           ├── dotnet-nuget/         # .NET NuGet publishing examples
│           ├── makefile-build/       # Makefile project examples
│           ├── meta-repository/      # Meta repository examples
│           ├── nodejs-build/         # Node.js project examples
│           ├── php-build/            # PHP project examples
│           ├── project-templates/    # Project template examples
│           ├── python-build/         # Python project examples
│           ├── python-release/       # Python release examples
│           ├── release/              # Release workflow examples
│           ├── repository-cleanup/   # Repository cleanup examples
│           ├── security/             # Security workflow examples
│           ├── shopware5-build/      # Shopware 5 plugin examples
│           ├── teams-notification/   # Teams notification examples
│           ├── zephyr-build/         # Zephyr RTOS examples
│           ├── esp32-build/          # ESP32 microcontroller examples
│           ├── stm32-build/          # STM32 microcontroller examples
│           └── platformio-build/     # PlatformIO build examples
├── docs/                      # 📚 Comprehensive Documentation
│   ├── workflows/                # Workflow documentation
│   │   ├── claude-code.md            # Claude Code AI assistant
│   │   ├── coolify-deploy.md         # Coolify deployment
│   │   ├── docker-build.md           # Docker build system
│   │   ├── dotnet-build.md           # .NET build system
│   │   ├── dotnet-desktop-build.md   # .NET desktop builds
│   │   ├── makefile-build.md         # Makefile build system
│   │   ├── meta-repository-sync.md   # Meta repository sync
│   │   ├── modules-validate-compose.md # Compose validation
│   │   ├── modules-validate-dockerfile.md # Dockerfile validation (Hadolint)
│   │   ├── modules-validate-shellscript.md # Shell validation
│   │   ├── nodejs-build.md           # Node.js build system
│   │   ├── php-build.md              # PHP build system
│   │   ├── python-build.md           # Python build system
│   │   ├── python-semantic-release.md # Python releases
│   │   ├── shopware5-build.md        # Shopware 5 plugin builds
│   │   ├── teams-notifications.md    # Teams notifications
│   │   ├── zephyr-build.md           # Zephyr RTOS builds
│   │   ├── esp32-build.md            # ESP32 microcontroller builds
│   │   ├── stm32-build.md            # STM32 microcontroller builds
│   │   └── platformio-build.md       # PlatformIO builds
│   ├── README.template.MD        # This template file
│   └── SECRETS-NAMING-CONVENTION.md # Secret naming standards
└── scripts/                   # 🔨 Utility Scripts
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
      image-tag: ${{ github.sha }}
      security-scan: true
    secrets:
      REGISTRY_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### 🐍 Python Semantic Release System

Modern Python automation with semantic versioning, automated releases, and comprehensive CI/CD pipeline.

| Component | Purpose | Usage |
|-----------|---------|-------|
| **🚀 python-semantic-release workflow** | Complete Python Semantic Release CI/CD | `uses: bauer-group/automation-templates/.github/workflows/python-semantic-release.yml@main` |

**Features:**
- ✅ **Semantic Versioning** - Automatic version bumps based on conventional commits
- ✅ **Trusted Publishing** - Secure PyPI publishing without API tokens
- ✅ **Local Wheel Testing** - Pre-release package validation
- ✅ **Documentation Updates** - Automatic documentation refresh
- ✅ **Security Policy Updates** - Automated security policy maintenance

**Quick Start - Python:**
```yaml
name: 🐍 Python Semantic Release

on: [push, pull_request]

jobs:
  python-release:
    uses: bauer-group/automation-templates/.github/workflows/python-semantic-release.yml@main
    with:
      python-version: '3.12'
      run-tests: true
      build-local-wheel: true
      update-documentation: true
      run-tests: true
      collect-coverage: true
    secrets:
      CODECOV_TOKEN: ${{ secrets.CODECOV_TOKEN }}
```

### 🛡️ Security & Compliance System

Enterprise-grade security scanning and compliance automation.

| Component | Purpose | Usage |
|-----------|---------|-------|
| **🛡️ security-scan action** | Multi-engine security scanning | Gitleaks, GitGuardian, Trivy |
| **📋 license-compliance action** | License compliance checks | SPDX, FOSSA integration |
| **🔍 Release Management** | Automated releases | Semantic versioning, changelog generation |

### ⚡ Zephyr RTOS Build System

Complete automation for Zephyr Real-Time Operating System projects with multi-platform support and hardware testing.

| Component | Purpose | Usage |
|-----------|---------|-------|
| **🔧 zephyr-build action** | Multi-board Zephyr builds | Composite action with SDK setup, testing, coverage |
| **🚀 zephyr-build workflow** | Complete Zephyr CI/CD | `uses: bauer-group/automation-templates/.github/workflows/zephyr-build.yml@main` |
| **📋 Configuration Templates** | Pre-configured setups | `default`, `iot-device`, `embedded-system`, `sample-application` |

**Quick Start - Zephyr:**
```yaml
name: ⚡ Zephyr Build

on: [push]

jobs:
  zephyr:
    uses: bauer-group/automation-templates/.github/workflows/zephyr-build.yml@main
    with:
      boards: '["qemu_x86", "esp32", "nucleo_f429zi"]'
      build-types: '["debug", "release"]'
      run-tests: true
      enable-coverage: true
```

### 📟 ESP32 Build System

Complete automation for ESP32 microcontroller projects using official Espressif ESP-IDF toolchain.

| Component | Purpose | Usage |
|-----------|---------|-------|
| **🔧 esp32-build action** | ESP32 firmware builds | Composite action with ESP-IDF setup, testing |
| **🚀 esp32-build workflow** | Complete ESP32 CI/CD | `uses: bauer-group/automation-templates/.github/workflows/esp32-build.yml@main` |
| **📋 Configuration Templates** | Pre-configured setups | `default`, `iot-device`, `industrial`, `prototype` |

**Features:**
- ✅ **Official ESP-IDF Docker Images** - Espressif's official container images
- ✅ **Multi-Target Support** - ESP32, ESP32-S2, ESP32-S3, ESP32-C3, ESP32-C6
- ✅ **VS Code ESP-IDF Extension** - Support for VS Code project structure
- ✅ **OTA Updates** - Over-the-Air firmware update support
- ✅ **Secure Boot & Flash Encryption** - Production security features

**Quick Start - ESP32:**
```yaml
name: 📟 ESP32 Build

on: [push]

jobs:
  esp32:
    uses: bauer-group/automation-templates/.github/workflows/esp32-build.yml@main
    with:
      idf-version: 'v5.3'
      targets: '["esp32", "esp32s3", "esp32c3"]'
      run-tests: true
      create-release: ${{ startsWith(github.ref, 'refs/tags/v') }}
```

### 🔧 STM32 Build System

Complete automation for STM32 microcontroller projects with support for multiple build systems.

| Component | Purpose | Usage |
|-----------|---------|-------|
| **🔧 stm32-build action** | STM32 firmware builds | Composite action with ARM toolchain, CubeIDE support |
| **🚀 stm32-build workflow** | Complete STM32 CI/CD | `uses: bauer-group/automation-templates/.github/workflows/stm32-build.yml@main` |
| **📋 Configuration Templates** | Pre-configured setups | `default`, `industrial`, `prototype`, `low-power` |

**Features:**
- ✅ **Multiple Build Systems** - Makefile, CMake, STM32CubeIDE
- ✅ **CubeIDE Version Support** - Configurable STM32CubeIDE versions (1.16.0, 1.15.x, etc.)
- ✅ **Multi-MCU Matrix** - Build for multiple STM32 families in parallel
- ✅ **Static Analysis** - Integrated code quality checks
- ✅ **Industrial Compliance** - Quality gates for industrial applications

**Quick Start - STM32:**
```yaml
name: 🔧 STM32 Build

on: [push]

jobs:
  stm32:
    uses: bauer-group/automation-templates/.github/workflows/stm32-build.yml@main
    with:
      build-system: 'cmake'
      mcus: '["STM32F446RE", "STM32H743ZI"]'
      cubeide-version: '1.16.0'
      run-tests: true
```

### ⚡ PlatformIO Build System

Complete automation for PlatformIO cross-platform embedded development.

| Component | Purpose | Usage |
|-----------|---------|-------|
| **🔧 platformio-build action** | Multi-environment PlatformIO builds | Composite action with testing, analysis |
| **🚀 platformio-build workflow** | Complete PlatformIO CI/CD | `uses: bauer-group/automation-templates/.github/workflows/platformio-build.yml@main` |
| **📋 Configuration Templates** | Pre-configured setups | `default`, `multi-platform`, `production`, `esp32-iot`, `stm32-industrial` |

**Features:**
- ✅ **Cross-Platform Support** - ESP32, STM32, AVR, ARM, native
- ✅ **Multi-Environment Matrix** - Parallel builds for all targets
- ✅ **Unit Testing** - Native and embedded test execution
- ✅ **Static Analysis** - cppcheck, clangtidy integration
- ✅ **Library Registry** - Automatic publishing to PlatformIO Registry

**Quick Start - PlatformIO:**
```yaml
name: ⚡ PlatformIO Build

on: [push]

jobs:
  platformio:
    uses: bauer-group/automation-templates/.github/workflows/platformio-build.yml@main
    with:
      environments: '["esp32dev", "nucleo_f446re", "uno"]'
      pio-version: 'latest'
      run-tests: true
      enable-check: true
      create-release: ${{ startsWith(github.ref, 'refs/tags/v') }}
```

### 🛒 Shopware 5 Plugin Build System

Complete automation for Shopware 5 plugin development with support for both legacy and modern plugin systems.

| Component | Purpose | Usage |
|-----------|---------|-------|
| **🔧 shopware5-build workflow** | Complete Shopware 5 plugin CI/CD | `uses: bauer-group/automation-templates/.github/workflows/shopware5-build.yml@main` |
| **📋 Configuration Templates** | Pre-configured setups | `default`, `legacy-plugin`, `modern-plugin`, `store-plugin` |

**Features:**
- ✅ **Dual Plugin System Support** - Automatic detection of legacy (v5.0-5.1) and modern (v5.2+) plugins
- ✅ **Shopware Store Integration** - Automatic upload, validation, and store page updates
- ✅ **GitHub Release Management** - Automated releases with changelog generation
- ✅ **Frontend Build Support** - Node.js/npm integration for asset compilation
- ✅ **Quality Assurance** - PHPUnit, PHPStan, PHP CodeSniffer integration

**Quick Start - Shopware 5:**
```yaml
name: 🛒 Shopware 5 Plugin Build

on: [push]

jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/shopware5-build.yml@main
    with:
      plugin-system: 'auto'  # Auto-detect legacy or modern
      php-version: '7.4'

      # Testing & Quality
      run-tests: true
      run-phpstan: true

      # Store Integration
      validate-plugin: true
      upload-to-store: true

      # Release Management
      create-github-release: true
      auto-tag-version: true
    secrets:
      SHOPWARE_ACCOUNT_EMAIL: ${{ secrets.SHOPWARE_ACCOUNT_EMAIL }}
      SHOPWARE_ACCOUNT_PASSWORD: ${{ secrets.SHOPWARE_ACCOUNT_PASSWORD }}
```

**Plugin System Detection:**
- **Legacy (v5.0-5.1)**: `plugin.xml`, `Bootstrap.php` in `src/Backend/PluginName` or `src/Frontend/PluginName`
- **Modern (v5.2+)**: `composer.json`, PSR-4 autoloading in `src/PluginName`

### 🔄 Meta Repository Sync System

Automated repository collection and organization using GitHub topics and git submodules.

| Component | Purpose | Usage |
|-----------|---------|-------|
| **🔧 meta-repository-sync workflow** | Automated submodule sync by topics | `uses: bauer-group/automation-templates/.github/workflows/meta-repository-sync.yml@main` |
| **📋 Configuration Templates** | Topic-based organization | `.github/config/meta-repository/default.json` |

**Features:**

- ✅ **Topic-Based Organization** - Automatically discover and organize repositories by GitHub topics
- ✅ **Public & Private Repos** - Support for both public and private repositories
- ✅ **Submodule Automation** - Add, update, and remove submodules based on topic configuration
- ✅ **README Generation** - Auto-generate repository overview with grouped project listings
- ✅ **Multi-Format Output** - Generate JSON and TXT files for each topic group
- ✅ **Prefix Removal** - Clean repository names with configurable prefix patterns
- ✅ **Scheduled Sync** - Automatic periodic synchronization with organization repositories

**Quick Start - Meta Repository:**
```yaml
name: 🔄 Meta Repository Sync

on:
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM
  workflow_dispatch:

jobs:
  sync:
    uses: bauer-group/automation-templates/.github/workflows/meta-repository-sync.yml@main
    with:
      config-file: '.github/config/meta-repository/topics.json'
      include-private: false  # Set to true to include private repos
      generate-readme: true
      generate-json: true
      generate-txt: true
      auto-commit: true
```

**Configuration Example (.github/config/meta-repository/topics.json):**

```json
{
  "title": "Project Portfolio",
  "description": "Organized collection of repositories by technology",
  "groups": [
    {
      "topic": "python-library",
      "folder": "Python-Libraries",
      "name": "Python Libraries",
      "description": "Reusable Python packages and libraries",
      "remove_prefix": "python-"
    },
    {
      "topic": "docker-app",
      "folder": "Docker-Applications",
      "name": "Docker Applications",
      "description": "Containerized applications and services",
      "remove_prefix": "docker-"
    }
  ]
}
```

### 🏗️ Additional Build Systems

| System | Status | Description | Usage |
|--------|--------|-------------|-------|
| **🟢 .NET Build** | Available | Complete .NET Core/Framework automation | `uses: bauer-group/automation-templates/.github/workflows/dotnet-build.yml@main` |
| **🟢 .NET Desktop** | Available | Desktop application builds (WPF, WinForms) | `uses: bauer-group/automation-templates/.github/workflows/dotnet-desktop-build.yml@main` |
| **🟢 .NET Library Publish** | Available | NuGet package build, sign, and publish | `uses: bauer-group/automation-templates/.github/workflows/dotnet-publish-library.yml@main` |
| **🟢 Node.js Build** | Available | Node.js and npm/yarn automation | `uses: bauer-group/automation-templates/.github/workflows/nodejs-build.yml@main` |
| **🟢 PHP Build** | Available | PHP and Composer automation | `uses: bauer-group/automation-templates/.github/workflows/php-build.yml@main` |
| **🟢 Makefile Build** | Available | Makefile-based build automation | `uses: bauer-group/automation-templates/.github/workflows/makefile-build.yml@main` |
| **🟢 Zephyr RTOS** | Available | Real-time OS build automation with hardware testing | `uses: bauer-group/automation-templates/.github/workflows/zephyr-build.yml@main` |
| **🟢 ESP32** | Available | ESP32 microcontroller builds with ESP-IDF | `uses: bauer-group/automation-templates/.github/workflows/esp32-build.yml@main` |
| **🟢 STM32** | Available | STM32 microcontroller builds (Makefile/CMake/CubeIDE) | `uses: bauer-group/automation-templates/.github/workflows/stm32-build.yml@main` |
| **🟢 PlatformIO** | Available | Cross-platform embedded development | `uses: bauer-group/automation-templates/.github/workflows/platformio-build.yml@main` |
| **🟢 Shopware 5** | Available | Shopware 5 plugin build and store automation | `uses: bauer-group/automation-templates/.github/workflows/shopware5-build.yml@main` |
| **🟡 Go Build** | Planned | Go module and build automation | - |
| **🟡 Rust Build** | Planned | Cargo and Rust build automation | - |

### 🤖 Claude Code AI Assistant

AI-powered code assistant that responds to @claude mentions in issues, PRs, and comments with intelligent code analysis and suggestions.

| Component | Purpose | Usage |
|-----------|---------|-------|
| **🔧 claude-code action** | AI code analysis composite action | Integrates Claude AI with configurable models |
| **🚀 claude-code workflow** | Complete AI assistant CI/CD | `uses: bauer-group/automation-templates/.github/workflows/claude-code.yml@main` |
| **📋 Configuration Templates** | Pre-configured AI profiles | `default`, `code-review`, `security-review`, `minimal` |

**Features:**
- ✅ **Intelligent Code Reviews** - Thorough analysis of pull requests
- ✅ **Issue Assistance** - Help with bug reports and feature requests
- ✅ **Security Analysis** - Security-focused code scanning
- ✅ **General Q&A** - Answer questions about your codebase

**Quick Start - Claude Code:**

```yaml
name: 🤖 Claude Code Assistant

on:
  issue_comment:
    types: [created]
  pull_request_review_comment:
    types: [created]

jobs:
  claude:
    if: contains(github.event.comment.body, '@claude')
    uses: bauer-group/automation-templates/.github/workflows/claude-code.yml@main
    with:
      model: 'opus'
      config-file: 'default'
    secrets:
      CLAUDE_CODE_OAUTH_TOKEN: ${{ secrets.CLAUDE_CODE_OAUTH_TOKEN }}
```

### 🔧 Utility & Management Systems

| System | Status | Description | Usage |
|--------|--------|-------------|-------|
| **🟢 Claude Code** | Available | AI-powered code assistant | `uses: bauer-group/automation-templates/.github/workflows/claude-code.yml@main` |
| **🟢 Meta Repository Sync** | Available | Automated submodule sync by topics | `uses: bauer-group/automation-templates/.github/workflows/meta-repository-sync.yml@main` |
| **🟢 Teams Notifications** | Available | Microsoft Teams integration | `uses: bauer-group/automation-templates/.github/workflows/teams-notifications.yml@main` |
| **🟢 Repository Cleanup** | Available | Automated repository maintenance | `uses: bauer-group/automation-templates/.github/workflows/repository-cleanup.yml@main` |
| **🟢 Coolify Deploy** | Available | Coolify deployment automation | `uses: bauer-group/automation-templates/.github/workflows/coolify-deploy.yml@main` |
| **🟢 AI Issue Summary** | Available | AI-powered issue summarization | `uses: bauer-group/automation-templates/.github/workflows/ai-issue-summary.yml@main` |
| **🟢 Issue Automation** | Available | Automated issue management | `uses: bauer-group/automation-templates/.github/workflows/issue-automation.yml@main` |
| **🟢 PR Labeler** | Available | Automated pull request labeling | `uses: bauer-group/automation-templates/.github/workflows/pr-labeler.yml@main` |

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
   cp github/workflows/examples/python-build/python-semantic-release.yml .github/workflows/python-release.yml
   
   # For Zephyr RTOS projects
   cp .github/workflows/examples/zephyr-build/basic-zephyr-app.yml .github/workflows/
   
   # For Shopware 5 plugins
   cp github/workflows/examples/shopware5-build/simple-modern-plugin.yml .github/workflows/shopware.yml

   # For general CI/CD
   cp .github/workflows/examples/ci-cd/comprehensive-ci-cd.yml .github/workflows/
   ```

3. **Configure required secrets:**

   ```bash
   # Basic (always required)
   gh secret set GITHUB_TOKEN --body "${{ secrets.GITHUB_TOKEN }}"
   
   # Docker builds
   gh secret set REGISTRY_TOKEN --body "your-registry-token"
   gh secret set COSIGN_PRIVATE_KEY --body "$(cat cosign.key)"
   gh secret set COSIGN_PASSWORD --body "your-cosign-password"
   
   # Python publishing
   gh secret set PYPI_API_TOKEN --body "your-pypi-token"
   gh secret set CODECOV_TOKEN --body "your-codecov-token"
   
   # Security scanning
   gh secret set GITGUARDIAN_API_KEY --body "your-gitguardian-key"

   # Shopware 5 plugins
   gh secret set SHOPWARE_ACCOUNT_EMAIL --body "your-shopware-email"
   gh secret set SHOPWARE_ACCOUNT_PASSWORD --body "your-shopware-password"
   ```

4. **Customize configuration:**

   ```bash
   # Edit Docker configuration
   vim .github/config/docker-build/web-application.yml
   
   # Edit Python configuration  
   vim pyproject.toml  # Configure semantic release
   
   # Edit Zephyr configuration
   vim .github/config/zephyr-build/iot-device.yml
   
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
      image-tag: ${{ github.ref_name }}-${{ github.sha }}
      platforms: 'linux/amd64,linux/arm64'
      security-scan: true
      generate-sbom: true
      sign-image: true
      deploy: ${{ github.ref == 'refs/heads/main' }}
    secrets:
      REGISTRY_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      COSIGN_PRIVATE_KEY: ${{ secrets.COSIGN_PRIVATE_KEY }}
      COSIGN_PASSWORD: ${{ secrets.COSIGN_PASSWORD }}
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
    uses: bauer-group/automation-templates/.github/workflows/python-semantic-release.yml@main
    with:
      config-file: 'application'
      python-version: '3.12'
      package-manager: 'poetry'
      run-tests: true
      collect-coverage: true
      security-scan: true
      quality-checks: true
    secrets:
      CODECOV_TOKEN: ${{ secrets.CODECOV_TOKEN }}
      
  publish:
    if: github.ref == 'refs/heads/main'
    needs: build
    uses: bauer-group/automation-templates/.github/workflows/python-semantic-release.yml@main
    with:
      config-file: 'application'
      package-manager: 'poetry'
      registry: 'pypi'
    secrets:
      PYPI_API_TOKEN: ${{ secrets.PYPI_API_TOKEN }}
```

#### ⚡ Zephyr RTOS Project Setup

```yaml
# .github/workflows/zephyr.yml
name: Zephyr Build & Test

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  zephyr:
    uses: bauer-group/automation-templates/.github/workflows/zephyr-build.yml@main
    with:
      config-file: 'iot-device'
      boards: '["esp32", "nucleo_f429zi", "nrf52840dk_nrf52840"]'
      build-types: '["debug", "release"]'
      run-tests: true
      enable-coverage: true
      static-analysis: true
    secrets:
      CODECOV_TOKEN: ${{ secrets.CODECOV_TOKEN }}
      TEAMS_WEBHOOK_URL: ${{ secrets.TEAMS_WEBHOOK_URL }}
```

### Using Individual Actions

#### 🐳 Docker Build Action

```yaml
- name: Build Docker Image
  uses: bauer-group/automation-templates/.github/actions/docker-build@main
  with:
    image-name: 'my-app'
    image-tag: ${{ github.sha }}
    platforms: 'linux/amd64,linux/arm64'
    security-scan: true
    fail-on-severity: 'HIGH'
    generate-sbom: true
    sign-image: true
```

#### 🐍 Python Setup Action

```yaml
- name: Setup Python Environment  
  uses: actions/setup-python@v5
  with:
    python-version: '3.12'
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
    github-token: ${{ secrets.GITHUB_TOKEN }}
    gitguardian-api-key: ${{ secrets.GITGUARDIAN_API_KEY }}
```

#### ⚡ Zephyr Build Action

```yaml
- name: Build Zephyr Application
  uses: bauer-group/automation-templates/.github/actions/zephyr-build@main
  with:
    board: 'esp32'
    build-type: 'release'
    run-tests: true
    enable-coverage: true
    static-analysis: true
    zephyr-version: '0.17.4'
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

## 🏃 Self-Hosted Runner Support

All reusable workflows support self-hosted GitHub Actions runners, allowing organizations to run workflows on their own infrastructure.

### Configuration

Every workflow accepts a `runs-on` parameter:

```yaml
jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/dotnet-build.yml@main
    with:
      project-path: 'src/MyApp.csproj'
      # GitHub-hosted (default)
      runs-on: 'ubuntu-latest'
      # OR Self-hosted with labels
      runs-on: '["self-hosted", "linux", "docker"]'
```

### Input Formats

| Format | Example | Use Case |
|--------|---------|----------|
| String | `'ubuntu-latest'` | GitHub-hosted runners |
| JSON Array | `'["self-hosted", "linux"]'` | Self-hosted with labels |
| JSON Array | `'["self-hosted", "Windows", "vs2022"]'` | Windows self-hosted |

### Benefits

- **Cost Control**: No GitHub Actions minutes consumption
- **Custom Hardware**: Use specialized hardware (GPU, high memory)
- **Network Access**: Access to internal networks and resources
- **Compliance**: Keep builds within your infrastructure

For detailed setup instructions, see [Self-Hosted Runner Documentation](docs/self-hosted-runners.md).

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
- [🐍 **Python Build System**](docs/workflows/python-build.md) - Python application builds and testing
- [🐍 **Python Semantic Release System**](docs/workflows/python-semantic-release.md) - Modern Python CI/CD with semantic versioning
- [⚡ **Zephyr RTOS Build System**](docs/workflows/zephyr-build.md) - Real-time OS automation with hardware testing
- [📟 **ESP32 Build System**](docs/workflows/esp32-build.md) - ESP32 microcontroller automation with ESP-IDF
- [🔧 **STM32 Build System**](docs/workflows/stm32-build.md) - STM32 microcontroller automation
- [⚡ **PlatformIO Build System**](docs/workflows/platformio-build.md) - Cross-platform embedded development
- [🔨 **.NET Build System**](docs/workflows/dotnet-build.md) - .NET Core/Framework automation
- [🖥️ **.NET Desktop Build System**](docs/workflows/dotnet-desktop-build.md) - Desktop application automation
- [📦 **.NET Library Publishing**](docs/workflows/dotnet-publish-library.md) - NuGet package build, sign, and publish
- [📦 **Node.js Build System**](docs/workflows/nodejs-build.md) - Node.js and npm/yarn automation
- [🐘 **PHP Build System**](docs/workflows/php-build.md) - PHP and Composer automation
- [🛒 **Shopware 5 Plugin Build System**](docs/workflows/shopware5-build.md) - Shopware 5 plugin automation with store integration
- [🔧 **Makefile Build System**](docs/workflows/makefile-build.md) - Makefile-based build automation
- [🤖 **Claude Code AI Assistant**](docs/workflows/claude-code.md) - AI-powered code assistant
- [🚀 **Coolify Deploy**](docs/workflows/coolify-deploy.md) - Coolify deployment automation
- [🔄 **Meta Repository Sync**](docs/workflows/meta-repository-sync.md) - Automated submodule synchronization
- [🔔 **Teams Notifications**](docs/workflows/teams-notifications.md) - Microsoft Teams integration
- [🏃 **Self-Hosted Runners**](docs/self-hosted-runners.md) - Self-hosted runner configuration guide

#### 🔍 Validation Modules

- [🐳 **Dockerfile Validation**](docs/workflows/modules-validate-dockerfile.md) - Dockerfile linting with Hadolint
- [📋 **Docker Compose Validation**](docs/workflows/modules-validate-compose.md) - Docker Compose validation
- [🐚 **Shell Script Validation**](docs/workflows/modules-validate-shellscript.md) - Shell script linting with ShellCheck

### 🔧 Actions Documentation

#### Build Actions

- [🐳 **docker-build**](.github/actions/docker-build/README.md) - Multi-platform Docker builds with security
- [📦 **dotnet-nuget**](.github/actions/dotnet-nuget/action.yml) - .NET NuGet build, sign, and pack
- [⚡ **zephyr-build**](.github/actions/zephyr-build/README.md) - Complete Zephyr RTOS build automation with SDK management
- [📟 **esp32-build**](.github/actions/esp32-build/README.md) - ESP32 microcontroller build automation with ESP-IDF
- [🔧 **stm32-build**](.github/actions/stm32-build/README.md) - STM32 microcontroller build automation
- [⚡ **platformio-build**](.github/actions/platformio-build/README.md) - PlatformIO cross-platform build automation
- [🔧 **makefile-build**](.github/actions/makefile-build/README.md) - Makefile-based build automation

#### Security & Compliance Actions

- [🛡️ **security-scan**](.github/actions/security-scan/README.md) - Multi-engine security scanning
- [🔒 **gitleaks-scan**](.github/actions/gitleaks-scan/README.md) - Gitleaks secret detection
- [🛡️ **gitguardian-scan**](.github/actions/gitguardian-scan/README.md) - GitGuardian security scanning
- [📋 **license-compliance**](.github/actions/license-compliance/README.md) - SPDX license compliance

#### AI & Automation Actions

- [🤖 **claude-code**](.github/actions/claude-code/README.md) - AI-powered code assistant
- [🔨 **artifact-generator**](.github/actions/artifact-generator/README.md) - Multi-format artifact generation
- [🏷️ **labeler-triage**](.github/actions/labeler-triage/README.md) - Issue/PR labeling and triage
- [🔀 **auto-merge**](.github/actions/auto-merge/README.md) - Automated PR merging

#### Utility Actions

- [📝 **readme-generate**](.github/actions/readme-generate/README.md) - Professional README generation
- [🛡️ **security-generate**](.github/actions/security-generate/README.md) - Security policy generation
- [🚀 **semantic-release**](.github/actions/semantic-release/README.md) - Automated release management
- [📋 **generate-changelog**](.github/actions/generate-changelog/README.md) - Changelog generation
- [🔔 **teams-notification**](.github/actions/teams-notification/README.md) - Microsoft Teams integration
- [🧹 **repository-cleanup**](.github/actions/repository-cleanup/README.md) - Repository maintenance automation

### 📋 Configuration References

- [🐳 **Docker Configurations**](.github/config/docker-build/) - Docker build configuration templates
- [⚡ **Zephyr Configurations**](.github/config/zephyr-build/) - Zephyr RTOS build configuration templates
- [📟 **ESP32 Configurations**](.github/config/esp32-build/) - ESP32 build configuration templates
- [🔧 **STM32 Configurations**](.github/config/stm32-build/) - STM32 build configuration templates
- [⚡ **PlatformIO Configurations**](.github/config/platformio-build/) - PlatformIO build configuration templates
- [🤖 **Claude Code Configurations**](.github/config/claude-code/) - Claude Code AI assistant configurations
- [🛒 **Shopware 5 Configurations**](.github/config/shopware5-build/) - Shopware 5 plugin build configuration templates
- [🔄 **Meta Repository Configurations**](.github/config/meta-repository/) - Meta repository sync configurations
- [⚙️ **Workflow Configuration**](.github/config/README.md) - General workflow configuration guide
- [🔒 **Secrets Naming Convention**](docs/SECRETS-NAMING-CONVENTION.md) - Standardized secret naming

### 🛠️ Repository Management Tools

- [🔐 **Branch Protection Tools**](github/branch-protect/README.md) - Automated branch protection
- [🤖 **Claude Code Documentation**](github/claude-code/README.md) - AI-powered code assistant documentation
- [🧹 **Repository Cleanup Tools**](github/cleanup/README.md) - Repository maintenance utilities
- [🏃 **Self-Hosted Runner Setup**](github/runner/README.md) - Runner deployment and management

### 📖 Examples and Templates

- [🐳 **Docker Examples**](github/workflows/examples/docker/) - Complete Docker workflow examples
- [🐳 **Docker Compose Examples**](github/workflows/examples/docker-compose/) - Docker Compose workflow examples
- [🐳 **Dockerfile Validation Examples**](github/workflows/examples/dockerfile-validation/) - Dockerfile linting examples
- [🐍 **Python Examples**](github/workflows/examples/python-build/) - Python build and test examples
- [🐍 **Python Release Examples**](github/workflows/examples/python-release/) - Python semantic release examples
- [⚡ **Zephyr Examples**](github/workflows/examples/zephyr-build/) - Zephyr RTOS project examples
- [📟 **ESP32 Examples**](github/workflows/examples/esp32-build/) - ESP32 microcontroller examples
- [🔧 **STM32 Examples**](github/workflows/examples/stm32-build/) - STM32 microcontroller examples
- [⚡ **PlatformIO Examples**](github/workflows/examples/platformio-build/) - PlatformIO build examples
- [🔨 **.NET Examples**](github/workflows/examples/dotnet-build/) - .NET project examples
- [🖥️ **.NET Desktop Examples**](github/workflows/examples/dotnet-desktop-build/) - .NET desktop application examples
- [📦 **.NET NuGet Examples**](github/workflows/examples/dotnet-nuget/) - .NET NuGet publishing examples
- [📦 **Node.js Examples**](github/workflows/examples/nodejs-build/) - Node.js project examples
- [🐘 **PHP Examples**](github/workflows/examples/php-build/) - PHP project examples
- [🛒 **Shopware 5 Examples**](github/workflows/examples/shopware5-build/) - Shopware 5 plugin workflow examples
- [🔧 **Makefile Examples**](github/workflows/examples/makefile-build/) - Makefile project examples
- [🤖 **Claude Code Examples**](github/workflows/examples/claude-code/) - Claude Code AI assistant examples
- [🚀 **Coolify Deploy Examples**](github/workflows/examples/coolify-deploy/) - Coolify deployment examples
- [🔄 **Meta Repository Examples**](github/workflows/examples/meta-repository/) - Meta repository sync examples
- [🔄 **CI/CD Examples**](github/workflows/examples/ci-cd/) - General CI/CD pipeline examples
- [📝 **Documentation Examples**](github/workflows/examples/documentation/) - Documentation automation examples
- [🔔 **Teams Examples**](github/workflows/examples/teams-notification/) - Teams notification examples
- [🧹 **Cleanup Examples**](github/workflows/examples/repository-cleanup/) - Repository maintenance examples
- [🔒 **Security Examples**](github/workflows/examples/security/) - Security workflow examples
- [🚀 **Release Examples**](github/workflows/examples/release/) - Release workflow examples

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

*Generated on 2026-04-27 22:41:48 UTC from [docs/README.template.MD](docs/README.template.MD)*

