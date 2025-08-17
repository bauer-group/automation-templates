# Automation Templates - GitHub Actions

Diese Sammlung bietet professionelle GitHub Actions Templates für moderne Entwicklungsprozesse.

## �️ Architektur

### **Composite Actions (Wiederverwendbare Logik):**
- `.github/actions/readme-generate/` - README-Generator mit umfangreichen Features
- `.github/actions/release-please/` - Release-Management mit semantic versioning

### **Beispiel-Workflows:**
- `examples/readme-example.yml` - README-Update für externe Projekte
- `examples/release-example.yml` - Release-Management für externe Projekte  
- `examples/full-pipeline-example.yml` - Vollständige CI/CD-Pipeline

## 🚀 Schnellstart

### 1. README-Generierung hinzufügen

```yaml
# .github/workflows/readme.yml
name: README Update
on:
  pull_request:
    branches: [ main ]
  workflow_dispatch:
jobs:
  readme:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: bauer-group/automation-templates/.github/actions/readme-generate@main
        with:
          project-name: "Mein Projekt"
          company-name: "Meine Firma"
```

### 2. Release-Management hinzufügen

```yaml
# .github/workflows/release.yml
name: Release
on:
  push:
    branches: [ main ]
jobs:
  release:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: bauer-group/automation-templates/.github/actions/release-please@main
        with:
          release-type: "simple"
```

## 🎯 Features

### � README-Generator
- **40+ Template-Platzhalter** - Umfassende Variablen-Unterstützung
- **Git-Auto-Detection** - Automatische Repository-Informationen
- **Conditional Blocks** - `{{#IF VARIABLE}}content{{/IF}}` Syntax
- **Script-Download** - Immer aktuelle Generator-Version
- **PR-Validierung** - Fails wenn README nicht aktuell

### 🚀 Release-Please
- **Conventional Commits** - Automatische Changelog-Generierung
- **Semantic Versioning** - feat/fix/BREAKING CHANGE Support
- **GitHub Releases** - Automatische Release-Erstellung
- **Flexible Modi** - PR-basiert oder direkte Releases

## 📋 Voraussetzungen

### Für README-Generierung:
- Template-Datei (z.B. `docs/README.template.md`)
- Python wird automatisch installiert

### Für Release-Please:
- Conventional Commit Messages
- Optional: Release-Please Konfigurationsdateien

## 🔧 Konfiguration

### README-Template Beispiel:
```markdown
# {{COMPANY_NAME}} - {{PROJECT_NAME}}

**Version:** {{VERSION}}  
**Repository:** {{REPO_URL}}

{{PROJECT_DESCRIPTION}}

{{#IF BADGE_RELEASE}}
{{BADGE_RELEASE}}
{{/IF}}
```

### Verfügbare Platzhalter:
- `{{VERSION}}` - Aktuelle Version (Git Tag oder 0.1.0)
- `{{DATE}}` - Aktuelles Datum (YYYY-MM-DD)
- `{{REPO_URL}}` - Repository URL
- `{{PROJECT_NAME}}` - Projektname
- `{{COMPANY_NAME}}` - Firmenname
- ... und 35+ weitere

Siehe [README-CONFIGURATION.md](README-CONFIGURATION.md) für vollständige Liste.

## 📁 Repository-Struktur für externe Projekte

```
your-project/
├── .github/
│   └── workflows/
│       ├── readme.yml              # README-Update
│       └── release.yml             # Release-Management
├── docs/
│   └── README.template.md          # README-Template
└── README.md                       # Generierte README
```

## 🌟 Erweiterte Beispiele

Siehe [examples/](examples/) für vollständige Workflow-Beispiele:
- Einfache README-Generierung
- Release-Management Setup
- Vollständige CI/CD-Pipeline mit beiden Features

## 🤝 Contributing

1. Testen Sie Änderungen in einem Feature-Branch
2. Aktualisieren Sie die Dokumentation
3. Erstellen Sie einen Pull Request

## 📞 Support

- **Issues:** [GitHub Issues](https://github.com/bauer-group/automation-templates/issues)
- **Dokumentation:** [README-CONFIGURATION.md](README-CONFIGURATION.md)

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
