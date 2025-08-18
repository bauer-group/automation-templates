# 🚀 Automation Templates - Workflows & Actions

**Zentrale GitHub Actions und Workflows für automatisierte Entwicklungsprozesse**

## 🏗️ Architektur

```
├── .github/
│   ├── actions/                    # 🔧 Wiederverwendbare Composite Actions
│   │   ├── readme-generate/       # 📄 README-Generator
│   │   └── release-please/        # 🚀 Release-Management
│   │
│   └── workflows/                  # 🎯 Lokale Workflows (für dieses Repository)
│       ├── readme.yml             # → nutzt lokale Action
│       └── release.yml            # → nutzt lokale Action
│
└── github/workflows/              # 📚 Für externe Repositories
    ├── readme.yml                 # 🔄 Wiederverwendbarer README-Workflow
    ├── release-please.yml         # 🔄 Wiederverwendbarer Release-Workflow
    └── examples/                  # 📋 Kopierbare Beispiele
        ├── readme-example.yml
        ├── release-example.yml
        └── full-pipeline-example.yml
```

## 🎯 Verwendung

### 🔧 Composite Actions (Empfohlen)

Für maximale Flexibilität verwende die Composite Actions direkt:

```yaml
- name: Generate README
  uses: bauer-group/automation-templates/.github/actions/readme-generate@main
  with:
    project-name: "Mein Projekt"
    company-name: "Meine Firma"

- name: Release Please
  uses: bauer-group/automation-templates/.github/actions/release-please@main
  with:
    release-type: "simple"
    token: ${{ secrets.GITHUB_TOKEN }}
```

### 🔄 Wiederverwendbare Workflows

Für komplette Workflow-Orchestrierung:

```yaml
jobs:
  readme:
    uses: bauer-group/automation-templates/github/workflows/readme.yml@main
    with:
      project-name: "Mein Projekt"
      
  release:
    uses: bauer-group/automation-templates/github/workflows/release-please.yml@main
    with:
      release-type: "simple"
```

## 📄 README-Generator

### Features:
- ✅ 40+ Template-Platzhalter
- ✅ Automatische Git-Repository-Erkennung
- ✅ Package.json/pyproject.toml Auto-Detection
- ✅ Workflow-Status-Badges
- ✅ Conditional Template-Blöcke
- ✅ Script-Download-Mechanismus

### Verfügbare Platzhalter:

#### Basis-Informationen:
- `{{VERSION}}` - Git Tag oder Umgebungsvariable
- `{{DATE}}` - Aktuelles Datum (YYYY-MM-DD)
- `{{DATETIME}}` - Datum und Zeit (YYYY-MM-DD HH:MM:SS UTC)
- `{{YEAR}}` - Aktuelles Jahr

#### Repository-Informationen:
- `{{REPOSITORY}}` - owner/repo
- `{{REPOSITORY_URL}}` - GitHub URL
- `{{REPOSITORY_OWNER}}` - Repository Owner
- `{{REPOSITORY_NAME}}` - Repository Name
- `{{CURRENT_BRANCH}}` - Aktueller Branch

#### Projekt-Informationen:
- `{{PROJECT_NAME}}` - Projektname
- `{{PROJECT_DESCRIPTION}}` - Projektbeschreibung
- `{{COMPANY_NAME}}` - Firmenname
- `{{CONTACT_EMAIL}}` - Kontakt E-Mail
- `{{DOCUMENTATION_URL}}` - Dokumentations-URL
- `{{SUPPORT_URL}}` - Support-URL

## 🚀 Release-Management

### Features:
- ✅ **Release-Please** Integration
- ✅ **Conventional Commits** Support
- ✅ **Semantic Versioning**
- ✅ Automatische GitHub Releases
- ✅ Changelog-Generierung
- ✅ Flexible Release-Types

### Unterstützte Commit-Types:
- `feat:` → Minor Version Bump
- `fix:` → Patch Version Bump
- `feat!:` oder `BREAKING CHANGE:` → Major Version Bump
- `docs:`, `chore:`, `ci:`, `refactor:` → Keine Version-Änderung

### Release-Types:
- `simple` - Einfache Projekte ohne Package-Management
- `node` - Node.js Projekte (package.json)
- `python` - Python Projekte (pyproject.toml, setup.py)
- `rust` - Rust Projekte (Cargo.toml)
- `java` - Java Projekte
- `go` - Go Module

## 📋 Schnellstart

### 1. README-Template erstellen:

```markdown
<!-- docs/README.template.md -->
# {{PROJECT_NAME}}

**{{PROJECT_DESCRIPTION}}**

Version: {{VERSION}} | Datum: {{DATE}}

Repository: [{{REPOSITORY}}]({{REPOSITORY_URL}})
```

### 2. Workflow hinzufügen:

Kopiere `examples/readme-example.yml` oder `examples/release-example.yml` in dein `.github/workflows/` Verzeichnis.

### 3. Konfigurieren:

Passe die Parameter in den Workflow-Dateien an deine Bedürfnisse an.

## 🔧 Erweiterte Konfiguration

### README-Generator mit Custom Script:

```yaml
- name: Custom README Generation
  uses: bauer-group/automation-templates/.github/actions/readme-generate@main
  with:
    template-path: "custom/template.md"
    output-path: "docs/generated.md"
    project-name: ${{ env.PROJECT_NAME }}
```

### Release-Please mit Custom Config:

```yaml
- name: Custom Release
  uses: bauer-group/automation-templates/.github/actions/release-please@main
  with:
    release-type: "node"
    package-name: "@company/my-package"
    bump-minor-pre-major: false
```

## 🛠️ Entwicklung

### Lokale Tests:

```bash
# README lokal generieren
python scripts/generate_readme.py

# Mit Custom-Umgebungsvariablen
PROJECT_NAME="Test" COMPANY_NAME="Test Corp" python scripts/generate_readme.py
```

### Action-Updates:

Änderungen an den Composite Actions werden automatisch für alle Nutzer verfügbar, da sie immer die `@main` Version verwenden.

## 📞 Support

- **Issues:** [GitHub Issues](https://github.com/bauer-group/automation-templates/issues)
- **Diskussionen:** [GitHub Discussions](https://github.com/bauer-group/automation-templates/discussions)
- **Wiki:** [Detaillierte Dokumentation](https://github.com/bauer-group/automation-templates/wiki)

## 🔄 Migration

### Von v0.1.x zu v0.2.x:

Die neuen Composite Actions sind abwärtskompatibel. Bestehende Workflows funktionieren weiterhin, aber für neue Projekte wird die Verwendung der Composite Actions empfohlen.

```yaml
# Alt (funktioniert weiterhin):
uses: bauer-group/automation-templates/github/workflows/readme.yml@main

# Neu (empfohlen):
uses: bauer-group/automation-templates/.github/actions/readme-generate@main
```

---

**Diese Workflows folgen GitHub Actions Best Practices und sind production-ready! 🌟**
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
