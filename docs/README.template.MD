# {{COMPANY_NAME}} – github/workflows/           # Wiederverwendbare Workflows
    ├── readme.yml             # Erweiterte README-Generierung
    ├── release-please.yml     # Release-Please mit automatischen PRs
    └── README.md              # Detaillierte Workflow-DokumentationT_NAME}}

**Status:** Version {{VERSION}} ({{DATE}})  
**Repository:** [{{REPO_FULL_NAME}}]({{REPO_URL}})  
**Branch:** {{CURRENT_BRANCH}}

{{PROJECT_DESCRIPTION}}

[![Create Release]({{REPO_URL}}/actions/workflows/release-please.yml/badge.svg)]({{REPO_URL}}/actions/workflows/release-please.yml)

## 🎯 Features

- **Wiederverwendbare Workflows**: Zentralisierte GitHub Actions Templates
- **Automatisches Release-Management**: Semantic Versioning mit Release-Please
- **README-Generierung**: Automatische Erstellung aus Templates mit umfangreichen Platzhaltern
- **Template-System**: Extensibles Template-System mit 40+ Platzhaltern

## 📁 Struktur

```text
├── .github/workflows/          # Caller Workflows (ausführbare Workflows)
│   ├── readme.yml             # → ruft github/workflows/readme.yml auf
│   └── release-please.yml     # → ruft github/workflows/release-please.yml auf
│
├── github/workflows/           # Wiederverwendbare Workflows
│   ├── readme.yml             # Erweiterte README-Generierung
│   ├── release-please.yml     # Release-Please mit automatischen PRs
│   └── README.md              # Detaillierte Workflow-Dokumentation
│
├── docs/                      # Dokumentation und Templates
│   └── README.template.MD     # README-Template mit Platzhaltern
│
└── scripts/                   # Automatisierungs-Skripte
    └── generate_readme.py     # Erweiterter README-Generator
```

## 🚀 Verwendung

### README-Template System

Das README-Template-System unterstützt zahlreiche Platzhalter:

#### Basis-Informationen

- `{{VERSION}}` - Aktuelle Version (aus Git Tags oder Umgebung)
- `{{DATE}}` - Aktuelles Datum (YYYY-MM-DD)
- `{{DATETIME}}` - Datum und Zeit (YYYY-MM-DD HH:MM:SS UTC)
- `{{YEAR}}` - Aktuelles Jahr

#### Repository-Informationen

- `{{REPO_FULL_NAME}}` - Repository Name (owner/repo)
- `{{REPO_URL}}` - Repository URL
- `{{REPO_OWNER}}` - Repository Owner
- `{{REPO_NAME}}` - Repository Name
- `{{CURRENT_BRANCH}}` - Aktueller Branch

#### Projekt-Informationen

- `{{PROJECT_NAME}}` - Projektname
- `{{PROJECT_DESCRIPTION}}` - Projektbeschreibung
- `{{COMPANY_NAME}}` - Firmenname
- `{{CONTACT_EMAIL}}` - Kontakt E-Mail
- `{{DOCUMENTATION_URL}}` - Dokumentations-URL
- `{{SUPPORT_URL}}` - Support-URL

#### Package-Informationen (automatisch erkannt)

- `{{PACKAGE_NAME}}` - Paketname (aus package.json, etc.)
- `{{PACKAGE_VERSION}}` - Paketversion
- `{{PACKAGE_AUTHOR}}` - Autor
- `{{PACKAGE_LICENSE}}` - Lizenz

#### Workflow-Badges (automatisch generiert)

- `{{BADGE_RELEASE}}` - Release-Status Badge

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
    uses: {{REPO_FULL_NAME}}/github/workflows/readme.yml@main
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

{{#IF CONTACT_EMAIL}}
**Kontakt:** [{{CONTACT_EMAIL}}](mailto:{{CONTACT_EMAIL}})
{{/IF}}

{{#IF SUPPORT_URL}}
**Support:** [{{SUPPORT_URL}}]({{SUPPORT_URL}})
{{/IF}}

**Issues:** [GitHub Issues]({{REPO_URL}}/issues)

---

*Dieses README wurde automatisch generiert am {{DATETIME}} aus [docs/README.template.MD](docs/README.template.MD)*
