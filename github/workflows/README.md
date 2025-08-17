# Wiederverwendbare GitHub Workflows

Dieses Repository enthält eine Sammlung von wiederverwendbaren GitHub Actions Workflows, die in anderen Projekten eingesetzt werden können.

## Struktur

### 📁 `github/workflows/` (Wiederverwendbare Workflows)
Enthält die eigentlichen wiederverwendbaren Workflow-Definitionen:
- `readme.yml` - Professionelle README-Generierung aus Templates
- `release.yml` - Release-Management mit semantic versioning
- `release-please.yml` - Release-Please Workflow für automatische PRs und Releases

### 📁 `.github/workflows/` (Caller Workflows)
Enthält die Caller-Workflows, die die wiederverwendbaren Workflows aufrufen:
- `readme.yml` - Ruft `github/workflows/readme.yml` auf
- `release-please.yml` - Ruft `github/workflows/release-please.yml` auf

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

###  README Workflow

- **Datei**: `github/workflows/readme.yml`
- **Zweck**: Professionelle README-Generierung aus Templates
- **Parameter**:
  - `template-path`: Pfad zur README-Template-Datei (Standard: "docs/README.template.MD")
  - `output-path`: Pfad zur Ausgabe-README-Datei (Standard: "README.MD")
  - `python-version`: Python-Version (Standard: "3.12")
  - `commit-message`: Commit-Message für README-Updates
  - `fail-on-pr`: PR fehlschlagen lassen, wenn README veraltet ist
  - `auto-commit`: Automatisches Committen bei workflow_dispatch
  - `project-name`: Projektname (überschreibt automatische Erkennung)
  - `project-description`: Projektbeschreibung
  - `company-name`: Firmenname
  - `contact-email`: Kontakt E-Mail
  - `documentation-url`: Dokumentations-URL
  - `support-url`: Support-URL
- **Outputs**:
  - `readme-updated`: Ob README aktualisiert wurde
  - `version-used`: Verwendete Version
- **Features**:
  - Umfangreiche Platzhalter-Unterstützung ({{VERSION}}, {{DATE}}, {{REPO_URL}}, etc.)
  - Automatische Repository-Informationen-Erkennung
  - Package.json Integration
  - Workflow-Badges-Generierung
  - Bedingte Blöcke: {{#IF VARIABLE}}content{{/IF}}
  - GitHub API Integration für Contributors
  - Fehlerbehandlung und Validierung
  - Fallback-Implementierung für fehlende Scripts

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
  readme-update:
    uses: bauer-group/automation-templates/github/workflows/readme.yml@main
    with:
      project-name: "Mein Projekt"
      company-name: "Meine Firma"
      project-description: "Beschreibung meines Projekts"

  release:
    if: github.ref == 'refs/heads/main'
    uses: bauer-group/automation-templates/github/workflows/release-please.yml@main
    with:
      target-branch: "main"
      package-name: "mein-projekt"
      release-type: "simple"
```
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
