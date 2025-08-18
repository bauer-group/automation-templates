# 🚀 Enhanced Release Management Actions

Diese Sammlung von modularen GitHub Actions bietet eine umfassende und erweiterbare Lösung für automatisierte Release-Prozesse mit Fokus auf Sicherheit, Compliance und Qualität.

## 📦 Modulare Actions

### 🛡️ Security Scan (`security-scan`)

Umfassende Sicherheitsüberprüfung mit Secrets-Erkennung und Vulnerability-Scanning.

**Features:**
- 🔐 Secrets Detection mit Gitleaks
- 🛡️ Vulnerability Scanning  
- 📊 Security Scoring (0-100)
- 📋 Detaillierte Reports
- ⚡ Konfigurierbare Fail-Bedingungen

**Verwendung:**
```yaml
- name: Security Scan
  uses: ./.github/actions/security-scan
  with:
    scan-type: 'all'              # secrets, vulnerabilities, all
    fail-on-findings: 'true'      # Workflow bei Findings beenden
    exclude-paths: '.git,node_modules'
    secrets-patterns: 'custom_pattern1,custom_pattern2'
    token: ${{ secrets.GITHUB_TOKEN }}
```

### 📋 License Compliance (`license-compliance`)

SPDX-konforme Lizenzprüfung mit FOSSA-Integration und SBOM-Generierung.

**Features:**
- 📄 SPDX License Identifier Validation
- 🚫 Forbidden License Detection
- 📦 Dependency License Scanning
- 🔬 FOSSA Integration (optional)
- 📋 SBOM Generation (SPDX & CycloneDX)

**Verwendung:**
```yaml
- name: License Compliance Check
  uses: ./.github/actions/license-compliance
  with:
    allowed-licenses: 'MIT,Apache-2.0,BSD-3-Clause'
    forbidden-licenses: 'GPL-2.0,GPL-3.0,AGPL-3.0'
    fail-on-forbidden: 'true'
    fail-on-unknown: 'false'
    scan-dependencies: 'true'
    generate-sbom: 'true'
    fossa-api-key: ${{ secrets.FOSSA_API_KEY }}  # optional
    token: ${{ secrets.GITHUB_TOKEN }}
```

### 📦 Artifact Generator (`artifact-generator`)

Generierung von Release-Artefakten inklusive Source-Archive, Binaries und Docker Images.

**Features:**
- 🗂️ Source Archive Generation (ZIP, TAR.GZ, TAR.XZ)
- 🔨 Binary Archive Creation
- 🐳 Docker Image Building & Publishing
- 🔐 Checksum Generation (SHA256, SHA512, MD5)
- 📤 Automatischer Upload zu GitHub Releases

**Verwendung:**
```yaml
- name: Generate Artifacts
  uses: ./.github/actions/artifact-generator
  with:
    artifact-types: 'source,binaries,docker'  # source, binaries, docker, all
    tag-name: ${{ github.ref_name }}
    version: ${{ needs.release.outputs.version }}
    upload-url: ${{ needs.release.outputs.upload_url }}
    source-formats: 'zip,tar.gz'
    build-command: 'make build'
    binary-paths: 'dist/,build/'
    docker-registry: 'ghcr.io'
    docker-username: ${{ github.actor }}
    docker-password: ${{ secrets.GITHUB_TOKEN }}
    token: ${{ secrets.GITHUB_TOKEN }}
```

### 🔄 Auto Merge (`auto-merge`)

Intelligentes automatisches Merging von Pull Requests basierend auf konfigurierbaren Bedingungen.

**Features:**
- ✅ Configurable Merge Conditions
- 👥 Author Allowlist/Blocklist
- 🏷️ Label-based Controls
- ⏳ Status Check Waiting
- 👥 Review Requirements
- 🧹 Automatic Branch Cleanup

