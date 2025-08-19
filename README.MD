<!-- AUTO-GENERATED FILE. DO NOT EDIT. Edit docs/README.template.MD instead. -->
<!-- Generated on 2025-08-19 10:32:50 UTC -->

# BAUER GROUP - Automation Templates

**Status:** Version 0.1.2 (2025-08-19)  
**Repository:** [bauer-group/automation-templates](https://github.com/bauer-group/automation-templates)  
**Branch:** {{CURRENT_BRANCH}}

Zentrale GitHub Actions Templates und Workflows für automatisierte Entwicklungsprozesse

[![Enhanced Release](https://github.com/bauer-group/automation-templates/actions/workflows/enhanced-release.yml/badge.svg)](https://github.com/bauer-group/automation-templates/actions/workflows/enhanced-release.yml)

## 🛡️ Security Scanning - Dual Engine Approach

### Meta Package (Empfohlen)
```yaml
- name: 🛡️ Comprehensive Security Scan
  uses: ./.github/actions/security-scan-meta
  with:
    scan-engine: both              # gitleaks, gitguardian, both
    scan-type: all                 # secrets, vulnerabilities, all
    fail-on-findings: true
    github-token: ${{ secrets.GITHUB_TOKEN }}
    gitguardian-api-key: ${{ secrets.GITGUARDIAN_API_KEY }}  # Optional
```

### Einzelne Engines

#### Gitleaks (Open Source)
```yaml
- name: ⚡ Fast Secrets Scan
  uses: ./.github/actions/gitleaks-scan
  with:
    scan-history: false
    github-token: ${{ secrets.GITHUB_TOKEN }}  # Optional für org repos
    format: json
```

#### GitGuardian (Enterprise)
```yaml
- name: 🛡️ Advanced Security Scan
  uses: ./.github/actions/gitguardian-scan
  with:
    scan-mode: ci
    gitguardian-api-key: ${{ secrets.GITGUARDIAN_API_KEY }}
    minimum-severity: medium
    all-policies: true
```

## 📦 Enhanced Release Management

### Vollständiger Release Workflow
```yaml
name: 🚀 Production Release

on:
  push:
    branches: [ $default-branch ]
  workflow_dispatch:
    inputs:
      security-scan-engine:
        type: choice
        default: 'both'
        options: [gitleaks, gitguardian, both]
      cleanup-release-branch:
        type: boolean
        default: true

jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
          
      - name: 🚀 Enhanced Release Please
        uses: ./.github/actions/release-please
        with:
          release-type: simple
          security-scan-engine: ${{ inputs.security-scan-engine || 'both' }}
          cleanup-release-branch: ${{ inputs.cleanup-release-branch || 'true' }}
          auto-merge-enabled: false
          token: ${{ secrets.GITHUB_TOKEN }}
```

## 🏗️ Modulare Actions Übersicht

### �️ Security Actions

| Action | Zweck | Engine | Geschwindigkeit | Enterprise Features |
|--------|-------|---------|----------------|---------------------|
| **security-scan-meta** | Meta Package für alle Engines | Beide | ⚡⚡⚡ | ✅ Umfassend |
| **gitleaks-scan** | Schnelle Pattern-Erkennung | Gitleaks | ⚡⚡⚡⚡ | ❌ Basic |
| **gitguardian-scan** | ML-basierte Erkennung | GitGuardian | ⚡⚡ | ✅ Advanced |

### ⚖️ Compliance & Quality

```yaml
# License Compliance mit SPDX & FOSSA
- uses: ./.github/actions/license-compliance
  with:
    fossa-api-key: ${{ secrets.FOSSA_API_KEY }}
    fail-on-issues: true

# Artifact Generation  
- uses: ./.github/actions/artifact-generator
  with:
    artifact-types: source,docker
    include-checksums: true

# Auto-Merge mit Bedingungen
- uses: ./.github/actions/auto-merge
  with:
    require-reviews: 2
    merge-method: squash
```

## 📁 Struktur

```text
├── .github/
│   ├── actions/               # Wiederverwendbare Actions
│   │   ├── security-scan-meta/ # Meta Package für Security Scans
│   │   ├── gitleaks-scan/     # Gitleaks Security Scanner
│   │   ├── gitguardian-scan/  # GitGuardian Security Scanner  
│   │   ├── license-compliance/ # SPDX License Compliance
│   │   ├── artifact-generator/ # Multi-Format Artifacts
│   │   ├── auto-merge/        # Intelligent Auto-Merge
│   │   └── release-please/    # Enhanced Release Management
│   ├── config/               # Konfigurationsdateien
│   │   └── commitlint.config.js # Commit-Linting-Regeln
│   └── workflows/            # Workflow-Templates
│       └── enhanced-release.yml # Haupt-Release-Workflow
├── docs/                     # Dokumentation
└── scripts/                  # Hilfsskripte
```

## 🔧 Konfiguration

### Commitlint Setup
Die Commitlint-Konfiguration wurde nach `.github/config/` verschoben:

**`.github/config/commitlint.config.js`**
```javascript
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [2, 'always', [
      'feat', 'fix', 'docs', 'style', 'refactor',
      'test', 'chore', 'ci', 'build', 'revert', 'perf'
    ]]
  }
};
```

### Security Engine Konfiguration

#### Gitleaks (.gitleaks.toml)
```toml
[extend]
useDefault = true

[allowlist]
paths = [
  ".git/",
  "node_modules/",
  "vendor/"
]

regexes = [
  '''password\s*=\s*["']?test["']?''',
  '''key\s*=\s*["']?your[_-]?key[_-]?here["']?'''
]
```

#### GitGuardian (.gitguardian.yaml)
```yaml
version: 2
paths-ignore:
  - .git
  - node_modules
  
secret:
  minimum-severity: medium
  ignore-known-secrets: false
  
policies:
  all-policies: true
```

## 🚀 Best Practices

### 1. **Dual Engine Security**
- **Entwicklung**: Gitleaks für schnelle Pre-Commit-Checks
- **CI/CD**: Beide Engines für maximale Abdeckung
- **Production**: GitGuardian für Policy-Enforcement

### 2. **Branch Management**
- `$default-branch` statt hardcodierter `main`
- Automatisches Cleanup von Release-Branches
- Konfigurierbare Auto-Merge-Bedingungen

### 3. **API Key Management**
```yaml
secrets:
  GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}           # Immer verfügbar
  GITGUARDIAN_API_KEY: ${{ secrets.GITGUARDIAN_API_KEY }} # Optional
  FOSSA_API_KEY: ${{ secrets.FOSSA_API_KEY }}         # Für License-Compliance
```

#### Repository-Informationen

- `bauer-group/automation-templates` - Repository Name (owner/repo)
- `https://github.com/bauer-group/automation-templates` - Repository URL
- `bauer-group` - Repository Owner
- `automation-templates` - Repository Name
- `{{CURRENT_BRANCH}}` - Aktueller Branch

#### Projekt-Informationen

- `Automation Templates` - Projektname
- `Zentrale GitHub Actions Templates und Workflows für automatisierte Entwicklungsprozesse` - Projektbeschreibung
- `BAUER GROUP` - Firmenname
- `support@bauer-group.com` - Kontakt E-Mail
- `https://github.com/bauer-group/automation-templates/wiki` - Dokumentations-URL
- `https://github.com/bauer-group/automation-templates/issues` - Support-URL

#### Package-Informationen (automatisch erkannt)

- `` - Paketname (aus package.json, etc.)
- `` - Paketversion
- `` - Autor
- `` - Lizenz

#### Workflow-Badges (automatisch generiert)

- `[![Release](https://github.com/bauer-group/automation-templates/actions/workflows/release-please.yml/badge.svg)](https://github.com/bauer-group/automation-templates/actions/workflows/release-please.yml)` - Release-Status Badge

### In anderen Projekten verwenden

```yaml
# .github/workflows/readme.yml
name: README Update

on:
  pull_request:
    branches: [ main ]
  workflow_dispatch:

jobs:
  readme:
    uses: bauer-group/automation-templates/github/workflows/readme.yml@main
    with:
      template-path: "docs/README.template.md"
      output-path: "README.md"
      project-name: "Mein Projekt"
      company-name: "Meine Firma"
      project-description: "Beschreibung meines Projekts"
      contact-email: "support@example.com"
```

### Lokale README-Generierung

```bash
# README manuell generieren
python scripts/generate_readme.py

# Mit benutzerdefinierten Umgebungsvariablen
PROJECT_NAME="Mein Projekt" \
COMPANY_NAME="Meine Firma" \
python scripts/generate_readme.py
```

## 🔄 Automatisches Release-Management

Das Projekt verwendet **Release-Please** für automatisches Release-Management:

1. **Conventional Commits** verwenden (feat:, fix:, chore:, docs:, etc.)
2. **Push nach main** triggert Release-Please
3. **Release-PR** wird automatisch erstellt
4. **Merge des Release-PR** erstellt das GitHub Release

### Unterstützte Commit-Typen

- `feat:` - Neue Features (minor version bump)
- `fix:` - Bugfixes (patch version bump)
- `feat!:` oder `BREAKING CHANGE:` - Breaking Changes (major version bump)
- `docs:`, `chore:`, `ci:`, `refactor:` - Keine Version-Änderung

## 🛠️ Entwicklung

### Voraussetzungen

- Python 3.12+
- Git
- GitHub Repository mit Actions aktiviert

### Setup

1. Repository klonen
2. Template in `docs/README.template.MD` anpassen
3. Workflows nach Bedarf konfigurieren
4. README generieren: `python scripts/generate_readme.py`

### Verfügbare Workflows

Siehe [github/workflows/README.md](github/workflows/README.md) für detaillierte Dokumentation aller verfügbaren Workflows.

## 📞 Support


**Kontakt:** [support@bauer-group.com](mailto:support@bauer-group.com)



**Support:** [https://github.com/bauer-group/automation-templates/issues](https://github.com/bauer-group/automation-templates/issues)


**Issues:** [GitHub Issues](https://github.com/bauer-group/automation-templates/issues)

---

*Dieses README wurde automatisch generiert am 2025-08-19 10:32:50 UTC aus [docs/README.template.MD](docs/README.template.MD)*
# Test for summary display
