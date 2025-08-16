# Wiederverwendbare GitHub Workflows

Dieses Repository enthält eine Sammlung von wiederverwendbaren GitHub Actions Workflows, die in anderen Projekten eingesetzt werden können.

## Struktur

### 📁 `github/workflows/` (Wiederverwendbare Workflows)
Enthält die eigentlichen wiederverwendbaren Workflow-Definitionen:
- `build.yml` - Build-Prozess für Node.js Projekte
- `deploy.yml` - Deployment in verschiedene Umgebungen
- `readme.yml` - Automatische README-Generierung
- `release.yml` - Release-Management mit semantic versioning
- `release-please.yml` - Release-Please Workflow für automatische PRs und Releases
- `security-scan.yml` - Sicherheitsscans (CodeQL, Trivy)

### 📁 `.github/workflows/` (Caller Workflows)
Enthält die Caller-Workflows, die die wiederverwendbaren Workflows aufrufen:
- `build.yml` - Ruft `github/workflows/build.yml` auf
- `deploy.yml` - Ruft `github/workflows/deploy.yml` auf
- `readme.yml` - Ruft `github/workflows/readme.yml` auf
- `release.yml` - Ruft `github/workflows/release.yml` auf
- `release-please.yml` - Ruft `github/workflows/release-please.yml` auf
- `security-scan.yml` - Ruft `github/workflows/security-scan.yml` auf
- `release-please.yml` - Bestehender Release-Please Workflow

## Verwendung in anderen Projekten

### Option 1: Direkte Verwendung der wiederverwendbaren Workflows

```yaml
name: Build
on:
  push:
    branches: [ main ]

jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/build.yml@main
    with:
      node-version: "18"
      run-tests: true
    secrets:
      NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
```

### Option 2: Lokale Anpassung

1. Kopieren Sie die gewünschten Workflows aus `github/workflows/` in Ihr Projekt
2. Passen Sie sie nach Bedarf an
3. Erstellen Sie eigene Caller-Workflows in `.github/workflows/`

## Verfügbare Workflows

### 🔨 Build Workflow
- **Datei**: `github/workflows/build.yml`
- **Zweck**: Node.js Build-Prozess mit Tests
- **Parameter**:
  - `node-version`: Node.js Version (Standard: "20")
  - `run-tests`: Tests ausführen (Standard: true)
- **Secrets**:
  - `NPM_TOKEN`: Optional für private NPM Registry

### 🚀 Deploy Workflow
- **Datei**: `github/workflows/deploy.yml`
- **Zweck**: Deployment in verschiedene Umgebungen
- **Parameter**:
  - `environment`: Zielumgebung (staging|production)
- **Secrets**:
  - `DEPLOY_TOKEN`: Deployment-Credentials (erforderlich)

### 📖 README Workflow
- **Datei**: `github/workflows/readme.yml`
- **Zweck**: Automatische README-Generierung
- **Trigger**: Pull Requests und manuelle Ausführung
- **Features**:
  - Generiert README aus Template
  - Validiert bei PRs
  - Committet automatisch bei manueller Ausführung

### 🏷️ Release Workflow
- **Datei**: `github/workflows/release.yml`
- **Zweck**: Automatisches Release-Management
- **Parameter**:
  - `direct_release`: Direktes Release ohne PR
  - `release_as`: Spezifische Versionsnummer
  - `package_name`: Name des Pakets
- **Features**:
  - Semantic Versioning
  - Release Notes
  - GitHub Releases

### 🤖 Release-Please Workflow
- **Datei**: `github/workflows/release-please.yml`
- **Zweck**: Automatische Release-PRs und Releases mit release-please
- **Parameter**:
  - `target-branch`: Ziel-Branch für Releases (Standard: "main")
  - `package-name`: Name des Pakets (Standard: Repository-Name)
  - `release-type`: Release-Typ (simple, node, python, etc.)
  - `direct-release`: Direktes Release ohne PR (Standard: false)
  - `config-file`: Pfad zur release-please Konfiguration
  - `manifest-file`: Pfad zum release-please Manifest
- **Features**:
  - Automatische Release-PRs basierend auf Conventional Commits
  - Semantic Versioning ohne "v" Präfix
  - Wahlweise direkte Releases
  - Konfigurierbare Changelog-Sections
  - Unterstützung für verschiedene Release-Typen

### 🔒 Security Scan Workflow
- **Datei**: `github/workflows/security-scan.yml`
- **Zweck**: Sicherheitsanalyse
- **Parameter**:
  - `enable-codeql`: CodeQL Analyse aktivieren
  - `enable-trivy`: Trivy Container-Scan aktivieren
- **Features**:
  - CodeQL für JavaScript/TypeScript
  - Trivy für Container-Sicherheit

## Best Practices

1. **Versionierung**: Verwenden Sie Tags oder Branches für stabile Versionen
2. **Secrets**: Definieren Sie Secrets auf Repository- oder Organization-Ebene
3. **Permissions**: Setzen Sie minimale erforderliche Permissions
4. **Dokumentation**: Dokumentieren Sie alle Parameter und Secrets
5. **Testing**: Testen Sie Workflows in Feature-Branches vor dem Merge

## Beispiel-Integration

```yaml
# .github/workflows/ci.yml
name: CI/CD Pipeline

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  build:
    uses: bauer-group/automation-templates/.github/workflows/build.yml@main
    with:
      node-version: "20"
      run-tests: true

  security:
    uses: bauer-group/automation-templates/.github/workflows/security-scan.yml@main
    with:
      enable-codeql: true
      enable-trivy: false

  deploy-staging:
    if: github.ref == 'refs/heads/develop'
    needs: [build, security]
    uses: bauer-group/automation-templates/.github/workflows/deploy.yml@main
    with:
      environment: staging
    secrets:
      DEPLOY_TOKEN: ${{ secrets.STAGING_DEPLOY_TOKEN }}

  deploy-production:
    if: github.ref == 'refs/heads/main'
    needs: [build, security]
    uses: bauer-group/automation-templates/.github/workflows/deploy.yml@main
    with:
      environment: production
    secrets:
      DEPLOY_TOKEN: ${{ secrets.PRODUCTION_DEPLOY_TOKEN }}
```

## Contribution

Bei Änderungen an den wiederverwendbaren Workflows:
1. Erstellen Sie einen Feature-Branch
2. Testen Sie die Änderungen
3. Aktualisieren Sie diese Dokumentation
4. Erstellen Sie einen Pull Request

## Support

Bei Fragen oder Problemen erstellen Sie bitte ein Issue in diesem Repository.

## Release-Please Beispiel

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    branches: [ main ]
  workflow_dispatch:
    inputs:
      direct-release:
        description: "Create direct release"
        type: boolean
        default: false

jobs:
  release:
    uses: bauer-group/automation-templates/github/workflows/release-please.yml@main
    with:
      target-branch: "main"
      package-name: "my-awesome-project" 
      release-type: "node"
      direct-release: ${{ inputs.direct-release || false }}
    secrets:
      RELEASE_PLEASE_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

**Wichtige Konfiguration für Tags ohne Versionsnummer:**

Die `release-please-config.json` ist so konfiguriert, dass:
- `include-v-in-tag: false` - Keine "v" Präfixe (z.B. `1.0.0` statt `v1.0.0`)
- `include-component-in-tag: false` - Keine Komponenten-Namen in Tags