**Verwendung:**
```yaml
- name: Auto Merge PR
  uses: ./.github/actions/auto-merge
  with:
    pr-number: ${{ github.event.number }}
    merge-method: 'squash'        # merge, squash, rebase
    auto-merge-enabled: 'true'
    required-checks: 'ci,security-scan'
    required-reviews: '1'
    allowed-authors: 'dependabot[bot],renovate[bot]'
    forbidden-labels: 'do-not-merge,wip'
    required-labels: 'ready-to-merge'
    wait-timeout: '30'            # minutes
    delete-branch-after-merge: 'true'
    token: ${{ secrets.GITHUB_TOKEN }}
```

### 🚀 Enhanced Release Please (`release-please`)

Erweiterte Release-Please Integration mit allen modularen Features.

**Features:**
- 📦 Semantic Versioning
- 🛡️ Integrierte Security Scans
- 📋 License Compliance Checks
- 📦 Automatische Artifact Generation
- 🔄 Auto-merge von Release PRs

**Verwendung:**
```yaml
- name: Enhanced Release
  uses: ./.github/actions/release-please
  with:
    release-type: 'simple'
    security-scan-enabled: 'true'
    license-check-enabled: 'true'
    artifact-generation-enabled: 'true'
    auto-merge-enabled: 'false'
    force-release: 'false'
    token: ${{ secrets.GITHUB_TOKEN }}
```

## 🔧 Workflow Integration

### Vollständiger Enhanced Release Workflow

Der neue `enhanced-release.yml` Workflow kombiniert alle Module für einen umfassenden Release-Prozess:

```yaml
name: 🚀 Enhanced Release Management

on:
  push:
    branches: [ main ]
  pull_request:
    types: [ closed ]
    branches: [ main ]
  workflow_dispatch:
    inputs:
      release-type:
        description: "Type of release"
        type: choice
        options: [simple, node, python, rust, java, go, docker]
      security-scan:
        description: "Enable security scanning"
        type: boolean
        default: true
      license-check:
        description: "Enable license compliance check"
        type: boolean
        default: true
      # ... weitere Inputs

jobs:
  pr-validation:     # Validierung von Pull Requests
  release-management: # Hauptrelease-Job mit allen Modulen
  extended-artifacts: # Erweiterte Artifact-Generierung
  post-release:      # Post-Release Actions und Benachrichtigungen
```

### Konfigurierbare Features

Der Workflow bietet folgende konfigurierbare Features:

| Feature | Beschreibung | Default |
|---------|--------------|---------|
| `security-scan` | Sicherheitsscanning aktivieren | `true` |
| `license-check` | Lizenz-Compliance prüfen | `true` |
| `artifact-generation` | Artefakt-Generierung | `true` |
| `auto-merge-pr` | Auto-merge von Release PRs | `false` |
| `artifact-types` | Art der Artefakte | `source` |

## 📊 Outputs und Reports

### Security Reports
- `security-scan-reports/` - Detaillierte Sicherheitsberichte
- Gitleaks JSON Reports
- Security Score und Empfehlungen

### License Reports  
- `license-compliance-reports/` - Lizenz-Compliance Berichte
- SBOM Files (SPDX & CycloneDX)
- FOSSA Reports (falls konfiguriert)

### Release Artifacts
- `release-artifacts/` - Alle generierten Artefakte
- Source Archives
- Binary Archives
- Docker Images
- Checksums

## 🔄 Migration vom alten Workflow

### Schritt 1: Actions hinzufügen
Die neuen modularen Actions sind bereits verfügbar unter `.github/actions/`.

### Schritt 2: Workflow aktualisieren
Ersetzen Sie `release.yml` mit `enhanced-release.yml` oder integrieren Sie die Module in bestehende Workflows.

### Schritt 3: Konfiguration anpassen
Aktualisieren Sie die Release-Please Konfiguration:
```bash
# Verwenden Sie die neue erweiterte Konfiguration
cp .github/config/enhanced-release-please-config.json .github/config/release-please-config.json
```

### Schritt 4: Secrets konfigurieren
Optionale Secrets für erweiterte Features:
- `FOSSA_API_KEY` - Für FOSSA Integration
- `DOCKER_REGISTRY_TOKEN` - Für Docker Registry Push

