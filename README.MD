<!-- AUTO-GENERATED FILE. DO NOT EDIT. Edit docs/README.template.MD instead. -->
<!-- Generated on 2025-08-18 13:56:24 UTC -->

# BAUER GROUP – {{P└── github/workflows/           # Wiederverwendbare Workflows
    ├── readme.yml             # Erweiterte README-Generierung
    ├── release-please.yml     # Release-Please mit automatischen PRs
    └── README.md              # Detaillierte Workflow-DokumentationT_NAME}}

**Status:** Version 0.2.0 (2025-08-18)  
**Repository:** [bauer-group/automation-templates](https://github.com/bauer-group/automation-templates)  
**Branch:** {{CURRENT_BRANCH}}

Zentrale GitHub Actions Templates und Workflows für automatisierte Entwicklungsprozesse

[![Create Release](https://github.com/bauer-group/automation-templates/actions/workflows/release-please.yml/badge.svg)](https://github.com/bauer-group/automation-templates/actions/workflows/release-please.yml)

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

- `0.2.0` - Aktuelle Version (aus Git Tags oder Umgebung)
- `2025-08-18` - Aktuelles Datum (YYYY-MM-DD)
- `2025-08-18 13:56:24 UTC` - Datum und Zeit (YYYY-MM-DD HH:MM:SS UTC)
- `2025` - Aktuelles Jahr

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

*Dieses README wurde automatisch generiert am 2025-08-18 13:56:24 UTC aus [docs/README.template.MD](docs/README.template.MD)*
