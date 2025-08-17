<!-- AUTO-GENERATED FILE. DO NOT EDIT. Edit docs/README.template.MD instead. -->
<!-- Generated on 2025-08-16 23:59:33 UTC -->

# {{COMPANY_NAME}} – {{PROJECT_NAME}}

**Status:** Version 0.1.5 (2025-08-16)  
**Repository:** [bauer-group/automation-templates](https://github.com/bauer-group/automation-templates)  
**Branch:** {{CURRENT_BRANCH}}

{{PROJECT_DESCRIPTION}}

[![Create Release](https://github.com/bauer-group/automation-templates/actions/workflows/release-please.yml/badge.svg)](https://github.com/bauer-group/automation-templates/actions/workflows/release-please.yml)
[![Build](https://github.com/bauer-group/automation-templates/actions/workflows/build.yml/badge.svg)](https://github.com/bauer-group/automation-templates/actions/workflows/build.yml)
[![Security Scan](https://github.com/bauer-group/automation-templates/actions/workflows/security-scan.yml/badge.svg)](https://github.com/bauer-group/automation-templates/actions/workflows/security-scan.yml)

## 🎯 Features

- **Zentralisierte Workflows**: Wiederverwendbare GitHub Actions Templates
- **Automatisches Release-Management**: Semantic Versioning mit Release-Please
- **README-Generierung**: Automatische Erstellung aus Templates mit umfangreichen Platzhaltern
- **Sicherheitsscans**: CodeQL und Trivy Integration
- **Deployment-Pipelines**: Flexible Deployment-Workflows für verschiedene Umgebungen

## 📁 Struktur

```text
├── .github/workflows/          # Caller Workflows (ausführbare Workflows)
│   ├── build.yml              # → ruft github/workflows/build.yml auf
│   ├── deploy.yml             # → ruft github/workflows/deploy.yml auf
│   ├── readme.yml             # → ruft github/workflows/readme.yml auf
│   ├── release.yml            # → ruft github/workflows/release.yml auf
│   ├── release-please.yml     # → ruft github/workflows/release-please.yml auf
│   └── security-scan.yml      # → ruft github/workflows/security-scan.yml auf
│
├── github/workflows/           # Wiederverwendbare Workflows
│   ├── build.yml              # Build-Prozess für verschiedene Sprachen
│   ├── deploy.yml             # Deployment in verschiedene Umgebungen
│   ├── readme.yml             # Erweiterte README-Generierung
│   ├── release.yml            # Release-Management
│   ├── release-please.yml     # Release-Please mit automatischen PRs
│   ├── security-scan.yml      # Sicherheitsanalyse
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

- `0.1.5` - Aktuelle Version (aus Git Tags oder Umgebung)
- `2025-08-16` - Aktuelles Datum (YYYY-MM-DD)
- `2025-08-16 23:59:33 UTC` - Datum und Zeit (YYYY-MM-DD HH:MM:SS UTC)
- `2025` - Aktuelles Jahr

#### Repository-Informationen

- `bauer-group/automation-templates` - Repository Name (owner/repo)
- `https://github.com/bauer-group/automation-templates` - Repository URL
- `bauer-group` - Repository Owner
- `automation-templates` - Repository Name
- `{{CURRENT_BRANCH}}` - Aktueller Branch

#### Projekt-Informationen

- `{{PROJECT_NAME}}` - Projektname
- `{{PROJECT_DESCRIPTION}}` - Projektbeschreibung
- `{{COMPANY_NAME}}` - Firmenname
- `{{CONTACT_EMAIL}}` - Kontakt E-Mail
- `{{DOCUMENTATION_URL}}` - Dokumentations-URL
- `{{SUPPORT_URL}}` - Support-URL

#### Package-Informationen (automatisch erkannt)

- `` - Paketname (aus package.json, etc.)
- `` - Paketversion
- `` - Autor
- `` - Lizenz

#### Workflow-Badges (automatisch generiert)

- `[![Build](https://github.com/bauer-group/automation-templates/actions/workflows/build.yml/badge.svg)](https://github.com/bauer-group/automation-templates/actions/workflows/build.yml)` - Build-Status Badge
- `[![Release](https://github.com/bauer-group/automation-templates/actions/workflows/release-please.yml/badge.svg)](https://github.com/bauer-group/automation-templates/actions/workflows/release-please.yml)` - Release-Status Badge
- `[![Security](https://github.com/bauer-group/automation-templates/actions/workflows/security-scan.yml/badge.svg)](https://github.com/bauer-group/automation-templates/actions/workflows/security-scan.yml)` - Security-Scan Badge
- `[![Deploy](https://github.com/bauer-group/automation-templates/actions/workflows/deploy.yml/badge.svg)](https://github.com/bauer-group/automation-templates/actions/workflows/deploy.yml)` - Deploy-Status Badge

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





**Issues:** [GitHub Issues](https://github.com/bauer-group/automation-templates/issues)

---

*Dieses README wurde automatisch generiert am 2025-08-16 23:59:33 UTC aus [docs/README.template.MD](docs/README.template.MD)*