## 🚀 Erweiterte Nutzung

### Standalone Module Usage

Jedes Modul kann auch standalone verwendet werden:

```yaml
# Nur Security Scan
- uses: ./.github/actions/security-scan
  with:
    scan-type: 'secrets'
    token: ${{ secrets.GITHUB_TOKEN }}

# Nur License Check
- uses: ./.github/actions/license-compliance
  with:
    fail-on-forbidden: 'true'
    token: ${{ secrets.GITHUB_TOKEN }}
```

### Custom Integrations

Die Module können in eigene Workflows integriert werden:

```yaml
# Custom CI/CD Pipeline
name: Custom Pipeline
on: [push, pull_request]

jobs:
  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/security-scan
        with:
          fail-on-findings: 'true'
          token: ${{ secrets.GITHUB_TOKEN }}

  license:
    runs-on: ubuntu-latest  
    steps:
      - uses: actions/checkout@v4
      - uses: ./.github/actions/license-compliance
        with:
          scan-dependencies: 'true'
          token: ${{ secrets.GITHUB_TOKEN }}
```

## 📈 Vorteile der neuen Lösung

### ✅ Modularer Aufbau
- **Wiederverwendbarkeit**: Module können in verschiedenen Workflows genutzt werden
- **Wartbarkeit**: Jedes Modul ist eigenständig testbar und erweiterbar
- **Flexibilität**: Konfigurierbare Ein-/Ausschaltung von Features

### 🛡️ Erhöhte Sicherheit
- **Secrets Detection**: Automatische Erkennung von Geheimnissen im Code
- **Vulnerability Scanning**: Überprüfung auf bekannte Sicherheitslücken
- **Security Scoring**: Numerische Bewertung der Sicherheit

### 📋 Compliance & Governance
- **License Compliance**: SPDX-konforme Lizenzprüfung
- **SBOM Generation**: Software Bill of Materials für Supply Chain Security
- **Audit Trails**: Detaillierte Reports für Compliance-Nachweise

### 📦 Professionelle Artefakte
- **Multi-Format Support**: ZIP, TAR.GZ, TAR.XZ Archive
- **Checksum Verification**: SHA256/SHA512/MD5 Checksums
- **Docker Integration**: Automatische Container Image Builds
- **Binary Packaging**: Cross-platform Binary Archives

### 🔄 Automatisierung
- **Smart Auto-Merge**: Intelligentes Merging basierend auf Bedingungen
- **PR Validation**: Automatische Validierung von Pull Requests
- **Semantic Versioning**: Automatische Versionierung basierend auf Conventional Commits

## 🔧 Troubleshooting

### Häufige Probleme

**Security Scan schlägt fehl:**
```bash
# Prüfen Sie die Exclude-Pfade
exclude-paths: '.git,node_modules,vendor,dist'

# Reduzieren Sie die Strenge
fail-on-findings: 'false'
```

**License Check Probleme:**
```bash
# Erweitern Sie die erlaubten Lizenzen
allowed-licenses: 'MIT,Apache-2.0,BSD-2-Clause,BSD-3-Clause,ISC'

# Deaktivieren Sie unbekannte Lizenz-Fails
fail-on-unknown: 'false'
```

**Artifact Generation Issues:**
```bash
# Prüfen Sie die Build-Commands
build-command: 'echo "No build required"'

# Reduzieren Sie Artifact-Types
artifact-types: 'source'
```

### Debug-Modus

Für detailliertes Debugging aktivieren Sie erweiterte Logs:

```yaml
env:
  ACTIONS_STEP_DEBUG: true
  ACTIONS_RUNNER_DEBUG: true
```

## 📚 Weitere Ressourcen

- [Release-Please Documentation](https://github.com/googleapis/release-please)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [SPDX License List](https://spdx.org/licenses/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)

---

**Entwickelt von BAUER GROUP** 🏗️  
*Für Fragen und Support erstellen Sie ein Issue im Repository.*
