# Wiederverwendbare GitHub Workflows

Diese Sammlung bietet professionelle, wiederverwendbare GitHub Actions Workflows für moderne Entwicklungsprozesse.

## 🎯 Verfügbare Workflows

### 📄 README Auto-Update (`readme.yml`)

Erweiterte README-Generierung aus Templates mit umfangreichen Platzhaltern und automatischer Repository-Information.

**Trigger:**
- Pull Requests (Validierung)
- Manual dispatch (Generierung + Commit)
- Workflow calls (wiederverwendbar)

**Key Features:**
- 🔄 **Script-Download**: Lädt automatisch die neueste Version des Generator-Scripts
- 📝 **40+ Template-Platzhalter**: Umfassende Variablen-Unterstützung  
- 🔍 **Git-Auto-Detection**: Automatische Repository-Informationen
- 📦 **Package Integration**: Support für package.json, requirements.txt
- 🏷️ **Workflow-Badges**: Automatische Badge-Generierung
- ⚡ **Conditional Blocks**: `{{#IF VARIABLE}}content{{/IF}}` Syntax
- ✅ **PR-Validierung**: Fails wenn README nicht aktuell
- 🤖 **Auto-Commit**: Bei manueller Ausführung

### 🚀 Release Please (`release-please.yml`)

Automatisches Release-Management mit semantic versioning und GitHub Releases.

**Trigger:**
- Workflow calls (wiederverwendbar)

**Key Features:**
- 📋 **Conventional Commits**: Automatische Changelog-Generierung
- 🏷️ **Semantic Versioning**: feat/fix/BREAKING CHANGE Support
- 📦 **GitHub Releases**: Automatische Release-Erstellung
- 🔄 **Flexible Modi**: PR-basiert oder direkte Releases
- ⚙️ **Konfigurierbar**: Custom Release-Typen und Pakete

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
